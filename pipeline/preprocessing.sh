# script to process bam files and generate bigWig tracks

# import the utils script
. utils.sh

# command line parameters
experiment=$1
unfiltered_alignments=( "$2" )
alignments=( "$3" )
bams_dir=$4
intermediates_dir=$5
bigWigs_dir=$6
stranded=$7
is_control=$8
reference_dir=$9
logfile=${10}

tag=""
if [ "$is_control" = "True" ]
then
    tag="_control"
fi

## Step 1 - find out if the bam is single ended or pair ended
echo $( timestamp ): Checking if unfiltered alignments bams are single ended \
or pair ended | tee -a $logfile

# counters to see how many files have paired end reads vs single ended reads
se_count=0
pe_count=0

for bam_file in $unfiltered_alignments
do
    bam_file_path=$bams_dir/$bam_file.bam
    
    # get the number of paired end reads
    echo $( timestamp ): "samtools view -c -f 1" $bam_file_path | \
    tee -a $logfile
    pe_read_count=`samtools view -c -f 1 ${bam_file_path}`
    
    # increment respective counters
    if [ "$pe_read_count" = "0" ]; then
        se_count=$((se_count + 1))
    else
        pe_count=$((pe_count + 1))
    fi
done

echo $( timestamp ): PE COUNT $tag $pe_count | tee -a $logfile
echo $( timestamp ): SE COUNT $tag $se_count | tee -a $logfile

# we need to check if all the bams are either single ended or pair ended
# if it's a mixed bag then we'll halt the pipeline because dealing with that
# becomes complicated (we have to match the corresponding bams from the 
# aligmemts and unfiltered_alignments and that metadata is not available)
if [ $se_count -gt 0 ] && [ $pe_count -gt 0 ]
then
    echo $( timestamp ): Both SE & PE found, Exiting. | tee -a $logfile
    exit 1
fi

all_bams_for_merging=() 
# if bams were single ended
if [ $se_count -gt 0 ]
then
    echo $( timestamp ): All unfiltered alignments bams are single ended. \
    Applying samtools filtering. | tee -a $logfile
    for bam_file in $unfiltered_alignments
    do
        bam_file_path=$bams_dir/$bam_file.bam
        
        # apply samtools filtering
        echo $( timestamp ): "samtools view -F 780 -q 30 -b" $bam_file_path \
        "-o" $intermediates_dir/${bam_file}.bam | tee -a $logfile
        samtools view -F 780 -q 30 -b $bam_file_path \
        -o $intermediates_dir/$bam_file.bam &
        all_bams_for_merging+=( $intermediates_dir/$bam_file.bam )
    done
    
    wait_for_jobs_to_finish "samtools filtering"
# if bams were pair ended
else
    # since all bams are paired end we use all the "alignments" bams 
    # directly since they have the correct filtering parameters for 
    # paired-end reads
    for bam_file in $alignments
    do
        bam_file_path=$bams_dir/$bam_file.bam
        # we dont need to do any filtering
        all_bams_for_merging+=( ${bam_file_path} )
    done
fi

if [ ${#all_bams_for_merging[*]} -gt 1 ]
then
    echo $( timestamp ): Merging bam files  | tee -a $logfile
    echo $( timestamp ): "samtools merge -f" \
    $intermediates_dir/$experiment$tag.bam ${all_bams_for_merging[*]} | \
    tee -a $logfile
    samtools merge -f $intermediates_dir/$experiment$tag.bam \
    ${all_bams_for_merging[*]}
# or we just use the single file as is
else
    echo $( timestamp ): Only one source bam file found. Copying over as \
    merged file. | tee -a $logfile
    echo $( timestamp ): "cp" ${all_bams_for_merging[0]} \
    $intermediates_dir/${experiment}${tag}.bam | tee -a $logfile
    cp ${all_bams_for_merging[0]} $intermediates_dir/$experiment$tag.bam
fi

# create index for the merged bam file
echo $( timestamp ): "samtools index" \
$intermediates_dir/$experiment$tag.bam | tee -a $logfile
samtools index $intermediates_dir/$experiment$tag.bam

if [ "$stranded" = "True" ]
then
    # get coverage of 5’ positions of the plus & minus strand
    bedtools genomecov \
    -5 -bg -strand + -ibam $intermediates_dir/$experiment$tag.bam | \
    sort -k1,1 -k2,2n > $intermediates_dir/$experiment${tag}_plus.bedGraph &
    
    echo $( timestamp ): [$!] "bedtools genomecov" \
    "-5 -bg -strand + -ibam" $intermediates_dir/$experiment$tag.bam "|" \
    "sort -k1,1 -k2,2n >" \
    $intermediates_dir/$experiment${tag}_plus.bedGraph | tee -a $logfile

    bedtools genomecov \
    -5 -bg -strand - -ibam $intermediates_dir/$experiment$tag.bam | \
    sort -k1,1 -k2,2n > $intermediates_dir/$experiment${tag}_minus.bedGraph &

    echo $( timestamp ): [$!] "bedtools genomecov" \
    "-5 -bg -strand - -ibam" $intermediates_dir/$experiment$tag.bam "|" \
    "sort -k1,1 -k2,2n >" \
    $intermediates_dir/$experiment${tag}_minus.bedGraph | tee -a $logfile

    wait_for_jobs_to_finish "bedtools genomecov"

    # Convert bedGraph files to bigWig files 
    bedGraphToBigWig $intermediates_dir/$experiment${tag}_plus.bedGraph \
    $reference_dir/chrom.sizes $bigWigs_dir/$experiment${tag}_plus.bigWig &
    
    echo $( timestamp ): [$!] "~/./bedGraphToBigWig" \
    $intermediates_dir/$experiment${tag}_plus.bedGraph \
    $reference_dir/chrom.sizes $bigWigs_dir/$experiment${tag}_plus.bigWig | \
    tee -a $logfile

    bedGraphToBigWig $intermediates_dir/$experiment${tag}_minus.bedGraph \
    $reference_dir/chrom.sizes $bigWigs_dir/$experiment${tag}_minus.bigWig &
 
    echo $( timestamp ): [$!] "~/./bedGraphToBigWig" \
    $intermediates_dir/$experiment${tag}_minus.bedGraph \
    $reference_dir/chrom.sizes $bigWigs_dir/$experiment${tag}_minus.bigWig | \
    tee -a $logfile

    wait_for_jobs_to_finish "bedGraphToBigWig"
else
    # get coverage of 5’ positions
    echo $( timestamp ): "bedtools genomecov" \
    "-5 -bg -ibam" $intermediates_dir/$experiment$tag.bam "|" \
    "sort -k1,1 -k2,2n >" $intermediates_dir/$experiment$tag.bedGraph | \
    tee -a $logfile
    
    bedtools genomecov \
    -5 -bg -ibam $intermediates_dir/$experiment$tag.bam | \
    sort -k1,1 -k2,2n > $intermediates_dir/$experiment$tag.bedGraph

    echo $( timestamp ): "~/./bedGraphToBigWig" \
    $intermediates_dir/$experiment${tag}.bedGraph \
    $reference_dir/chrom.sizes $bigWigs_dir/$experiment$tag.bigWig \
    | tee -a $logfile
    
    bedGraphToBigWig $intermediates_dir/$experiment$tag.bedGraph \
    $reference_dir/chrom.sizes $bigWigs_dir/$experiment$tag.bigWig
fi
