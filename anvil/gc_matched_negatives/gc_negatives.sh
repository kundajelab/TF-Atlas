#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}


experiment=$1
reference_file=$2
reference_file_index=$3
chrom_sizes=$4
chroms_txt=$5
reference_gc_hg38_stride_1000_flank_size_1057=$6
peaks=$7
split_folds=$8

mkdir /project
project_dir=/project

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


echo $( timestamp ): "cp" $peaks ${data_dir}/${1}_inliers.bed.gz |\
tee -a $logfile 

cp $peaks ${data_dir}/${1}_inliers.bed.gz

echo $( timestamp ): "gunzip" ${data_dir}/${1}_inliers.bed.gz |\
tee -a $logfile 

gunzip ${data_dir}/${1}_inliers.bed.gz


# copy down data and reference
echo $( timestamp ): "cp" $reference_file ${reference_dir}/hg38.genome.fa | \
tee -a $logfile 

echo $( timestamp ): "cp" $reference_file_index ${reference_dir}/hg38.genome.fa.fai |\
tee -a $logfile 

echo $( timestamp ): "cp" $chrom_sizes ${reference_dir}/chrom.sizes |\
tee -a $logfile 

echo $( timestamp ): "cp" $chroms_txt ${reference_dir}/hg38_chroms.txt |\
tee -a $logfile 

echo $( timestamp ): "cp" $reference_gc_hg38_stride_1000_flank_size_1057 ${reference_dir}/genomewide_gc_hg38_stride_1000_flank_size_1057.bed |\
tee -a $logfile 

# copy down data and reference

cp $reference_file ${reference_dir}/hg38.genome.fa
cp $reference_file_index ${reference_dir}/hg38.genome.fa.fai
cp $chrom_sizes $reference_dir/chrom.sizes
cp $chroms_txt $reference_dir/hg38_chroms.txt
cp $reference_gc_hg38_stride_1000_flank_size_1057 ${reference_dir}/genomewide_gc_hg38_stride_1000_flank_size_1057.bed


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
    $reference_dir/genomewide_gc_hg38_stride_1000_flank_size_1057.bed \\
    -b $data_dir/${1}_inliers.bed > $data_dir/${experiment}.tsv" | \
    tee -a $logfile 

bedtools intersect -v -a \
$reference_dir/genomewide_gc_hg38_stride_1000_flank_size_1057.bed \
-b $data_dir/${1}_inliers.bed > $data_dir/${experiment}.tsv

echo $( timestamp ): "
python get_gc_matched_negatives.py \\
        --candidate_negatives $data_dir/${experiment}.tsv \\
        --foreground_gc_bed  $data_dir/$experiment.gc.bed \\
        --output_prefix $data_dir/${experiment}_negatives \\
        --chr_fold_path $split_folds\\
        --neg_to_pos_ratio_train 4" \\ | tee -a $logfile 

python get_gc_matched_negatives.py \
        --candidate_negatives $data_dir/${experiment}.tsv \
        --foreground_gc_bed  $data_dir/$experiment.gc.bed \
        --chr_fold_path $split_folds \
        --output_prefix $data_dir/${experiment}_negatives \
        --neg_to_pos_ratio_train 4


# also export the negatives only file
echo $( timestamp ): "mv" $data_dir/${experiment}_negatives.bed \
    $data_dir/gc_neg_only.bed  | tee -a $logfile 

mv $data_dir/${experiment}_negatives.bed $data_dir/gc_neg_only.bed

mv $data_dir/${experiment}_negatives_compared_with_foreground.png $data_dir/gc_distribution.png

