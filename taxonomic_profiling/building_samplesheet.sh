#!/bin/bash

# RUN INFO
run_name="KOMPAS"
platform="ILLUMINA"

# paths for data storage
path_input="/home/povp/Projects/kompas/decontaminated/human_phix/"
path_output="/home/povp/Projects/kompas/kraken/"
path_project_dir="/home/povp/Projects/kompas/"

# create csv
out=${path_output}/samplesheet.csv
echo "sample,run_accession,instrument_platform,fastq_1,fastq_2,fasta" > $out

# add info for each sample
for f1 in ${path_input}/*_R1_trimmed_cleaned.fastq.gz; do
    # Get R2 by replacing R1 with R2
    f2=${f1/_R1_/_R2_}

    # Extract sample name - TO DO: NEEDS improvement
    sample=$(basename "$f1" | sed 's/^S24-137-//' | sed 's/_R1_trimmed_cleaned.fastq.gz//')

    echo "${sample},${run_name},${platform},${f1},${f2}," >> $out
done

