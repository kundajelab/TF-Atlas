#!/bin/bash

# import the utils script
. utils.sh

# command line arguments
access_key=$1
secret_key=$2
download_url=$3
md5_sum=$4 # use underscore to distinguish from bash command md5sum
perform_md5sum_check=$5
logfile=$6
downloads_dir=$7

# Define a timestamp function
function timestamp {
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

# get basename of file from the url
# bash magic
# ${download_url  <-- from variable download_url
#   ##   <-- greedy front trim
#   *    <-- matches anything
#   /    <-- until the last '/'
#  }
fname=${download_url##*/}

# destination path of the downloaded file
dst_fname=$downloads_dir/$fname  
echo $( timestamp ): File save location... $dst_fname  | tee -a $logfile

# check if the file already exists
if [ -f $dst_fname ]
then
    # perform md5sum check if requested
    if [ "$perform_md5sum_check" = "1" ]
    then
        # compute the md5sum
        echo $( timestamp ): "md5sum" $dst_fname "| cut -d ' ' -f" | \
        tee -a $logfile
        md5=`md5sum ${dst_fname} | cut -d ' ' -f1`

        # if the md5 matches we quit
        if [ "$md5" = "$md5_sum" ]
        then
            # append msg to log file
            echo $( timestamp ): File already exists $dst_fname | \
            tee -a $logfile
            # great!! nothing else to do
            exit 0
        fi
    else 
        echo $( timestamp ): File already exists $dst_fname | tee -a $logfile
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
    echo $( timestamp ): "curl -sRL -u" $access_key":"$secret_key \
    $download_url "-o" $dst_fname | tee -a $logfile
    curl -sRL -u $access_key:$secret_key $download_url -o $dst_fname
    
    # perform md5sum check if requested
    if [ "$perform_md5sum_check" = "1" ]; then
        # compute the md5sum
        echo $( timestamp ): "md5sum" ${dst_fname} "| cut -d ' ' -f" | \
        tee -a $logfile
        md5=`md5sum ${dst_fname} | cut -d ' ' -f1`

        # if the md5 matches download was a success, we quit
        if [ "$md5" = "$md5_sum" ]; then
            # append msg to log file
            echo $( timestamp ): Successfully downloaded $download_url | \
            tee -a $logfile
            exit 0
        fi

        attempt=$((attempt + 1))
        continue
    fi
    
    # append msg to log file
    echo $( timestamp ): Successfully downloaded $download_url | \
    tee -a $logfile
    exit 0
done

# append msg to log file
echo $( timestamp ): Failed to download ${download_url} after 3 attempts | \
tee -a $logfile
exit 1
