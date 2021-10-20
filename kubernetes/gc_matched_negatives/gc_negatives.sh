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
samtools faidx $reference_dir/genome.fa

echo $( timestamp ): "
python /tfatlas/SVM_pipelines/make_inputs/get_gc_content.py \\
       --input_bed $data_dir/${1}_inliers.bed \\
       --ref_fasta $reference_dir/hg38.genome.fa \\
       --out_prefix $data_dir/$experiment.gc \\
       --center_summit \\
       --flank_size 1057 \\
       --store_seq" | tee -a $logfile 

python /tfatlas/SVM_pipelines/make_inputs/get_gc_content.py \
       --input_bed $data_dir/${1}_inliers.bed \
       --ref_fasta $reference_dir/hg38.genome.fa \
       --out_prefix $data_dir/$experiment.gc \
       --center_summit \
       --flank_size 1057 \
       --store_seq

echo $( timestamp ): "bedtools intersect -v -a" $reference_dir/gc_hg38_nosmooth.tsv \
"-b" $data_dir/${1}_inliers.bed > $data_dir/$experiment.tsv  | tee -a $logfile 

bedtools intersect -v -a $reference_dir/gc_hg38_nosmooth.tsv \
-b $data_dir/${1}_inliers.bed > $data_dir/$experiment.tsv

echo $( timestamp ): "
python /tfatlas/SVM_pipelines/SVM_pipelines/make_inputs/get_chrom_gc_region_dict.py \\
    --input_bed $data_dir/$experiment.tsv \\
    --outf $data_dir/$experiment.gc.p" | tee -a $logfile 

python /tfatlas/SVM_pipelines/SVM_pipelines/make_inputs/get_chrom_gc_region_dict.py \
    --input_bed $data_dir/$experiment.tsv \
    --outf $data_dir/${experiment}.gc.p

echo $( timestamp ): "
python create_negatives_bed.py \\
    --out-bed $data_dir/${experiment}_negatives.bed \\
    --neg-pickle $data_dir/$experiment.gc.p \\
    --ref-fasta $reference_dir/hg38.genome.fa \\
    --peaks $data_dir/${experiment}.gc" | tee -a $logfile 

python create_negatives_bed.py \
    --out-bed $data_dir/${experiment}_negatives.bed \
    --neg-pickle $data_dir/${experiment}.gc.p \
    --ref-fasta $reference_dir/hg38.genome.fa1 \
    --peaks $data_dir/${experiment}.gc


