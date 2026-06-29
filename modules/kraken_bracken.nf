process KRAKEN2 {
    publishDir "${params.outdir}/06_kraken2", mode: 'copy'
    
    input:
    tuple val(sample_id), path(read1), path(read2)
    path(db)

    output:
    path "${sample_id}_kraken.txt", emit: kraken_profile
    tuple val(sample_id), path("${sample_id}.kreport"), emit: kraken_report

    script:
    """
    k2 classify \\
    --db ${db} \\
    --output ${sample_id}_kraken.txt \\
    --paired --use-names \\
    ${read1} ${read2} \\
    --report ${sample_id}.kreport

    """
}


process BRACKEN {
    publishDir "${params.outdir}/07_bracken", mode: 'copy'
    
    input:
    tuple( val(sample_id), path(kraken_report))
    path(db)

    output:
    path "${sample_id}.bracken", emit: bracken_profile

    script:
    """
    est_abundance.py \\
    -i ${kraken_report} \\
    -o ${sample_id}.bracken \\
    --out-report ${sample_id}.kraken2.report_bracken.txt \\
    -k ${db}/database150mers.kmer_distrib \\
    -l S -t 10

    """
}