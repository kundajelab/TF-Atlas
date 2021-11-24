version 1.0

task run_reports {
	input {
		String experiment
		File peaks
		Array [File] predictions
		Array [File] shap
		Array [File] modisco_counts
		Array [File] modisco_profile
		File tomtom_database
		File input_json


  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone https://github.com/kundajelab/TF-Atlas.git
		chmod -R 777 TF-Atlas
		cd TF-Atlas/anvil/reports/

		##shap

		echo "run /my_scripts/TF-Atlas/anvil/reports/reports_pipeline.sh" ${experiment} ${peaks} ${sep=',' predictions} ${sep=',' shap} ${sep=',' modisco_counts} ${sep=',' modisco_profile} ${tomtom_database}
		/my_scripts/TF-Atlas/anvil/reports/reports_pipeline.sh ${experiment} ${peaks} ${sep=',' predictions} ${sep=',' shap} ${sep=',' modisco_counts} ${sep=',' modisco_profile} ${tomtom_database}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/reports /cromwell_root/
		
	}
	
	output {

		File performance_reports = glob("reports/*")
		Array[File] reports = glob("reports/*")
		
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-reports'
		memory: 30 + "GB"
		bootDiskSizeGb: 100
		disks: "local-disk 250 HDD"
		preemptible: 1
  		maxRetries: 3
	}
}

workflow reports {
	input {
		String experiment
		File peaks
		Array [File] predictions
		Array [File] shap
		Array [File] modisco_counts
		Array [File] modisco_profile
		File tomtom_database
		File input_json

	}

	call run_reports {
		input:
			experiment = experiment,
			peaks = peaks,
			predictions = predictions,
			shap = shap,	
			modisco_counts = modisco_counts,
			modisco_profile = modisco_profile,
			tomtom_database = tomtom_database,
			input_json = input_json
 	}
	output {
		File performance_reports = run_reports.performance_reports
		Array [File] reports = run_reports.reports

		
	}
}
