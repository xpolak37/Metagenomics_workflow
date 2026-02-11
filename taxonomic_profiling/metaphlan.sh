#!/bin/bash
eval "$(conda shell.bash hook)"

# variables for conda environment
conda_env_dir_metaphlan="/home/povp/conda_envs/WGS"

# Define other parameters
export n_parallel_jobs=5
export path_input="/home/povp/Projects/kompas/decontaminated/human_phix/"
export path_output="/home/povp/Projects/kompas/metaphlan/"
export path_project_dir="/home/povp/Projects/kompas/"
export TMPDIR=/home/povp/tmp

# Tool specific variables
# Here, we are using mpa_vJan25_CHOCOPhlAnSGB_202503
export metaphlan_bowtie_db=${path_scripts}/taxonomic_profiling/metaphlan_dbs
export BOWTIE_DB_FILE=$(cat ${metaphlan_bowtie_db}/mpa_latest)
export MP_VERSION="vJun25"
export metaphlan_nproc=10

conda activate ${conda_env_dir_metaphlan}

# info for tools and versions txt
echo "metaphlan.sh:" >> ${path_project_dir}/run_info/tools.txt

mkdir ${path_output}
mkdir ${path_output}/bowtie_output/
mkdir ${path_output}/sam_output/

run_metaphlan() {
        sample_path=$1
        sample_name=$(basename ${sample_path})
        f1=${sample_path}_R1_trimmed_cleaned.fastq.gz
        f2=${sample_path}_R2_trimmed_cleaned.fastq.gz

        metaphlan ${f1},${f2} \
                --input_type fastq \
                --mapout ${path_output}/bowtie_output/${sample_name}.bowtie2.bz2 \
                --samout ${path_output}/sam_output/${sample_name}.sam \
                --db_dir $metaphlan_bowtie_db \
                -x $BOWTIE_DB_FILE \
                -t "rel_ab_w_read_stats" \
                --profile_vsc \
                --nproc $metaphlan_nproc \
                --pres_th 0 \
                -o ${path_output}/${sample_name}_map${MP_VERSION}.tsv \
                --vsc_out ${path_output}/${sample_name}_${MP_VERSION}_vsc_profile.tsv \
                --tmp_dir ${TMPDIR} \
                --verbose

}

export -f run_metaphlan

#Parallel execution of MetaPhlan for each sample
find ${path_input} -type f -name "*_R1_trimmed_cleaned.fastq.gz" | sed 's/_R1_trimmed_cleaned.fastq.gz//' | parallel -j ${n_parallel_jobs} run_metaphlan

## track version
metaphlan --version >> ${path_project_dir}/run_info/tools.txt

## merge all samples into one table, save this table for counts as well as relative abundances
bash metaphlan_postprocessing.sh

# REMOVE intermediate RESULTS
if [[ "${keep_intermediate}" == "FALSE" ]]; then
    rm -r ${path_project_dir}/metaphlan/bowtie_output
fi

# compress the SAM files to BAM format
ls ${path_output}/sam_output/*.sam | parallel -j 10 'samtools view -bS {} > {.}.bam && rm {}'