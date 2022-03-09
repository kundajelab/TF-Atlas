#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}



experiment=$1
peaks=$2
predictions_metrics_test=$3
predictions_metrics_all=$4
shap=$5
modisco_counts=$6
modisco_profile=$7
tomtom_database=${8}
splits_json=${9}

reports_notebooks_dir="/my_scripts/TF-Atlas/anvil/reports/"

mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/${1}_reports.log
touch $logfile

# create the report directories
reports_output_dir=$project_dir/reports
echo $( timestamp ): "mkdir" $reports_output_dir | tee -a $logfile
mkdir $reports_output_dir


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

# create the predictions directories
predictions_metrics_test_dir=$project_dir/predictions_test
echo $( timestamp ): "mkdir" $predictions_metrics_test_dir | tee -a $logfile
mkdir $predictions_metrics_test_dir

predictions_metrics_all_dir=$project_dir/predictions_all
echo $( timestamp ): "mkdir" $predictions_metrics_all_dir | tee -a $logfile
mkdir $predictions_metrics_all_dir

# create the modisco directories
modisco_profile_dir=$project_dir/modisco_profile
echo $( timestamp ): "mkdir" $modisco_profile_dir | tee -a $logfile
mkdir $modisco_profile_dir

modisco_counts_dir=$project_dir/modisco_counts
echo $( timestamp ): "mkdir" $modisco_counts_dir | tee -a $logfile
mkdir $modisco_counts_dir

# create the tomtom directory
tomtom_motif_database_dir=$project_dir/tomtom_motif_database
echo $( timestamp ): "mkdir" $tomtom_motif_database_dir | tee -a $logfile
mkdir $tomtom_motif_database_dir

tomtom_temp_dir=$project_dir/tomtom_temp_dir
echo $( timestamp ): "mkdir" $tomtom_temp_dir | tee -a $logfile
mkdir $tomtom_temp_dir



# copy down bed file, shap, predictions, modisco files


echo $( timestamp ): "cp" $predictions_metrics_test ${predictions_metrics_test_dir}/ |\
tee -a $logfile 

echo $predictions_metrics_test | sed 's/,/ /g' | xargs cp -t $predictions_metrics_test_dir/


echo $( timestamp ): "cp" $predictions_metrics_all ${predictions_metrics_all_dir}/ |\
tee -a $logfile 

echo $predictions_metrics_all | sed 's/,/ /g' | xargs cp -t $predictions_metrics_all_dir/



echo $( timestamp ): "cp" $shap ${shap_dir}/ |\
tee -a $logfile 

echo $shap | sed 's/,/ /g' | xargs cp -t $shap_dir/


echo $( timestamp ): "cp" $modisco_counts ${modisco_counts_dir}/ |\
tee -a $logfile 

echo $modisco_counts | sed 's/,/ /g' | xargs cp -t $modisco_counts_dir/


echo $( timestamp ): "cp" $modisco_profile ${modisco_profile_dir}/ |\
tee -a $logfile 

echo $modisco_profile | sed 's/,/ /g' | xargs cp -t $modisco_profile_dir/


#tomtom_motif_database_dir

echo $( timestamp ): "cp" $tomtom_database ${tomtom_motif_database_dir}/HOCOMOCO_JASPAR_motifs.txt |\
tee -a $logfile 

cp $tomtom_database ${tomtom_motif_database_dir}/HOCOMOCO_JASPAR_motifs.txt


echo $( timestamp ): "cp" $peaks ${data_dir}/${experiment}.bed.gz |\
tee -a $logfile 

cp $peaks ${data_dir}/${experiment}.bed.gz

echo $( timestamp ): "gunzip" ${data_dir}/${experiment}.bed.gz |\
tee -a $logfile 

gunzip ${data_dir}/${experiment}.bed.gz

peaks_path=${data_dir}/${experiment}.bed

# download input json template
# the input json 

echo $( timestamp ): "cp" $splits_json \
$project_dir/splits_json.json | tee -a $logfile 
cp $splits_json $project_dir/splits.json


#get the test chromosome

echo 'test_chromosome=jq .["0"]["test"][0] $project_dir/splits.json | sed s/"//g'

test_chromosome=`jq '.["0"]["test"][0]' $project_dir/splits.json | sed 's/"//g'` 

#Performance
TFM_PRED_PATH=$predictions_metrics_test_dir/${experiment}_split000_predictions.h5 \
	TFM_METRICS_DIR=$predictions_metrics_test_dir \
	TEST_CHROMS=$test_chromosome \
	jupyter nbconvert \
    --execute $reports_notebooks_dir/model_performance.ipynb --to HTML \
    --output $reports_output_dir/performance \
    --ExecutePreprocessor.timeout=-1


#TF-MoDISco results
for key in profile counts
do
    # temp directory for tomtom matching
    echo $( timestamp ): "mkdir" $tomtom_temp_dir/$key | tee -a $logfile
    mkdir $tomtom_temp_dir/$key
    
	TFM_PRED_PATH=$predictions_metrics_all_dir/${experiment}_split000_predictions.h5 \
		TFM_SHAP_PATH=$shap_dir/${key}_scores.h5 \
		TFM_TFM_PATH=$project_dir/modisco_${key}/modisco_results.h5 \
		TFM_PEAKS_PATH=$peaks_path \
        TFM_TOMTOM_DB_PATH=${tomtom_motif_database_dir}/HOCOMOCO_JASPAR_motifs.txt \
        TFM_TOMTOM_TEMP_DIR=$tomtom_temp_dir/$key \
        TFM_KEY=$key \
        TFM_REPORTS_DIR=$reports_output_dir \
		jupyter nbconvert \
        --execute $reports_notebooks_dir/view_tfmodisco_results.ipynb \
        --to HTML --output $reports_output_dir/${key}_tfm_results \
        --ExecutePreprocessor.timeout=-1 &
done
wait

# #Examples of seqlets and profile predictions
# for key in profile counts
# do
# 	TFM_PRED_PATH=$predictions_path \
# 		TFM_SHAP_PATH=$shap_dir/${key}_scores.h5 \
# 		TFM_TFM_PATH=$modisco_dir/$key/modisco_results.h5 \
# 		jupyter nbconvert \
#         --execute $reports_notebooks_dir/showcase_motifs_and_profiles.ipynb \
#         --to HTML --output $reports_output_dir/${key}_seqlet_profile_examples \
#         --ExecutePreprocessor.timeout=-1 &
# done

# #Motif hits (this runs MOODS)
# for key in profile counts
# do
# 	TFM_TFM_PATH=$modisco_dir/$key/modisco_results.h5 \
# 		TFM_SHAP_PATH=$shap_dir/${key}_scores.h5 \
# 		TFM_PEAKS_PATH=$peaks_path \
# 		TFM_MOODS_DIR=$moods_dir/$key \
#         TFM_REFERENCE_PATH=$reference_dir/genome.fa \
# 		jupyter nbconvert \
#         --execute $reports_notebooks_dir/summarize_motif_hits.ipynb --to HTML \
#         --output $reports_output_dir/${key}_motif_hits \
#         --ExecutePreprocessor.timeout=-1 &
# done
# wait

# # Clustering of motif hits and peaks
# for key in profile counts
# do
#     # cache directory for cluster motifs reports notebook
#     cluster_cache_dir=$reports_output_dir/cluster_cache_$key
#     echo $( timestamp ): "mkdir" $cluster_cache_dir | tee -a $logfile
#     mkdir $cluster_cache_dir

# 	TFM_TFM_PATH=$modisco_dir/$key/modisco_results.h5 \
# 		TFM_SHAP_PATH=$shap_dir/${key}_scores.h5 \
# 		TFM_MOODS_DIR=$moods_dir/$key \
# 		TFM_EMB_PATH=$embeddings_path \
#         TFM_CLUSTER_CACHE=$cluster_cache_dir \
# 		jupyter nbconvert \
#         --execute $reports_notebooks_dir/cluster_motif_hits_and_peaks.ipynb \
#         --to HTML --output $reports_output_dir/${key}_motif_peak_clustering \
#         --ExecutePreprocessor.timeout=-1 &
# done
# wait
