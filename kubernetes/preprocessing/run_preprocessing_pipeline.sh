#!/bin/bash

# The entry point for the TF-Atlas preprocessing pipeline

. utils.sh

# command line params
experiment=$1
encode_access_key=$2
encode_secret_key=$3
gcp_bucket=$4
project_dir=$5
metadata=$6

# create the log file
logfile=$project_dir/${1}_preprocessing.log
touch $logfile

# path to the metadata file in the gcp bucket
metadata_file_path=gs://tfatlas/metadata/$metadata
echo $( timestamp ): "metadata_file_path - " $metadata_file_path | \
tee -a $logfile

# download the metadata file from gcp
echo $( timestamp ): "gsutil cp" $metadata_file_path \
$project_dir/metadata.tsv | tee -a $logfile

gsutil cp $metadata_file_path $project_dir/metadata.tsv

# change directory to the pipeline folder
cd $project_dir/TFAtlas/kubernetes/preprocessing

# create pipeline params json
echo $( timestamp ): "
python \\
    cerate_pipeline_params_json.py \\
    $project_dir/metadata.tsv \\
    $experiment \\
    $gcp_bucket" | tee -a $logfile
    
python \
    create_pipeline_params_json.py \
    $project_dir/metadata.tsv \
    $experiment \
    $gcp_bucket

# if the pipeline params json was generated successfully
if [ -f pipeline_params_$experiment.json ]
then
    # run the main pipeline script
    echo $( timestamp ): "./pipeline.sh" pipeline_params_$experiment.json \
    $encode_access_key $encode_secret_key $project_dir $logfile | \
    tee -a $logfile
    
    ./pipeline.sh pipeline_params_$experiment.json $encode_access_key \
    $encode_secret_key $project_dir $logfile
else
    echo $( timestamp ): Could not "find" pipeline params json. \
    Aborting. | tee -a $logfile
fi


# copy the logfile to gcp
echo $( timestamp ): "gsutil -m cp" $logfile \
$gcp_bucket/logs/$logfile | tee -a $logfile

gsutil -m cp $logfile gs://$gcp_bucket/logs/${1}_preprocessing.log
