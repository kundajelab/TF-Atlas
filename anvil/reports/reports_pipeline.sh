#!/bin/bash


mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/${1}_reports.log
touch $logfile

# import the utils script
. utils.sh


experiment=$1
peaks=$2
predictions_metrics_dir=$3
shap_dir=$4
modisco_counts_dir=$5
modisco_profile_dir=$6
tomtom_database=${7}
input_json=${8}

# create the modisco directories
reports_output_dir=$project_dir/reports
echo $( timestamp ): "mkdir" $reports_output_dir | tee -a $logfile
mkdir $reports_output_dir



#Performance
TFM_PRED_PATH=$predictions_path \
	TFM_METRICS_DIR=$metrics_dir \
	jupyter nbconvert \
    --execute $reports_notebooks_dir/model_performance.ipynb --to HTML \
    --output $reports_output_dir/performance \
    --ExecutePreprocessor.timeout=-1

# #TF-MoDISco results
# for key in profile counts
# do
#     # temp directory for tomtom matching
#     echo $( timestamp ): "mkdir" $tomtom_temp_dir/$key | tee -a $logfile
#     mkdir $tomtom_temp_dir/$key
    
# 	TFM_PRED_PATH=$predictions_path \
# 		TFM_SHAP_PATH=$shap_dir/${key}_scores.h5 \
# 		TFM_TFM_PATH=$modisco_dir/$key/modisco_results.h5 \
# 		TFM_PEAKS_PATH=$peaks_path \
#         TFM_TOMTOM_DB_PATH=$motif_db \
#         TFM_TOMTOM_TEMP_DIR=$tomtom_temp_dir/$key \
# 		jupyter nbconvert \
#         --execute $reports_notebooks_dir/view_tfmodisco_results.ipynb \
#         --to HTML --output $reports_output_dir/${key}_tfm_results \
#         --ExecutePreprocessor.timeout=-1 &
# done

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
