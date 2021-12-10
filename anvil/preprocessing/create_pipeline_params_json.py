import os
import pandas as pd
import sys
import json

# command line params
metadata_file_path=sys.argv[1]
experiment_id=sys.argv[2]
params_json_outfile=sys.argv[3]

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
params_dict['peaks'] = \
    make_string(row['preferred_default_bed_narrowPeak'])
params_dict['peaks_md5sum'] = \
    make_string(row['preferred_default_bed_narrowPeak_md5sums'])
params_dict['assay_type'] = \
    make_string(row['assay_type'])
# write python dictionary to json file
with open(params_json_outfile) as outfile:  
    json.dump(params_dict, outfile, indent='\t')
