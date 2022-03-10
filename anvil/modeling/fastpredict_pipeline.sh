#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
model=$2
input_json=$3
testing_input_json=$4
splits_json=$5
reference_file=$6
reference_file_index=$7
chrom_sizes=$8
chroms_txt=$9
bigwigs=${10}
peaks=${11}
peaks_for_testing=${12}


mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/${1}_fastpredict.log
touch $logfile

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

# create the predictions directory with all peaks and all chromosomes
predictions_dir_all_peaks_all_chroms=$project_dir/predictions_and_metrics_all_peaks_all_chroms
echo $( timestamp ): "mkdir" $predictions_dir_all_peaks_all_chroms| tee -a $logfile
mkdir $predictions_dir_all_peaks_all_chroms

# create the predictions directory with all peaks and test chromosomes
predictions_dir_all_peaks_test_chroms=$project_dir/predictions_and_metrics_all_peaks_test_chroms
echo $( timestamp ): "mkdir" $predictions_dir_all_peaks_test_chroms| tee -a $logfile
mkdir $predictions_dir_all_peaks_test_chroms

# create the predictions directory with test_peaks and test chroms
predictions_dir_test_peaks_test_chroms=$project_dir/predictions_and_metrics_test_peaks_test_chroms
echo $( timestamp ): "mkdir" $predictions_dir_test_peaks_test_chroms | tee -a $logfile
mkdir $predictions_dir_test_peaks_test_chroms

# create the predictions directory with test_peaks and all_chroms
predictions_dir_test_peaks_all_chroms=$project_dir/predictions_and_metrics_test_peaks_all_chroms
echo $( timestamp ): "mkdir" $predictions_dir_test_peaks_all_chroms | tee -a $logfile
mkdir $predictions_dir_test_peaks_all_chroms


ls $project_dir

echo $( timestamp ): "cp" $reference_file ${reference_dir}/hg38.genome.fa | \
tee -a $logfile 

echo $( timestamp ): "cp" $reference_file_index ${reference_dir}/hg38.genome.fa.fai |\
tee -a $logfile 

echo $( timestamp ): "cp" $chrom_sizes ${reference_dir}/chrom.sizes |\
tee -a $logfile 

echo $( timestamp ): "cp" $chroms_txt ${reference_dir}/hg38_chroms.txt |\
tee -a $logfile 


# copy down data and reference

cp $reference_file $reference_dir/hg38.genome.fa
cp $reference_file_index $reference_dir/hg38.genome.fa.fai
cp $chrom_sizes $reference_dir/chrom.sizes
cp $chroms_txt $reference_dir/hg38_chroms.txt


# Step 1: Copy the bigwig,models and peak files

echo $bigwigs | sed 's/,/ /g' | xargs cp -t $data_dir/

echo $( timestamp ): "cp" $bigwigs ${data_dir}/ |\
tee -a $logfile 


echo $model | sed 's/,/ /g' | xargs cp -t $model_dir/

echo $( timestamp ): "cp" $model ${model_dir}/ |\
tee -a $logfile 


echo $( timestamp ): "cp" $peaks ${data_dir}/${experiment}_combined.bed.gz |\
tee -a $logfile 

cp $peaks ${data_dir}/${experiment}_combined.bed.gz

echo $( timestamp ): "gunzip" ${data_dir}/${experiment}_combined.bed.gz |\
tee -a $logfile 

gunzip ${data_dir}/${experiment}_combined.bed.gz



echo $( timestamp ): "cp" $peaks_for_testing ${data_dir}/${experiment}_peaks_only.bed.gz |\
tee -a $logfile 

cp $peaks_for_testing ${data_dir}/${experiment}_peaks_only.bed.gz


echo $( timestamp ): "gunzip" ${data_dir}/${experiment}_peaks_only.bed.gz |\
tee -a $logfile 

gunzip ${data_dir}/${experiment}_peaks_only.bed.gz



# cp the input json for the rest of the commands 

echo $( timestamp ): "cp" $input_json \
$project_dir/input.json | tee -a $logfile 
cp $input_json $project_dir/input.json

# modify the input json
echo  $( timestamp ): "sed -i -e" "s/<>/$1/g" $project_dir/input.json 
sed -i -e "s/<>/$1/g" $project_dir/input.json | tee -a $logfile 



echo $( timestamp ): "cp" $testing_input_json \
$project_dir/testing_input.json | tee -a $logfile 
cp $testing_input_json $project_dir/testing_input.json

# modify the testing_input json
echo  $( timestamp ): "sed -i -e" "s/<>/$1/g" $project_dir/testing_input.json 
sed -i -e "s/<>/$1/g" $project_dir/testing_input.json | tee -a $logfile 


# cp splits json template
echo $( timestamp ): "cp" $splits_json \
$project_dir/splits.json | tee -a $logfile 
cp $splits_json $project_dir/splits.json




#set threads based on number of peaks
#
if [ $(wc -l < ${data_dir}/${experiment}_combined.bed) -lt 3500 ];then
    threads=1
else
    threads=2
fi

# threads=1

#get the test chromosome

echo 'test_chromosome=jq .["0"]["test"][0] $project_dir/splits.json | sed s/"//g'

test_chromosome=`jq '.["0"]["test"][0]' $project_dir/splits.json | sed 's/"//g'` 

echo $( timestamp ): "
fastpredict \\
    --model $model_dir/${1}_split000.h5 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $test_chromosome \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir_all_peaks_test_chroms \\
    --input-data $project_dir/input.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --output-window-size 1000 \\
    --batch-size 64 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads" | tee -a $logfile 

fastpredict \
    --model $model_dir/${1}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $test_chromosome \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir_all_peaks_test_chroms \
    --input-data $project_dir/input.json \
    --sequence-generator-name BPNet \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000 \
    --batch-size 64 \
    --generate-predicted-profile-bigWigs \
    --threads $threads



echo $( timestamp ): "
fastpredict \\
    --model $model_dir/${1}_split000.h5 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir_all_peaks_all_chroms \\
    --input-data $project_dir/input.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --output-window-size 1000 \\
    --batch-size 64 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads" | tee -a $logfile 

fastpredict \
    --model $model_dir/${1}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir_all_peaks_all_chroms \
    --input-data $project_dir/input.json \
    --sequence-generator-name BPNet \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000 \
    --batch-size 64 \
    --generate-predicted-profile-bigWigs \
    --threads $threads




echo $( timestamp ): "
fastpredict \\
    --model $model_dir/${1}_split000.h5 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $test_chromosome \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir_test_peaks_test_chroms \\
    --input-data $project_dir/testing_input.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --output-window-size 1000 \\
    --batch-size 64 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads" | tee -a $logfile 

fastpredict \
    --model $model_dir/${1}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $test_chromosome \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir_test_peaks_test_chroms \
    --input-data $project_dir/testing_input.json \
    --sequence-generator-name BPNet \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000 \
    --batch-size 64 \
    --generate-predicted-profile-bigWigs \
    --threads $threads


echo $( timestamp ): "
fastpredict \\
    --model $model_dir/${1}_split000.h5 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir_test_peaks_all_chroms \\
    --input-data $project_dir/testing_input.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --output-window-size 1000 \\
    --batch-size 64 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads" | tee -a $logfile 

fastpredict \
    --model $model_dir/${1}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir_test_peaks_all_chroms \
    --input-data $project_dir/testing_input.json \
    --sequence-generator-name BPNet \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000 \
    --batch-size 64 \
    --generate-predicted-profile-bigWigs \
    --threads $threads

# create necessary files to copy the predictions results to cromwell folder

tail -n 1 $predictions_dir_test_peaks_test_chroms/predict.log | awk '{a=$8;print (substr(a,2,6)+substr($9,1,6))/2}' > $predictions_dir_test_peaks_test_chroms/spearman.txt
tail -n 2 $predictions_dir_test_peaks_test_chroms/predict.log | head -n 1 | awk '{a=$8;print (substr(a,2,6)+substr($9,1,6))/2}' > $predictions_dir_test_peaks_test_chroms/pearson.txt
tail -n 7 $predictions_dir_test_peaks_test_chroms/predict.log | head -n 1 | awk '{print $NF}' > $predictions_dir_test_peaks_test_chroms/jsd.txt


tail -n 1 $predictions_dir_all_peaks_test_chroms/predict.log | awk '{a=$8;print (substr(a,2,6)+substr($9,1,6))/2}' > $predictions_dir_all_peaks_test_chroms/spearman.txt
tail -n 2 $predictions_dir_all_peaks_test_chroms/predict.log | head -n 1 | awk '{a=$8;print (substr(a,2,6)+substr($9,1,6))/2}' > $predictions_dir_all_peaks_test_chroms/pearson.txt
tail -n 7 $predictions_dir_all_peaks_test_chroms/predict.log | head -n 1 | awk '{print $NF}' > $predictions_dir_all_peaks_test_chroms/jsd.txt

