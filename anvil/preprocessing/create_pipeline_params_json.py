import os
import pandas as pd
import sys
import json

# command line params
metadata_file_path=sys.argv[1]
experiment_id=sys.argv[2]
has_control=sys.argv[3]
stranded=sys.argv[4]
model_arch_name=sys.argv[5]
sequence_generator_name=sys.argv[6]
splits_json_path=sys.argv[7]
test_chroms=sys.argv[8]
tuning=sys.argv[9]
learning_rate=sys.argv[10]
counts_loss_weight=sys.argv[11]
epochs=sys.argv[12]
gcp_bucket=sys.argv[13]
params_json_outfile=sys.argv[14]

def make_string(pandas_col_obj):
    """
        Convert a single pandas column object to a string of 
        desired format for the params json
        
        For e.g. take this ['ENCFF646IIC', 'ENCFF859NYB'] and 
        transform it to "ENCFF646IIC ENCFF859NYB"
    """
    return pandas_col_obj.values[0].translate(str.maketrans('','', "[',]"))
    
if not os.path.exists(metadata_file_path):
    print("Metadata file not found! Please check the path")
    sys.exit(1)

params_dict = {}
params_dict['experiment'] = experiment_id

# load the metadata file
metadata_df = pd.read_csv(metadata_file_path, sep='\t', header=0)

# find the row matching the experiment_id
row = metadata_df[metadata_df['experiment'] == experiment_id]

# check if the experiment_id exists
if row.empty:
    print("Experiment {} not found in metadata".format(experiment_id))
    sys.exit(1)
    
# construct a python dictionary with all the fields
params_dict['assembly'] = row['assembly'].values[0]
params_dict['unfiltered_alignments'] = \
    make_string(row['unfiltered_alignments'])
params_dict['unfiltered_alignments_md5sums'] = \
    make_string(row['unfiltered_alignments_md5sums'])
params_dict['alignments'] = \
    make_string(row['alignments'])
params_dict['alignments_md5sums'] = \
    make_string(row['alignments_md5sums'])
params_dict['control_unfiltered_alignments'] = \
    make_string(row['control_unfiltered_alignments'])
params_dict['control_unfiltered_alignments_md5sums'] = \
    make_string(row['control_unfiltered_alignments_md5sums'])
params_dict['control_alignments'] = \
    make_string(row['control_alignments'])
params_dict['control_alignments_md5sums'] = \
    make_string(row['control_alignments_md5sums'])
params_dict['peaks'] = \
    make_string(row['preferred_default_bed_narrowPeak'])
params_dict['peaks_md5sum'] = \
    make_string(row['preferred_default_bed_narrowPeak_md5sums'])
params_dict['has_control'] = has_control
params_dict['stranded'] = stranded
params_dict['model_arch_name'] = model_arch_name
params_dict['sequence_generator_name'] = sequence_generator_name
params_dict['splits_json_path'] = splits_json_path
params_dict['test_chroms'] = test_chroms
params_dict['tuning'] = tuning
params_dict['learning_rate'] = learning_rate
params_dict['counts_loss_weight'] = counts_loss_weight
params_dict['epochs'] = epochs
params_dict['gcp_bucket'] = gcp_bucket

# write python dictionary to json file
with open(params_json_outfile) as outfile:  
    json.dump(params_dict, outfile, indent='\t')
