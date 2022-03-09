version 1.0

task run_performance_reports{
	input {
		String experiment
		File peaks
		Array [File] predictions_test_chrom
		Array [File] predictions_all_chrom
		File splits_json


  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone https://github.com/kundajelab/TF-Atlas.git
		chmod -R 777 TF-Atlas
		cd TF-Atlas/anvil/reports/

		##shap

		echo "run /my_scripts/TF-Atlas/anvil/reports/performance_reports_pipeline.sh" ${experiment} ${peaks} ${sep=',' predictions_test_chrom} ${sep=',' predictions_all_chrom} ${splits_json}
		/my_scripts/TF-Atlas/anvil/reports/performance_reports_pipeline.sh ${experiment} ${peaks} ${sep=',' predictions_test_chrom} ${sep=',' predictions_all_chrom} ${splits_json}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/reports /cromwell_root/

		ls /project/reports

		
	}
	
	output {

		File performance_reports = "reports/performance.html"
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-reports'
		memory: 4 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 50 HDD"
  		maxRetries: 1
	}
}

workflow performance_reports {
	input {
		String experiment
		File peaks
		Array [File] predictions_test_chrom
		Array [File] predictions_all_chrom
		File splits_json

	}

	call run_performance_reports {
		input:
			experiment = experiment,
			peaks = peaks,
			predictions_test_chrom = predictions_test_chrom,
			predictions_all_chrom = predictions_all_chrom,
			splits_json = splits_json
 	}
	output {
		File performance_reports = run_performance_reports.performance_reports

	}
}
