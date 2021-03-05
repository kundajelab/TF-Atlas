# import the utils script
. utils.sh

# command line arguments
experiment=$1
reference_dir=$2
downloads_dir=$3
model_dir=$4
peaks=$5
shap_dir=$6
modisco_profile_dir=$7
modisco_counts_dir=$8
logfile=$9

# run interpret to get profile and counts shap score
echo $( timestamp ): "
shap_scores \\
    --reference-genome $reference_dir/genome.fa \\
    --model $model_dir/${experiment}_split000.h5  \\
    --bed-file $downloads_dir/$peaks.bed.gz \\
    --chroms $(paste -s -d ' ' $reference_dir/chroms.txt) \\
    --output-dir $shap_dir \\
    --input-seq-len 2114 \\
    --control-len 1000 \\
    --control-smoothing 7.0 81 \\
    --task-id 0 \\
    --control-info $experiment.json" | tee -a $logfile

shap_scores \
    --reference-genome $reference_dir/genome.fa \
    --model $model_dir/${experiment}_split000.h5  \
    --bed-file $downloads_dir/$peaks.bed.gz \
    --chroms $(paste -s -d ' ' $reference_dir/chroms.txt) \
    --output-dir $shap_dir \
    --input-seq-len 2114 \
    --control-len 1000 \
    --control-smoothing 7.0 81 \
    --task-id 0 \
    --control-info $experiment.json

# run modisco on profile shap scores
echo $( timestamp ): "
motif_discovery \\
    --scores-path $shap_dir/profile_scores.h5 \\
    --output-directory $modisco_profile_dir" | tee -a $logfile

motif_discovery \
    --scores-path $shap_dir/profile_scores.h5 \
    --output-directory $modisco_profile_dir

# run modisco on counts shap scores
echo $( timestamp ): "
motif_discovery \\
    --scores-path $shap_dir/counts_scores.h5 \\
    --output-directory $modisco_counts_dir" | tee -a $logfile

motif_discovery \
    --scores-path $shap_dir/counts_scores.h5 \
    --output-directory $modisco_counts_dir
