// TODO nf-core: If in doubt look at other nf-core/modules to see how we are doing things! :)
//               https://github.com/nf-core/modules/tree/master/modules/nf-core/
//               You can also ask for help via your pull request or on the #modules channel on the nf-core Slack workspace:
//               https://nf-co.re/join
// TODO nf-core: A module file SHOULD only define input and output files as command-line parameters.
//               All other parameters MUST be provided using the "task.ext" directive, see here:
//               https://www.nextflow.io/docs/latest/process.html#ext
//               where "task.ext" is a string.
//               Any parameters that need to be evaluated in the context of a particular sample
//               e.g. single-end/paired-end data MUST also be defined and evaluated appropriately.
// TODO nf-core: Software that can be piped together SHOULD be added to separate module files
//               unless there is a run-time, storage advantage in implementing in this way
//               e.g. it's ok to have a single module for bwa to output BAM instead of SAM:
//                 bwa mem | samtools view -B -T ref.fasta
// TODO nf-core: Optional inputs are not currently supported by Nextflow. However, using an empty
//               list (`[]`) instead of a file can be used to work around this issue.

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
    tuple val(meta), path("*final_clusters.tsv"), emit: final_clusters
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
    if [ -f savont_out/final_clusters.tsv ]; then
        mv savont_out/final_clusters.tsv ${prefix}_final_clusters.tsv
    fi
    cat savont_out/*.log ${prefix}_savont.log
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo ${args}
    
    touch ${prefix}_final_asvs.fasta.gz
    touch ${prefix}_feature-table.tsv
    touch ${prefix}_final_clusters.tsv
    touch ${prefix}_savont.log
    """
}
