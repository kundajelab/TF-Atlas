version 1.0

task run_reports {
	input {
		String experiment
		File peaks
		Array [File] predictions_test_chrom
		Array [File] predictions_all_chrom
		Array [File] shap
		Array [File] modisco_counts
		Array [File] modisco_profile
		File tomtom_database
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

		echo "run /my_scripts/TF-Atlas/anvil/reports/reports_pipeline.sh" ${experiment} ${peaks} ${sep=',' predictions_test_chrom} ${sep=',' predictions_all_chrom} ${sep=',' shap} ${sep=',' modisco_counts} ${sep=',' modisco_profile} ${tomtom_database} ${splits_json}
		/my_scripts/TF-Atlas/anvil/reports/reports_pipeline.sh ${experiment} ${peaks} ${sep=',' predictions_test_chrom} ${sep=',' predictions_all_chrom} ${sep=',' shap} ${sep=',' modisco_counts} ${sep=',' modisco_profile} ${tomtom_database} ${splits_json}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/reports /cromwell_root/
		
	}
	
	output {

		File performance_reports = glob("reports/performance.html")
		File counts_motif_reports = glob("reports/counts_tfm_results.html")
		File profile_motif_reports = glob("reports/profile_tfm_results.html")
		Array[File] reports = glob("reports/*")
		
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-reports'
		memory: 30 + "GB"
		bootDiskSizeGb: 100
		disks: "local-disk 250 HDD"
  		maxRetries: 3
	}
}

workflow reports {
	input {
		String experiment
		File peaks
		Array [File] predictions_test_chrom
		Array [File] predictions_all_chrom
		Array [File] shap
		Array [File] modisco_counts
		Array [File] modisco_profile
		File tomtom_database
		File splits_json

	}

	call run_reports {
		input:
			experiment = experiment,
			peaks = peaks,
			predictions_test_chrom = predictions_test_chrom,
			predictions_all_chrom = predictions_all_chrom,
			shap = shap,	
			modisco_counts = modisco_counts,
			modisco_profile = modisco_profile,
			tomtom_database = tomtom_database,
			splits_json = splits_json
 	}
	output {
		File performance_reports = run_reports.performance_reports
		Array [File] reports = run_reports.reports
		File counts_motif_reports = run_reports.counts_motif_reports
		File profile_motif_reports = run_reports.profile_motif_reports

		
	}
}
