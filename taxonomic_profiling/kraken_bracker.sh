#!/bin/bash
eval "$(conda shell.bash hook)"

# variables for conda environment
conda_env_dir_kraken="nextflow_env"
conda_env_dir_R="/home/povp/conda_envs/R_v4_env"

# paths for data storage
path_input="/home/povp/Projects/kompas/decontaminated/human_phix"
path_output="/home/povp/Projects/kompas/kraken/"
path_project_dir="/home/povp/Projects/kompas/"

# TMPDIR
export TMPDIR=/home/povp/tmp

# activate environment
conda activate ${conda_env_dir_kraken}

# info for tools and versions txt
echo "kraken_bracken.sh:" >> ${path_project_dir}/run_info/tools.txt

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

## track version
cat ${path_output}/kraken_output/pipeline_infonf_core_taxprofiler_software_mqc_versions.yml >> ${path_project_dir}/run_info/tools.txt

# copy the report to run_info
cp ${path_output}/kraken_output/multiqc/multiqc_report.html ${path_project_dir}/run_info/bracken_multiqc_report.html

# POLISH THE RESULTS
## activate R environment
conda activate ${conda_env_dir_R}
## Run R script for merging the tables
Rscript merging_bracken_tables.R ${path_output}/kraken_output/bracken/db1/ ${path_output}
## track version
R --version | head -n 1 >> ${path_project_dir}/run_info/tools.txt