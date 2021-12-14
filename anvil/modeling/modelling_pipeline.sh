#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
reference_file=$2
chrom_sizes=$3
bigwigs=$4
peaks=$5
non_peaks=$6
bias_model=$7

export CUDNN=cudnn-8.1_cuda11.2
export cuda=cuda-11.2
export LD_LIBRARY_PATH=/usr/local/$cuda/lib64:/usr/local/$CUDNN/lib64:/usr/local/$CUDNN/include:/usr/local/$cuda/extras/CUPTI/lib64:/usr/local/lib:$LD_LIBRARY_PATH
export PATH=/usr/local/$cuda/bin:$PATH
export CUDA_HOME=/usr/local/$cuda
export CPATH="/usr/local/$CUDNN/include:${CPATH}"
export LIBRARY_PATH="/usr/local/$CUDNN/lib64:${LIBRARY_PATH}"
export CPLUS_INCLUDE_PATH=/usr/local/$cuda/include

mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/${1}_modeling.log
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



echo $( timestamp ): "cp" $reference_file ${reference_dir}/hg38.genome.fa | \
tee -a $logfile 

echo $( timestamp ): "cp" $chrom_sizes ${reference_dir}/chrom.sizes |\
tee -a $logfile 

echo $( timestamp ): "cp" $chroms_txt ${reference_dir}/hg38_chroms.txt |\
tee -a $logfile 


# copy down data and reference

cp $reference_file $reference_dir/hg38.genome.fa
cp $chrom_sizes $reference_dir/chrom.sizes
cp $chroms_txt $reference_dir/hg38_chroms.txt


# Step 1: Copy the bigwig and peak files

echo $bigwigs | sed 's/,/ /g' | xargs cp -t $data_dir/

echo $( timestamp ): "cp" $bigwigs ${data_dir}/ |\
tee -a $logfile 

# copy peaks
echo $( timestamp ): "cp" $peaks ${data_dir}/${experiment}_peaks.bed.gz |\
tee -a $logfile 

cp $peaks ${data_dir}/${experiment}_peaks.bed.gz

echo $( timestamp ): "gunzip" ${data_dir}/${experiment}_peaks.bed.gz |\
tee -a $logfile 

gunzip ${data_dir}/${experiment}_peaks.bed.gz

#copy non-peaks
echo $( timestamp ): "cp" $non_peaks ${data_dir}/${experiment}_non_peaks.bed.gz |\
tee -a $logfile 

cp $non_peaks ${data_dir}/${experiment}_non_peaks.bed.gz

echo $( timestamp ): "gunzip" ${data_dir}/${experiment}_non_peaks.bed.gz |\
tee -a $logfile 

gunzip ${data_dir}/${experiment}_non_peaks.bed.gz

#set threads based on number of peaks

if [ $(wc -l < ${data_dir}/${experiment}_peaks.bed) -lt 3500 ];then
    threads=1
else
    threads=2
fi

# python src/train_chrombpnet.py \
#     -g ${reference_dir}/hg38.genome.fa \
#     -b ${data_dir}/$experiment.bigWig \
#     -p ${data_dir}/${experiment}_peaks.bed  \
#     -n ${data_dir}/${experiment}_non_peaks.bed \
#     -o $model_dir/${1} \
#     -e 1 \
#     -bm $bias_model

python src/metrics.py \
    -b ${data_dir}/$experiment.bigWig  \
    -g ${reference_dir}/hg38.genome.fa \
    -p ${data_dir}/${experiment}_peaks.bed \
    -n ${data_dir}/${experiment}_non_peaks.bed \
    -o $project_dir/predictions_and_metrics_all_peaks_test_chroms/${1}\
    -bm $model_dir/${1}.adjusted_bias_model.h5\
    -cm $model_dir/${1}.h5 \
    -tc "chr1"

# python marginal_footprinting.py  \
#     -g ${reference_dir}/hg38.genome.fa \
#     -r ${data_dir}/${experiment}_non_peaks.bed \
#     -chr "chr1" -m /path/to/model.h5 \
#     -o /path/to/output_dir/outputprefix \
#     -pwm_f motif_to_pwm.tsv \
#     -mo tn5_1,tn5_2,tn5_3,tn5_4,tn5_5 \
