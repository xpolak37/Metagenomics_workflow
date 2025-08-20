#!/bin/bash

source activate base
conda init
source ~/.bashrc

# variables for conda environment
conda_env_dir_quality="/home/povp/conda_envs/quality"
conda_env_dir_blast="/home/povp/conda_envs/blast"
conda_env_dir_R="home/povp/conda_envs/R_v4_env"

# paths for data storage
path_input="/home/povp/seq_data/WGS/sub_data_optimalizace"
path_output="/home/povp/Projects/kompas/quality_raw2/"
path_project_dir="/home/povp/Projects/kompas/"

# activate conda environment 
conda activate ${conda_env_dir_quality}

mkdir ${path_output}

cd ${path_input}
find . -type f -name "*.fastq.gz" | xargs fastqc -o "${path_output}" -quiet -t 20

cd ${path_output}
multiqc . --interactive

cd multiqc_output

# QUICK SUMMARY
## Adapter content
echo "ADAPTER CONTENT:" >  custom_summary.txt
awk 'NR>1 {print $3}' fastqc_adapter_content_plot.txt | sort -u >> custom_summary.txt

## sequencing septh
conda activate ${conda_env_dir_R}
echo "SEQUENCING DEPTH SUMMARY" >> custom_summary.txt
awk 'NR>1 {print $NF*1000000}' multiqc_general_stats.txt | Rscript -e 'x <- scan("stdin", quiet=TRUE); summary(x)' >> custom_summary.txt

## overrepresented sequences
conda activate ${conda_env_dir_blast}

### get overrepresented sequences to fasta
awk 'NR>1 {print ">seq" NR-1 "\n" $1}' fastqc_top_overrepresented_sequences_table.txt > overrepresented.fasta

### run blastn
blastn -query overrepresented.fasta -db nt -remote -out overrepresented_results.txt -outfmt 6 

### filter results
awk '{
    if (!($1 in best) || $12 > best[$1]) {
        best[$1] = $12
        line[$1] = $0
    }
}
END {
    for (q in line) {
        print line[q]
    }
}' overrepresented_results.txt > best_hits.txt

### change the headers to identificants
# First: build a mapping from BLAST results (seqID -> accession)
awk '{print $1, $2}' best_hits.txt | sort -u > mapping.txt

# Now rewrite the fasta
awk '
BEGIN {
    # read mapping into array
    while ((getline < "mapping.txt") > 0) {
        map[$1] = $2
    }
}
{
    if ($0 ~ /^>/) {
        seqid = substr($0,2)   # remove ">"
        if (seqid in map) {
            # fetch NCBI header
            cmd = "esearch -db nucleotide -query \"" map[seqid] "\" | efetch -format fasta | head -n1"
            cmd | getline newheader
            close(cmd)
            print newheader
        } else {
            # no BLAST hit → keep original header
            print $0
        }
    } else {
        # sequence line
        print $0
    }
}' overrepresented.fasta > overrepresented.fasta

echo "OVERREPRESENTED SEQUENCES:" >> custom_summary.txt
cat overrepresented.fasta >> custom_summary.txt

### remove all redundant files
rm overrepresented.fasta mapping.txt best_hits.txt overrepresented_results.txt

# The final counts statistics
## Output file
outfile=${path_project_dir}/run_info/read_counts_summary.txt

# Header
echo -e "Sample\tRaw\tTrimmed\tDecontaminated" > ${outfile}

awk 'NR>1 {printf "%s\t%.0f\n", $1, $7*1000000}' ${path_output}/multiqc_data/multiqc_general_stats.txt >> ${outfile}

# copy the summaries to the run_info file
cp custom_summary.txt ${path_project_dir}/run_info/raw_custom_summary.txt
cp ../multiqc_report.html ${path_project_dir}/run_info/raw_multiqc_report.html
