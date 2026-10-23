process SAVONT_ASV {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/savont:0.8.0--hec9b1f2_0'
        : 'quay.io/biocontainers/savont:0.8.0--hec9b1f2_0'}"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*final_asvs.fasta.gz"), emit: fasta
    tuple val(meta), path("*feature-table.tsv"), emit: feature_table
    tuple val(meta), path("*final_assignments.tsv"), emit: final_assignments
    tuple val(meta), path("*.log"), emit: log
    tuple val("${task.process}"), val('savont'), eval("savont --version"), topic: versions, emit: versions_savont

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    savont asv\\
        ${reads} \\
        -t ${task.cpus} \\
        -o savont_out \\
        ${args}

    if [ -f savont_out/final_asvs.fasta ]; then
        mv savont_out/final_asvs.fasta ${prefix}_final_asvs.fasta
        gzip -n ${prefix}_final_asvs.fasta
    fi
    if [ -f savont_out/feature-table.tsv ]; then
        mv savont_out/feature-table.tsv ${prefix}_feature-table.tsv
    fi
    if [ -f savont_out/final_assignments.tsv ]; then
        mv savont_out/final_assignments.tsv ${prefix}_final_assignments.tsv
    fi
    cat savont_out/*.log > ${prefix}_savont.log
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo ${args}
    
    echo "" | gzip > ${prefix}_final_asvs.fasta.gz
    touch ${prefix}_feature-table.tsv
    touch ${prefix}_final_assignments.tsv
    touch ${prefix}_savont.log
    """
}
