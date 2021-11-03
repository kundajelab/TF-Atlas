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
logfile=$project_dir/${1}_outliers.log
touch $logfile

# create the data directory
data_dir=$project_dir/data
echo $( timestamp ): "mkdir" $data_dir | tee -a $logfile
mkdir $data_dir

# create the reference directory
reference_dir=$project_dir/reference
echo $( timestamp ): "mkdir" $reference_dir | tee -a $logfile
mkdir $reference_dir

# copy down data and reference
echo $( timestamp ): "gsutil cp" gs://$2/data/$1/*.bigWig $data_dir | \
tee -a $logfile
gsutil cp gs://$2/data/$1/*.bigWig $data_dir

echo $( timestamp ): "gsutil cp" gs://$2/data/$1/$1.bed.gz $data_dir | \
tee -a $logfile
gsutil cp gs://$2/data/$1/$1.bed.gz $data_dir

echo $( timestamp ): "gsutil cp" gs://$2/reference/hg38_chroms.txt $reference_dir | \
tee -a $logfile
gsutil cp gs://$2/reference/hg38_chroms.txt $reference_dir

echo $( timestamp ): "gsutil cp" gs://$2/reference/chrom.sizes $reference_dir | \
tee -a $logfile
gsutil cp gs://$2/reference/chrom.sizes $reference_dir

# download input json
echo $( timestamp ): "gsutil cp" gs://$2/input_json/input_outliers.json  $project_dir | \
tee -a $logfile 
gsutil cp gs://$2/input_json/input_outliers.json $project_dir/

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
    --output-bed ${experiment}_inliers.bed" | tee -a $logfile 
    
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
    --output-bed ${experiment}_inliers.bed 

# copy inliers bed file to gcp
echo $( timestamp ): "gsutil cp" ${experiment}_inliers.bed  gs://$2/data/$1/ | \
tee -a $logfile
gsutil cp ${experiment}_inliers.bed  gs://$2/data/$1/

# copy log file to gcp
echo $( timestamp ): "gsutil cp" $logfile gs://$2/logs/ | tee -a $logfile 
gsutil cp $logfile gs://$2/logs/
