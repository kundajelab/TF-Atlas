import tensorflow as tf
from tensorflow import keras
from utils import data_utils, argmanager
from utils.loss import multinomial_nll
import numpy as np
import os
import json
import scipy
import sklearn.metrics
import scipy.stats
from collections import OrderedDict
import h5py


def softmax(x, temp=1):
    norm_x = x - np.mean(x,axis=1, keepdims=True)
    return np.exp(temp*norm_x)/np.sum(np.exp(temp*norm_x), axis=1, keepdims=True)


def get_jsd(preds, cts, min_tot_cts=10):
    return np.array([scipy.spatial.distance.jensenshannon(x,y) for x,y in zip(preds, cts) \
                     if y.sum()>min_tot_cts])

def write_predictions_h5py(output_prefix, file_prefix, profile, logcts, coords, output_window_size=1000):
    # open h5 file for writing predictions    
    output_h5_fname = "{}.{}_predictions.h5".format(output_prefix, file_prefix)    
    h5_file = h5py.File(output_h5_fname, "w")
    # create groups 
    coord_group = h5_file.create_group("coords")
    pred_group = h5_file.create_group("predictions")

    num_examples=len(coords)

    coords_chrom_dset =  [str(coords[i][0]) for i in range(num_examples)]
    coords_start_dset =  [coords[i][1] for i in range(num_examples)]
    coords_end_dset =  [coords[i][2] for i in range(num_examples)]

    dt = h5py.special_dtype(vlen=str)

    # create the "coords" group datasets
    coords_chrom_dset = coord_group.create_dataset(
        "coords_chrom", data=np.array(coords_chrom_dset, dtype=dt),
        dtype=dt, compression="gzip")
    coords_start_dset = coord_group.create_dataset(
        "coords_start", data=coords_start_dset, dtype=int, compression="gzip")
    coords_end_dset = coord_group.create_dataset(
        "coords_end", data=coords_end_dset, dtype=int, compression="gzip")

    # create the "predictions" group datasets
    profs_dset = pred_group.create_dataset(
        "profs", 
        data=profile,
        dtype=float, compression="gzip")
    logcounts_dset = pred_group.create_dataset(
        "logcounts", data=logcts,
        dtype=float, compression="gzip")

    # close hdf5 file
    h5_file.close()


def main():
    args = argmanager.fetch_metrics_args()
    print(args)

    # load bias model
    with keras.utils.CustomObjectScope({'multinomial_nll':multinomial_nll, 'tf':tf}):
        model_bias = keras.models.load_model(args.bias_model)
        model_chrombpnet = keras.models.load_model(args.chrombpnet_model)
    inputlen = int(model_bias.input_shape[1])
    outputlen = int(model_bias.output_shape[0][1])
    # input and output shapes should be the same for bias model and
    # chrombpnet model
    assert(model_chrombpnet.input_shape[0][1]==inputlen)
    assert(model_chrombpnet.output_shape[0][1]==outputlen)

    # load data
    test_peaks_seqs, test_peaks_cts, \
    test_nonpeaks_seqs, test_nonpeaks_cts, \
    peak_coords, non_peak_coords = data_utils.load_test_data(
                            args.peaks, args.nonpeaks, args.genome, args.bigwig,
                            args.test_chr, inputlen, outputlen
                           )

    # predict bias on peaks and nonpeaks
    test_peaks_pred_bias_logits, test_peaks_pred_bias_logcts = \
            model_bias.predict(test_peaks_seqs, 
                               batch_size = args.batch_size,
                               verbose=True)
    test_nonpeaks_pred_bias_logits, test_nonpeaks_pred_bias_logcts = \
            model_bias.predict(test_nonpeaks_seqs,
                               batch_size = args.batch_size,
                               verbose=True)


    # predict chrombpnet on peaks and nonpeaks
    test_peaks_pred_logits, test_peaks_pred_logcts = \
            model_chrombpnet.predict([test_peaks_seqs, 
                                      test_peaks_pred_bias_logits, 
                                      test_peaks_pred_bias_logcts],
                                    batch_size=args.batch_size,
                                    verbose=True)
    test_nonpeaks_pred_logits, test_nonpeaks_pred_logcts = \
            model_chrombpnet.predict([test_nonpeaks_seqs, 
                                      test_nonpeaks_pred_bias_logits, 
                                      test_nonpeaks_pred_bias_logcts],
                                    batch_size=args.batch_size,
                                    verbose=True)



    # this assumes a specific form of integration of bias
    # specifically addition of bias logits to unobseved unbias logits
    # and logsumexp of bias logcts with unobserved unbiased logcts
    test_peaks_pred_logits_wo_bias = test_peaks_pred_logits - test_peaks_pred_bias_logits

    test_peaks_pred_cts_wo_bias = np.exp(test_peaks_pred_logcts)-np.exp(test_peaks_pred_bias_logcts)

    # replace 0 with lowest non-zero and take log
    test_peaks_pred_cts_wo_bias[test_peaks_pred_cts_wo_bias==0] = np.min(test_peaks_pred_cts_wo_bias[test_peaks_pred_cts_wo_bias!=0])
    test_peaks_pred_logcts_wo_bias = np.log(test_peaks_pred_cts_wo_bias)

    # for non peaks
    test_nonpeaks_pred_logits_wo_bias = test_nonpeaks_pred_logits - test_nonpeaks_pred_bias_logits

    test_nonpeaks_pred_cts_wo_bias = np.exp(test_nonpeaks_pred_logcts)-np.exp(test_nonpeaks_pred_bias_logcts)

    # replace 0 with lowest non-zero and take log
    test_nonpeaks_pred_cts_wo_bias[test_nonpeaks_pred_cts_wo_bias==0] = np.min(test_nonpeaks_pred_cts_wo_bias[test_nonpeaks_pred_cts_wo_bias!=0])
    test_nonpeaks_pred_logcts_wo_bias = np.log(test_nonpeaks_pred_cts_wo_bias)

    ## save predictions as h5py file 

    write_predictions_h5py(args.output_prefix, "ground_truth_peaks", test_peaks_cts, np.log(1+test_peaks_cts.sum(-1, keepdims=True)), peak_coords, outputlen)
    write_predictions_h5py(args.output_prefix, "ground_truth_non_peaks", test_nonpeaks_cts, np.log(1+test_nonpeaks_cts.sum(-1, keepdims=True)), non_peak_coords, outputlen)
    
    write_predictions_h5py(args.output_prefix, "bias_peaks", softmax(test_peaks_pred_bias_logits)*(np.exp(test_peaks_pred_bias_logcts)-1), test_peaks_pred_bias_logcts, peak_coords, outputlen)
    write_predictions_h5py(args.output_prefix, "bias_non_peaks", softmax(test_nonpeaks_pred_bias_logits)*(np.exp(test_nonpeaks_pred_bias_logcts)-1), test_nonpeaks_pred_bias_logcts, non_peak_coords, outputlen)

    write_predictions_h5py(args.output_prefix, "chrombpnet_wo_bias_peaks", test_peaks_pred_logits_wo_bias, test_peaks_pred_cts_wo_bias, peak_coords, outputlen)
    write_predictions_h5py(args.output_prefix, "chrombpnet_wo_bias_non_peaks", test_nonpeaks_pred_logits_wo_bias, test_nonpeaks_pred_cts_wo_bias, non_peak_coords, outputlen)

    write_predictions_h5py(args.output_prefix, "chrombpnet_w_bias_peaks", test_peaks_pred_logits, test_peaks_pred_logcts, peak_coords, outputlen)
    write_predictions_h5py(args.output_prefix, "chrombpnet_w_bias_non_peaks", test_nonpeaks_pred_logits, test_nonpeaks_pred_logcts, non_peak_coords, outputlen)


    metrics = OrderedDict()

    # counts metrics
    all_test_logcts = np.log(1 + np.vstack([test_peaks_cts, test_nonpeaks_cts]).sum(-1))
    cur_pair = (all_test_logcts,
                np.vstack([test_peaks_pred_logcts,
                           test_nonpeaks_pred_logcts]).ravel())
    metrics['chrombpnet_cts_pearson_peaks_nonpeaks'] = scipy.stats.pearsonr(*cur_pair)[0]
    metrics['chrombpnet_cts_spearman_peaks_nonpeaks'] = scipy.stats.spearmanr(*cur_pair)[0]

    cur_pair = ([1]*len(test_peaks_pred_logcts) + [0]*len(test_nonpeaks_pred_logcts), 
                 np.vstack([test_peaks_pred_logcts,
                           test_nonpeaks_pred_logcts]).ravel())

    metrics['binary_auc'] = sklearn.metrics.roc_auc_score(*cur_pair)

    # peaks counts metrics
    peaks_test_logcts = np.log(1 + test_peaks_cts.sum(-1))
    cur_pair = (peaks_test_logcts, test_peaks_pred_logcts.ravel())
    metrics['chrombpnet_cts_pearson_peaks'] =  scipy.stats.pearsonr(*cur_pair)[0]
    metrics['chrombpnet_cts_spearman_peaks'] = scipy.stats.spearmanr(*cur_pair)[0]

    cur_pair = (peaks_test_logcts, test_peaks_pred_logcts_wo_bias.ravel())
    metrics['chrombpnet_cts_pearson_peaks_wo_bias'] = scipy.stats.pearsonr(*cur_pair)[0]
    metrics['chrombpnet_cts_spearman_peaks_wo_bias'] = scipy.stats.spearmanr(*cur_pair)[0]

    cur_pair = (peaks_test_logcts, test_peaks_pred_bias_logcts.ravel())
    metrics['bias_cts_pearson_peaks'] = scipy.stats.pearsonr(*cur_pair)[0]
    metrics['bias_cts_spearman_peaks'] = scipy.stats.spearmanr(*cur_pair)[0]

    # nonpeaks counts metrics
    nonpeaks_test_logcts = np.log(1 + test_nonpeaks_cts.sum(-1))
    cur_pair = (nonpeaks_test_logcts, test_nonpeaks_pred_logcts.ravel())
    metrics['chrombpnet_cts_pearson_nonpeaks'] =  scipy.stats.pearsonr(*cur_pair)[0]
    metrics['chrombpnet_cts_spearman_nonpeaks'] = scipy.stats.spearmanr(*cur_pair)[0]

    cur_pair = (nonpeaks_test_logcts, test_nonpeaks_pred_logcts_wo_bias.ravel())
    metrics['chrombpnet_cts_pearson_nonpeaks_wo_bias'] = scipy.stats.pearsonr(*cur_pair)[0]
    metrics['chrombpnet_cts_spearman_nonpeaks_wo_bias'] = scipy.stats.spearmanr(*cur_pair)[0]

    cur_pair = (nonpeaks_test_logcts, test_nonpeaks_pred_bias_logcts.ravel())
    metrics['bias_cts_pearson_nonpeaks'] = scipy.stats.pearsonr(*cur_pair)[0]
    metrics['bias_cts_spearman_nonpeaks'] = scipy.stats.spearmanr(*cur_pair)[0]

    # profile metrics (all within peaks)
    cur_pair = (softmax(test_peaks_pred_logits), test_peaks_cts)
    metrics['chrombpnet_profile_median_jsd_peaks'] = np.median(get_jsd(*cur_pair))

    cur_pair = (softmax(test_peaks_pred_logits_wo_bias), test_peaks_cts)
    metrics['chrombpnet_profile_median_jsd_peaks_wo_bias'] = np.median(get_jsd(*cur_pair))

    cur_pair = (softmax(test_peaks_pred_bias_logits), test_peaks_cts)
    metrics['bias_profile_median_jsd_peaks'] = np.median(get_jsd(*cur_pair))

    cur_pair = (softmax(test_peaks_pred_logits), 
                test_peaks_cts[:, np.random.permutation(test_peaks_cts.shape[1])])
    metrics['chrombpnet_profile_median_jsd_peaks_randomized'] = np.median(get_jsd(*cur_pair))

    # profile metrics (all within nonpeaks)
    cur_pair = (softmax(test_nonpeaks_pred_logits), test_nonpeaks_cts)
    metrics['chrombpnet_profile_median_jsd_nonpeaks'] = np.median(get_jsd(*cur_pair))

    cur_pair = (softmax(test_nonpeaks_pred_logits_wo_bias), test_nonpeaks_cts)
    metrics['chrombpnet_profile_median_jsd_nonpeaks_wo_bias'] = np.median(get_jsd(*cur_pair))

    cur_pair = (softmax(test_nonpeaks_pred_bias_logits), test_nonpeaks_cts)
    metrics['bias_profile_median_jsd_nonpeaks'] = np.median(get_jsd(*cur_pair))

    cur_pair = (softmax(test_nonpeaks_pred_logits), 
                test_nonpeaks_cts[:, np.random.permutation(test_nonpeaks_cts.shape[1])])
    metrics['chrombpnet_profile_median_jsd_nonpeaks_randomized'] = np.median(get_jsd(*cur_pair))

    #with open(args.output_prefix + ".metrics.json", "w") as f:
    #    json.dump(metrics, f, ensure_ascii=False, indent=4)

    for key in metrics:
        ofile = open(args.output_prefix +"."+ key, "w")
        ofile.write(str(metrics[key]))
        ofile.close()


if __name__=="__main__":
    main()

