# /users/zahoor/TF-Atlas/data/idr_peaks/ENCFF458PBB.bed.gz /users/zahoor/TF-Atlas/data/idr_peaks/ENCFF654RRF.bed.gz > ../data/idr_peaks/ENCFF458PBB_ENCFF654RRF.bed.gz

# sort -k1,1 -k2,2n ENCFF458PBB_ENCFF654RRF.bed -o ENCFF458PBB_ENCFF654RRF.bed_sorted

# bedtools merge -i ENCFF458PBB_ENCFF654RRF.bed_sorted > ENCFF458PBB_ENCFF654RRF.bed_sorted_merged

# /mnt/lab_data2/vir/tf_chr_atlas/02-24-2021/TF-Atlas/3M/reports/run_shap_combined_peaks.sh ENCSR000EEC

# EXPERIMENT=ENCSR000EEC
# BASE_DIR=/mnt/lab_data2/vir/tf_chr_atlas/02-24-2021/
# REFERENCE_DIR=/users/zahoor/reference
# CHROM_SIZES=$REFERENCE_DIR/hg38.chrom.sizes
# REFERENCE_GENOME=$REFERENCE_DIR/hg38.genome.fa
# INPUT_DATA=$BASE_DIR/jsons/$EXPERIMENT\_EDZ_EEB_combined.json
# PREDICTIONS_DIR=/mnt/lab_data2/vir/tf_chr_atlas/02-24-2021/predictions/ENCSR000EDZ_EEB/$EXPERIMENT/

# predict \
#     --model /mnt/lab_data2/vir/tf_chr_atlas/02-24-2021//models/$EXPERIMENT/$EXPERIMENT\_split000.h5 \
#     --input-seq-len 2114 \
#     --chrom-sizes $CHROM_SIZES \
#     --reference-genome $REFERENCE_GENOME \
#     --chroms $(cat /users/zahoor/reference/hg38_chroms.txt) \
#     --exponentiate-counts \
#     --output-dir $PREDICTIONS_DIR \
#     --input-data $INPUT_DATA \
#     --predict-peaks \
#     --write-buffer-size 2000 \
#     --batch-size 1 \
#     --has-control \
#     --stranded \
#     --automate-filenames


SRCDIR=/mnt/lab_data2/vir/tf_chr_atlas/02-24-2021/latest_repo/TF-Atlas/3M/reports/
OUTDIR=/mnt/lab_data2/vir/tf_chr_atlas/02-24-2021/reports/tfmodisco/notebooks/ENCSR000EDZ_EEB/
INDIR=/mnt/lab_data2/vir/tf_chr_atlas/02-24-2021/
PEAKSDIR=/mnt/lab_data2/vir/tf_chr_atlas/data/idr_peaks/

EXPID=$1
PEAKID=ENCFF458PBB_ENCFF654RRF.bed_sorted_merged_compatible


tfmdir=$INDIR/modisco/ENCSR000EDZ_EEB/$EXPID
impscoredir=$INDIR/shap/ENCSR000EDZ_EEB/$EXPID
predspath=$INDIR/predictions/$EXPID/profile_predictions.h5
peakspath=$PEAKSDIR/$PEAKID
moodsdir=$OUTDIR/$EXPID/moods
tomtom_db_path=/users/amtseng/tfmodisco/data/processed/motif_databases/HOCOMOCO_JASPAR_motifs.txt

cd $SRCDIR


# TF-MoDISco results
for key in profile counts
do
    TFM_PRED_PATH=$predspath \
        TFM_SHAP_PATH=$impscoredir/$key\_scores.h5 \
        TFM_TFM_PATH=$tfmdir/$key/modisco_results.h5 \
        TFM_PEAKS_PATH=$peakspath \
        TFM_TOMTOM_DB_PATH=$tomtom_db_path \
        TFM_TOMTOM_TEMP_DIR=$OUTDIR \
        jupyter nbconvert --execute view_tfmodisco_results.ipynb --to HTML --output $OUTDIR/$EXPID/$EXPID\_$key\_tfm_results --ExecutePreprocessor.timeout=-1 &
done
wait

# Examples of seqlets and profile predictions
for key in profile counts
do
	TFM_PRED_PATH=$predspath \
		TFM_SHAP_PATH=$impscoredir/$key\_scores.h5 \
		TFM_TFM_PATH=$tfmdir/$key/modisco_results.h5 \
		jupyter nbconvert --execute showcase_motifs_and_profiles.ipynb --to HTML --output $OUTDIR/$EXPID/$EXPID\_$key\_seqlet_profile_examples --ExecutePreprocessor.timeout=-1 &
done
wait

# Motif hits (this runs MOODS)
for key in profile counts
do
	TFM_TFM_PATH=$tfmdir/$key/modisco_results.h5 \
		TFM_SHAP_PATH=$impscoredir/$key\_scores.h5 \
		TFM_PEAKS_PATH=$peakspath \
		TFM_MOODS_DIR=$moodsdir/$key \
		jupyter nbconvert --execute summarize_motif_hits.ipynb --to HTML --output $OUTDIR/$EXPID/$EXPID\_$key\_motif_hits --ExecutePreprocessor.timeout=-1 &
done
wait