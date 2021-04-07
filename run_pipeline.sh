#!/bin/bash

# The entry point for the TF-Atlas pipeline
# 
# This script assumes that the present working directory is the 
# git cloned TF-Atlas repo folder

. pipeline/utils.sh

# command line params
experiment=$1
learning_rate=$2
# use -1 for counts_loss_weight if you want to auto set
counts_loss_weight=$3 
epochs=$4
encode_access_key=$5
encode_secret_key=$6
#gbsc-gcp-lab-kundaje-tf-atlas
gcp_bucket=$7
pipeline_destination=$8

# create the log file
logfile=$PWD/$experiment.log
touch $logfile

# path to the metadata file in the Tf-Atlas folder
metadata_file_path=$PWD/data/metadata.tsv
echo $( timestamp ): "metadata_file_path - " $metadata_file_path | \
tee -a $logfile

# change directory to the pipeline folder
cd pipeline

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
    learning_rate \\
    counts_loss_weight \\
    epochs \\
    $gcp_bucket" | tee -a $logfile
    
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
    $learning_rate \
    $counts_loss_weight \
    $epochs \
    $gcp_bucket

# if the pipeline params json was generated successfully
if [ -f pipeline_params_$experiment.json ]
then
    # run the main pipeline script
    echo $( timestamp ): "./pipeline.sh" pipeline_params_$experiment.json \
    $encode_access_key $encode_secret_key $pipeline_destination | \
    tee -a $logfile
    
    ./pipeline.sh pipeline_params_$experiment.json $encode_access_key \
    $encode_secret_key $pipeline_destination
else
    echo $( timestamp ): Could not "find" pipeline params json. \
    Aborting. | tee -a $logfile
fi
