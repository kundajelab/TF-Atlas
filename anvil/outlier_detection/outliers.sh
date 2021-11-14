#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
input_outliers_json=$2
chrom_sizes=$3
chroms_txt=${4}
bigwigs=${5}
peaks=${6}

# create the log file
logfile=$project_dir/${1}_outliers.log
touch $logfile

mkdir /project
project_dir=/project

# create the data directory
data_dir=$project_dir/data
echo $( timestamp ): "mkdir" $data_dir | tee -a $logfile
mkdir $data_dir

# create the reference directory
reference_dir=$project_dir/reference
echo $( timestamp ): "mkdir" $reference_dir | tee -a $logfile
mkdir $reference_dir


# copy down data and reference

echo $( timestamp ): "cp" $chrom_sizes ${reference_dir}/chrom.sizes |\
tee -a $logfile 

echo $( timestamp ): "cp" $chroms_txt ${reference_dir}/hg38_chroms.txt |\
tee -a $logfile 


# copy down data and reference

cp $chrom_sizes $reference_dir/chrom.sizes
cp $chroms_txt $reference_dir/hg38_chroms.txt


# Step 1: Copy the bigwig and peak files

echo $bigwigs | sed 's/,/ /g' | xargs cp -t $data_dir/

echo $( timestamp ): "cp" $bigwigs ${data_dir}/ |\
tee -a $logfile 

echo $( timestamp ): "cp" $peaks ${data_dir}/${experiment}.bed.gz |\
tee -a $logfile 

cp $peaks ${data_dir}/${experiment}.bed.gz


# download input json

echo $( timestamp ): "cp" $input_outliers_json \
$project_dir/input_outliers.json | tee -a $logfile 
cp $input_outliers_json $project_dir/input_outliers.json


# modify the input json for this experiment
echo  $( timestamp ): "sed -i -e" "s/<>/$1/g" $project_dir/input_outliers.json 
sed -i -e "s/<>/$1/g" $project_dir/input_outliers.json  | tee -a $logfile 

echo $( timestamp ): "
outliers \\
    --input-data $project_dir/input_outliers.json  \\
    --quantile 0.99 \\
    --quantile-value-scale-factor 1.2 \\
    --task 0 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \\
    --sequence-len 1000 \\
    --blacklist blacklist.bed \\
    --global-sample-weight 1.0 \\
    --output-bed $project_dir/peaks_inliers.bed" | tee -a $logfile 
    
outliers \
    --input-data $project_dir/input_outliers.json  \
    --quantile 0.99 \
    --quantile-value-scale-factor 1.2 \
    --task 0 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \
    --sequence-len 1000 \
    --blacklist blacklist.bed \
    --global-sample-weight 1.0 \
    --output-bed $project_dir/peaks_inliers.bed 
