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

# create log file
logfile=$experiment.log
touch $logfile



# Step 0. Create all required directories

# check if the pipeline_destination folder exists
if [ "$pipeline_destination" != "gcp" ] && [ ! -d $pipeline_destination ]
then
    echo Pipeline destination folder $pipeline_destination does not exist! | \
    tee -a $logfile
    exit 1
fi

if [ "$pipeline_destination" = "gcp" ]
then
    # all outputs be stored in the local directory first
    dst_dir=$PWD/
else
    dst_dir=$pipeline_destination/
fi

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

# create new directory to store model file
model_dir=${dst_dir}model
echo $( timestamp ): "mkdir" $model_dir | tee -a $logfile
mkdir $model_dir

# create new directory to store hyperparameter tuning files
tuning_dir=${dst_dir}tuning
echo $( timestamp ): "mkdir" $tuning_dir | tee -a $logfile
mkdir $tuning_dir

# dreictory to store predictions
predictions_dir=${dst_dir}predictions
echo $( timestamp ): "mkdir" $predictions_dir | tee -a $logfile
mkdir $predictions_dir

# directory to store computed embeddings
embeddings_dir=${dst_dir}embeddings
echo $( timestamp ): "mkdir" $embeddings_dir | tee -a $logfile
mkdir $embeddings_dir

# directory to store min max bounds
bounds_dir=${dst_dir}bounds
echo $( timestamp ): "mkdir" $bounds_dir | tee -a $logfile
mkdir $bounds_dir
   
# directory to store metrics output
metrics_dir=${dst_dir}metrics
echo $( timestamp ): "mkdir" $metrics_dir | tee -a $logfile
mkdir $metrics_dir

# directory to store shap contribution scores
shap_dir=${dst_dir}shap
echo $( timestamp ): "mkdir" $shap_dir | tee -a $logfile
mkdir $shap_dir

# directory to store modisco output
modisco_dir=${dst_dir}modisco
echo $( timestamp ): "mkdir" $modisco_dir | tee -a $logfile
mkdir $modisco_dir

# directory to store motif databases needed for reports generation
motif_dbs_dir=${dst_dir}motif_databases
echo $( timestamp ): "mkdir" $motif_dbs_dir | tee -a $logfile
mkdir $motif_dbs_dir

# directory to store the temp output of tomtom matching in MEME suite
tomtom_temp_dir=${dst_dir}tomtom
echo $( timestamp ): "mkdir" $tomtom_temp_dir | tee -a $logfile
mkdir $tomtom_temp_dir

# directory to store html reports 
reports_output_dir=${dst_dir}reports_output
echo $( timestamp ): "mkdir" $reports_output_dir | tee -a $logfile
mkdir $reports_output_dir

# create subdirectory for modisco on profile shap scores
modisco_profile_dir=$modisco_dir/profile
echo $( timestamp ): "mkdir" $modisco_profile_dir | tee -a $logfile
mkdir $modisco_profile_dir

# create subdirectory for modisco on counts shap scores
modisco_counts_dir=$modisco_dir/counts
echo $( timestamp ): "mkdir" $modisco_counts_dir | tee -a $logfile
mkdir $modisco_counts_dir

# Step 1. Download the reference files from gcp based on assembly
echo $( timestamp ): "gsutil -m cp" gs://$gcp_bucket/reference/$assembly/* \
$reference_dir/ | tee -a $logfile
gsutil -m cp gs://$gcp_bucket/reference/$assembly/* $reference_dir/

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
    
# Step 4. Run 3M (Modeling, Metrics, Modisco)


if [ "$tuning" = "True" ]
then
    # Step 4.1.0 Tuning
    
    # We will train models with different hyperparameters and 
    # pick the learning rate and counts_loss_weight based on the model
    # with the lowest loss. This can be any script it just to output
    # tuning_output.json with learning_rate and counts_loss_weight values.

    echo $( timestamp ): "./tuning.sh" $experiment $model_arch_name \
    $sequence_generator_name $splits_json_path $peaks $learning_rate \
    $counts_loss_weight $epochs $reference_dir $downloads_dir $model_dir \
    $predictions_dir $embeddings_dir $logfile $tuning_dir | tee -a $logfile

    ./tuning.sh $experiment $model_arch_name $sequence_generator_name \
    $splits_json_path $peaks $learning_rate $counts_loss_weight $epochs \
    $reference_dir $downloads_dir $model_dir $predictions_dir $embeddings_dir \
    $logfile $tuning_dir | tee -a $logfile


    learning_rate=`jq .learning_rate tuning_output.json | sed 's/"//g'`

    counts_loss_weight=`jq .counts_loss_weight tuning_output.json | sed 's/"//g'`
    
    echo "learning_rate="$learning_rate
    echo "counts_loss_weight="$counts_loss_weight

fi

# Step 4.1.1 Modeling

echo $( timestamp ): "./modeling.sh" $experiment $model_arch_name \
$sequence_generator_name $splits_json_path $peaks $learning_rate \
$counts_loss_weight $epochs $reference_dir $downloads_dir $model_dir \
$predictions_dir $embeddings_dir $logfile | tee -a $logfile

./modeling.sh $experiment $model_arch_name $sequence_generator_name \
$splits_json_path $peaks $learning_rate $counts_loss_weight $epochs \
$reference_dir $downloads_dir $model_dir $predictions_dir $embeddings_dir \
$logfile

# Step 4.2 Metrics

echo $( timestamp ): "./metrics.sh" $experiment $downloads_dir $reference_dir \
$predictions_dir $peaks $test_chroms $logfile | tee -a $logfile

./metrics.sh $experiment $downloads_dir $reference_dir $predictions_dir \
$peaks $test_chroms $bounds_dir $metrics_dir $logfile

# Step 4.3 Modisco

# run shap followed by modisco
echo $( timestamp ): "./modisco.sh" $experiment $reference_dir $downloads_dir \
$model_dir $peaks $shap_dir $modisco_profile_dir $modisco_counts_dir \
$logfile | tee -a $logfile

./modisco.sh $experiment $reference_dir $downloads_dir $model_dir $peaks \
$shap_dir $modisco_profile_dir $modisco_counts_dir $logfile

# Step pre_5. Convert predictions to hdf5

echo $( timestamp ):"
python convert_predictions_to_HDF5.py \\
    2114 \\
    1000 \\
    $bigWigs_dir/${experiment}_plus.bigWig \\
    $bigWigs_dir/${experiment}_minus.bigWig \\
    $predictions_dir/${experiment}_split000_task0_plus.bw \\
    $predictions_dir/${experiment}_split000_task0_minus.bw \\
    $predictions_dir/${experiment}_split000_task0_plus_exponentiated_counts.bw \\
    $predictions_dir/${experiment}_split000_task0_minus_exponentiated_counts.bw \\
    $downloads_dir/${peaks}.bed.gz \\
    \"$(paste -s -d ' ' $reference_dir/chroms.txt)\" \\
    $predictions_dir/profile_predictions.h5" | tee -a $logfile

python convert_predictions_to_HDF5.py \
    2114 \
    1000 \
    $bigWigs_dir/${experiment}_plus.bigWig \
    $bigWigs_dir/${experiment}_minus.bigWig \
    $predictions_dir/${experiment}_split000_task0_plus.bw \
    $predictions_dir/${experiment}_split000_task0_minus.bw \
    $predictions_dir/${experiment}_split000_task0_plus_exponentiated_counts.bw \
    $predictions_dir/${experiment}_split000_task0_minus_exponentiated_counts.bw \
    $downloads_dir/${peaks}.bed.gz \
    "$(paste -s -d ' ' $reference_dir/chroms.txt)" \
    $predictions_dir/profile_predictions.h5

# Step 5. Generate Reports
reports_notebooks_dir=reports

# copy motif data databases, required for tomtom matching, from gcp
echo $( timestamp ): "gsutil -m cp" gs://$gcp_bucket/motif_databases/* \
$motif_dbs_dir/ | tee -a $logfile
gsutil -m cp gs://$gcp_bucket/motif_databases/* $motif_dbs_dir/

# run the reports generation script that converts reports notebooks
# to HTML
echo $( timestamp ): "./run_tf_atlas_reports.sh" $experiment $peaks \
$reference_dir $downloads_dir $predictions_dir \
$metrics_dir $embeddings_dir $shap_dir $modisco_dir \
$motif_dbs_dir/HOCOMOCO_JASPAR_motifs.txt $tomtom_temp_dir \
$reports_notebooks_dir $reports_output_dir | tee -a $logfile

./run_tf_atlas_reports.sh $experiment $peaks $reference_dir \
$downloads_dir $predictions_dir $metrics_dir \
$embeddings_dir $shap_dir $modisco_dir \
$motif_dbs_dir/HOCOMOCO_JASPAR_motifs.txt $tomtom_temp_dir \
$reports_notebooks_dir $reports_output_dir

echo $( timestamp ): Done. | tee -a $logfile

# Step 6. Copy files to gcp if pipeline_destination is "gcp"
if [ "$pipeline_destination" = "gcp" ]
then
    # bigWigs
    echo $( timestamp ): "gsutil -m cp" $bigWigs_dir/* \
    gs://$gcp_bucket/data/bigWigs/$experiment/ | tee -a $logfile

    gsutil -m cp $bigWigs_dir/* gs://$gcp_bucket/data/bigWigs/$experiment/
    
    # model
    echo $( timestamp ): "gsutil -m cp" $model_dir/* \
    gs://$gcp_bucket/models/$experiment/ | tee -a $logfile

    gsutil -m cp $model_dir/* gs://$gcp_bucket/models/$experiment/
    
    # predictions
    echo $( timestamp ): "gsutil -m cp" $predictions_dir/* \
    gs://$gcp_bucket/predictions/$experiment/ | tee -a $logfile
    
    gsutil -m cp $predictions_dir/* gs://$gcp_bucket/predictions/$experiment/
    
    # metrics
    echo $( timestamp ): "gsutil -m cp" $metrics_dir/* \
    gs://$gcp_bucket/metrics/$experiment/
    
    gsutil -m cp $metrics_dir/* gs://$gcp_bucket/metrics/$experiment/
    
    # embeddings
    echo $( timestamp ): "gsutil -m cp" $embeddings_dir/* \
    gs://$gcp_bucket/embeddings/$experiment/ | tee -a $logfile
    
    gsutil -m cp $embeddings_dir/* gs://$gcp_bucket/embeddings/$experiment/

    # shap
    echo $( timestamp ): "gsutil -m cp" $shap_dir/* \
    gs://$gcp_bucket/shap/$experiment/ | tee -a $logfile
    
    gsutil -m cp $shap_dir/* gs://$gcp_bucket/shap/$experiment/

    # modisco
    echo $( timestamp ): "gsutil -m cp" $modisco_dir/* \
    gs://$gcp_bucket/modisco/$experiment/ | tee -a $logfile

    gsutil -m cp $modisco_dir/* gs://$gcp_bucket/modisco/$experiment/

    # reports
    echo $( timestamp ): "gsutil -m cp" $reports_dir/* \
    gs://$gcp_bucket/reports/$experiment/ | tee -a $logfile
    
    gsutil -m cp $reports_dir/* gs://$gcp_bucket/reports/$experiment/
fi
