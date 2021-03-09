# import the utils script
. utils.sh

# command line arguments
experiment=$1
arch_name=$2
seqgen_name=$3
splits_file_path=$4
peaks=$5
reference_dir=$6
downloads_dir=$7
model_dir=$8
predictions_dir=$9
embeddings_dir=${10}
logfile=${11}

# the train command
counts_loss_weight=`counts_loss_weight --input-data $experiment.json`
echo $( timestamp ): "
train \\
    --input-data $experiment.json \\
    --stranded \\
    --output-dir $model_dir \\
    --reference-genome $reference_dir/genome.fa \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $(paste -s -d ' ' $reference_dir/chroms.txt)  \\
    --shuffle \\
    --epochs 100 \\
    --splits $splits_file_path \\
    --model-arch-name $arch_name \\
    --sequence-generator-name $seqgen_name \\
    --model-output-filename $experiment \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --filters 64 \\
    --threads 10 \\
    --counts-loss-weight $counts_loss_weight" | tee -a $logfile

train \
    --input-data $experiment.json \
    --stranded \
    --output-dir $model_dir \
    --reference-genome $reference_dir/genome.fa \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $(paste -s -d ' ' $reference_dir/chroms.txt)  \
    --shuffle \
    --epochs 100 \
    --splits $splits_file_path \
    --model-arch-name $arch_name \
    --sequence-generator-name $seqgen_name \
    --model-output-filename $experiment \
    --input-seq-len 2114 \
    --output-len 1000 \
    --filters 64 \
    --threads 10 \
    --counts-loss-weight $counts_loss_weight

echo $( timestamp ): "
predict \\
    --model $model_dir/${experiment}_split000.h5 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $(paste -s -d ' ' $reference_dir/chroms.txt) \\
    --reference-genome $reference_dir/genome.fa \\
    --exponentiate-counts \\
    --output-dir $predictions_dir \\
    --input-data $experiment.json \\
    --predict-peaks \\
    --write-buffer-size 2000 \\
    --batch-size 1 \\
    --stranded \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --output-window-size 1000" | tee -a $logfile

predict \
    --model $model_dir/${experiment}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $(paste -s -d ' ' $reference_dir/chroms.txt) \
    --reference-genome $reference_dir/genome.fa \
    --exponentiate-counts \
    --output-dir $predictions_dir \
    --input-data $experiment.json \
    --predict-peaks \
    --write-buffer-size 2000 \
    --batch-size 1 \
    --stranded \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000

echo $( timestamp ): "
embeddings \\
    --model $model_dir/${experiment}_split000.h5 \\
    --reference-genome $reference_dir/genome.fa \\
    --input-layer-shape 2114 4 \\
    --peaks $downloads_dir/$peaks.bed.gz \\
    --output-directory $embeddings_dir" | tee -a $logfile

embeddings \
    --model $model_dir/${experiment}_split000.h5 \
    --reference-genome $reference_dir/genome.fa \
    --input-layer-shape 2114 4 \
    --peaks $downloads_dir/$peaks.bed.gz \
    --output-directory $embeddings_dir
