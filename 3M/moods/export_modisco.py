import h5py
import numpy as np
import pandas as pd
import argparse
import os
import logging



def export_argsparser():
    # command line arguments
    parser = argparse.ArgumentParser()
    
    # params
    
    parser.add_argument('--modisco-path', '-m', type=str, required=True, 
                        help="path to modisco results directory")

    parser.add_argument('--output-dir', '-o', type=str, required=True, 
                        help="output directory")
    
    return parser

def import_tfmodisco_motifs(tfm_results_path, trim=True, only_pos=True):
    """
    Imports the set of all motifs identified by TF-MoDISco.
    Arguments:
        `tfm_results_path`: path to HDF5 containing TF-MoDISco results
        `trim`: if True, trim the motif flanks based on total importance
        `only_pos`: if True, only return motifs with positive contributions
    Returns a list of PFMs, a list of hCWMs, and a list of CWMs (all as
    NumPy arrays).
    """ 
    pfms, hcwms, cwms = [], [], []
    with h5py.File(tfm_results_path, "r") as f:
        metaclusters = f["metacluster_idx_to_submetacluster_results"]
        num_metaclusters = len(metaclusters.keys())
        for metacluster_i, metacluster_key in enumerate(metaclusters.keys()):
            metacluster = metaclusters[metacluster_key]
            patterns = metacluster["seqlets_to_patterns_result"]["patterns"]
            num_patterns = len(patterns["all_pattern_names"][:])
            for pattern_i, pattern_name in enumerate(patterns["all_pattern_names"][:]):
                pattern_name = pattern_name.decode()
                pattern = patterns[pattern_name]
                pfm = pattern["sequence"]["fwd"][:]
                hcwm = pattern["task0_hypothetical_contribs"]["fwd"][:]
                cwm = pattern["task0_contrib_scores"]["fwd"][:]
                # Check that the contribution scores are overall positive
                if only_pos and np.sum(cwm) < 0:
                    continue
                if trim:
                    score = np.sum(np.abs(cwm), axis=1)
                    trim_thresh = np.max(score) * 0.2  # Cut off anything less than 20% of max score
                    pass_inds = np.where(score >= trim_thresh)[0]
                    pfm = pfm[np.min(pass_inds): np.max(pass_inds) + 1]
                    hcwm = hcwm[np.min(pass_inds): np.max(pass_inds) + 1]
                    cwm = cwm[np.min(pass_inds): np.max(pass_inds) + 1]
                pfms.append((pfm,metacluster_i,pattern_i))
                hcwms.append(hcwm)
                cwms.append(cwm)
    return pfms

def export_md(args):
    
    head = 'profile'
    modisco_result = import_tfmodisco_motifs(args.modisco_path+"{head}/modisco_results.hd5".format(head=head))

    _ = [pd.DataFrame(np.transpose(data[0])).to_csv(args.output_dir+'{metacluster}_{pattern}_{head}.pfm'.format(metacluster=data[1],pattern=data[2],head=head),index=False,sep=' ',header=False) for ind, data in enumerate(modisco_result)]
    
    head = 'counts'
    modisco_result = import_tfmodisco_motifs(args.modisco_path+"{head}/modisco_results.hd5".format(head=head))

    _ = [pd.DataFrame(np.transpose(data[0])).to_csv(args.output_dir+'{metacluster}_{pattern}_{head}.pfm'.format(metacluster=data[1],pattern=data[2],head=head),index=False,sep=' ',header=False) for ind, data in enumerate(modisco_result)]


    return

def export_main():
    # parse the command line arguments
    parser = export_argsparser()
    args = parser.parse_args()
    
    
    
    # check if the modisco and output directory exists
    
    if os.path.exists(args.output_dir):
        
        logging.error("Directory {} is not empty".format(
            args.modisco_path))
        
        return
    os.makedirs(args.output_dir)
    
    logging.basicConfig(filename=args.output_dir+'/export_modisco.log', filemode='w')
    
    if not os.path.exists(args.modisco_path):
        logging.error("Directory {} does not exist".format(
            args.modisco_path))
        return
    
    
    # export modisco results
    logging.info("Exporting modisco results from {}".format(args.modisco_path))
    
    export_md(args)

if __name__ == '__main__':
    export_main()