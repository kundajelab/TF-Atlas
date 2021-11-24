version 1.0

task run_modisco {
	input {
		String experiment
		Array [File] shap


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
		memory: 64 + "GB"
		cpu: "16"
		bootDiskSizeGb: 100
		disks: "local-disk 250 HDD"
		preemptible: 1
  		maxRetries: 3
	}
}

workflow modisco {
	input {
		String experiment
		Array [File] shap

	}

	call run_modisco {
		input:
			experiment = experiment,
			shap = shap
 	}
	output {
		Array[File] modisco_profile = run_modisco.modisco_profile
		Array[File] modisco_counts = run_modisco.modisco_counts

		
	}
}
