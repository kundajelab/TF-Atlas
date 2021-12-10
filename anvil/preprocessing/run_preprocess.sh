#!/bin/bash

# TF-Atlas pipeline
# Step 1. Copy reference files from gcp
# Step 2. Download bams and peaks file for the experiment
# Step 3. Process bam files to generate bigWigs
# Step 4. Modeling, predictions, metrics, shap, modisco, embeddings
# Step 5. Generate reports

# import the utils script
source ./utils.sh



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

tuning=`jq .tuning $pipeline_json | sed 's/"//g'`

learning_rate=`jq .learning_rate $pipeline_json | sed 's/"//g'`

counts_loss_weight=`jq .counts_loss_weight $pipeline_json | sed 's/"//g'`

epochs=`jq .epochs $pipeline_json | sed 's/"//g'`

gcp_bucket=`jq .gcp_bucket $pipeline_json | sed 's/"//g'`

encode_access_key=$2

encode_secret_key=$3

# the place where the results of the pipeline run will be stored
# either mnt or gcp. If "mnt" then output files are stored in 
# --mnt target, or if "gcp" then the files are uploaded to gcp
pipeline_destination=$4

reference_file=${5}
reference_file_index=${6}
chrom_sizes=${7}


# create log file
logfile=$experiment.log
touch $logfile



# Step 0. Create all required directories

dst_dir=$PWD/

# local reference files directory
reference_dir=${dst_dir}reference
echo $( timestamp ): "mkdir" $reference_dir | tee -a $logfile
mkdir $reference_dir

# directory to store downloaded files
downloads_dir=${dst_dir}downloads
echo $( timestamp ): "mkdir" $downloads_dir | tee -a $logfile
mkdir $downloads_dir

# directory to store intermediate preprocessing files
# (merged bams, bedGraphs)
intermediates_dir=${dst_dir}intermediates
echo $( timestamp ): "mkdir" $intermediates_dir | tee -a $logfile
mkdir $intermediates_dir

# directory to store bigWigs
bigWigs_dir=${dst_dir}bigWigs
echo $( timestamp ): "mkdir" $bigWigs_dir | tee -a $logfile
mkdir $bigWigs_dir


# Step 1: Copy the reference files

echo $( timestamp ): "cp" $reference_file $reference_dir/ | \
tee -a $logfile 
echo $( timestamp ): "cp" $reference_file_index $reference_dir/ |\
tee -a $logfile 


cp $reference_file $reference_dir/
cp $reference_file_index $reference_dir/
cp $chrom_sizes $reference_dir/chrom.sizes

# Step 2. download bam files and peaks file

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

# Step pre_4: Create the input json for the experiment that will
# be used in training
echo $( timestamp ): "python create_input_json.py" $experiment $peaks True \
True $bigWigs_dir $downloads_dir . | tee -a $logfile

python create_input_json.py $experiment $peaks True True $bigWigs_dir \
$downloads_dir .
