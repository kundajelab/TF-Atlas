# import the utils script
. utils.sh

# command line arguments
experiment=$1
downloads_dir=$2
reference_dir=$3
predictions_dir=$4
peaks=$5
test_chroms=$6
bounds_dir=$7
metrics_dir=$8
logfile=$9

# get the top level keys (task ids) from the experiment json
echo $( timestamp ): "jq keys" $experiment.json | tee -a $logfile
tasks=`jq keys $experiment.json`

# remove unwanted characters then replace ',' (comma) with ' ' (space)
tasks=`echo $tasks | sed 's/[][ "]//g' | sed 's/,/ /g'`

for task_id in $tasks
do
    # get path to the 'signal' bigWig file for this task
    input_file=`jq .$task_id.signal $experiment.json | sed 's/"//g'`
    
    # compute upper and lower bounds for the task
    echo $( timestamp ): "
    bounds \\
        --input-profiles $input_file \\
        --output-names $task_id \\
        --output-directory $bounds_dir \\
        --peaks $downloads_dir/$peaks.bed.gz \\
        --chroms $test_chroms" | tee -a $logfile
    
    bounds \
        --input-profiles $input_file \
        --output-names $task_id \
        --output-directory $bounds_dir \
        --peaks $downloads_dir/$peaks.bed.gz \
        --chroms $test_chroms
    
    echo $( timestamp ): "mkdir" $metrics_dir/$task_id | tee -a $logfile
    mkdir $metrics_dir/$task_id
    
    # compute metrics with min max normalization
    echo $( timestamp ): "
    metrics \\
       -A $input_file \\
       -B $predictions_dir/${experiment}_split000_$task_id.bw \\
       --peaks $downloads_dir/$peaks.bed.gz \\
       --chroms $test_chroms \\
       --output-dir $metrics_dir/$task_id \\
       --apply-softmax-to-profileB \\
       --countsB $predictions_dir/${experiment}_split000_${task_id}_exponentiated_counts.bw \\
       --chrom-sizes $reference_dir/chrom.sizes \\
       --bounds-csv $bounds_dir/$task_id.bds"
    
    metrics \
       -A $input_file \
       -B $predictions_dir/${experiment}_split000_$task_id.bw \
       --peaks $downloads_dir/$peaks.bed.gz \
       --chroms $test_chroms  \
       --output-dir $metrics_dir/$task_id \
       --apply-softmax-to-profileB \
       --countsB $predictions_dir/${experiment}_split000_${task_id}_exponentiated_counts.bw \
       --chrom-sizes $reference_dir/chrom.sizes \
       --bounds-csv $bounds_dir/$task_id.bds
done
