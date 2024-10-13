// import modules
include { SAMNSORTER                 } from '../../../modules/local/samnsorter/main.nf'
include { MERGE_DELIM                } from '../../../modules/local/merge_delim/main.nf'

workflow SORT {

    take: 
    asm // channel: [meta, path(fasta)]

    main:
    // initialize channels
    ch_versions = Channel.empty()

    SAMNSORTER(asm)
    ch_versions = ch_versions.mix(SAMNSORTER.out.versions)

    SAMNSORTER.out.results
      .map{ [ [id: 'sort_results'], it[1] ] }
      .groupTuple()
      .set { ch_combined_sort }

    MERGE_DELIM(
      ch_combined_sort,
      SAMNSORTER.out.results.first().map{ it[1].getExtension() }
    )
    ch_versions = ch_versions.mix(MERGE_DELIM.out.versions)

    emit:
    results          = SAMNSORTER.out.results
    distance         = SAMNSORTER.out.distance
    cluster          = SAMNSORTER.out.cluster
    combined_results = MERGE_DELIM.out.combined
    versions         = ch_versions

}