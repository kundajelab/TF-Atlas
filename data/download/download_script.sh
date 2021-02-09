# $1 access_key
# $2 secret_key
# $3 output_dir
# $4 log_file
# $5 download_url
# $6 md5sum

# create the log file
touch $4

# get basename of file from the url
# bash magic
# ${url  <-- from variable foo
#   ##   <-- greedy front trim
#   *    <-- matches anything
#   /    <-- until the last '/'
#  }
url=$5
fname=${url##*/}

# destination path of the downloaded file 
dst_fname=$3/$fname  
echo $dst_fname

# check if the file already exists
if [ -e $dst_fname ]; then
    # compute the md5sum
    md5=`md5sum ${dst_fname} | cut -d ' ' -f1`
    
    # if the md5 matches we quit
    if [ "$md5" = "$6" ]; then
        # append msg to log file
        echo 'File already exists' $dst_fname >> $4
        # great!! nothing else to do
        exit 0
    fi
fi

# proceed to download the file

# We'll try to download the file. If the download finishes
# and the md5sum matches then the download was a success, if not
# we attempt to download again for a maximum of 3 attempts
max_attempts=3
attempt=0
while [ $attempt -lt $max_attempts ]; do
    # download the file using the authentication parameters
    curl -sRL -u $1:$2 $5 -o $dst_fname
    
    # compute the md5sum
    md5=`md5sum ${dst_fname} | cut -d ' ' -f1`
    
    # if the md5 matches download was a success, we quit
    if [ "$md5" = "$6" ]; then
        # append msg to log file
        echo "Successfully downloaded " $url >> $4
        exit 0
    fi
    
    attempt=$((attempt + 1))
done

# append msg to log file
echo "Failed to download ${url} after 3 attempts" >> $4
exit 1


# cat ../data/alignments_bams_urls_md5sums.txt | xargs -n2 -P10 ./download_script.sh HBZNC72F dxjvsz3pfvnaqoxw ../data/filtered_bams alignments_bams_log.txt
# cat ../data/unfiltered_alignments_bams_urls_md5sums.txt | xargs -n2 -P10 ./download_script.sh HBZNC72F dxjvsz3pfvnaqoxw ../data/unfiltered_bams unfiltererd_alignments_bams_log.txt
# cat ../data/preferred_default_urls_md5sums.txt | xargs -n2 -P10 ./download_script.sh HBZNC72F dxjvsz3pfvnaqoxw ../data/idr_peaks idr_peaks_log.txt

# ./download_script.sh HBZNC72F dxjvsz3pfvnaqoxw . log.txt https://www.encodeproject.org/files/ENCFF681RYK/@@download/ENCFF681RYK.bed.gz 2ef5301e8e9fcc39596748f03f7f5216
