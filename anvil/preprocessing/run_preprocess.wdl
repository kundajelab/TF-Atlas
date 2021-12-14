version 1.0

task run_preprocess {
	input {
		String experiment
		String encode_access_key
		String encode_secret_key
		File metadata
		File reference_file
		File chrom_sizes
		File blacklist
  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_data
		cd /my_data
		git clone --single-branch --branch chromatin-atlas https://github.com/kundajelab/TF-Atlas.git
		chmod -R 777 TF-Atlas
		cd TF-Atlas/anvil/preprocessing

		#run the params create script and preprocess script
		echo "run create_params.sh"
		bash create_params.sh ${experiment} ${metadata}
		cp params_file.json /cromwell_root/params_file.json	#copy the file to the root folder for cromwell to copy

		##preprocessing
		echo "run run_preprocess.sh"
		bash run_preprocess.sh params_file.json ${encode_access_key} ${encode_secret_key} ${reference_file}  ${chrom_sizes} ${blacklist}

		# is there only one peak file in downloads_dir?
		cp downloads/peaks_no_blacklist.bed.gz /cromwell_root/peaks.bed.gz
		cp -r bigWigs /cromwell_root/
		
	}
	
	output {
		File peaks_bed = "peaks.bed.gz"
		Array[File] output_bw = glob("bigWigs/*.bigWig")
		Array[File] pwm_bw = glob("bigWigs/*.png")
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas'
		memory: 40 + "GB"
		bootDiskSizeGb: 200
		disks: "local-disk 1000 HDD"
	}
}

workflow preprocess {
	input {
		String experiment
		String encode_access_key
		String encode_secret_key
		File metadata
		File reference_file
		File chrom_sizes
		File blacklist
	}

	call run_preprocess {
		input:
			experiment = experiment,
			encode_access_key = encode_access_key,
			encode_secret_key = encode_secret_key,
			pipeline_destination = pipeline_destination,
			metadata = metadata,
			reference_file = reference_file,
			reference_file_index = reference_file_index,	
			chrom_sizes = chrom_sizes
 	}
	output {
		File peaks_bed = run_preprocess.peaks_bed
		Array[File] output_bw = run_preprocess.output_bw
		Array[File] pwm_bw = run_preprocess.pwm_bw
	}
}
