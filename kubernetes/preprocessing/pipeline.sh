#!/bin/bash

# TF-Atlas pipeline
# Step 1. Copy reference files from gcp
# Step 2. Download bams and peaks file for the experiment
# Step 3. Process bam files to generate bigWigs

# import the utils script
. utils.sh

# path to json file with pipeline params
pipeline_json=$1

# get params from the pipleine json
experiment=`jq .experiment $pipeline_json | sed 's/"//g'` 

assembly=`jq .assembly $pipeline_json | sed 's/"//g'`

unfiltered_alignments=`jq .unfiltered_alignments $pipeline_json | sed 's/"//g'`

unfiltered_alignments_md5sums=\
`jq .unfiltered_alignments_md5sums $pipeline_json | sed 's/"//g'`

alignments=`jq .alignments $pipeline_json | sed 's/"//g'`

alignments_md5sums=`jq .alignments_md5sums $pipeline_json | sed 's/"//g'`

control_unfiltered_alignments=\
`jq .control_unfiltered_alignments $pipeline_json | sed 's/"//g'`

control_unfiltered_alignments_md5sums=\
`jq .control_unfiltered_alignments_md5sums $pipeline_json | sed 's/"//g'`

control_alignments=`jq .control_alignments $pipeline_json | sed 's/"//g'`

control_alignments_md5sums=\
`jq .control_alignments_md5sums $pipeline_json | sed 's/"//g'`

peaks=`jq .peaks $pipeline_json | sed 's/"//g'`

peaks_md5sum=`jq .peaks_md5sum $pipeline_json | sed 's/"//g'`

gcp_bucket=`jq .gcp_bucket $pipeline_json | sed 's/"//g'`

encode_access_key=$2

encode_secret_key=$3

project_dir=$4

logfile=$5

# Step 0. Create all required directories
# local reference files directory
reference_dir=${project_dir}/reference
echo $( timestamp ): "mkdir" $reference_dir | tee -a $logfile
mkdir $reference_dir

# directory to store downloaded files
downloads_dir=${project_dir}/downloads
echo $( timestamp ): "mkdir" $downloads_dir | tee -a $logfile
mkdir $downloads_dir

# directory to store intermediate preprocessing files
# (merged bams, bedGraphs)
intermediates_dir=${project_dir}/intermediates
echo $( timestamp ): "mkdir" $intermediates_dir | tee -a $logfile
mkdir $intermediates_dir

# directory to store bigWigs
bigWigs_dir=${project_dir}/bigWigs
echo $( timestamp ): "mkdir" $bigWigs_dir | tee -a $logfile
mkdir $bigWigs_dir

# Step 1. Download the reference files from gcp based on assembly
echo $( timestamp ): "gsutil -m cp" gs://$gcp_bucket/reference/* \
$reference_dir/ | tee -a $logfile
gsutil -m cp gs://$gcp_bucket/reference/* $reference_dir/

# Step 1.1 create index for the fasta file
echo $( timestamp ): "samtools faidx" $reference_dir/genome.fa | \
tee -a $logfile
samtools faidx $reference_dir/genome.fa

# Step 2. download bam files and peaks file

# 2.1 download unfiltered alignments bams
download_file "$unfiltered_alignments" "bam" \
"$unfiltered_alignments_md5sums" 1 $logfile $encode_access_key \
$encode_secret_key $downloads_dir

# 2.2 download alignments bams
download_file "$alignments" "bam" "$alignments_md5sums" 1 $logfile \
$encode_access_key $encode_secret_key $downloads_dir

# 2.3 download control unfiltered alignmentsbams
download_file "$control_unfiltered_alignments" "bam" \
"$control_unfiltered_alignments_md5sums" 1 $logfile $encode_access_key \
$encode_secret_key $downloads_dir

# 2.4 download control alignments bams
download_file "$control_alignments" "bam" "$control_alignments_md5sums" 1 \
$logfile $encode_access_key $encode_secret_key $downloads_dir

# 2.5 download peaks file
download_file $peaks "bed.gz" $peaks_md5sum 1 $logfile $encode_access_key \
$encode_secret_key $downloads_dir

wait_for_jobs_to_finish "Download"

# Step 3. preprocess

# 3.1 preprocess experiment bams
./preprocessing.sh $experiment "$unfiltered_alignments" "$alignments" \
$downloads_dir $intermediates_dir $bigWigs_dir True False $reference_dir \
$logfile &

echo $( timestamp ): [$!] "./preprocessing.sh" $experiment \
\"$unfiltered_alignments\" \"$alignments\" $downloads_dir $intermediates_dir \
$bigWigs_dir True False $reference_dir $logfile  | tee -a $logfile

# 3.2 preprocess experiment control bams
./preprocessing.sh $experiment "$control_unfiltered_alignments" \
"$control_alignments" $downloads_dir $intermediates_dir $bigWigs_dir \
True True $reference_dir $logfile &

echo $( timestamp ): [$!] "./preprocessing.sh" $experiment \
\"$control_unfiltered_alignments\" \"$control_alignments\" $downloads_dir \
$intermediates_dir $bigWigs_dir True True $reference_dir $logfile | \
tee -a $logfile

wait_for_jobs_to_finish "Preprocessing"

# bigWigs
echo $( timestamp ): "gsutil -m cp" $bigWigs_dir/* \
gs://$gcp_bucket/data/$experiment/ | tee -a $logfile

gsutil -m cp $bigWigs_dir/* gs://$gcp_bucket/data/$experiment/

