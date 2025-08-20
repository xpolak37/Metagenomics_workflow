#!/bin/bash

source activate base
conda init
source ~/.bashrc

# variables for conda environment
conda_env_dir_kraken="nextflow_env"
conda_env_dir_R="/home/povp/conda_envs/R_v4_env"

# paths for data storage
path_input="/home/povp/seq_data/WGS/sub_data_optimalizace"
path_output="/home/povp/Projects/kompas/kraken/"
path_project_dir="/home/povp/Projects/kompas/"

# TMPDIR
export TMPDIR=/home/povp/tmp

# activate environment
conda activate ${conda_env_dir_kraken}

# make output dirs
mkdir ${path_output}

# samplesheet
bash building_samplesheet.sh

# databases
# there are two databases downloaded and created: - k2_pluspf_08gb_20250402.tar.gz
# Here, we are using PLUSPF. For more databases, see:
# https://benlangmead.github.io/aws-indexes/k2

# run KRAKEN2 + BRACKEN via taxprofiler
nextflow run nf-core/taxprofiler \
-profile conda \
--input ${path_output}/samplesheet.csv \
--databases databases.csv \
--outdir ${path_output}/kraken_output \
--skip_preprocessing_qc \
--run_kraken2 \
--run_bracken

# copy the report to run_info
cp ${path_output}/kraken_output/multiqc/multiqc_report.html ${path_project_dir}/run_info/bracken_multiqc_report.html

# POLISH THE RESULTS

## activate R environment
conda activate ${conda_env_dir_R}

Rscript merging_bracken_tables.R ${path_output}/kraken_output/bracken/db1/ ${path_output}