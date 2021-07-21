#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

function wait_for_jobs_to_finish {
    # Function to wait for child processes to finish
    # and accumulate a count of how many failed
    #
    # Args:
    #     $1: string description
    #
    job_description=$1
        
    all_jobs=()
    for job in `jobs -p`
    do
        all_jobs+=( $job )
        echo $( timestamp ): [$job] Waiting for $job_description to \
        finish... | tee -a $logfile
    done
    echo $( timestamp ): Pending jobs "-" ${all_jobs[*]} | tee -a $logfile
    
    FAIL=0
    for job in `jobs -p`
    do
        wait $job || { echo $( timestamp ): [$job] ${job_description}  \
        failed. | tee -a $logfile; let "FAIL+=1"; }
    done

    if [ "$FAIL" = "0" ];
    then
        echo $( timestamp ): [${all_jobs[*]}] ${job_description} finished. | \
        tee -a $logfile    
    else
        echo $( timestamp ): $FAIL ${job_description} jobs failed. Aborting \
        pipeline. | tee -a $logfile
        exit 1
    fi
}

function download_file {
    # function that takes a comma separated list of ENCODE file ids
    # and invokes the download script with the correct parameters 
    #
    # Args:
    #     $1: comma separated list of ENCODE file ids
    #     $2: file extension ".bam", ".bed.gz" etc ...
    #     $3: comma separated list of md5sums corresponding to each
    #         file
    #     $4: "1" or "0" to indicate of md5sum check should be
    #         performed (1=yes)
    #     $5: path to logfile
    #     $6: ENCODE access key
    #     $7: ENCODE secret key
    #     $8: destination download directory
    
    file_ids="$1"
    file_type=$2
    md5sums="$3"
    
    # convert the space separated file ids and md5sums to arrays
    file_ids=( $file_ids )
    md5sums=( $md5sums )

    # all the other required params to the download script
    perform_md5sum_check=$4
    logfile=$5
    access_key=$6
    secret_key=$7
    downloads_dir=$8
    
    # iterate through all the files
    for i in "${!file_ids[@]}"
    do
        file_id=${file_ids[i]}
        md5sum=${md5sums[i]}
        
        # the encode download url
        file_download_url="https://www.encodeproject.org/files/$file_id/
        @@download/$file_id.$file_type"
        
        # HACK ALERT - bash is adding a space before @@download
        # can't seem to figure out how to make bash not do it. If 
        # you type the same in a shell there is no space ¯\_(ツ)_/¯.
        # So, we'll remove spaces using sed
        file_download_url=`echo $file_download_url | sed 's/ //g'`
        
        # call the download script with the right params
        ./download.sh $access_key $secret_key $file_download_url $md5sum \
        $perform_md5sum_check $logfile $downloads_dir &
        
        echo $( timestamp ): [$!] "./download.sh" $access_key $secret_key \
        $file_download_url $md5sum $perform_md5sum_check $logfile \
        $downloads_dir | tee -a $logfile
    done   
}
