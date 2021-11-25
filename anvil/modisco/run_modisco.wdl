version 1.0

task run_modisco {
	input {
		String experiment
		Array [File] shap
		Int mem_gb


  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone https://github.com/kundajelab/TF-Atlas.git
		chmod -R 777 TF-Atlas
		cd TF-Atlas/anvil/modisco/

		##modisco

		echo "run /my_scripts/TF-Atlas/anvil/modisco/modisco_pipeline.sh" ${experiment} ${sep=',' shap}
		/my_scripts/TF-Atlas/anvil/modisco/modisco_pipeline.sh ${experiment} ${sep=',' shap}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/modisco_profile /cromwell_root/
		cp -r /project/modisco_counts /cromwell_root/
		
	}
	
	output {
		Array[File] modisco_profile = glob("modisco_profile/*")
		Array[File] modisco_counts = glob("modisco_counts/*")
		
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling'
		memory: mem_gb + "GB"
		cpu: "16"
		bootDiskSizeGb: 100
		disks: "local-disk 250 HDD"
  		maxRetries: 3
	}
}

workflow modisco {
	input {
		String experiment
		Array [File] shap
		File peak_bed_for_mem_calculation

	}

	Float size_of_peak_file = size(peak_bed_for_mem_calculation, "KB")

	Int mem_gb=ceil(size_of_peak_file/250.0)*32


	call run_modisco {
		input:
			experiment = experiment,
			shap = shap,
			mem_gb = mem_gb
 	}
	output {
		Array[File] modisco_profile = run_modisco.modisco_profile
		Array[File] modisco_counts = run_modisco.modisco_counts

		
	}
}
