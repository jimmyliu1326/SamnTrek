process NCBIDATASETS_DOWNLOAD {
    tag "$meta.id"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/ncbi-datasets-cli_unzip:5c55fa462c8d75ac':
        'community.wave.seqera.io/library/ncbi-datasets-cli_unzip:ec913708564558ae' }"

    input:
    tuple val(meta), path(accessions)

    output:
    tuple val(meta), path("*.zip")                            , emit: zip
    tuple val(meta), path("$meta.id/ncbi_dataset")            , emit: data_dir
    path "versions.yml"                                       , emit: versions
    
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    datasets download  \\
        ${args} \\
        --filename ${prefix}_ncbi_dataset.zip \\
        --inputfile ${accessions}
        
    # extract zip file
    unzip ${prefix}_ncbi_dataset.zip -d ${meta.id}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ncbi-datasets-cli: \$(echo \$(datasets --version 2>&1) | sed 's/datasets version: //' )
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_ncbi_dataset.zip

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ncbi-datasets-cli: \$(echo \$(datasets --version 2>&1) | sed 's/datasets version: //' )
    END_VERSIONS
    """
}
