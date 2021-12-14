version 1.0

task run_modelling {
	input {
		String experiment		
		File reference_file
		File chrom_sizes
		Array [File] bigwigs
		File peaks
		File non_peaks
		File bias_model
  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_data
		cd /my_data
		git clone --single-branch --branch chromatin-atlas https://github.com/kundajelab/TF-Atlas.git
		chmod -R 777 TF-Atlas
		cd TF-Atlas/anvil/modeling

		## modelling

		echo "run modelling_pipeline.sh" ${experiment} ${reference_file} ${chrom_sizes} ${sep=',' bigwigs} ${peaks} ${non_peaks} ${bias_model}

		bash run modelling_pipeline.sh ${experiment} ${reference_file} ${chrom_sizes} ${sep=',' bigwigs} ${peaks} ${non_peaks} ${bias_model}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/model /cromwell_root/
		cp -r /project/predictions_and_metrics_all_peaks_test_chroms /cromwell_root/
		cp -r /project/predictions_and_metrics_all_peaks_all_chroms /cromwell_root/


		cp -r /project/predictions_and_metrics_all_peaks_test_chroms/${experiment}.chrombpnet_profile_median_jsd_nonpeaks /cromwell_root/chrombpnet_profile_median_jsd_nonpeaks.txt
		cp -r /project/predictions_and_metrics_all_peaks_test_chroms/${experiment}.chrombpnet_profile_median_jsd_nonpeaks_wo_bias /cromwell_root/chrombpnet_profile_median_jsd_nonpeaks_wo_bias.txt
		cp -r /project/predictions_and_metrics_all_peaks_test_chroms/${experiment}.bias_profile_median_jsd_nonpeaks /cromwell_root/bias_profile_median_jsd_nonpeaks.txt


		cp -r /project/predictions_and_metrics_all_peaks_test_chroms/${experiment}.chrombpnet_cts_pearson_peaks /cromwell_root/chrombpnet_cts_pearson_peaks.txt
		cp -r /project/predictions_and_metrics_all_peaks_test_chroms/${experiment}.chrombpnet_cts_pearson_peaks_wo_bias /cromwell_root/chrombpnet_cts_pearson_peaks_wo_bias.txt
		cp -r /project/predictions_and_metrics_all_peaks_test_chroms/${experiment}.bias_cts_pearson_peaks /cromwell_root/bias_cts_pearson_peaks.txt
		
	}
	
	output {
		Array[File] model = glob("model/*")
		Array[File] predictions_and_metrics_all_peaks_test_chroms = glob("predictions_and_metrics_all_peaks_test_chroms/*")
		Array[File] predictions_and_metrics_all_peaks_all_chroms = glob("predictions_and_metrics_all_peaks_all_chroms/*")

		Float chrombpnet_profile_median_jsd_nonpeaks = read_float("chrombpnet_profile_median_jsd_nonpeaks.txt")
		Float chrombpnet_profile_median_jsd_nonpeaks_wo_bias = read_float("chrombpnet_profile_median_jsd_nonpeaks_wo_bias.txt")
		Float bias_profile_median_jsd_nonpeaks = read_float("bias_profile_median_jsd_nonpeaks.txt")
		Float chrombpnet_cts_pearson_peaks = read_float("chrombpnet_cts_pearson_peaks.txt")
		Float chrombpnet_cts_pearson_peaks_wo_bias = read_float("chrombpnet_cts_pearson_peaks_wo_bias.txt")
		Float bias_cts_pearson_peaks = read_float("bias_cts_pearson_peaks.txt")
	
	}

	runtime {
		docker: 'kundajelab/chrombpnet-lite'
		memory: 32 + "GB"
		bootDiskSizeGb: 100
		disks: "local-disk 250 HDD"
		gpuType: "nvidia-tesla-p100"
		gpuCount: 1
		nvidiaDriverVersion: "418.87.00"
		preemptible: 1
  		maxRetries: 3 
	}
}

workflow modelling {
	input {
		String experiment		
		File reference_file
		File chrom_sizes
		Array [File] bigwigs
		File peaks
		File non_peaks
		File bias_model

	}

	call run_modelling {
		input:
			experiment = experiment,
			reference_file = reference_file,
			chrom_sizes = chrom_sizes,
			bigwigs = bigwigs,
			peaks = peaks,
			non_peaks = non_peaks,
			bias_model = bias_model
 	}
	output {
		Array[File] model = run_modelling.model
		Array[File] predictions_and_metrics_all_peaks_test_chroms = run_modelling.predictions_and_metrics_all_peaks_test_chroms
		Array[File] predictions_and_metrics_all_peaks_all_chroms = run_modelling.predictions_and_metrics_all_peaks_all_chroms
		Float chrombpnet_profile_median_jsd_nonpeaks = run_modelling.chrombpnet_profile_median_jsd_nonpeaks
		Float chrombpnet_profile_median_jsd_nonpeaks_wo_bias = run_modelling.chrombpnet_profile_median_jsd_nonpeaks_wo_bias
		Float bias_profile_median_jsd_nonpeaks = run_modelling.bias_profile_median_jsd_nonpeaks
		Float chrombpnet_cts_pearson_peaks = run_modelling.chrombpnet_cts_pearson_peaks
		Float chrombpnet_cts_pearson_peaks_wo_bias = run_modelling.chrombpnet_cts_pearson_peaks_wo_bias
		Float bias_cts_pearson_peaks = run_modelling.bias_cts_pearson_peaks
			
	}
}
