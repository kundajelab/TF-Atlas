version 1.0

task run_modisco {
	input {
		String experiment
		Array [File] shap
		Int mem_gb
		Int number_of_cpus


  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone https://github.com/kundajelab/TF-Atlas.git
		chmod -R 777 TF-Atlas
		cd TF-Atlas/anvil/modisco/

		##modisco

		echo "run /my_scripts/TF-Atlas/anvil/modisco/modisco_pipeline.sh" ${experiment} ${sep=',' shap} ${number_of_cpus}
		/my_scripts/TF-Atlas/anvil/modisco/modisco_pipeline.sh ${experiment} ${sep=',' shap} ${number_of_cpus}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/modisco_profile /cromwell_root/
		cp -r /project/modisco_counts /cromwell_root/
		
	}
	
	output {
		Array[File] modisco_profile = glob("modisco_profile/*")
		Array[File] modisco_counts = glob("modisco_counts/*")
		Int max_memory_used_gb = read_int("max_memory_used_gb.txt")
		
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling'
		memory: mem_gb + "GB"
		cpu: number_of_cpus
		bootDiskSizeGb: 50
		disks: "local-disk 100 HDD"
  		maxRetries: 1
	}
}

workflow modisco {
	input {
		String experiment
		Array [File] shap
		File peak_bed_for_mem_calculation

	}

	Float size_of_peak_file = size(peak_bed_for_mem_calculation, "KB")

	Int mem_gb=32

	Int number_of_cpus=16



	call run_modisco {
		input:
			experiment = experiment,
			shap = shap,
			mem_gb = mem_gb,
			number_of_cpus = number_of_cpus
 	}
	output {
		Array[File] modisco_profile = run_modisco.modisco_profile
		Array[File] modisco_counts = run_modisco.modisco_counts
		Int max_memory_used_gb = run_modisco.max_memory_used_gb

		
	}
}
