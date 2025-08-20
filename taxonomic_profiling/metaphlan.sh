#!/bin/bash

# Define the list of sample IDs
SAMPLES=(
#   "S24-137-KA14"
#   "S24-137-KA15"
   "S24-137-KA1MOCK"
#   "S24-137-KA20"
#   "S24-137-KA21"
#   "S24-137-KA88"
#   "S24-137-KA98"
)

# Define other parameters
export MAX_JOBS=5  # Number of parallel jobs to run
export PATH_TO_DATA="/home/povp/WGS_lane1/subsampled_data"

# Tool specific variables
export BOWTIE_DB_PATH="metaphlan_dbs"
export BOWTIE_DB_FILE=$(cat $BOWTIE_DB_PATH/mpa_latest)
export MP_VERSION=vJun23
export NU_THREADS=5
export JO_THREADS=8

run_metaphlan() {

        SAMPLEID=$1
        SAMPLEFOLDER=${PATH_TO_DATA}/${SAMPLEID}

        echo $SAMPLEFOLDER



                                  --input_type fastq \
                                  --bowtie2out $SAMPLEFOLDER/metagenome.bowtie2.bz2 \
                                  --db_dir $BOWTIE_DB_PATH \
                                  -x $BOWTIE_DB_FILE \
                                  --profile_vsc \
                                  --nproc $NU_THREADS \
                                  --stat_q 0.05 \
                                  --min_cu_len 1000 \
                                  --pres_th 0 \
                                  --unclassified_estimation \
                                  -o ${SAMPLEFOLDER}/${SAMPLEID}_${BOWTIE_DB_FILE}.txt \
                                  --vsc_out ${SAMPLEFOLDER}/${SAMPLEID}_mpa_${MP_VERSION}_vsc_profile.txt
                fi
        fi

}

export -f run_metaphlan
#Parallel execution of MetaPhlan for each sample
echo ${SAMPLES[@]}
echo "${SAMPLES[@]}" | tr ' ' '\n' | parallel -j "$MAX_JOBS" run_metaphlan