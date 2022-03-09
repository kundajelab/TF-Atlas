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
splits_json=${5}

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


# create the predictions directories
predictions_metrics_test_dir=$project_dir/predictions_test
echo $( timestamp ): "mkdir" $predictions_metrics_test_dir | tee -a $logfile
mkdir $predictions_metrics_test_dir

predictions_metrics_all_dir=$project_dir/predictions_all
echo $( timestamp ): "mkdir" $predictions_metrics_all_dir | tee -a $logfile
mkdir $predictions_metrics_all_dir




# copy down bed file, shap, predictions files


echo $( timestamp ): "cp" $predictions_metrics_test ${predictions_metrics_test_dir}/ |\
tee -a $logfile 

echo $predictions_metrics_test | sed 's/,/ /g' | xargs cp -t $predictions_metrics_test_dir/


echo $( timestamp ): "cp" $predictions_metrics_all ${predictions_metrics_all_dir}/ |\
tee -a $logfile 

echo $predictions_metrics_all | sed 's/,/ /g' | xargs cp -t $predictions_metrics_all_dir/




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

