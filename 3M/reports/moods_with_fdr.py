import os
import subprocess
import numpy as np
import pandas as pd
import tempfile
import statsmodels.stats.multitest as mc
import statistics
from statsmodels.distributions.empirical_distribution import ECDF
import h5py

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
    pfm_files = [p for p in os.listdir(out_dir) if p.endswith("pfm")]
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
    
        
def resize_peaks(peaks_path, resized_peak_path, input_seq_len):
    """
    resize peaks to input length for the bpnet model, so that motifs can be searched 
    in all of the input sequence to the model.
    """
    peak_table = pd.read_csv(peaks_path, sep='\t', header=None)
    peak_table = peak_table[[0, 1, 2, 9]]
    peak_table.columns = ['chrom', 'start', 'end', 'summit']
    peak_table['old_start'] = peak_table['start']
    peak_table['start'] = peak_table['old_start'] + peak_table['summit'] - (input_seq_len // 2)
    peak_table['end'] = peak_table['old_start'] + peak_table['summit'] + (input_seq_len // 2)
    peak_table.to_csv(resized_peak_path,sep='\t',header=False,index=False)
    return True



def filter_hits_for_peaks(moods_out_bed_path, filtered_hits_path, peak_bed_path):
    """
    Filters MOODS hits for only those that overlap a particular set of peaks.
    """
    comm = ["bedtools", "intersect"]
    comm += ["-wa"]
    comm += ["-wb"]
    comm += ["-a", moods_out_bed_path]
    comm += ["-b", peak_bed_path]
    with open(filtered_hits_path, "w") as f:
        proc = subprocess.Popen(comm, stdout=f)
        proc.wait()


def collapse_hits(filtered_hits_path, collapsed_hits_path, pfm_keys):
    """
    Collapses hits by merging instances of the same motif that overlap.
    """
    # For each PFM key, merge all its hits, collapsing strand and score
    temp_file = collapsed_hits_path + ".tmp"
    f = open(temp_file, "w")  # Clear out the file
    f.close()
    with open(temp_file, "a") as f:
        for pfm_key in pfm_keys:
            comm = ["cat", filtered_hits_path]
            comm += ["|", "awk", "'{peak=$7\"_\"$8\"_\"$9;print $1\"\t\"$2\"\t\"$3\"\t\"$4\"\t\"$5\"\t\"$6\"\t\"peak}'"]
            comm += ["|", "awk", "'$4 == \"%s\"'" % pfm_key]
            comm += ["|", "sort", "-k1,1", "-k2,2n", "-t'\t'"]
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
            scores = [float(x) for x in tokens[5].split(",")]
            peaks = [str(x) for x in tokens[6].split(",")]
            peaks_set = set(peaks)
            chr_to_motif = tokens[:4]
            strand = tokens[4]
            for peak in peaks_set:
                g.write("\t".join(chr_to_motif))
                i = np.argmax(scores)
                g.write(
                    "\t" + strand.split(",")[i] + "\t" + str(scores[i]) + "\t" + str(peak) + "\n"
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
    score.
    `key` is the name of the originating PFM, and `length` is its length.
    """
    # Create dictionary mapping PFM key to length
    hit_table = pd.read_csv(
        hits_bed, sep="\t", header=None, index_col=False,
        names=["chrom", "start", "end", "key", "strand", "score","peak_name"]
    )
    return hit_table


def import_peaks(peaks_bed,input_seq_len):
    """
    Imports the peaks as a single Pandas DataFrame.
    Returns a Pandas DataFrame with the columns: peak_chrom, peak_start, peak_end, 
    peak_summit, peak_index, peaks_name.
    """
    # Create dictionary mapping PFM key to length
    peak_table = pd.read_csv(peaks_bed, sep='\t', header=None, index_col=False)
    peak_table = peak_table[[0, 1, 2, 9]]
    peak_table = peak_table.reset_index()
    peak_table.columns = ['peak_index', 'peak_chrom', 'peak_start', 'peak_end', 'peak_summit']
    peak_table = peak_table[['peak_chrom', 'peak_start', 'peak_end', 'peak_summit', 'peak_index']]
    h5_start = peak_table['peak_start'] + peak_table['peak_summit'] - (input_seq_len//2)
    h5_end = peak_table['peak_start'] + peak_table['peak_summit'] + (input_seq_len//2)
    peak_table['peak_name'] = peak_table['peak_chrom'] + '_' + h5_start.astype(str) + '_' + h5_end.astype(str)
    
    return peak_table

def merge_peaks_moods_hits(peak_table,motif_table,input_seq_len):
    """
    Merges the peaks and motif hits into a single Pandas DataFrame based on peak_name.
    Returns a Pandas DataFrame with the columns: chrom, start, end, summit, peak_index, peaks_name.
    """
    merged_table = motif_table.merge(peak_table, on=['peak_name'])
    merged_table['motif_local_start_peak_coord'] = merged_table['start'] - merged_table['peak_start']
    merged_table['motif_local_end_peak_coord'] = merged_table['end'] - merged_table['peak_start']
    merged_table['motif_local_start_h5_coord'] = merged_table['start'] - (merged_table['peak_start'] + merged_table['peak_summit'] - (input_seq_len // 2))
    merged_table['motif_local_end_h5_coord'] = merged_table['end'] - (merged_table['peak_start'] + merged_table['peak_summit'] - (input_seq_len // 2))
    
    motif_local_start_h5_coord = merged_table['motif_local_start_h5_coord']
    merged_table = merged_table.assign(motif_local_start_h5_coord=motif_local_start_h5_coord.mask(motif_local_start_h5_coord<0, 0)) 
    motif_local_end_h5_coord = merged_table['motif_local_end_h5_coord']
    merged_table = merged_table.assign(motif_local_end_h5_coord=motif_local_end_h5_coord.mask(motif_local_end_h5_coord>=input_seq_len, input_seq_len-1))
    
    return merged_table


def extract_scores_from_h5(h5_file_path,h5_type='Z'):
    """
    Extracts scores from h5 file and returns a list of numpy arrays. 
    Default expects zahoor's h5 file format, h5_type = Z. 
    Can also extract from Alex's format h5_type = A. Alex's format is not yet implemented.
    """
    if h5_type == 'Z':
        f = h5py.File(h5_file_path, "r")
        scores = [f['projected_shap']['seq'][i][:].sum(0) for i in range(len(f['projected_shap']['seq']))]
    
    return scores

def filter_motifs_by_imp_score(actual_scores,null_scores,merged_table,alpha = 0.05,method='indep'):
    motif_scores = []
    error_count = 0
    warn = True
    for index,row in merged_table.iterrows():
        try:
            temp = statistics.mean(actual_scores[row['peak_index']][row['motif_local_start_h5_coord']:row['motif_local_end_h5_coord']])
            motif_scores.append(temp)
        except statistics.StatisticsError:
            temp = statistics.mean(actual_scores[row['peak_index']][row['motif_local_start_h5_coord']:(row['motif_local_end_h5_coord']+1)])
            motif_scores.append(temp)
        except:
            if warn:
                print("unknown error at {ind}, data\n {data}".format(ind=index,data=row))
                warn = False
            error_count+=1
    print("total unknown errors = {}".format(error_count))
    
    merged_table['actual_score'] = motif_scores

    ecdf=ECDF(np.concatenate(np.vstack(null_scores)))

    merged_table['fdr_significant'] = mc.fdrcorrection(1-ecdf(merged_table['actual_score']),alpha = alpha,method=method)[0]
    filtered_table = merged_table[merged_table['fdr_significant']]
    
    return filtered_table






def get_moods_hits(
    pfm_dict, reference_fasta, peak_bed_path, imp_scores_h5_path, null_scores_h5_path, pval_thresh=0.0001, temp_dir=None, input_seq_len = 2114, fdr = 0.05):
    """
    From a dictionary of PFMs, runs MOODS and returns the result as a Pandas
    DataFrame.
    Arguments:
        `pfm_dict`: a dictionary mapping keys to N x 4 NumPy arrays (N may be
            different for each PFM); the key will be the name of each motif
        `reference_fasta`: path to reference Fasta to use
        `peak_bed_path`: path to peaks BED file; only keeps MOODS hits from
            these intervals
        `imp_scores_h5_path`: path to importance scores h5 file. Currently
            accepts Zahoor's format
        `null_scores_h5_path`: path to null importance scores h5 file. Currently
            accepts Zahoor's format
        `pval_thresh`: threshold p-value for MOODS to use
        `temp_dir`: a temporary directory to store intermediates; defaults to
            a randomly created directory
        `input_seq_len`: peaks will be resized to input_seq_len from the summit
            and motifs will be scanned in the resized region
        `fdr`: fdr threshold for importance score based filtering
            
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
    
    # resize peaks to model input length
    
    resize_peaks(peaks_path = peak_bed_path,
                 resized_peak_path = os.path.join(temp_dir, "resized_peak.bed"),
                 input_seq_len = input_seq_len
    )
    
    # Filter hits for those that overlap peaks
    filter_hits_for_peaks(
        os.path.join(temp_dir, "moods_out.bed"),
        os.path.join(temp_dir, "moods_filtered.bed"),
        os.path.join(temp_dir, "resized_peak.bed")
    )
    
    


    collapse_hits(
        os.path.join(temp_dir, "moods_filtered.bed"),
        os.path.join(temp_dir, "moods_filtered_collapsed.bed"),
        pfm_keys
    )

    motif_hits = import_moods_hits(
        os.path.join(temp_dir, "moods_filtered_collapsed.bed")
    )
        
    peak_table = import_peaks(peak_bed_path,input_seq_len)
    
    merged_table = merge_peaks_moods_hits(peak_table,motif_hits,input_seq_len)

    actual_scores = extract_scores_from_h5(imp_scores_h5_path)
    
    null_scores = extract_scores_from_h5(null_scores_h5_path)
    
    filtered_table = filter_motifs_by_imp_score(actual_scores,null_scores,merged_table,alpha = fdr)

    if temp_dir_obj is not None:
        temp_dir_obj.cleanup()

    return filtered_table
