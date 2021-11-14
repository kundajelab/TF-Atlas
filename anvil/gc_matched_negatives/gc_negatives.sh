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
ratio=$4

# create the log file
logfile=$project_dir/${1}_gc_matched_negatives.log
touch $logfile

# create the data directory
data_dir=$project_dir/data
echo $( timestamp ): "mkdir" $data_dir | tee -a $logfile
mkdir $data_dir

# create the reference directory
reference_dir=$project_dir/reference
echo $( timestamp ): "mkdir" $reference_dir | tee -a $logfile
mkdir $reference_dir

# copy down inliers bed file and reference files
echo $( timestamp ): "gsutil cp" gs://$2/data/$1/${1}_inliers.bed $data_dir | \
tee -a $logfile
gsutil cp gs://$2/data/$1/$1_inliers.bed  $data_dir

echo $( timestamp ): "gsutil -m cp" gs://$gcp_bucket/reference/* \
$reference_dir/ | tee -a $logfile
gsutil -m cp gs://$gcp_bucket/reference/* $reference_dir/

# create index for the fasta file
echo $( timestamp ): "samtools faidx" $reference_dir/genome.fa | \
tee -a $logfile
samtools faidx $reference_dir/hg38.genome.fa

echo $( timestamp ): "
python get_gc_content.py \\
       --input_bed $data_dir/${1}_inliers.bed \\
       --ref_fasta $reference_dir/hg38.genome.fa \\
       --out_prefix $data_dir/$experiment.gc.bed \\
       --flank_size 1057" | tee -a $logfile 

python get_gc_content.py \
       --input_bed $data_dir/${1}_inliers.bed \
       --ref_fasta $reference_dir/hg38.genome.fa \
       --out_prefix $data_dir/$experiment.gc.bed \
       --flank_size 1057

echo $( timestamp ): "
bedtools intersect -v -a \\
    $reference_dir/genomewide_gc_hg38_stride_50_flank_size_1057.bed \\
    -b $data_dir/${1}_inliers.bed > $data_dir/${experiment}.tsv" | \
    tee -a $logfile 

bedtools intersect -v -a \
$reference_dir/genomewide_gc_hg38_stride_50_flank_size_1057.bed \
-b $data_dir/${1}_inliers.bed > $data_dir/${experiment}.tsv

echo $( timestamp ): "
python get_gc_matched_negatives.py \\
        --candidate_negatives $data_dir/${experiment}.tsv \\
        --foreground_gc_bed  $data_dir/$experiment.gc.bed \\
        --out_prefix $data_dir/${experiment}_negatives.bed" | tee -a $logfile 

python get_gc_matched_negatives.py \
        --candidate_negatives $data_dir/${experiment}.tsv \
        --foreground_gc_bed  $data_dir/$experiment.gc.bed \
        --out_prefix $data_dir/${experiment}_negatives.bed

# select negatives based on specified ratio

# count the number of lines in the bed file
echo $( timestamp ): "num_negatives=`cat $data_dir/${experiment}_negatives.bed | wc -l`" | tee -a $logfile 
num_negatives=`cat $data_dir/${experiment}_negatives.bed | wc -l`

# number of lines to select
echo $( timestamp ): "num_select=($num_negatives / $ratio)" | tee -a $logfile 
num_select=$(( num_negatives / ratio ))

# select random rows
echo $( timestamp ): "shuf -n" $num_select $data_dir/${experiment}_negatives.bed \
">" $data_dir/${experiment}_negatives_select.bed | tee -a $logfile 
shuf -n $num_select $data_dir/${experiment}_negatives.bed > \
    $data_dir/${experiment}_negatives_select.bed

# combine the gc matched negatives and the original peaks file into 
# a single file
echo $( timestamp ): "cat" $data_dir/${1}_inliers.bed $data_dir/${experiment}_negatives_select.bed ">" \
    $data_dir/${experiment}_combined_1_${ratio}.bed  | tee -a $logfile 

cat $data_dir/${1}_inliers.bed $data_dir/${experiment}_negatives_select.bed > \
    $data_dir/${experiment}_combined_1_${ratio}.bed

# copy combined bed file to gcp
echo $( timestamp ): "gsutil cp" $data_dir/${experiment}_combined_1_${ratio}.bed  gs://$2/data/$1/ | \
tee -a $logfile
gsutil cp $data_dir/${experiment}_combined_1_${ratio}.bed  gs://$2/data/$1/

# copy log file to gcp
echo $( timestamp ): "gsutil cp" $logfile gs://$2/logs/ | tee -a $logfile 
gsutil cp $logfile gs://$2/logs/
