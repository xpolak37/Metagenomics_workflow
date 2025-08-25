# Metagenomics workflow

This repository includes the bioinformatic workflow for metagenomics, all parameters are set to 
work properly on specific data from our lab. Before any usage, please check if it fits your data as well. 

## Quick usage

Whole workflow can be executed by main_metagenomics.sh, where you have to change paths to conda environments and to your data

```bash
bash main_metagenomics.sh
```

### Inputs

### Outputs

### Requirements

## About
The workflow consists of multiple modules, all will be exececuted if not set otherwise:

**1. Quality control**
Runs **FastQC & MultiQC** to provide quality control report of all samples. Additionally, it creates a **QUICK SUMMARY** 
of adapter content, sequencing depth, overrepresented sequences and their BLAST hits, for overall summary of the run.

Input: raw fastqcs
Output: 
- *quality_raw* folder with fastqc and multiqc data
- *run_info* folder with:
     - raw_custom_summary.txt - adapter content, sequencing depth, overrepresented sequences
     - raw_multiqc_report.html - copy of the multiqc_report.html
     - reads_count_summary.txt - read counts
     
**2. Preprocessing**
Runs **fastp** for preprocessing the raw fastq files. It performs quality filtering and trimming. Generally, it is executed with the default parameters with the minor changes. See the command below.

```bash
fastp \
    -i sample_R1_001.fastq.gz \
    -I sample_R2_001.fastq.gz \
    -o /path/to/output/sample_R1_trimmed.fastq.gz \
    -O /path/to/output/sample_R2_trimmed.fastq.gz \
    --adapter_fasta adapters.fasta \
    --trim_poly_g --trim_poly_x \
    --cut_tail --cut_front \
    --length_required 75 \
    --thread 5 \
    --html ${path_output}/reports/{/}.html \
    --json ${path_output}/reports/{/}.json"
```

Next, it runs **hostile** to remove human and phix contamination. As for human decontamination, it uses hostile's prepared indexes (human-t2t-hla-argos985-mycob140) that consist of T2T-CHM13v2.0 + IPD-IMGT/HLA v3.51 masked with 150mers for 985 FDA-ARGOS bacterial & 140 mycobacterial genomes. As for phix decontamination, it uses custom indexes of [phiX174](https://www.ncbi.nlm.nih.gov/nuccore/9626372), built by:

```bash
bowtie2-build phiX174.fasta phiX174
```

See the executed commands below. 

```bash
# human decontamination
hostile clean \
--fastq1 sample_R1_trimmed.fastq.gz \
--fastq2 sample_R2_trimmed.fastq.gz \
--index human-t2t-hla-argos985-mycob140
--output /path/to/project_dir/decontaminated/human/

# phix decontamination
hostile clean \
--fastq1 sample_R1_trimmed.clean_1.fastq.gz \
--fastq2 sample_R2_trimmed.clean_2.fastq.gz \
--index path/to/prebuilt/phix_indexes \
--output /path/to/project_dir/decontaminated/human_phix/
```

Input: trimmed fastqcs
Output: 
- *trimmed* folder - results of fastp
- *decontaminated* folder:
    - *decontaminated/human/* folder - results of hostile's human removal
    - *decontmainated/human_phix/* folder - results of hostile's phix removal
- *run_info* folder with:
     - read_counts_summary.txt - updated read counts track
     - trimmed_multiqc_report.html - copy of the multiqc_report.html

**3. Taxonomic profiling**



**4. Functional profiling**
