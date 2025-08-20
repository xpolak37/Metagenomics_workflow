#!/bin/bash

source activate base
conda init
source ~/.bashrc

# variables for conda environment
conda_env_dir_preprocessing="/home/povp/conda_envs/WGS_preprocessing"
conda_env_dir_R="home/povp/conda_envs/R_v4_env"

# paths for data storage
path_input="/home/povp/seq_data/WGS/Illumina_IAB/"
path_input="/home/povp/seq_data/WGS/sub_data_optimalizace"
path_output="/home/povp/Projects/kompas/trimmed/"
path_project_dir="/home/povp/Projects/kompas/"

# activate environment
conda activate ${conda_env_dir_preprocessing}

# make output dirs
mkdir ${path_output}
mkdir ${path_output}/reports

# run fastp to trim adapters, polygs and quality trim
find ${path_input} -type f -name "*_R1_001.fastq.gz" | sed 's/_R1_001.fastq.gz//' | parallel -j 10 "fastp \
    -i {}_R1_001.fastq.gz \
    -I {}_R2_001.fastq.gz \
    -o ${path_output}/{/}_R1_trimmed.fastq.gz \
    -O ${path_output}/{/}_R2_trimmed.fastq.gz \
    --adapter_fasta adapters.fasta \
    --trim_poly_g --trim_poly_x \
    --cut_tail --cut_front \
    --length_required 75 \
    --thread 5 \
    --html ${path_output}/reports/{/}.html \
    --json ${path_output}/reports/{/}.json"

cd ${path_output}

# FASTQC+MULTIQC for trimmed report
fastqc *.fastq.gz -o ${path_output}/reports/ -quiet -t 20
cd ${path_output}/reports/
multiqc . --interactive

# The final counts statistics
## Output file
outfile=${path_project_dir}/run_info/read_counts_summary.txt
infile=${path_output}/reports/multiqc_data/multiqc_general_stats.txt

python3 counts_summary.py ${infile} ${outfile} 2

# copy the summaries to the run_info file
cp multiqc_report.html ${path_project_dir}/run_info/trimmed_multiqc_report.html