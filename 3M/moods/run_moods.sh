#!/bin/bash

fasta_path=$1
p_value=$2
output_dir=$3
bedfile_path=$4

parallel "moods-dna.py -m {} -s $1 -p $2  > {.}_moods_results.csv" ::: $3/*.pfm

parallel "/mnt/lab_data2/vir/tf_chr_atlas/02-08-2021/modisco/ENCSR000BGZ/awk_moods_to_bed.sh {} {.}" ::: $3/*.csv

parallel "bedtools intersect -wa -wb -b $4 -a {} -f 1 > {.}_peak_overlaps.bed" ::: $3/*.bed

