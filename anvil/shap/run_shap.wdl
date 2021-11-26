version 1.0

task run_shap {
	input {
		String experiment
		File input_json
		File reference_file
		File reference_file_index
		File chrom_sizes
		File chroms_txt
		Array [File] bigwigs
		File peaks
		Array [File] model


  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone https://github.com/kundajelab/TF-Atlas.git
		chmod -R 777 TF-Atlas
		cd TF-Atlas/anvil/shap/

		##shap

		echo "run /my_scripts/TF-Atlas/anvil/shap/shap_pipeline.sh" ${experiment} ${input_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${sep=',' model}
		/my_scripts/TF-Atlas/anvil/shap/shap_pipeline.sh ${experiment} ${input_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${sep=',' model}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/shap /cromwell_root/
		
	}
	
	output {
		Array[File] shap = glob("shap/*")
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling'
		memory: 30 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 100 HDD"
		gpuType: "nvidia-tesla-k80"
		gpuCount: 1
		nvidiaDriverVersion: "450.51.05" 
  		maxRetries: 3
	}
}

workflow shap {
	input {
		String experiment
		File input_json
		File reference_file
		File reference_file_index
		File chrom_sizes
		File chroms_txt
		Array [File] bigwigs
		File peaks
		Array [File] model

	}

	call run_shap {
		input:
			experiment = experiment,
			input_json = input_json,
			reference_file = reference_file,
			reference_file_index = reference_file_index,	
			chrom_sizes = chrom_sizes,
			chroms_txt = chroms_txt,
			bigwigs = bigwigs,
			peaks = peaks,
			model = model
 	}
	output {
		Array[File] shap = run_shap.shap

		
	}
}
