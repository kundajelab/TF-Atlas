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

		ls /project/reports

		
	}
	
	output {

		File performance_reports = "reports/performance.html"


		File counts_motif_reports = "reports/counts_tfm_results.html"
		File profile_motif_reports = "reports/profile_tfm_results.html"


		String counts_motif1 = read_string("reports/counts_motif0.txt")
		String counts_motif2 = read_string("reports/counts_motif1.txt")
		String counts_motif3 = read_string("reports/counts_motif2.txt")
		String counts_motif4 = read_string("reports/counts_motif3.txt")
		String counts_motif5 = read_string("reports/counts_motif4.txt")

		String profile_motif1 = read_string("reports/profile_motif0.txt")
		String profile_motif2 = read_string("reports/profile_motif1.txt")
		String profile_motif3 = read_string("reports/profile_motif2.txt")
		String profile_motif4 = read_string("reports/profile_motif3.txt")
		String profile_motif5 = read_string("reports/profile_motif4.txt")


		Array[File] reports = glob("reports/*")
		
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-reports'
		memory: 20 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 100 HDD"
  		maxRetries: 1
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

		String counts_motif1 = run_reports.counts_motif1
		String counts_motif2 = run_reports.counts_motif2
		String counts_motif3 = run_reports.counts_motif3
		String counts_motif4 = run_reports.counts_motif4
		String counts_motif5 = run_reports.counts_motif5

		String profile_motif1 = run_reports.profile_motif1
		String profile_motif2 = run_reports.profile_motif2
		String profile_motif3 = run_reports.profile_motif3
		String profile_motif4 = run_reports.profile_motif4
		String profile_motif5 = run_reports.profile_motif5


	}
}
