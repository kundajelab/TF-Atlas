#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
gcp_bucket=$2
project_dir=$3

# create the log file
logfile=$project_dir/${1}_modisco.log
touch $logfile

# create the shap directory
shap_dir=$project_dir/shap
echo $( timestamp ): "mkdir" $shap_dir | tee -a $logfile
mkdir $shap_dir

# create the modisco directories
modisco_profile_dir=$project_dir/modisco_profile
echo $( timestamp ): "mkdir" $modisco_profile_dir | tee -a $logfile
mkdir $modisco_profile_dir

modisco_counts_dir=$project_dir/modisco_counts
echo $( timestamp ): "mkdir" $modisco_counts_dir | tee -a $logfile
mkdir $modisco_counts_dir

# copy down shap scores .h5 files
echo $( timestamp ): "gsutil cp" gs://$2/shap/$1/*.h5 $shap_dir | \
tee -a $logfile
gsutil cp gs://$2/shap/$1/*.h5 $shap_dir

echo $( timestamp ): "
motif_discovery \\
    --scores-path $shap_dir/profile_scores.h5 \\
    --output-directory $modisco_profile_dir" | tee -a $logfile

motif_discovery \
    --scores-path $shap_dir/profile_scores.h5 \
    --output-directory $modisco_profile_dir
    
echo $( timestamp ): "
motif_discovery \\
    --scores-path $shap_dir/counts_scores.h5 \\
    --output-directory $modisco_counts_dir" | tee -a $logfile

motif_discovery \
    --scores-path $shap_dir/counts_scores.h5 \
    --output-directory $modisco_counts_dir

# copy the result to gcp bucket
echo $( timestamp ): "gsutil cp" $modisco_profile_dir/* gs://$2/modisco_profile/$1/ | tee -a $logfile 
gsutil cp $modisco_profile_dir/* gs://$2/modisco_profile/$1/

echo $( timestamp ): "gsutil cp" $modisco_counts_dir/* gs://$2/modisco_counts/$1/ | tee -a $logfile 
gsutil cp $modisco_counts_dir/* gs://$2/modisco_counts/$1/

echo $( timestamp ): "gsutil cp" gsutil cp $logfile gs://$2/logs/ | tee -a $logfile 
gsutil cp $logfile gs://$2/logs/

