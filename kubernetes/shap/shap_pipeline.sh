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
logfile=$project_dir/${1}_shap.log
touch $logfile

# create the data directory
data_dir=$project_dir/data
echo $( timestamp ): "mkdir" $data_dir | tee -a $logfile
mkdir $data_dir

# create the reference directory
reference_dir=$project_dir/reference
echo $( timestamp ): "mkdir" $reference_dir | tee -a $logfile
mkdir $reference_dir

# create the model directory
model_dir=$project_dir/model
echo $( timestamp ): "mkdir" $model_dir | tee -a $logfile
mkdir $model_dir

# create the shap directory
shap_dir=$project_dir/shap
echo $( timestamp ): "mkdir" $shap_dir | tee -a $logfile
mkdir $shap_dir

# copy down bigwig files, bed file, reference, and model file
echo $( timestamp ): "gsutil cp" gs://$2/data/$1/*.bigWig $data_dir | \
tee -a $logfile
gsutil cp gs://$2/data/$1/*.bigWig $data_dir

echo $( timestamp ): "gsutil cp" gs://$2/data/$1/$1.bed $data_dir | \
tee -a $logfile
gsutil cp gs://$2/data/$1/$1.bed $data_dir

echo $( timestamp ): "gsutil cp" gs://$2/reference/* $reference_dir | \
tee -a $logfile
gsutil cp gs://$2/reference/* $reference_dir

echo $( timestamp ): "gsutil cp" gs://$2/models/$1/${1}_split000.h5 $model_dir | \
tee -a $logfile
gsutil cp gs://$2/models/$1/${1}_split000.h5 $model_dir

# create the index to the genome fasta file
echo $( timestamp ): "samtools faidx" $reference_dir/hg38.genome.fa | tee -a $logfile
samtools faidx $reference_dir/hg38.genome.fa

# download input json template
# the input json for the rest of the commands (with bed file without 
# gc-matched negatives)
echo $( timestamp ): "gsutil cp" gs://$2/input_json/input.json \
$project_dir/ | tee -a $logfile 
gsutil cp gs://$2/input_json/input.json $project_dir/

# modify the input json to add the experiment name
echo  $( timestamp ): "sed -i -e" "s/<>/$1/g" $project_dir/input.json | \
tee -a $logfile 
sed -i -e "s/<>/$1/g" $project_dir/input.json

# modify the input json to change the directory name
echo  $( timestamp ): "sed -i -e" "s/modeling/shap/g" $project_dir/input.json | \
tee -a $logfile 
sed -i -e "s/modeling/shap/g" $project_dir/input.json

echo $( timestamp ): "
shap_scores \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --model $model_dir/${1}_split000.h5 \\
    --bed-file $data_dir/${1}.bed \\
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \\
    --output-dir $shap_dir \\
    --input-seq-len 2114 \\
    --control-len 1000 \\
    --task-id 0 \\
    --input-data $project_dir/input.json" | tee -a $logfile

shap_scores \
    --reference-genome $reference_dir/hg38.genome.fa \
    --model $model_dir/${1}_split000.h5 \
    --bed-file $data_dir/${1}.bed \
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \
    --output-dir $shap_dir \
    --input-seq-len 2114 \
    --control-len 1000 \
    --task-id 0 \
    --input-data $project_dir/input.json # this file doesnt have negatives

# copy the result to gcp bucket
echo $( timestamp ): "gsutil cp" $project_dir/shap/* gs://$2/shap/$1/ | tee -a $logfile 
gsutil cp $project_dir/shap/* gs://$2/shap/$1/

echo $( timestamp ): "gsutil cp" gsutil cp $logfile gs://$2/logs/ | tee -a $logfile 
gsutil cp $logfile gs://$2/logs/

