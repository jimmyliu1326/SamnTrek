// import native java libraries
import java.nio.file.Paths

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_samntrek_pipeline'
include { SORT                   } from '../subworkflows/local/sort/main'
include { SEARCH                 } from '../subworkflows/local/search/main'
include { DOWNLOAD_DB            } from '../subworkflows/local/download_db/main'
include { FETCH_HITS             } from '../subworkflows/local/fetch_hits/main.nf'
include { CONTEXTUALIZE          } from '../subworkflows/local/contextualize/main.nf'
include { MERGE_SUMMARY          } from '../modules/local/merge_summary/main.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SAMNTREK {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()
    
    // parse wf parameter
    wf = params.wf.tokenize(',')

    // download db
    if ( wf.any { ['download_db'].contains(it) } ) {
        DOWNLOAD_DB(params.download_path)
        ch_versions = ch_versions.mix(DOWNLOAD_DB.out.versions)
    }

    // Sort genomes into stable clusters
    if ( wf.any { ['sort', 'all'].contains(it) } ) {
        SORT(ch_samplesheet)
        ch_versions = ch_versions.mix(SORT.out.versions)
    }
    // Conduct fast similarity search
    if ( wf.any { ['search', 'all'].contains(it) } ) {
        // resume from persistent results directory
        if ( !wf.any { ['sort', 'all'].contains(it) } ) {
            log.warn "Resuming from previous results directory: ${params.results_dir}"
            log.warn "Previous results may be overwritten if --outdir is the same as --results_dir"
            // check if previous sort results are available
            sort_results = "${params.results_dir}/SORT_RESULTS/"
            sort_results_dir = file(sort_results)
            if ( !sort_results_dir.exists() ) {
                log.error "SORT results are not found in --results_dir ${params.results_dir}"
                exit 1
            }
            // construct search input channel
            // from SORT results
            ch_samplesheet
                .map { meta, genome ->
                    res_file_path = file(Paths.get(sort_results, meta.id)).list().findAll { it.equals('samnsorter_res.tsv') }
                    if ( res_file_path.size() == 0 ) {
                        log.error "Missing SORT results for ${meta.id}. Please re-run the pipeline from the 'sort' step."
                        exit 1
                    }
                    res_file = file(Paths.get(sort_results, meta.id, res_file_path[0]))
                    // read file
                    res = res_file.readLines()
                    // parse cluster ID
                    cluster_id = res[1].split('\t')[4]
                    // return tuple
                    return [ meta, cluster_id ]
                }
                .set { ch_CLUSTER }
            // construct combined sort results channel
            // from SORT results
            sort_combined_path = file(Paths.get(params.results_dir, "SUMMARY")).list().findAll { it.equals('sort_results.tsv') }
            if ( sort_combined_path.size() == 0 ) {
                        log.error "Missing combined SORT results. Please re-run the pipeline from the 'sort' step."
                        exit 1
            }
            ch_SORT_COMBINED = Channel.of(file(Paths.get(params.results_dir, "SUMMARY", sort_combined_path[0])))
        } else {
            ch_CLUSTER = SORT.out.cluster
            ch_SORT_COMBINED = SORT.out.combined_results
        }
        // run search
        SEARCH(ch_samplesheet, ch_CLUSTER.filter { it[1] != 'NOVEL' })
        ch_versions = ch_versions.mix(SEARCH.out.versions)
        // Build summary file
        ch_SORT_COMBINED
            .map { [ [id: 'SamnTrek_summary'], it ] }
            .concat(SEARCH.out.combined_stats.map { [ [id: 'SamnTrek_summary'], it ] })
            .groupTuple()
            .set { ch_combined_results }
        MERGE_SUMMARY(ch_combined_results)
        ch_versions = ch_versions.mix(MERGE_SUMMARY.out.versions)
    }
        
    // Download FASTA files of search hits
    if ( wf.any { ['fetch_hits', 'all'].contains(it) } ) {
        if ( !wf.any { ['search', 'all'].contains(it) } ) {
            log.warn "Resuming from previous results directory: ${params.results_dir}"
            log.warn "Previous results may be overwritten if --outdir is the same as --results_dir"
            // check if previous sort results are available
            search_results = "${params.results_dir}/SEARCH_RESULTS/"
            search_results_dir = file(search_results)
            if ( !search_results_dir.exists() ) {
                log.error "SEARCH results are not found in --results_dir ${params.results_dir}"
                exit 1
            }
            // construct FETCH_HITS input channel
            // from previous results directory
            ch_samplesheet
                .map { meta, genome ->
                    res_file_path = file(Paths.get(search_results, meta.id)).list().findAll { it.endsWith('.hits') }
                    if ( res_file_path.size() == 0 ) {
                        log.error "Missing SEARCH results for ${meta.id}. Please re-run the pipeline from the 'search' step."
                        exit 1
                    }
                    res_file = file(Paths.get(search_results, meta.id, res_file_path[0]))
                    // return tuple
                    return [ meta, res_file ]
                }
                .set { ch_HITS }
        } else {
            ch_HITS = SEARCH.out.hits
        }
        // fetch PD genomes from identified hits
        FETCH_HITS(ch_HITS)
        ch_versions = ch_versions.mix(FETCH_HITS.out.versions)
    }

    // Contextualization - Integration of local and global data
    if ( wf.any { ['contextualize', 'all'].contains(it) } ) {
        if ( !wf.any { ['fetch_hits', 'all'].contains(it) } ) {
            log.warn "Resuming from previous results directory: ${params.results_dir}"
            log.warn "Previous results may be overwritten if --outdir is the same as --results_dir"
            // check if previous sort results are available
            search_results = "${params.results_dir}/SEARCH_RESULTS/"
            search_results_dir = new File(search_results)
            def downloaded_genomes = "${params.results_dir}/PD_GENOMES/"
            def downloaded_genomes_dir = new File(downloaded_genomes)
            if ( !search_results_dir.exists() ) {
                log.error "SEARCH results are not found in --results_dir ${params.results_dir}"
                exit 1
            }
            if ( !downloaded_genomes_dir.exists() ) {
                log.error "NCBI PATHOGEN GENOMES are not found in --results_dir ${params.results_dir}"
                exit 1
            }
            // get paths to all FASTA files under downloaded_genomes_dir
            def downloaded_FASTA = downloaded_genomes_dir.listFiles()
            // construct CONTEXTUALIZATION input channel
            // from previous results directory
            ch_samplesheet
                .map { meta, genome ->
                    res_file_path = file(Paths.get(search_results, meta.id)).list().findAll { it.endsWith('.hits') }
                    if ( res_file_path.size() == 0) {
                        log.error "Missing SEARCH results for ${meta.id}. Please re-run the pipeline from the 'search' step."
                        exit 1
                    }
                    res_file = file(Paths.get(search_results, meta.id, res_file_path[0]))
                    // read file
                    res = res_file.readLines()
                    // validate whether the genomes in the search results have been dled
                    hits_path = [] // keep track of paths to downloaded genomes
                    res.each { id ->
                        genome = downloaded_FASTA.findAll { it.name =~ id }
                        if ( genome.size() == 0 ) {
                            log.error "Missing genome ${id} in ${downloaded_genomes}. Please re-run the pipeline from the 'fetch_hits' step."
                            exit 1
                        }
                        hits_path.add(file(genome[0]))
                    }
                    // return tuple
                    return hits_path
                }
                .flatten()
                .map { path -> 
                       id = path.getBaseName().replaceAll('.fna|.fa|.fasta', '')
                       [ [id:id], path ]   
                }
                .distinct()
                .set { ch_global }
            
            ch_local  = ch_samplesheet
            ch_fasta  = ch_global.concat(ch_local)
            // ch_fasta.view()
        } else {
            // collate all fasta files
            ch_global = FETCH_HITS.out.fasta
                        .transpose()
                        .map { meta, fasta ->
                            id = fasta.getBaseName().replaceAll('.fna|.fa|.fasta', '')
                            [ [id:id], fasta ]
                        }
            ch_local  = ch_samplesheet
            ch_fasta  = ch_global.concat(ch_local)
            // ch_fasta.view()
        }
        // construct phylogeny
        CONTEXTUALIZE(ch_fasta)
        ch_versions = ch_versions.mix(CONTEXTUALIZE.out.versions)
    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/PIPELINE_INFO",
            name: 'nf_core_pipeline_software_mqc_versions.yml',
            sort: true,
            newLine: true
        )
        .set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        []
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))

    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
