include { MASHTREE                                      } from '../../../modules/nf-core/mashtree/main.nf'
include { CHEWBBACA_ALLELECALL                          } from '../../../modules/local/chewbbaca/allelecall/main.nf'
include { CGMLST_DISTS                                  } from '../../../modules/local/cgmlst-dists/main.nf'
include { MERGE_DELIM as MERGE_DELIM_H                  } from '../../../modules/local/merge_delim/main.nf'
include { MERGE_DELIM                                   } from '../../../modules/local/merge_delim/main.nf'
include { RAPIDNJ                                       } from '../../../modules/local/rapidnj/main.nf'

workflow CONTEXTUALIZE {
    take: fasta // channel: [meta, path(fasta)]

    main:
    // initialize channels
    ch_versions = Channel.empty()
    ch_tree     = Channel.empty()
    ch_alleles  = Channel.empty()
    ch_matrix   = Channel.empty()

    if ( params.tree_method == 'mash' ) {
        ch_mashtree = fasta.map{ it[1] }.collect().map { [ [id: 'mash' ], it ] }
        MASHTREE(ch_mashtree)
        ch_versions = ch_versions.mix(MASHTREE.out.versions)
        ch_tree = MASHTREE.out.tree
        ch_matrix = MASHTREE.out.matrix
    } else if ( params.tree_method == 'cgmlst' ) {
        // cgmlst allele calling
        CHEWBBACA_ALLELECALL(fasta)
        ch_versions = ch_versions.mix(CHEWBBACA_ALLELECALL.out.versions)
        ch_alleles = CHEWBBACA_ALLELECALL.out.alleles
        ch_alleles_h = CHEWBBACA_ALLELECALL.out.alleles_hashed
        // ch_alleles.view()
        // merge allele profiles
        MERGE_DELIM(ch_alleles.map { [ [id: 'SamnTrek_cgMLST_alleles'], it[1] ] }.groupTuple(), "tsv")
        MERGE_DELIM_H(ch_alleles_h.map { [ [id: 'SamnTrek_cgMLST_alleles_hashed'], it[1] ] }.groupTuple(), "tsv")
        ch_merged_alleles = MERGE_DELIM.out.combined
        ch_merged_alleles_h = MERGE_DELIM_H.out.combined
        // calculate hamming distance
        ch_CGMLST_DISTS = ch_merged_alleles_h.map { [ [id: 'SamnTrek_cgMLST_distance_matrix'], it ] }
        CGMLST_DISTS(ch_CGMLST_DISTS)
        ch_versions = ch_versions.mix(CGMLST_DISTS.out.versions)
        // build tree
        RAPIDNJ(CGMLST_DISTS.out.matrix_phylip)
        ch_tree = RAPIDNJ.out.phylogeny
        ch_versions = ch_versions.mix(RAPIDNJ.out.versions)
    }

    emit:
    versions = ch_versions
    tree     = ch_tree
    alleles  = ch_alleles

}