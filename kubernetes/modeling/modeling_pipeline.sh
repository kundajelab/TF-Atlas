#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}


function commandstatus {
    # Function to check the status of recently run command
    
    if [ $? -ne 0 ]; then
        echo "Exiting!"
        exit $?
    fi
}


experiment=$1
gcp_bucket=$2
project_dir=$3
bpnet_params=$4
peaks_file_suffix=$5
model_tag=$6

# create the log file
command_logfile=$project_dir/${1}_modeling_commands.log
touch $command_logfile

# create the error log file
output_logfile=$project_dir/${1}_modeling_output.log
touch $output_logfile

{
    # create the data directory
    data_dir=$project_dir/data
    echo $( timestamp ): "mkdir" $data_dir | tee -a $command_logfile
    mkdir $data_dir

    # create the reference directory
    reference_dir=$project_dir/reference
    echo $( timestamp ): "mkdir" $reference_dir | tee -a $command_logfile
    mkdir $reference_dir

    # create the model directory
    model_dir=$project_dir/model
    echo $( timestamp ): "mkdir" $model_dir | tee -a $command_logfile
    mkdir $model_dir

    # create the predictions directory
    predictions_dir=$project_dir/predictions_and_metrics
    echo $( timestamp ): "mkdir" $predictions_dir | tee -a $command_logfile
    mkdir $predictions_dir

    # copy down data and reference
    echo $( timestamp ): "gsutil cp" gs://$2/data/$1/*.bigWig $data_dir | \
    tee -a $command_logfile
    gsutil cp gs://$2/data/$1/*.bigWig $data_dir

    # peaks only bed file
    echo $( timestamp ): "gsutil cp" gs://$2/data/$1/${1}_inliers.bed $data_dir | \
    tee -a $command_logfile
    gsutil cp gs://$2/data/$1/${1}_inliers.bed $data_dir

    # user specified peaks+non peaks
    echo $( timestamp ): "gsutil cp" gs://$2/data/$1/${1}_${peaks_file_suffix}.bed $data_dir | \
    tee -a $command_logfile
    gsutil cp gs://$2/data/$1/${1}_${peaks_file_suffix}.bed $data_dir

    echo $( timestamp ): "gsutil cp" gs://$2/reference/* $reference_dir | \
    tee -a $command_logfile
    gsutil cp gs://$2/reference/* $reference_dir

    # create the index to the genome fasta file
    echo $( timestamp ): "samtools faidx" $reference_dir/hg38.genome.fa | tee -a $command_logfile
    samtools faidx $reference_dir/hg38.genome.fa
    commandstatus

    # download input json template
    echo $( timestamp ): "gsutil cp" gs://$2/input_json/input.json \
    $project_dir/ | tee -a $command_logfile 
    gsutil cp gs://$2/input_json/input.json $project_dir/

    # modify the input json to add experiment id
    echo  $( timestamp ): "sed -i -e" "s/<>/$1/g" $project_dir/input.json | tee -a $command_logfile 
    sed -i -e "s/<>/$1/g" $project_dir/input.json
    commandstatus

    # modify the input json for peaks only
    echo  $( timestamp ): "sed -e \"s/.bed/_inliers.bed/g\"" $project_dir/input.json \
    ">" $project_dir/input_peaks.json | tee -a $command_logfile 
    sed -e "s/.bed/_inliers.bed/g" $project_dir/input.json > \
    $project_dir/input_peaks.json
    commandstatus

    # modify the input json for the user specified bed file
    echo  $( timestamp ): "sed -e \"s/.bed/_${peaks_file_suffix}.bed/g\"" \
    $project_dir/input.json ">" $project_dir/input_peaks_nonpeaks.json | tee -a $command_logfile 
    sed -e "s/.bed/_${peaks_file_suffix}.bed/g" $project_dir/input.json > \
    $project_dir/input_peaks_nonpeaks.json
    commandstatus

    # download bpnet params json template
    echo $( timestamp ): "gsutil cp" gs://$2/bpnet_params/$bpnet_params \
    $project_dir/ | tee -a $command_logfile 
    gsutil cp gs://$2/bpnet_params/$bpnet_params $project_dir/

    # download splits json template
    echo $( timestamp ): "gsutil cp" gs://$2/splits/splits.json \
    $project_dir/ | tee -a $command_logfile 
    gsutil cp gs://$2/splits/splits.json $project_dir/

    # compute the counts loss weight to be used for this experiment
    echo $( timestamp ): "counts_loss_weight=\`counts_loss_weight --input-data \
    $project_dir/input_peaks_nonpeaks.json\`" | tee -a $command_logfile
    counts_loss_weight=`counts_loss_weight --input-data $project_dir/input_peaks_nonpeaks.json`
    commandstatus

    # print the counts loss weight
    echo $( timestamp ): "counts_loss_weight:" $counts_loss_weight | tee -a $command_logfile 

    # modify the bpnet params json to reflect the counts loss weight
    echo  $( timestamp ): "sed -i -e" "s/<>/$counts_loss_weight/g" \
    $project_dir/bpnet_params.json | tee -a $command_logfile 
    sed -i -e "s/<>/$counts_loss_weight/g" $project_dir/bpnet_params.json
    commandstatus

    echo $( timestamp ): "
    train \\
        --input-data $project_dir/input_peaks_nonpeaks.json \\
        --output-dir $model_dir \\
        --reference-genome $reference_dir/hg38.genome.fa \\
        --chrom-sizes $reference_dir/chrom.sizes \\
        --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt)  \\
        --shuffle \\
        --epochs 100 \\
        --splits $project_dir/splits.json \\
        --model-arch-name BPNet \\
        --model-arch-params-json $project_dir/$bpnet_params \\
        --sequence-generator-name BPNet \\
        --model-output-filename $1 \\
        --input-seq-len 2114 \\
        --output-len 1000 \\
        --threads 2 \\
        --learning-rate 0.004" | tee -a $command_logfile 

    train \
        --input-data $project_dir/input_peaks_nonpeaks.json \
        --output-dir $model_dir \
        --reference-genome $reference_dir/hg38.genome.fa \
        --chrom-sizes $reference_dir/chrom.sizes \
        --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt)  \
        --shuffle \
        --epochs 100 \
        --splits $project_dir/splits.json \
        --model-arch-name BPNet \
        --model-arch-params-json $project_dir/$bpnet_params \
        --sequence-generator-name BPNet \
        --model-output-filename $1 \
        --input-seq-len 2114 \
        --output-len 1000 \
        --threads 2 \
        --learning-rate 0.004

    commandstatus

    # create the predictions directory
    echo $( timestamp ): "mkdir" $predictions_dir/peaks_chr1 | tee -a $command_logfile
    mkdir $predictions_dir/peaks_chr1

    echo $( timestamp ): "
    fastpredict \\
        --model $model_dir/${1}_split000.h5 \\
        --chrom-sizes $reference_dir/chrom.sizes \\
        --chroms chr1 \\
        --reference-genome $reference_dir/hg38.genome.fa \\
        --output-dir $predictions_dir/peaks_chr1 \\
        --input-data $project_dir/input_peaks.json \\
        --sequence-generator-name BPNet \\
        --input-seq-len 2114 \\
        --output-len 1000 \\
        --output-window-size 1000 \\
        --batch-size 64 \\
        --generate-predicted-profile-bigWigs \\
        --threads 2" | tee -a $command_logfile 

    fastpredict \
        --model $model_dir/${1}_split000.h5 \
        --chrom-sizes $reference_dir/chrom.sizes \
        --chroms chr1 \
        --reference-genome $reference_dir/hg38.genome.fa \
        --output-dir $predictions_dir/peaks_chr1 \
        --input-data $project_dir/input_peaks.json \
        --sequence-generator-name BPNet \
        --input-seq-len 2114 \
        --output-len 1000 \
        --output-window-size 1000 \
        --batch-size 64 \
        --generate-predicted-profile-bigWigs \
        --threads 2

    commandstatus

    # create the predictions directory
    echo $( timestamp ): "mkdir" $predictions_dir/peaks_all | tee -a $command_logfile
    mkdir $predictions_dir/peaks_all

    echo $( timestamp ): "
    fastpredict \\
        --model $model_dir/${1}_split000.h5 \\
        --chrom-sizes $reference_dir/chrom.sizes \\
        --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \\
        --reference-genome $reference_dir/hg38.genome.fa \\
        --output-dir $predictions_dir/peaks_all \\
        --input-data $project_dir/input_peaks.json \\
        --sequence-generator-name BPNet \\
        --input-seq-len 2114 \\
        --output-len 1000 \\
        --output-window-size 1000 \\
        --batch-size 64 \\
        --generate-predicted-profile-bigWigs \\
        --threads 2" | tee -a $command_logfile 

    fastpredict \
        --model $model_dir/${1}_split000.h5 \
        --chrom-sizes $reference_dir/chrom.sizes \
        --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \
        --reference-genome $reference_dir/hg38.genome.fa \
        --output-dir $predictions_dir/peaks_all \
        --input-data $project_dir/input_peaks.json \
        --sequence-generator-name BPNet \
        --input-seq-len 2114 \
        --output-len 1000 \
        --output-window-size 1000 \
        --batch-size 64 \
        --generate-predicted-profile-bigWigs \
        --threads 2

    commandstatus

    # create the predictions directory
    echo $( timestamp ): "mkdir" $predictions_dir/peaks_nonpeaks_chr1 | tee -a $command_logfile
    mkdir $predictions_dir/peaks_nonpeaks_chr1

    echo $( timestamp ): "
    fastpredict \\
        --model $model_dir/${1}_split000.h5 \\
        --chrom-sizes $reference_dir/chrom.sizes \\
        --chroms chr1 \\
        --reference-genome $reference_dir/hg38.genome.fa \\
        --output-dir $predictions_dir/peaks_nonpeaks_chr1 \\
        --input-data $project_dir/input_peaks.json \\
        --sequence-generator-name BPNet \\
        --input-seq-len 2114 \\
        --output-len 1000 \\
        --output-window-size 1000 \\
        --batch-size 64 \\
        --generate-predicted-profile-bigWigs \\
        --threads 2" | tee -a $command_logfile 

    fastpredict \
        --model $model_dir/${1}_split000.h5 \
        --chrom-sizes $reference_dir/chrom.sizes \
        --chroms chr1 \
        --reference-genome $reference_dir/hg38.genome.fa \
        --output-dir $predictions_dir/peaks_nonpeaks_chr1 \
        --input-data $project_dir/input_peaks_nonpeaks.json \
        --sequence-generator-name BPNet \
        --input-seq-len 2114 \
        --output-len 1000 \
        --output-window-size 1000 \
        --batch-size 64 \
        --generate-predicted-profile-bigWigs \
        --threads 2

    commandstatus

    # create the predictions directory
    echo $( timestamp ): "mkdir" $predictions_dir/peaks_nonpeaks_all | tee -a $command_logfile
    mkdir $predictions_dir/peaks_nonpeaks_all

    echo $( timestamp ): "
    fastpredict \\
        --model $model_dir/${1}_split000.h5 \\
        --chrom-sizes $reference_dir/chrom.sizes \\
        --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \\
        --reference-genome $reference_dir/hg38.genome.fa \\
        --output-dir $predictions_dir/peaks_nonpeaks_all \\
        --input-data $project_dir/input_peaks.json \\
        --sequence-generator-name BPNet \\
        --input-seq-len 2114 \\
        --output-len 1000 \\
        --output-window-size 1000 \\
        --batch-size 64 \\
        --generate-predicted-profile-bigWigs \\
        --threads 2" | tee -a $command_logfile 

    fastpredict \
        --model $model_dir/${1}_split000.h5 \
        --chrom-sizes $reference_dir/chrom.sizes \
        --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \
        --reference-genome $reference_dir/hg38.genome.fa \
        --output-dir $predictions_dir/peaks_nonpeaks_all \
        --input-data $project_dir/input_peaks_nonpeaks.json \
        --sequence-generator-name BPNet \
        --input-seq-len 2114 \
        --output-len 1000 \
        --output-window-size 1000 \
        --batch-size 64 \
        --generate-predicted-profile-bigWigs \
        --threads 2

    commandstatus

} 2>&1 | tee $output_logfile

# copy the result to gcp bucket
echo $( timestamp ): "gsutil cp" $project_dir/model/* gs://$2/models/$1/$model_tag/ | tee -a $command_logfile 
gsutil cp $project_dir/model/* gs://$2/models/$1/$model_tag/

# copy jsons to gcp bucket
echo $( timestamp ): "gsutil cp" $project_dir/*.json gs://$2/dynamicjsons/$1/$model_tag/ | tee -a $command_logfile 
gsutil cp $project_dir/*.json gs://$2/dynamicjsons/$1/$model_tag/

echo $( timestamp ): "gsutil cp" $project_dir/predictions_and_metrics/peaks_chr1/* gs://$2/predictions_and_metrics/$1/$model_tag/peaks_chr1/ | tee -a $command_logfile 
gsutil cp $project_dir/predictions_and_metrics/peaks_chr1/* gs://$2/predictions_and_metrics/$1/$model_tag/peaks_chr1/

echo $( timestamp ): "gsutil cp" $project_dir/predictions_and_metrics/peaks_all/* gs://$2/predictions_and_metrics/$1/$model_tag/peaks_all/ | tee -a $command_logfile 
gsutil cp $project_dir/predictions_and_metrics/peaks_all/* gs://$2/predictions_and_metrics/$1/$model_tag/peaks_all/

echo $( timestamp ): "gsutil cp" $project_dir/predictions_and_metrics/peaks_nonpeaks_chr1/* gs://$2/predictions_and_metrics/$1/$model_tag/peaks_nonpeaks_chr1/ | tee -a $command_logfile 
gsutil cp $project_dir/predictions_and_metrics/peaks_nonpeaks_chr1/* gs://$2/predictions_and_metrics/$1/$model_tag/peaks_nonpeaks_chr1/

echo $( timestamp ): "gsutil cp" $project_dir/predictions_and_metrics/peaks_nonpeaks_all/* gs://$2/predictions_and_metrics/$1/$model_tag/peaks_nonpeaks_all/ | tee -a $command_logfile 
gsutil cp $project_dir/predictions_and_metrics/peaks_nonpeaks_all/* gs://$2/predictions_and_metrics/$1/$model_tag/peaks_nonpeaks_all/

echo $( timestamp ): "gsutil cp" gsutil cp $output_logfile gs://$2/logs/$model_tag/ | tee -a $command_logfile 
gsutil cp $output_logfile gs://$2/logs/$model_tag/

echo $( timestamp ): "gsutil cp" gsutil cp $command_logfile gs://$2/logs/$model_tag/ | tee -a $command_logfile 
gsutil cp $command_logfile gs://$2/logs/$model_tag/
