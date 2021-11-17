#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
input_json=$2
reference_file=$3
reference_file_index=$4
chrom_sizes=$5
chroms_txt=$6
bigwigs=$7
peaks=$8
model=$9

mkdir /project
project_dir=/project

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


echo $( timestamp ): "cp" $reference_file ${reference_dir}/hg38.genome.fa | \
tee -a $logfile 

echo $( timestamp ): "cp" $reference_file_index ${reference_dir}/hg38.genome.fa.fai |\
tee -a $logfile 

echo $( timestamp ): "cp" $chrom_sizes ${reference_dir}/chrom.sizes |\
tee -a $logfile 

echo $( timestamp ): "cp" $chroms_txt ${reference_dir}/hg38_chroms.txt |\
tee -a $logfile 



# copy down data and reference

cp $reference_file $reference_dir/hg38.genome.fa
cp $reference_file_index $reference_dir/hg38.genome.fa.fai
cp $chrom_sizes $reference_dir/chrom.sizes
cp $chroms_txt $reference_dir/hg38_chroms.txt


# Step 1: Copy the bigwigs, model and peak files

echo $( timestamp ): "cp" $bigwigs ${data_dir}/ |\
tee -a $logfile 

echo $bigwigs | sed 's/,/ /g' | xargs cp -t $data_dir/


echo $( timestamp ): "cp" $model ${model_dir}/ |\
tee -a $logfile 

echo $model | sed 's/,/ /g' | xargs cp -t $model_dir/


echo $( timestamp ): "cp" $peaks ${data_dir}/${experiment}.bed.gz |\
tee -a $logfile 

cp $peaks ${data_dir}/${experiment}.bed.gz

echo $( timestamp ): "gunzip" ${data_dir}/${experiment}.bed.gz |\
tee -a $logfile 

gunzip ${data_dir}/${experiment}.bed.gz

ls ${data_dir}


# download input json template
# the input json 

echo $( timestamp ): "cp" $input_json \
$project_dir/input.json | tee -a $logfile 
cp $input_json $project_dir/input.json


# modify the input json for 
echo  $( timestamp ): "sed -i -e" "s/<>/$1/g" $project_dir/input.json 
sed -i -e "s/<>/$1/g" $project_dir/input.json | tee -a $logfile 


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
