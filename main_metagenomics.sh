#!/bin/bash
set -euo pipefail

eval "$(conda shell.bash hook)"

perform_quality_control=TRUE
perform_preprocessing=TRUE
perform_taxprofiling=TRUE
perform_metaphlan=FALSE
perform_kraken=FALSE
keep_intermediate=FALSE

# DIRECTORIES
input_dir="/home/povp/seq_data/WGS/Illumina_IAB/"
project_dir="/home/povp/Projects/kompas/"

# CONDA ENVIRONMENTS
quality_env="/home/povp/conda_envs/quality"
blast_env="/home/povp/conda_envs/blast_env"
R_env="/home/povp/conda_envs/R_v4_env"
preprocessing_env="/home/povp/conda_envs/WGS_preprocessing"
nextflow_env="/home/povp/conda_envs/WGS_preprocessing"
metaphlan_env="/home/povp/conda_envs/WGS"

# set all variables
while [[ $# -gt 0 ]]; do
    case $1 in
        --input_dir) input_dir=$2; shift 2 ;;
        --project_dir) project_dir=$2; shift 2 ;;
        --keep_intermediate) keep_intermediate=TRUE; shift ;;
        --skip_quality) perform_quality_control=FALSE; shift ;;
        --skip_preprocessing) perform_preprocessing=FALSE; shift ;;
        --skip_taxprofiling) perform_taxprofiling=FALSE; shift ;;
        --metaphlan) perform_metaphlan=TRUE; shift ;;
        --kraken) perform_kraken=TRUE; shift ;;
        --quality_env) quality_env=$2; shift 2;;
        --blast_env) blast_env=$2; shift 2;;
        --R_env) R_env=$2; shift 2;;
        --preprocessing_env) preprocessing_env=$2; shift 2;;
        --nextflow_env) nextflow_env=$2; shift 2;;
        --metaphlan_env) metaphlan_env=$2; shift 2;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

export path_scripts="$(pwd)"

# define the txt file for version tracking
mkdir -p ${project_dir}/run_info/
echo "# Tools and their versions throughout the run" > ${project_dir}/run_info/tools.txt

# RUN the pipeline

# Quality control
if [[ "${perform_quality_control}" == "TRUE" ]]; then
    echo "Performing quality control..."
    cd quality_control
    bash main_qc.sh
    echo "Done"
    cd ${path_scripts}
fi

# Preprocessing
if [[ "${perform_preprocessing}" == "TRUE" ]]; then
    cd preprocessing
    echo "Performing trimming with fastp"
    bash fastp_trimming.sh
    echo "Performing host decontamination with hostile"
    bash host_decontamination.sh
    echo "Done"
    cd ${path_scripts}
fi

# Taxonomic_profiling
if [[ "${perform_taxprofiling}" == "TRUE" ]]; then
    if [[ "$perform_metaphlan" == "FALSE" && "$perform_kraken" == "FALSE" ]]; then
        perform_metaphlan=TRUE
    fi

    cd taxonomic_profiling

    if [[ "${perform_metaphlan}" == "TRUE" ]]; then
        echo "Running Metaphlan4 for tax profiling..."
        bash metaphlan.sh
        echo Done
    fi
    if [[ "${perform_kraken}" == "TRUE" ]]; then
        echo "Running Kraken2+Bracken for tax profiling..."
        bash kraken_bracken.sh
        echo Done
    fi
    cd ..
fi

# Functional profiling