#!/bin/bash

# The entry point for the TF-Atlas pipeline
# 
# This script assumes that the present working directory is the 
# git cloned TF-Atlas repo folder

source ./utils.sh

# command line params
experiment=$1
metadata_file_path=$2

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
    params_file.json" | tee -a $logfile
    
python \
    create_pipeline_params_json.py \
    $metadata_file_path \
    $experiment \
    params_file.json

