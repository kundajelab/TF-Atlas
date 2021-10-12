## Reports

This directory contains Jupyter Notebooks and scripts needed to generate motif reports.

Note that these reports are only compatible with the outputs of single-task models, so below, `T` (the number of tasks) will always be 1.

The convention used by these notebooks is to name each TF-MoDISco motif by the metacluster and pattern index (e.g. motif `0_5` is the 6th motif (index 5) in the first metacluster (index 0)).

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

- Set of all peaks as ENCODE NarrowPeak format (used for distance distribution of seqlets to peak summits)
- Path to a motif database to use for computing TOMTOM matches (in MEME format)
- Optional path to directory where results of notebook are stored:
	- An HDF5 of all TF-MoDISco motifs, including the PFMs, CWMs, and hypothetical CWMs (and trimmed versions of these)
	- For the set of seqlets underlying each motif, a NumPy object of the set of true/predicted profiles, DNA sequences, hypothetical importance scores, coordinates, and distances to peak summits of these seqlets
	- Plotted images of the full PFMS, CWMs, and hypothetical CWMs
	- Plotted images of the true/predicted profiles surrounding the seqlets underlying each motif
	- Plotted images of the distribution of distances of each underlying seqlet to the closest peak summit

Note that the N sequences in the importance scores must be precisely those that TF-MoDISco was run on (in the exact order). N is the number of peaks, T is the number of tasks (for single task models, that is just 1), O is the output profile length (e.g. 1000bp), L is the input sequence length (e.g. 2114bp), and 2 is for the two strands.

We also assume that TF-MoDISco wsa run only on the central 400bp of the importance scores.

### `showcase_motifs_and_profiles.ipynb`
For each TF-MoDISco motif, visualizes a sample of:
- Predicted/observed profile of that sequence
- Importance scores for that sequence
- The underlying seqlet

This notebook requires:
- TF-MoDISco result HDF5
- Peak predictions HDF5 (same format as above)
- Importance scores HDF5 (same format as above)
- Optional path to directory where results of notebook are stored:
	- Plotted images of the profiles, importance scores, and underlying seqlet

### `cluster_motifs.ipynb`
Given a set of motifs (perhaps from multiple TF-MoDISco runs), clusters them to show structure across all motifs.

This notebook requires:
- Comma-delimited list of paths to motif files, each one being an HDF5 of the same format as the motif HDF5 saved by `view_tfmodisco_results.ipynb`
- Parallel comma-delimited list of group names (i.e. unique identifiers for each given motif file)
- Optional path to directory where results of notebook are stored:
	- Plotted image of heatmap with dendrogram showing motif clusters
	- HDF5 containing the similarity matrix between all motifs, the distinct clusters, and the aggregated CWM of the cluster

### `summarize_motif_hits.ipynb`
This notebook analyzes the resulting hits of the TF-MoDISco scoring algorithm. This notebook will visualize:
- The distribution of how many motif hits are found per peak
- The proportion of peaks that have each type of motif
- Example importance score tracks with highlighted motif hits
- Co-occurrence of different motifs in peaks
- Homotypic motif densities in peaks
- Distribution of distances between strongly co-occurring motifs

This notebook requires:
- TF-MoDISco result HDF5
- Importance scores HDF5 (same format as above)
- Set of all peaks as a single BED file in ENCODE NarrowPeak format
	- This needs to be the exact same peak file that was used to call the TF-MoDISco hit scoring algorithm
- Path to TF-MoDISco hit scoring output table (output by `tfmodisco_hit_scoring.py`)
- Optional path to directory where results of notebook are stored:
	- The filtered hits after FDR thresholding
	- The set of all peaks
	- The mapping between the index of each peak to the set of indices of the filtered hits belonging to that peak
	- Plotted images of the FDR thresholding
	- Plotted images of the CDF of hits per peak, bar plot of peaks with each motif, and homotypic density CDFs
	- HDF5 of co-occurrence matrices of the different motifs in p-values and raw counts
	- Plotted images of the co-occurrence heatmaps, and binary indicator matrix of which peaks have which motifs
	- HDF5 of motif distance distributions between significantly co-occurring motifs
	- Plotted image of distance distributions between significantly co-occurring motifs

Note that before running this notebook, `tfmodisco_hit_scoring.py` must be run.

### `submotif_clustering.ipynb`
From the set of TF-MoDISco motifs, this notebook will visualize the subclustering structure of submotifs within the motifs themselves.

This notebook requires:
- TF-MoDISco result HDF5
- Importance scores HDF5 (same format as above)
- Optional path to directory where results of notebook are stored:
	- HDF5 of all motif subclusters (the PFM, CWM, hypothetical CWM, and trimmed hypothetical CWM of each sub-motif for each motif), and the transformed submotif embeddings for each motif
	- Plotted images of the trimmed hypothetical CWM of each submotif 
	- Plotted images of UMAPs showing the embeddings of the submotifs

### `cluster_motif_hits_and_peaks.ipynb`
From the set of TF-MoDISco motifs and the motif hits in peaks, this notebook will visualize the clustering of peak embeddings based on which peaks contain which motifs

This notebook requires:
- TF-MoDISco result HDF5
- Path to motif hits table (e.g. the output of `tfmodisco_hit_scoring.py` or the filtered table output by `summarize_motif_hits.ipynb`)
- Set of all peaks as a single BED file in ENCODE NarrowPeak format
	- This needs to be the exact same peak file that was used to call the TF-MoDISco hit scoring algorithm
- Embeddings of peaks from the model as an HDF5 of the following format:

		`coords`:
		    `coords_chrom`: M-array of chromosome (string)
		    `coords_start`: M-array
		    `coords_end`: M-array
		`predictions`:
		    `mean`: M x C x F array of embeddings, where collapsing is done by
				taking the mean across the output length (C convolutional layers
				in order of the model, F filters)
			`std`: M x C x F array of embeddings, collapsed using standard
                deviation
            `max`: M x C x F array of embeddings, collapsed using maximum
            `min`: M x C x F array of embeddings, collapsed using minimum

- Optional path to directory where results of notebook are stored:
	- HDF5 mapping each motif key to the set of indices of embeddings (out of M) that correspond to peaks/regions that contain hits of that motif
	- Plotted images of UMAPs showing the embeddings of the submotifs
	- HDF5 of transformed peak embeddings in UMAP space
	- Plotted images of UMAPs of peak embeddings for every layer and motif

### `model_performance.ipynb`
Plots the profile and counts performance of a model, including:
- CDFs of profile performance metrics over peaks (MNLL, cross entropy, and JSD are min-max-normalized)
- Scatter plot of predicted and true log counts, and their correlation

This notebook requires:
- Peak predictions HDF5 (same format as above)
- Path to metrics directory:
	- This directory must contain the subdirectories `plus/` and `minus/`, each with NumPy arrays of `{key}.npz` for each metric key
	- Any min-max-normalization must have already happened prior to saving these vectors