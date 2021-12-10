version 1.0

task run_preprocess {
	input {
		String experiment
		String encode_access_key
		String encode_secret_key
		#gbsc-gcp-lab-kundaje-tf-atlas
		String pipeline_destination
		File metadata
		File reference_file
		File reference_file_index
		File chrom_sizes
  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_data
		cd /my_data
		#does this have to be a gitlink to my scripts?
		git clone https://github.com/viramalingam/tf_atlas_analysis.git
		chmod -R 777 tf_atlas_analysis
		cd tf_atlas_analysis/pipeline

		#run the params create script and preprocess script
		echo "run ../create_params.sh"
		../create_params.sh ${experiment} ${encode_access_key} ${encode_secret_key} ${pipeline_destination} ${metadata}
		cp params_file.json /cromwell_root/params_file.json	#copy the file to the root folder for cromwell to copy

		##preprocessing
		echo "run ../run_preprocess.sh"
		../run_preprocess.sh params_file.json ${encode_access_key} ${encode_secret_key} ${pipeline_destination} ${reference_file} ${reference_file_index} ${chrom_sizes}
		cp downloads/*.bed.gz /cromwell_root/peaks.bed.gz
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
		#gbsc-gcp-lab-kundaje-tf-atlas
		String pipeline_destination
		File metadata
		File reference_file
		File reference_file_index
		File chrom_sizes
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
