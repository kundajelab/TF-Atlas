version 1.0

task run_gc_matched_negatives {
	input {
		String experiment
		File reference_file
		File reference_file_index
		File chrom_sizes
		File chroms_txt
		File reference_gc_hg38_stride_1000_flank_size_1057
		File peaks
		File splits

  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone https://github.com/kundajelab/TF-Atlas.git
		chmod -R 777 TF-Atlas
		cd TF-Atlas/anvil/gc_matched_negatives/




		##outlier_detection

		echo "run /my_scripts/TF-Atlas/anvil/gc_matched_negatives/gc_negatives.sh" ${experiment} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${reference_gc_hg38_stride_1000_flank_size_1057} ${peaks} ${splits}
		/my_scripts/TF-Atlas/anvil/gc_matched_negatives/gc_negatives.sh ${experiment} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${reference_gc_hg38_stride_1000_flank_size_1057} ${peaks} ${splits}

		echo "copying all files to cromwell_root folder"

		gzip /project/data/gc_neg_only.bed
		
		cp /project/data/gc_neg_only.bed.gz /cromwell_root/gc_neg_only.bed.gz
		cp /project/data/gc_distribution.png /cromwell_root/gc_distribution.png
		
	}
	
	output {

		File gc_neg_only_bed = "gc_neg_only.bed.gz"
		File gc_distribution_png = "gc_distribution.png"
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling'
		memory: 32 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 100 HDD"

	}
}

workflow gc_matched_negatives {
	input {
		String experiment
		File reference_file
		File reference_file_index
		File chrom_sizes
		File chroms_txt
		File reference_gc_hg38_stride_1000_flank_size_1057
		File peaks
		File splits
	}

	call run_gc_matched_negatives {
		input:
			experiment = experiment,
			reference_file = reference_file,
			reference_file_index = reference_file_index,
			chrom_sizes = chrom_sizes,
			chroms_txt = chroms_txt,
			reference_gc_hg38_stride_1000_flank_size_1057 = reference_gc_hg38_stride_1000_flank_size_1057,
			peaks = peaks,
			splits = splits
 	}
	output {

		File gc_neg_only_bed = run_gc_matched_negatives.gc_neg_only_bed
		File gc_distribution_png = run_gc_matched_negatives.gc_distribution_png
	
	}
}
