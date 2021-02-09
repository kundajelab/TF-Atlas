## Reports

This directory contains Jupyter Notebooks and scripts needed to generate motif reports.

### `view_tfmodisco_results.ipynb`
Visualizes the TF-MoDISco motifs, including:
- PFM, PWM, CWM, and hCWM of each discovered motif
- Average predicted/observed profile underlying motif seqlets
- Distance distribution of motif seqlets to peak summits
- TOMTOM matches of each motif
- Examples of seqlet importance scores for each motif

This notebook requires:
- TF-MoDISco result HDF5
- Peak predictions HDF5 of the following format:

		`coords`:
		    `coords_chrom`: N-array of chromosome (string)
		    `coords_start`: N-array
		    `coords_end`: N-array
		`predictions`:
		    `log_pred_profs`: N x T x O x 2 array of predicted log profile
		        probabilities
		    `log_pred_counts`: N x T x 2 array of log counts
		    `true_profs`: N x T x O x 2 array of true profile counts
		    `true_counts`: N x T x 2 array of true counts

- Importance scores HDF5 of the following format:

		`coords_chrom`: N-array of chromosome (string)
		`coords_start`: N-array
		`coords_end`: N-array
		`hyp_scores`: N x L x 4 array of hypothetical importance scores
		`input_seqs`: N x L x 4 array of one-hot encoded input sequences

Note that the N sequences in the importance scores must be precisely those that TF-MoDISco was run on (in the exact order). N is the number of peaks, T is the number of tasks (for single task models, that is just 1), O is the output profile length (e.g. 1000bp), L is the input sequence length (e.g. 2114bp), and 2 is for the two strands.

We also assume that TF-MoDISco wsa run only on the central 400bp of the importance scores.
