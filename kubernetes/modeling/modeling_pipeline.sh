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
logfile=$project_dir/${1}_modeling.log
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

# create the predictions directory
predictions_dir=$project_dir/predictions_and_metrics
echo $( timestamp ): "mkdir" $predictions_dir | tee -a $logfile
mkdir $predictions_dir

# copy down data and reference
echo $( timestamp ): "gsutil cp" gs://$2/data/$1/*.bigWig $data_dir | \
tee -a $logfile
gsutil cp gs://$2/data/$1/*.bigWig $data_dir

echo $( timestamp ): "gsutil cp" gs://$2/data/$1/$1.bed.gz $data_dir | \
tee -a $logfile
gsutil cp gs://$2/data/$1/$1.bed.gz $data_dir

echo $( timestamp ): "gsutil cp" gs://$2/reference/* $reference_dir | \
tee -a $logfile
gsutil cp gs://$2/reference/* $reference_dir

create the index to the genome fasta file
echo $( timestamp ): "samtools faidx" $reference_dir/hg38.genome.fa | \ 
tee -a $logfile
echo $( timestamp ): "samtools faidx"
samtools faidx $reference_dir/hg38.genome.fa

download input json template
echo $( timestamp ): "gsutil cp" gs://$2/input_json/input.json \
$project_dir/ | tee -a $logfile 
gsutil cp gs://$2/input_json/input.json $project_dir/

# modify the input json for this experiment
echo  $( timestamp ): "sed -i -e" "s/<>/$1/g" $project_dir/input.json 
sed -i -e "s/<>/$1/g" $project_dir/input.json | tee -a $logfile 

# download bpnet params json for this experiment
echo $( timestamp ): "gsutil cp" gs://$2/bpnet_params/bpnet_params.json \
$project_dir/ | tee -a $logfile 
gsutil cp gs://$2/bpnet_params/bpnet_params.json $project_dir/

# download splits json template
echo $( timestamp ): "gsutil cp" gs://$2/splits/splits.json \
$project_dir/ | tee -a $logfile 
gsutil cp gs://$2/splits/splits.json $project_dir/

# compute the counts loss weight to be used for this experiment
echo  $( timestamp ): "counts_loss_weight=`counts_loss_weight --input-data \
$project_dir/input.json`" | tee -a $logfile
counts_loss_weight=`counts_loss_weight --input-data $project_dir/input.json`

# modify the bpnet params json to reflect the counts loss weight
echo  $( timestamp ): "sed -i -e" "s/<>/$counts_loss_weight/g" \
$project_dir/bpnet_params.json | tee -a $logfile 
sed -i -e "s/<>/$counts_loss_weight/g" $project_dir/bpnet_params.json

train \
    --input-data $project_dir/input.json \
    --output-dir $model_dir \
    --reference-genome $reference_dir/hg38.genome.fa \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt)  \
    --shuffle \
    --epochs 100 \
    --splits $project_dir/splits.json \
    --model-arch-name BPNet \
    --model-arch-params-json $project_dir/bpnet_params.json \
    --sequence-generator-name BPNet \
    --model-output-filename $1 \
    --input-seq-len 2114 \
    --output-len 1000 \
    --threads 2 \
    --learning-rate 0.004

predictions_dir=$project_dir/predictions_and_metrics
fastpredict \
    --model $model_dir/${1}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms chr1 \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir \
    --input-data $project_dir/input.json \
    --sequence-generator-name BPNet \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000 \
    --batch-size 64 \
    --threads 2

# copy the result to gcp bucket
gsutil cp $project_dir/model/* gs://tfatlas/models/$1/
gsutil cp $project_dir/predictions_and_metrics/* gs://tfatlas/predictions_and_metrics/$1/
gsutil cp $logfile gs://tfatlas/logs
