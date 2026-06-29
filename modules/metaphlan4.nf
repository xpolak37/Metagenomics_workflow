process METAPHLAN4 {
    tag "$sample_id"
    publishDir "${params.outdir}/04_metaphlan4", mode: 'copy', pattern: "*.txt"
    
    input:
    tuple val(sample_id), path(read1), path(read2)
    path(db)
    
    output:
    path "${sample_id}_metaphlan4_profile.txt", emit: profile
    path "${sample_id}.mapout.bz2", emit: mapout, optional: true
    path "${sample_id}.bowtie2.bz2", emit: bowtie2out, optional: true
    tuple val(sample_id), path("${sample_id}.sam.bz2"), emit: bowtie2sam, optional: true

    script:
    // Database options
    def db_option = "--db_dir ${db}"
    
    // Taxonomic filtering
    def ignore_eukaryotes = params.metaphlan_ignore_eukaryotes ? "--ignore_eukaryotes" : ""
    def ignore_bacteria = params.metaphlan_ignore_bacteria ? "--ignore_bacteria" : ""
    def ignore_archaea = params.metaphlan_ignore_archaea ? "--ignore_archaea" : ""
    
    // Markers
    def ignore_markers = params.metaphlan_ignore_markers ? "--ignore_markers ${params.metaphlan_ignore_markers}" : ""
    
    // Min alignment length (only add if not null)
    def min_alignment_len = params.metaphlan_min_alignment_len ? "--min_alignment_len ${params.metaphlan_min_alignment_len}" : ""
    
    // Other options
    def offline = params.metaphlan_offline ? "--offline" : ""
    def verbose = params.metaphlan_verbose ? "--verbose" : ""
    
    // Check if the user needs strain-level profiling and add the appropriate argument
    def metaphlan_extra_args = params.metaphlan_extra_args ?: ""
    if (params.metaphlan_strain) {
        metaphlan_extra_args += " -s ${sample_id}.sam.bz2 --mapout ${sample_id}.bowtie2.bz2"
    }

    """
    metaphlan \\
        ${read1},${read2} \\
        --input_type fastq \\
        --nproc ${task.cpus} \\
        ${db_option} \\
        --index ${params.metaphlan_index} \\
        --mapout ${sample_id}.mapout.bz2 \\
        --bt2_ps ${params.metaphlan_bt2_ps} \\
        --tax_lev ${params.metaphlan_tax_level} \\
        ${min_alignment_len} \\
        --stat_q ${params.metaphlan_stat_q} \\
        --perc_nonzero ${params.metaphlan_perc_nonzero} \\
        --stat ${params.metaphlan_stat} \\
        -t ${params.metaphlan_analysis_type} \\
        --read_min_len ${params.metaphlan_read_min_len} \\
        --min_mapq_val ${params.metaphlan_min_mapq_val} \\
        ${ignore_eukaryotes} \\
        ${ignore_bacteria} \\
        ${ignore_archaea} \\
        ${ignore_markers} \\
        ${offline} \\
        ${verbose} \\
        --sample_id ${sample_id} \\
        ${metaphlan_extra_args} \\
        -o ${sample_id}_metaphlan4_profile.txt 
    """
}

process EXTRACT_MARKERS {
    publishDir "${params.outdir}/05_strainphlan", mode: 'copy'
    
    input:
    val(sgb)
    path(db)

    output:
    path "t__${sgb}.fna", emit: extracted_markers

    
    script:
    // Database options
    def db_option = "-d ${db}/mpa_vJan25_CHOCOPhlAnSGB_202503.pkl"
    """
    
    extract_markers.py -c t__${sgb} ${db_option} -o .
    """
}


process SAMPLE2MARKERS {
    
    input:
    path sams
    path(extracted_markers)
    path(db)

    output:
    path "*.json.bz2", emit: jsons

    script:
    // Database options
    def db_option = "-d ${db}/mpa_vJan25_CHOCOPhlAnSGB_202503.pkl"
    """
    sample2markers.py -i ${sams} -o . -n ${task.cpus} ${db_option}

    """
}

process STRAINPHLAN {
    publishDir "${params.outdir}/05_strainphlan", mode: 'copy'
    
    input:
    path jsons
    path(extracted_markers)
    val(sgb)
    path(db)

    output:
    path "*", emit: profile

    script:
    // Database options
    def db_option = "-d ${db}/mpa_vJan25_CHOCOPhlAnSGB_202503.pkl"
    """
    strainphlan -s ${jsons} -m ${extracted_markers} -o . -n ${task.cpus} -c t__${sgb} --mutation_rates ${db_option} \\
    --sample_with_n_markers ${params.strainphlan_sample_with_n_markers} \\
    --sample_with_n_markers_perc ${params.strainphlan_sample_with_n_markers_perc} 

    """
}