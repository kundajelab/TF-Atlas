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
		
		cp -r /project/modisco /cromwell_root/
		
	}
	
	output {
		Array[File] modisco = glob("modisco/*")
		
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling'
		memory: 50 + "GB"
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
		Array[File] modisco = run_modisco.modisco

		
	}
}
