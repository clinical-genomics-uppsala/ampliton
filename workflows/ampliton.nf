/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { MULTIQC } from '../modules/nf-core/multiqc/main'
include { PORECHOP_ABI } from '../modules/nf-core/porechop/abi/main'
include { NANOQ } from '../modules/nf-core/nanoq/main'
include { CUTADAPT } from '../modules/nf-core/cutadapt/main'
include { CAT_FASTQ } from '../modules/nf-core/cat/fastq/main'
include { KROCUS } from '../modules/local/krocus/main'
include { SAVONT_ASV } from '../modules/local/savont/asv/main'
include { paramsSummaryMap } from 'plugin/nf-schema'
include { paramsSummaryMultiqc } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_ampliton_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow AMPLITON {
    take:
    ch_samplesheet // channel: samplesheet read in from --input
    ch_targets // channel: targets sheet read in from --targets
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:

    def ch_versions = channel.empty()
    def ch_multiqc_files = channel.empty()

    // Handle input fastq files
    ch_samplesheet
        .map { meta, reads ->
            [meta, reads]
        }
        .set { ch_reads }

    // Add targets metadata to channel with sample sheet information
    ch_reads_with_targets = ch_reads
        .combine(ch_targets.collect().map { targets_list -> [targets: targets_list] })
        .map { meta, reads, target_meta ->
            def new_meta = meta + target_meta
            return [new_meta, reads]
        }


    //
    // MODULE: Porechop_ABI
    //
    PORECHOP_ABI(ch_reads_with_targets, [])
    ch_chopped_reads = PORECHOP_ABI.out.reads
    ch_multiqc_files = ch_multiqc_files.mix(PORECHOP_ABI.out.log.map { meta, log -> log })

    //
    // MODULE: nanoq
    //
    NANOQ(ch_chopped_reads, 'fastq.gz')
    ch_filtered_reads = NANOQ.out.reads
    ch_multiqc_files = ch_multiqc_files.mix(NANOQ.out.stats.map { meta, stats -> stats })

    //
    // MODULE: cutadapt 
    //
    CUTADAPT(ch_filtered_reads)
    // Match metadata to each cutadapt fastq output file
    ch_trimmed_matched_reads = CUTADAPT.out.reads
        .transpose()
        .map { meta, reads ->

            def target_name = reads.name.replace("${meta.id}_", '').replace('.trim.fastq.gz', '')
            def target_info = meta.targets.find { it.target == target_name }

            def base_meta = meta.subMap(['id', 'single_end'])
            def target_meta = target_info.subMap(['target', 'analysis', 'FW_primer', 'RV_primer', 'min_length', 'max_length'])
            def new_meta = base_meta + target_meta

            return [new_meta, reads]
        }

    ch_multiqc_files = ch_multiqc_files.mix(CUTADAPT.out.log.map { meta, stats -> stats })

    //
    // MLST: krocus
    //
    ch_mlst = ch_trimmed_matched_reads.filter { meta, reads -> meta.analysis == 'MLST' }
    // Create list with MLST fastq files
    ch_mlst_combined = ch_mlst
        .map { meta, reads ->
            def new_meta = meta.subMap(['id', 'single_end'])
            return [new_meta, reads]
        }
        .groupTuple()

    CAT_FASTQ(ch_mlst_combined)
    ch_krocus_input = CAT_FASTQ.out.reads

    ch_krocus_scheme = ch_mlst_combined
        .first()
        .map { file(params.krocus_scheme, checkIfExists: true) }
    KROCUS(ch_krocus_input, ch_krocus_scheme)

    //
    // ASV: savont
    //
    ch_asv = ch_trimmed_matched_reads.filter { meta, reads -> meta.analysis == 'ASV' || meta.analysis == 'SPA' }
    SAVONT_ASV(ch_asv)

    ch_counts = ch_trimmed_matched_reads.filter { meta, reads -> meta.analysis == 'COUNT' }

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [process[process.lastIndexOf(':') + 1..-1], "  ${tool}: ${version}"]
        }
        .groupTuple(by: 0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'ampliton_software_' + 'mqc_' + 'versions.yml',
            sort: true,
            newLine: true,
        )

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))
    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'ampliton'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )

    emit:
    multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
    versions = ch_versions // channel: [ path(versions.yml) ]
}
