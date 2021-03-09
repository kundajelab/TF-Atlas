import pandas as pd
import numpy as np

from scipy.special import logsumexp
import pyBigWig
from tqdm import tqdm
import deepdish as dd

import h5py
import sys

def single_task_predictions_to_hdf5(input_len, output_len,
                                    true_plus_bigWig, true_minus_bigWig, 
                                    pred_plus_bigWig, pred_minus_bigWig,
                                    pred_counts_plus_bigWig, 
                                    pred_counts_minus_bigWig, peaks, chroms, 
                                    output_fname):

    input_flank = input_len // 2
    output_flank = output_len // 2
    
    # read the peaks file 
    peaks_df = pd.read_csv(peaks, sep='\t', header=None, 
                           names=['chrom', 'st', 'end', 'name', 'score',
                              'strand', 'signal', 'p', 'q', 'summit'])
    
    # keep only those rows corresponding to the required 
    # chromosomes
    peaks_df = peaks_df[peaks_df['chrom'].isin(chroms)]

    # create new column for peak pos
    peaks_df['pos'] = peaks_df['st'] + peaks_df['summit']

    # compute start coordinates of the input sequences 
    peaks_df['start'] = (peaks_df['pos'] - input_flank).astype(int)

    # compute end coordinates of the input sequences 
    peaks_df['end'] = (peaks_df['pos'] + input_flank).astype(int)
    
    # compute start coordinates of the input sequences 
    peaks_df['output_start'] = (peaks_df['pos'] - output_flank).astype(int)

    # compute end coordinates of the input sequences 
    peaks_df['output_end'] = (peaks_df['pos'] + output_flank).astype(int)
    
    coords_chrom = peaks_df['chrom'].values
    coords_start = peaks_df['start'].values
    coords_end = peaks_df['end'].values
    
    log_pred_profs = np.zeros((peaks_df.shape[0], 1, output_len, 2))
    log_pred_counts = np.zeros((peaks_df.shape[0], 1, 2))
    true_profs = np.zeros((peaks_df.shape[0], 1, output_len, 2))
    true_counts = np.zeros((peaks_df.shape[0], 1, 2))
    
    true_plus = pyBigWig.open(true_plus_bigWig)
    true_minus = pyBigWig.open(true_minus_bigWig)
    pred_plus = pyBigWig.open(pred_plus_bigWig)
    pred_minus = pyBigWig.open(pred_minus_bigWig)
    pred_counts_plus = pyBigWig.open(pred_counts_plus_bigWig)
    pred_counts_minus = pyBigWig.open(pred_counts_minus_bigWig)

    count_counts_plus_zero = 0
    count_counts_minus_zero = 0
    
    for idx, row in tqdm(peaks_df.iterrows(), total=peaks_df.shape[0]):
        chrom = row['chrom']
        start = row['output_start']
        end = row['output_end']
        mid = row['output_start'] + output_flank
        
        true_plus_prof = np.nan_to_num(true_plus.values(chrom, start, end))
        true_minus_prof = np.nan_to_num(true_minus.values(chrom, start, end))
        
        true_profs[idx, 0, :, 0] = true_plus_prof
        true_profs[idx, 0, :, 1] = true_minus_prof
        
        true_counts[idx, 0, 0] = np.sum(true_plus_prof)
        true_counts[idx, 0, 1] = np.sum(true_minus_prof)
        
        pred_plus_prof = np.nan_to_num(pred_plus.values(chrom, start, end))
        pred_minus_prof = np.nan_to_num(pred_minus.values(chrom, start, end))

        pred_counts_plus_prof = np.mean(np.nan_to_num(np.array(pred_counts_plus.values(chrom, start, end))))
        pred_counts_minus_prof = np.mean(np.nan_to_num(np.array(pred_counts_minus.values(chrom, start, end))))

        if pred_counts_plus_prof == 0:
            count_counts_plus_zero  += 1
            
        if pred_counts_minus_prof == 0:
            count_counts_minus_zero  += 1            

        log_pred_profs[idx, 0, :, 0] = pred_plus_prof - logsumexp(pred_plus_prof)
        log_pred_profs[idx, 0, :, 1] = pred_minus_prof - logsumexp(pred_minus_prof)
        
        log_pred_counts[idx, 0, 0] = np.log(pred_counts_plus_prof + 1)
        log_pred_counts[idx, 0, 1] = np.log(pred_counts_minus_prof + 1)
        
    print(count_counts_plus_zero)
    print(count_counts_minus_zero)
       
    num_examples = peaks_df.shape[0]
    h5_file = h5py.File(output_fname, "w")
    coord_group = h5_file.create_group("coords")
    pred_group = h5_file.create_group("predictions")
    
    coords_chrom_dset = coord_group.create_dataset(
        "coords_chrom", (num_examples,),
        dtype=h5py.string_dtype(encoding="ascii"), compression="gzip"
    )
    coords_chrom_dset[:] = coords_chrom
    
    coords_start_dset = coord_group.create_dataset(
        "coords_start", (num_examples,), dtype=int, compression="gzip"
    )
    coords_start_dset[:] = coords_start
    
    coords_end_dset = coord_group.create_dataset(
        "coords_end", (num_examples,), dtype=int, compression="gzip"
    )
    coords_end_dset [:] = coords_end
    
    log_pred_profs_dset = pred_group.create_dataset(
        "log_pred_profs", (num_examples, 1, output_len, 2),
        dtype=float, compression="gzip"
    )
    log_pred_profs_dset[:, :, :, :] = log_pred_profs
    
    log_pred_counts_dset = pred_group.create_dataset(
        "log_pred_counts", (num_examples, 1, 2), dtype=float,
        compression="gzip"
    )
    log_pred_counts_dset[:, :, :] = log_pred_counts
    
    true_profs_dset = pred_group.create_dataset(
        "true_profs", (num_examples, 1, output_len, 2),
        dtype=float, compression="gzip"
    )
    true_profs_dset[:, :, :, :] = true_profs
    
    true_counts_dset = pred_group.create_dataset(
        "true_counts", (num_examples, 1, 2), dtype=float,
        compression="gzip"
    )
    true_counts_dset[:, :, :] = true_counts
    h5_file.close()

if __name__ == '__main__':
    single_task_predictions_to_hdf5(
        int(sys.argv[1]), int(sys.argv[2]), sys.argv[3], sys.argv[4], 
        sys.argv[5], sys.argv[6], sys.argv[7], sys.argv[8], sys.argv[9],
        sys.argv[10].split(' '), sys.argv[11])
    
    
    
#         2114, 1000, "/users/zahoor/TF-Atlas/02-16-2021/bigWigs/{}_plus.bw".format(experiment), 
#         "/users/zahoor/TF-Atlas/02-16-2021/bigWigs/{}_minus.bw".format(experiment),
#         "/users/zahoor/TF-Atlas/02-16-2021/predictions/{}/{}_split000_task0_plus.bw".format(experiment, experiment),
#         "/users/zahoor/TF-Atlas/02-16-2021/predictions/{}/{}_split000_task0_minus.bw".format(experiment, experiment), 
#         "/users/zahoor/TF-Atlas/02-16-2021/predictions/{}/{}_split000_task0_plus_exponentiated_counts.bw".format(experiment, experiment),
#         "/users/zahoor/TF-Atlas/02-16-2021/predictions/{}/{}_split000_task0_minus_exponentiated_counts.bw".format(experiment, experiment),
#         "/users/zahoor/TF-Atlas/02-16-2021/shap/{}/peaks_valid_scores.bed".format(experiment), chroms, 
#         "/users/zahoor/TF-Atlas/02-16-2021/predictions/{}/profile_predictions.h5".format(experiment))


# python convert_predictions_to_HDF5.py \
# 2114 \
# 1000 \
# bigWigs/ENCSR000BGZ_plus.bigWig \
# bigWigs/ENCSR000BGZ_minus.bigWig \
# predictions/ENCSR000BGZ_split000_task0_plus.bw \
# predictions/ENCSR000BGZ_split000_task0_minus.bw \
# predictions/ENCSR000BGZ_split000_task0_plus_exponentiated_counts.bw \
# predictions/ENCSR000BGZ_split000_task0_plus_exponentiated_counts.bw \
# downloads/ENCFF068YYR.bed.gz \
# "$(paste -s -d ' ' reference/chroms.txt)" \
# predictions/profile_predictions.h5
