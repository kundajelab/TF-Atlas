import h5py
import numpy as np
import pandas as pd
import argparse
import os
import logging
import statistics
import glob


def process_moods_results_argsparser():
    # command line arguments
    parser = argparse.ArgumentParser()
    
    # params
    parser.add_argument('--deepshap_path', '-s', type=str, required=True, 
                        help="path to deepshap results directory")
    
    parser.add_argument('--genome_fasta', '-f', type=str, required=True, 
                        help="path to genome fasta file")
    
    parser.add_argument('--output-dir', '-o', type=str, required=True, 
                        help="output directory and moods run directory")

    parser.add_argument('--peaks-path', '-p', type=str, required=True, 
                        help="path to peaks bed file")
    
    parser.add_argument('--input-seq-len', '-l', type=int, default=2114, 
                        help="input sequence length to the model")

    parser.add_argument('--active-thresh', '-t', type=float, default=0.05, 
                        help="threshold for deepshap score based filtering of moods results")
    
    return parser


def process_moods_results(args,model_head):
  
    f = h5py.File(os.path.join(args.deepshap_path,model_head+"_scores.h5"), "r")
    actual_scores = [f['projected_shap']['seq'][i][:].sum(0) for i in range(len(f['projected_shap']['seq']))]

    f = h5py.File(os.path.join(args.deepshap_path,model_head+"_shuffled_scores.h5"), "r")
    null_scores = [f['projected_shap']['seq'][i][:].sum(0) for i in range(len(f['projected_shap']['seq']))]
    
    
    all_files = glob.glob(os.path.join(args.output_dir, "*"+model_head+"*_overlaps.bed"))
    motif_table = pd.concat(pd.read_csv(f, sep='\t', header=None) for f in all_files)
    motif_table = motif_table[[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]]
    motif_table.columns = ['chrom', 'start', 'end', 'strand', 'motif', 'match_score', 'sequence',
                       'peak_chrom', 'peak_start', 'peak_end', 'peak_strand']
    
    
    peak_table = pd.read_csv(args.peaks_path, sep='\t', header=None)
    peak_table = peak_table[[0, 1, 2, 9]]
    peak_table = peak_table.reset_index()
    peak_table.columns = ['peak_index', 'peak_chrom', 'peak_start', 'peak_end', 'peak_summit']
    peak_table = peak_table[['peak_chrom', 'peak_start', 'peak_end', 'peak_summit', 'peak_index']]
    peak_table['peak_name'] = peak_table['peak_chrom'] + '_' + peak_table['peak_start'].astype(str) + '_' + peak_table['peak_end'].astype(str)

    merged_table = motif_table.merge(peak_table, on=['peak_chrom', 'peak_start', 'peak_end'])
    merged_table['motif_local_start_peak_coord'] = merged_table['start'] - merged_table['peak_start']
    merged_table['motif_local_end_peak_coord'] = merged_table['end'] - merged_table['peak_start']
    merged_table['motif_local_start_h5_coord'] = merged_table['start'] - (merged_table['peak_start'] + merged_table['peak_summit'] - (args.input_seq_len // 2))
    merged_table['motif_local_end_h5_coord'] = merged_table['end'] - (merged_table['peak_start'] + merged_table['peak_summit'] - (args.input_seq_len // 2))

    motif_scores = []
    for index,row in merged_table.iterrows():
        temp = statistics.mean(actual_scores[row['peak_index']][row['motif_local_start_h5_coord']:row['motif_local_end_h5_coord']])
        motif_scores.append(temp)
    merged_table['actual_score'] = pd.Series(motif_scores)

    filtered_table = merged_table[merged_table['actual_score']>np.quantile(null_scores,1-args.active_thresh)]

    filtered_table.iloc[:,[0,1,2,4]].to_csv(os.path.join(args.output_dir, "deepshap_filtered_"+model_head+"_motifs.bed"),header=False,index=False,sep="\t")

    return



def process_moods_results_main():
    # parse the command line arguments
    parser = process_moods_results_argsparser()
    args = parser.parse_args()
    
    

    # check if the output directory and other files exists
    
    if not os.path.exists(args.output_dir):
        logging.error("Directory {} does not exist".format(
            args.output_dir))
        return
    logging.basicConfig(filename=os.path.join(args.output_dir,'procces_moods_results.log'), filemode='w')
    
    if not os.path.exists(args.genome_fasta):
        logging.error("Directory {} does not exist".format(
            args.genome_fasta))
        return
    
    if not os.path.exists(args.peaks_path):
        logging.error("Peaks file {} does not exist".format(
            args.output_dir))
        return
    
    if not (args.active_thresh>0) & (args.active_thresh<=1):
        logging.error("Given active threshold {} out of range. It should be between 0.0 and 1.0".format(
            args.output_dir))
        return
    
    
    # process_moods_results
    logging.info("Processing and diltering MOODS results from {}".format(args.output_dir))
    
    process_moods_results(args,'counts')
    
    process_moods_results(args,'profile')

if __name__ == '__main__':
    process_moods_results_main()