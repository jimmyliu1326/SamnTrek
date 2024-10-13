// import modules
include { DB_FETCH               } from '../../../modules/local/db/fetch/main.nf'
include { DB_UNTAR               } from '../../../modules/local/db/untar/main.nf'

workflow DOWNLOAD_DB {

    take:
    dl_path // path(params.download_path)
    main:
    // initialize channels
    ch_versions = Channel.empty()
    // Fetch the latest version of DB
    DB_loc = 'https://object-arbutus.cloud.computecanada.ca/cidgohshare/eagle/jimmyliu/SamnTrek/'
    DB_version = file(DB_loc + 'LATEST', checkIfExists: true)
    ch_db = Channel.of([ [id:'db'], DB_version ])
    ch_dl_path = Channel.fromPath(dl_path, checkIfExists: true, type: 'dir')
    // Fetch DB tar file
    DB_FETCH(ch_db)
    ch_versions = ch_versions.mix(DB_FETCH.out.versions)
    // Untar DB to dl_path
    DB_UNTAR(ch_db.join(DB_FETCH.out.db).combine(ch_dl_path))
    ch_versions = ch_versions.mix(DB_UNTAR.out.versions)

    emit:
    db = DB_UNTAR.out.db
    versions = ch_versions

}