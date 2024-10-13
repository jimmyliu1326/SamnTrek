include { COMBINE_HITS                     } from '../../../modules/local/combine/main.nf'
include { NCBIDATASETS_DOWNLOAD            } from '../../../modules/local/ncbidatasets/download/main.nf'
include { NCBIDATASETS_REHYDRATE           } from '../../../modules/local/ncbidatasets/rehydrate/main.nf'

workflow FETCH_HITS {
    take: accessions // channel: [meta, path(accession)]

    main:
    // initialize channels
    ch_versions = Channel.empty()

    COMBINE_HITS(accessions.map{it[1]}.collect())
    ch_versions = ch_versions.mix(COMBINE_HITS.out.versions)

    COMBINE_HITS.out.uniq_hits
      .map { file(it) }
      .splitText(by: params.dl_chunk_size, file: true)
      .map { file -> 
        tuple([id: file.getBaseName()], file)
      }
      .set { ch_dl_chunks}
    
    NCBIDATASETS_DOWNLOAD(ch_dl_chunks)
    ch_versions = ch_versions.mix(NCBIDATASETS_DOWNLOAD.out.versions)

    NCBIDATASETS_REHYDRATE(NCBIDATASETS_DOWNLOAD.out.data_dir)
    ch_versions = ch_versions.mix(NCBIDATASETS_REHYDRATE.out.versions)
    
    // NCBIDATASETS_REHYDRATE.out.fasta.view()

    emit:
    versions = ch_versions
    fasta    = NCBIDATASETS_REHYDRATE.out.fasta
}