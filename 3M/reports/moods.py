import os
import subprocess
import numpy as np
import pandas as pd
import tempfile
import tqdm

def export_motifs(pfms, out_dir):
    """
    Exports motifs to an output directory as PFMs for MOODS.
    Arguments:
        `pfms`: a dictionary mapping keys to N x 4 NumPy arrays (N may be
            different for each PFM); `{key}.pfm` will be the name of each saved
            motif
        `out_dir`: directory to save each motif
    """
    for key, pfm in pfms.items():
        outfile = os.path.join(out_dir, "%s.pfm" % key)
        with open(outfile, "w") as f:
            for i in range(4):
                f.write(" ".join([str(x) for x in pfm[:, i]]) + "\n")


def run_moods(out_dir, reference_fasta, pval_thresh=0.0001):
    """
    Runs MOODS on every `.pfm` file in `out_dir`. Outputs the results for each
    PFM into `out_dir/moods_out.csv`.
    Arguments:
        `out_dir`: directory with PFMs
        `reference_fasta`: path to reference Fasta to use
        `pval_thresh`: threshold p-value for MOODS to use
    """
    procs = []
    pfm_files = [p for p in os.listdir(out_dir) if p.endswith(".pfm")]
    comm = ["moods-dna.py"]
    comm += ["-m"]
    comm += [os.path.join(out_dir, pfm_file) for pfm_file in pfm_files]
    comm += ["-s", reference_fasta]
    comm += ["-p", str(pval_thresh)]
    comm += ["-o", os.path.join(out_dir, "moods_out.csv")]
    proc = subprocess.Popen(comm)
    proc.wait()


def moods_hits_to_bed(moods_out_csv_path, moods_out_bed_path):
    """
    Converts MOODS hits into BED file.
    """
    f = open(moods_out_csv_path, "r")
    g = open(moods_out_bed_path, "w")
    warn = True
    for line in f:
        tokens = line.split(",")
        try:
            # The length of the interval is the length of the motif
            g.write("\t".join([
                tokens[0].split()[0], tokens[2],
                str(int(tokens[2]) + len(tokens[5])), tokens[1][:-4], tokens[3],
                tokens[4]
            ]) + "\n")
        except ValueError:
            # If a line is formatted incorrectly, skip it and warn once
            if warn:
                print("Found bad line: " + line)
                warn = False
            pass
        # Note: depending on the Fasta file and version of MOODS, only keep the
        # first token of the "chromosome"
    f.close()
    g.close()


def filter_hits_for_peaks(
    moods_out_bed_path, filtered_hits_path, peak_bed_path
):
    """
    Filters MOODS hits for only those that overlap a particular set of peaks.
    `peak_bed_path` must be a BED file; only the first 3 columns are used.
    A new column is added to the resulting hits: the index of the peak in
    `peak_bed_path`. If `peak_bed_path` has repeats, the later index is kept.
    """
    # First filter using bedtools intersect, keeping track of matches
    temp_file = filtered_hits_path + ".tmp"
    comm = ["bedtools", "intersect"]
    comm += ["-wa", "-wb"]
    comm += ["-a", moods_out_bed_path]
    comm += ["-b", peak_bed_path]
    with open(temp_file, "w") as f:
        proc = subprocess.Popen(comm, stdout=f)
        proc.wait()

    # Create mapping of peaks to indices in `peak_bed_path`
    peak_table = pd.read_csv(
        peak_bed_path, sep="\t", header=None, index_col=False,
        usecols=[0, 1, 2], names=["chrom", "start", "end"]
    )
    peak_keys = (
        peak_table["chrom"] + ":" + peak_table["start"].astype(str) + "-" + \
        peak_table["end"].astype(str)
    ).values
    peak_index_map = {k : str(i) for i, k in enumerate(peak_keys)}

    # Convert last three columns to peak index
    f = open(temp_file, "r")
    g = open(filtered_hits_path, "w")
    for line in f:
        tokens = line.strip().split("\t")
        g.write("\t".join((tokens[:-3])))
        peak_index = peak_index_map["%s:%s-%s" % tuple(tokens[-3:])]
        g.write("\t" + peak_index + "\n")
    f.close()
    g.close()


def collapse_hits(filtered_hits_path, collapsed_hits_path, pfm_keys):
    """
    Collapses hits by merging instances of the same motif that overlap.
    """
    # For each PFM key, merge all its hits, collapsing strand, score, and peak
    # index
    temp_file = collapsed_hits_path + ".tmp"
    f = open(temp_file, "w")  # Clear out the file
    f.close()
    with open(temp_file, "a") as f:
        for pfm_key in pfm_keys:
            comm = ["cat", filtered_hits_path]
            comm += ["|", "awk", "'$4 == \"%s\"'" % pfm_key]
            comm += ["|", "bedtools", "sort"]
            comm += [
                "|", "bedtools", "merge",
                "-c", "4,5,6,7", "-o", "distinct,collapse,collapse,collapse"
            ]
            proc = subprocess.Popen(" ".join(comm), shell=True, stdout=f)
            proc.wait()

    # For all collapsed instances, pick the instance with the best score
    f = open(temp_file, "r")
    g = open(collapsed_hits_path, "w")
    for line in f:
        if "," in line:
            tokens = line.strip().split("\t")
            g.write("\t".join(tokens[:4]))
            scores = [float(x) for x in tokens[5].split(",")]
            i = np.argmax(scores)
            g.write(
                "\t" + tokens[4].split(",")[i] + "\t" + str(scores[i]) + \
                "\t" + tokens[6].split(",")[i] + "\n"
            )
        else:
            g.write(line)

    f.close()
    g.close()


def import_moods_hits(hits_bed):
    """
    Imports the MOODS hits as a single Pandas DataFrame. `pfm_lengths` is a
    dictionary mapping PFM key to PFM length.
    Returns a Pandas DataFrame with the columns: chrom, start, end, key, strand,
    score, peak_index.
    `key` is the name of the originating PFM, and `length` is its length.
    """
    # Create dictionary mapping PFM key to length
    hit_table = pd.read_csv(
        hits_bed, sep="\t", header=None, index_col=False,
        names=["chrom", "start", "end", "key", "strand", "score", "peak_index"]
    )
    return hit_table


def test_moods_hits(
    hit_table, shap_scores_hdf5_path, null_shap_scores_hdf5_path
):
    """
    Filters MOODS hits for only significant hits based on importance score
    thresholding.
    Arguments:
        `hit_table`: table of MOODS hits as returned by `import_moods_hits`
        `shap_scores_hdf5_path`: an HDF5 of DeepSHAP scores of peak regions
            measuring importance
        `null_shap_scores_hdf5_path`: an HDF5 of null DeepSHAP scores of peak
            regions measuring importance
    Each of the DeepSHAP score HDF5s must be of the form:
        `coords_chrom`: N-array of chromosome (string)
        `coords_start`: N-array
	`coords_end`: N-array
	`hyp_scores`: N x L x 4 array of hypothetical importance scores
	`input_seqs`: N x L x 4 array of one-hot encoded input sequences
    Returns a reduced hit table of the same format.
    """


def get_moods_hits(
    pfm_dict, reference_fasta, peak_bed_path, expand_peak_length=None,
    pval_thresh=0.0001, temp_dir=None
):
    """
    From a dictionary of PFMs, runs MOODS and returns the result as a Pandas
    DataFrame.
    Arguments:
        `pfm_dict`: a dictionary mapping keys to N x 4 NumPy arrays (N may be
            different for each PFM); the key will be the name of each motif
        `reference_fasta`: path to reference Fasta to use
        `peak_bed_path`: path to peaks BED file; only keeps MOODS hits from
            these intervals; must be in NarrowPeak format
        `expand_peak_length`: if given, expand the peaks (centered at summits)
            to this length
        `pval_thresh`: threshold p-value for MOODS to use
        `temp_dir`: a temporary directory to store intermediates; defaults to
            a randomly created directory
    """
    if temp_dir is None:
        temp_dir_obj = tempfile.TemporaryDirectory()
        temp_dir = temp_dir_obj.name
    else:
        os.makedirs(temp_dir, exist_ok=True)
        temp_dir_obj = None

    pfm_keys = list(pfm_dict.keys())
    
    # Create PFM files
    export_motifs(pfm_dict, temp_dir)

    # Run MOODS
    run_moods(temp_dir, reference_fasta)

    # Convert MOODS output into BED file
    moods_hits_to_bed(
        os.path.join(temp_dir, "moods_out.csv"),
        os.path.join(temp_dir, "moods_out.bed")
    )

    # If needed, expand peaks to given length
    if expand_peak_length:
        peaks_table = pd.read_csv(
            peak_bed_path, sep="\t", header=None, index_col=False,
            usecols=[0, 1, 2, 9],
            names=["chrom", "start", "end", "summit_offset"]
        )
        peaks_table["start"] = \
            (peaks_table["start"] + peaks_table["summit_offset"]) - \
            (expand_peak_length // 2)
        peaks_table["end"] = peaks_table["start"] + expand_peak_length
        peaks_table[["chrom", "start", "end"]].to_csv(
            os.path.join(temp_dir, "peaks_expanded.bed"), sep="\t",
            header=False, index=False
        )
        peak_bed_path = os.path.join(temp_dir, "peaks_expanded.bed")
    
    # Filter hits for those that overlap peaks
    filter_hits_for_peaks(
        os.path.join(temp_dir, "moods_out.bed"),
        os.path.join(temp_dir, "moods_filtered.bed"),
        peak_bed_path
    )

    collapse_hits(
        os.path.join(temp_dir, "moods_filtered.bed"),
        os.path.join(temp_dir, "moods_filtered_collapsed.bed"),
        pfm_keys
    )

    hit_table = import_moods_hits(
        os.path.join(temp_dir, "moods_filtered_collapsed.bed")
    )

    if temp_dir_obj is not None:
        temp_dir_obj.cleanup()

    return hit_table
