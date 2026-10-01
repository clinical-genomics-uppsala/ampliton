process KROCUS {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/krocus:1.0.3--pyhdfd78af_0'
        : 'quay.io/biocontainers/krocus:1.0.3--pyhdfd78af_0'}"

    input:
    tuple val(meta), path(reads)
    path allele_directory

    output:
    tuple val(meta), path("*.tsv"), emit: tsv
    tuple val("${task.process}"), val('krocus'), eval("krocus --version"), topic: versions, emit: versions_krocus

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    krocus \\
        ${args} \\
        -o ${prefix}.tsv \\
        ${allele_directory} \\
        ${reads}
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    echo ${allele_directory}
    echo ${args}
    
    touch ${prefix}.tsv
    """
}
