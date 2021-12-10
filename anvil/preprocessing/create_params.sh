#!/bin/bash

# The entry point for the TF-Atlas pipeline
# 
# This script assumes that the present working directory is the 
# git cloned TF-Atlas repo folder

source ./utils.sh

# command line params
experiment=$1
tuning=$2
learning_rate=$3
# use -1 for counts_loss_weight if you want to auto set
counts_loss_weight=$4 
epochs=$5
encode_access_key=$6
encode_secret_key=$7
#gbsc-gcp-lab-kundaje-tf-atlas
gcp_bucket=$8
pipeline_destination=$9
metadata_file_path=${10}

# create the log file
logfile=$PWD/$experiment.log
touch $logfile

# path to the metadata file in the Tf-Atlas folder
echo $( timestamp ): "metadata_file_path - " $metadata_file_path | \
tee -a $logfile

# change directory to the pipeline folder

# create pipeline params json
echo $( timestamp ): "
python \\
    create_pipeline_params_json.py \\
    $metadata_file_path \\
    $experiment \\
    True \\
    True \\
    BPNetd10008 \\
    BPNet \\
    one_split.json \\
    chr1 \\
    $tuning \\
    $learning_rate \\
    $counts_loss_weight \\
    $epochs \\
    $gcp_bucket \\
    params_file.json" | tee -a $logfile
    
python \
    create_pipeline_params_json.py \
    $metadata_file_path \
    $experiment \
    True \
    True \
    BPNet1000d8 \
    BPNet \
    one_split.json \
    chr1 \
    $tuning \
    $learning_rate \
    $counts_loss_weight \
    $epochs \
    $gcp_bucket \
    params_file.json

