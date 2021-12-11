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


  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone https://github.com/kundajelab/TF-Atlas.git
		chmod -R 777 TF-Atlas
		cd TF-Atlas/anvil/analysis/

		##shap

		echo "run /my_scripts/TF-Atlas/anvil/analysis/analysis_motif_contributions.sh" ${experiment} ${peaks} ${sep=',' predictions_test_chrom} ${sep=',' predictions_all_chrom} ${sep=',' shap} ${sep=',' modisco_counts} ${sep=',' modisco_profile} ${tomtom_database}
		/my_scripts/TF-Atlas/anvil/analysis/analysis_motif_contributions.sh ${experiment} ${peaks} ${sep=',' predictions_test_chrom} ${sep=',' predictions_all_chrom} ${sep=',' shap} ${sep=',' modisco_counts} ${sep=',' modisco_profile} ${tomtom_database}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/analysis /cromwell_root/

		ls /project/analysis

		
	}
	
	output {


		String counts_motif_contributions = read_string("analysis/counts_motif_contributions.txt")

		String profile_motif_contributions = read_string("analysis/profile_motif_contributions.txt")
		
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-reports'
		memory: 16 + "GB"
		bootDiskSizeGb: 40
		disks: "local-disk 50 HDD"
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
 	}
	output {

		String counts_motif_contributions = run_reports.counts_motif_contributions

		String profile_motif_contributions = run_reports.profile_motif_contributions


	}
}
