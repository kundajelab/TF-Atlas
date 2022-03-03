#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
shap=$2
number_of_cpus=$3



mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/${1}_modisco.log
touch $logfile


# create the data directory
data_dir=$project_dir/data
echo $( timestamp ): "mkdir" $data_dir | tee -a $logfile
mkdir $data_dir

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

#Step 1: Copy the shap files

echo $( timestamp ): "cp" $shap ${shap_dir}/ |\
tee -a $logfile 

echo $shap | sed 's/,/ /g' | xargs cp -t $shap_dir/


#Step 2: Run modisco on counts and profile

free -g -s 30 | tee -a $logfile &

echo $( timestamp ): "
motif_discovery \\
    --scores-path $shap_dir/profile_scores.h5 \\
    --output-directory $modisco_profile_dir \\
    --number-of-cpus $number_of_cpus
    --max-seqlets-per-metacluster 20000" | tee -a $logfile

motif_discovery \
    --scores-path $shap_dir/profile_scores.h5 \
    --output-directory $modisco_profile_dir \
    --number-of-cpus $number_of_cpus \
    --max-seqlets-per-metacluster 20000
    
echo $( timestamp ): "
motif_discovery \\
    --scores-path $shap_dir/counts_scores.h5 \\
    --output-directory $modisco_counts_dir\\
    --number-of-cpus $number_of_cpus \\
    --max-seqlets-per-metacluster 20000" | tee -a $logfile

motif_discovery \
    --scores-path $shap_dir/counts_scores.h5 \
    --output-directory $modisco_counts_dir \
    --number-of-cpus $number_of_cpus \
    --max-seqlets-per-metacluster 20000

awk '$1=="Mem:"{print $3}' $logfile | sort -n | tail -n 1 > /cromwell_root/max_memory_gb.txt


