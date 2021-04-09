# import the utils script
. utils.sh


#Tuning

echo $( timestamp ):hyperparameter tuning now
echo chroms: $(paste -s -d ' ' $9/chroms.txt)
EXPERIMENT=$1 \
    ARCH_NAME=$2 \
    SEQGEN_NAME=$3 \
    SPLITS_FILE_PATH=$4 \
    PEAKS=$5 \
    LEARNING_RATE=$6 \
    COUNTS_LOSS_WEIGHT=$7 \
    EPOCHS=$8 \
    REFERENCE_DIR=$9 \
    DOWNLOADS_DIR=${10} \
    MODEL_DIR=${11} \
    PREDICTIONS_DIR=${12} \
    EMBEDDINGS_DIR=${13} \
    LOGFILE=${14} \
    TUNING_DIR=${15} \
    CHROMS=$(paste -s -d ' ' $REFERENCE_DIR/chroms.txt)\
	jupyter nbconvert \
    --execute tuning.ipynb --to HTML \
    --output tuning \
    --ExecutePreprocessor.timeout=-1




