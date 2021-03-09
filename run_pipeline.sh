#!/bin/bash

# The entry point for the TF-Atlas pipeline
# 
# This script assumes that the present working directory is the 
# git cloned TF-Atlas repo folder

. pipeline/utils.sh

# command line params
experiment=$1
encode_access_key=$2
encode_secret_key=$3

# path to the metadata file in the Tf-Atlas folder
metadata_file_path=$PWD/data/metadata.tsv
echo $( timestamp ): "metadata_file_path - " $metadata_file_path | \
tee -a $logfile

# change directory to the pipeline folder
cd pipeline

# create the log file
logfile=$experiment.log
touch $logfile

# create pipeline params json
echo $( timestamp ): "
python \\
    cerate_pipeline_params_json.py \\
    $metadata_file_path \\
    $experiment \\
    True \\
    True \\
    BPNetd10008 \\
    BPNet \\
    one_split.json \\
    chr1 \\
    bsc-gcp-lab-kundaje-tf-atlas" | tee -a $logfile
    
python \
    create_pipeline_params_json.py \
    $metadata_file_path \
    $experiment \
    True \
    True \
    BPNetd10008 \
    BPNet \
    one_split.json \
    chr1 \
    bsc-gcp-lab-kundaje-tf-atlas

# if the pipeline params json was generated successfully
if [ -f pipeline_params_$experiment.json ]
then
    # run the main pipeline script
    echo $( timestamp ): "./pipeline.sh" $pipeline_params_$experiment.json \
    $encode_access_key $encode_secret_key | tee -a $logfile
    
#     ./pipeline.sh $pipeline_params_$experiment.json $encode_access_key \
#     $encode_secret_key
else
    echo $( timestamp ): Could not "find" pipeline params json. \
    Aborting. | tee -a $logfile
fi
