#!/usr/bin/env nextflow

nextflow.enable.dsl=2

/*
========================================================================================
    METAGENOMIC PROFILING PIPELINE
========================================================================================
    Fastp -> FastQC -> MetaPhlAn4 + mOTUs -> MultiQC
----------------------------------------------------------------------------------------
*/

// Print pipeline header
log.info """\
    ===================================
    METAGENOMIC PROFILING PIPELINE
    ===================================
    Input samplesheet : ${params.input}
    Output directory  : ${params.outdir}
    ===================================
    """
    .stripIndent()

/*
========================================================================================
    IMPORT MODULES
========================================================================================
*/

include { FASTQC as FASTQC_RAW }   from './modules/fastqc'
include { SEQTK_SUBSAMPLE }        from './modules/subsample'
include { FASTP }                   from './modules/fastp'
include { FASTQC as FASTQC_CLEAN } from './modules/fastqc'
include { HOST_REMOVAL; PHIX_REMOVAL; FASTQ_SYNC }     from './modules/host_decontamination'
include { METAPHLAN4_DB }           from './modules/metaphlan4_db'
include { METAPHLAN4 }              from './modules/metaphlan4'
include { MULTIQC }                 from './modules/multiqc'
include { METASTANDARD as METAPHLAN_METASTANDARD }        from './modules/MetaStandard'
include { METASTANDARD as BRACKEN_METASTANDARD }        from './modules/MetaStandard'
include { METASTANDARD_PLOTS }       from './modules/metastandard_plots'
include { STRAINPHLAN }       from './modules/metaphlan4'
include { SAMPLE2MARKERS }       from './modules/metaphlan4'
include { EXTRACT_MARKERS }       from './modules/metaphlan4'
include { MOCK_EVALUATION } from './modules/mock_evaluation'
include { KRAKEN2 } from './modules/kraken_bracken'
include { BRACKEN } from './modules/kraken_bracken'

/*
========================================================================================
    MAIN WORKFLOW
========================================================================================
*/

workflow {
    
    // Read and parse samplesheet
    Channel
        .fromPath(params.input)
        .splitCsv(header: true)
        .map { row -> 
            def sample_id = row.sample
            def read1 = file(row.read1)
            def read2 = file(row.read2)
            
            // Validate files exist
            if (!read1.exists()) exit 1, "ERROR: Read1 file does not exist: ${read1}"
            if (!read2.exists()) exit 1, "ERROR: Read2 file does not exist: ${read2}"
            
            return tuple(sample_id, read1, read2)
        }
        .set { ch_input_reads }
    
    // Setup MetaPhlAn4 database if not provided
    def ch_metaphlan_db
    if (params.metaphlan_db == null) {
        METAPHLAN4_DB()
        ch_metaphlan_db = METAPHLAN4_DB.out.db
    } else {
        ch_metaphlan_db = Channel.value(file(params.metaphlan_db))
    }
    
    // FastQC on raw reads
    FASTQC_RAW(ch_input_reads, "raw")
    
    // Optional subsampling for --quick mode
    def ch_reads_for_fastp
    if (params.quick) {
        SEQTK_SUBSAMPLE(ch_input_reads)
        ch_reads_for_fastp = SEQTK_SUBSAMPLE.out.reads
    } else {
        ch_reads_for_fastp = ch_input_reads
    }

    // Fastp trimming and filtering
    FASTP(ch_reads_for_fastp)
    
    // host decontamination (optional)
    def ch_decontaminated_reads
    if (params.host_decontamination) {
        HOST_REMOVAL(FASTP.out.reads, params.host_genome_index)
        PHIX_REMOVAL(HOST_REMOVAL.out.reads, params.bowtie_phix_index)
        FASTQ_SYNC(PHIX_REMOVAL.out.reads)  
        ch_decontaminated_reads = FASTQ_SYNC.out.reads
    } else {
        ch_decontaminated_reads = FASTP.out.reads
    }
    // FastQC on cleaned reads
    FASTQC_CLEAN(ch_decontaminated_reads, "clean")
    
    // MetaPhlAn4 profiling (parallel)
    METAPHLAN4(ch_decontaminated_reads, ch_metaphlan_db)
    
    // Kraken2 + Bracken profiling (parallel)
    if (params.kraken_profiling) {
        def kraken_db = "${params.database_cache_dir}/kraken_db"
        KRAKEN2(ch_decontaminated_reads, kraken_db)
        BRACKEN(KRAKEN2.out.kraken_report, kraken_db)
    }

    // Extract genes for strain-level profiling (if requested)
    def ch_bowtie2sam_files = Channel.empty()
    if (params.metaphlan_strain) {
        // Extract markers for strainphlan
        EXTRACT_MARKERS(params.strainphlan_sgb, ch_metaphlan_db)

        // Collect bowtie2sam files for strainphlan
        ch_bowtie2sam_files = METAPHLAN4.out.bowtie2sam
            .map { sample_id, sam -> sam }   // drop the id, keep only the path 
            .collect()                        // ONE emission: [s1.sam.bz2, s2.sam.bz2, ...]

        // Run strainphlan with extracted markers
        SAMPLE2MARKERS(ch_bowtie2sam_files, EXTRACT_MARKERS.out.extracted_markers, ch_metaphlan_db)
        STRAINPHLAN(SAMPLE2MARKERS.out.jsons, EXTRACT_MARKERS.out.extracted_markers, params.strainphlan_sgb, ch_metaphlan_db)
    }
    
    // MetaStandard - format standardization
    def metaphlan_files = METAPHLAN4.out.profile.collect()
    METAPHLAN_METASTANDARD(metaphlan_files)

     if (params.kraken_profiling) {
        def bracken_files = BRACKEN.out.bracken_profile.collect()
        BRACKEN_METASTANDARD(bracken_files)
    }

    // Collect all QC files for MultiQC
    def ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_RAW.out.zip.collect().ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(FASTP.out.json.collect().ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_CLEAN.out.zip.collect().ifEmpty([]))
    
    // MultiQC aggregation
    MULTIQC(ch_multiqc_files.collect())

    // Plot all metastandard outputs (one job per TSV)
    // TO DO !!! INTERACTIVE
    def ch_metastandard_plots = Channel.empty()
    ch_metastandard_plots = ch_metastandard_plots.mix(METAPHLAN_METASTANDARD.out)
    METASTANDARD_PLOTS(ch_metastandard_plots)
}

/*
========================================================================================
    WORKFLOW COMPLETION
========================================================================================
*/

workflow.onComplete {
    log.info """\
        Pipeline completed at: ${workflow.complete}
        Execution status: ${workflow.success ? 'SUCCESS' : 'FAILED'}
        Duration: ${workflow.duration}
        Output directory: ${params.outdir}
        """
        .stripIndent()
}