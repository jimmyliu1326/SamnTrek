// import modules
include { PPSKETCHLIB_DIST                   } from '../../../modules/local/ppsketchlib/dist/main.nf'
include { PPSKETCHLIB_SKETCH                 } from '../../../modules/local/ppsketchlib/sketch/main.nf'
include { PARSE_DIST                         } from '../../../modules/local/parse_dist/main.nf'
include { DIST2NGBRS                         } from '../../../modules/local/dist2ngbrs/main.nf'
include { MERGE_DELIM                        } from '../../../modules/local/merge_delim/main.nf'
include { RENAME_FASTA                       } from '../../../modules/local/rename_fasta/main.nf'

workflow SEARCH {

    take:
    asm // channel: [meta, path(fasta)]
    cluster // channel: [meta, val(cluster_id)]

    main:
    // initialize channels
    ch_versions = Channel.empty()
    ch_db = file(params.db, checkIfExists: true)

    RENAME_FASTA(asm)

    PPSKETCHLIB_SKETCH(RENAME_FASTA.out.fasta)
    ch_versions = ch_versions.mix(PPSKETCHLIB_SKETCH.out.versions)

    PPSKETCHLIB_SKETCH.out.sketch
      .join(cluster)
      .set { ch_search }

    PPSKETCHLIB_DIST(ch_search, ch_db)
    ch_versions = ch_versions.mix(PPSKETCHLIB_DIST.out.versions)

    PARSE_DIST(PPSKETCHLIB_DIST.out.npy.join(PPSKETCHLIB_DIST.out.pkl))
    ch_versions = ch_versions.mix(PARSE_DIST.out.versions)

    DIST2NGBRS(PARSE_DIST.out.distance)
    ch_versions = ch_versions.mix(DIST2NGBRS.out.versions)

    DIST2NGBRS.out.stats
      .map{ [ [id: 'search_results'], it[1] ] }
      .groupTuple()
      .set { ch_combined_stats }

    MERGE_DELIM(
      ch_combined_stats,
      DIST2NGBRS.out.stats.first().map{ it[1].getExtension() }
    )
    ch_versions = ch_versions.mix(MERGE_DELIM.out.versions)

    emit:
    versions       = ch_versions
    hits           = DIST2NGBRS.out.hits
    stats          = DIST2NGBRS.out.stats
    combined_stats = MERGE_DELIM.out.combined
}
