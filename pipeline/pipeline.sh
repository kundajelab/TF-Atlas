#!/bin/bash

# TF-Atlas pipeline
# Step 1. Copy reference files from gcp
# Step 2. Download bams and peaks file for the experiment
# Step 3. Process bam files to generate bigWigs
# Step 4. Modeling, predictions, metrics, shap, modisco, embeddings
# Step 5. Generate reports

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

has_control=`jq .has_control $pipeline_json | sed 's/"//g'`

stranded=`jq .stranded $pipeline_json | sed 's/"//g'`

model_arch_name=`jq .model_arch_name $pipeline_json | sed 's/"//g'`

sequence_generator_name=\
`jq .sequence_generator_name $pipeline_json | sed 's/"//g'`

splits_json_path=`jq .splits_json_path $pipeline_json | sed 's/"//g'`

test_chroms=`jq .test_chroms $pipeline_json | sed 's/"//g'`

gcp_bucket=`jq .gcp_bucket $pipeline_json | sed 's/"//g'`

encode_access_key=$2

encode_secret_key=$3

# create log file
logfile=$experiment.log
touch $logfile

# # Step 1. download reference files from gcp

# # create local reference directory
reference_dir="reference"
echo $( timestamp ): "mkdir" $reference_dir | tee -a $logfile
mkdir $reference_dir

# Step 1. Download the reference files from gcp based on assembly
echo $( timestamp ): "gsutil -m cp" gs://$gcp_bucket/reference/$assembly/* \
$reference_dir/ | tee -a $logfile
gsutil -m cp gs://$gcp_bucket/reference/$assembly/* $reference_dir/

# Step 1.1 create index for the fasta file
echo $( timestamp ): "samtools faidx" reference/genome.fa  | tee -a $logfile
samtools faidx reference/genome.fa

# Step 2. download bam files and peaks file

# directory to store downloaded files
downloads_dir="downloads"
echo $( timestamp ): "mkdir" $downloads_dir | tee -a $logfile
mkdir $downloads_dir

# 2.1 download unfiltered alignments bams
download_file "$unfiltered_alignments" "bam" \
"$unfiltered_alignments_md5sums" 1 $logfile $encode_access_key \
$encode_secret_key $downloads_dir

# 2.2 download alignments bams
download_file "$alignments" "bam" "$alignments_md5sums" 1 $logfile \
$encode_access_key $encode_secret_key $downloads_dir

if [ "$has_control" = "True" ]
then
    # 2.3 download control unfiltered alignmentsbams
    download_file "$control_unfiltered_alignments" "bam" \
    "$control_unfiltered_alignments_md5sums" 1 $logfile $encode_access_key \
    $encode_secret_key $downloads_dir

    # 2.4 download control alignments bams
    download_file "$control_alignments" "bam" "$control_alignments_md5sums" 1 \
    $logfile $encode_access_key $encode_secret_key $downloads_dir
fi

# 2.5 download peaks file
download_file $peaks "bed.gz" $peaks_md5sum 1 $logfile $encode_access_key \
$encode_secret_key $downloads_dir

wait_for_jobs_to_finish "Download"

# Step 3. preprocess

# create a new directory to store intermediate files
intermediates_dir=intermediates
echo $( timestamp ): "mkdir" $intermediates_dir | tee -a $logfile
mkdir $intermediates_dir

# create a new directory to store bigWigs
bigWigs_dir=bigWigs
echo $( timestamp ): "mkdir" $bigWigs_dir | tee -a $logfile
mkdir $bigWigs_dir

# 3.1 preprocess experiment bams
./preprocessing.sh $experiment "$unfiltered_alignments" "$alignments" \
$downloads_dir $intermediates_dir $bigWigs_dir $stranded False $reference_dir \
$logfile &

echo $( timestamp ): [$!] "./preprocessing.sh" $experiment \
\"$unfiltered_alignments\" \"$alignments\" $downloads_dir $intermediates_dir \
$bigWigs_dir $stranded False $reference_dir $logfile  | tee -a $logfile


if [ "$has_control" = "True" ]
then
    # 3.2 preprocess experiment control bams
    ./preprocessing.sh $experiment "$control_unfiltered_alignments" \
    "$control_alignments" $downloads_dir $intermediates_dir $bigWigs_dir \
    $stranded True $reference_dir $logfile &
    
    echo $( timestamp ): [$!] "./preprocessing.sh" $experiment \
    \"$control_unfiltered_alignments\" \"$control_alignments\" $downloads_dir \
    $intermediates_dir $bigWigs_dir $stranded True $reference_dir $logfile | \
    tee -a $logfile

fi

wait_for_jobs_to_finish "Preprocessing"

# Step pre_4:
echo $( timestamp ): "python create_input_json.py" $experiment $peaks True \
True $bigWigs_dir $downloads_dir . | tee -a $logfile

python create_input_json.py $experiment $peaks True True $bigWigs_dir \
$downloads_dir .
    
# Step 4. Run 3M

# Step 4.1 Modeling
model_dir=model
echo $( timestamp ): "mkdir" $model_dir
mkdir $model_dir

predictions_dir=predictions
echo $( timestamp ): "mkdir" $predictions_dir | tee -a $logfile
mkdir $predictions_dir

embeddings_dir=embeddings
echo $( timestamp ): "mkdir" $embeddings_dir | tee -a $logfile
mkdir $embeddings_dir

echo $( timestamp ): "./modeling.sh" $experiment $model_arch_name \
$sequence_generator_name $splits_json_path $reference_dir $model_dir \
$predictions_dir $embeddings_dir $logfile | tee -a $logfile

./modeling.sh $experiment $model_arch_name $sequence_generator_name \
$splits_json_path $reference_dir $model_dir $predictions_dir \
$embeddings_dir $logfile

# Step 4.3 Metrics

echo $( timestamp ): "./metrics.sh" $experiment $downloads_dir $reference_dir \
$predictions_dir $peaks $test_chroms $logfile | tee -a $logfile

./metrics.sh $experiment $downloads_dir $reference_dir $predictions_dir \
$peaks $test_chroms $logfile

# Step 4.3 Modisco

# create shap directory
shap_dir=shap
echo $( timestamp ): "mkdir" $shap_dir | tee -a $logfile
mkdir $shap_dir

# create modisco dir
modisco_dir=modisco
echo $( timestamp ): "mkdir" $modisco_dir | tee -a $logfile
mkdir $modisco_dir

# create subdirectory for modisco on profile shap scores
modisco_profile_dir=$modisco_dir/profile
echo $( timestamp ): "mkdir" $modisco_profile_dir | tee -a $logfile
mkdir $modisco_profile_dir

# create subdirectory for modisco on counts shap scores
modisco_counts_dir=$modisco_dir/counts
echo $( timestamp ): "mkdir" $modisco_counts_dir | tee -a $logfile
mkdir $modisco_counts_dir

# run shap followed by modisco
echo $( timestamp ): "./modisco.sh" $experiment $reference_dir $downloads_dir \
$model_dir $peaks $shap_dir $modisco_profile_dir $modisco_counts_dir \
$logfile | tee -a $logfile

./modisco.sh $experiment $reference_dir $downloads_dir $model_dir $peaks \
$shap_dir $modisco_profile_dir $modisco_counts_dir $logfile

#Step 5. reports

echo $( timestamp ): Done. | tee -a $logfile
