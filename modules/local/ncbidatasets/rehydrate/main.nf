process NCBIDATASETS_REHYDRATE {
    tag "$meta.id"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/ncbi-datasets-cli_unzip:5c55fa462c8d75ac':
        'community.wave.seqera.io/library/ncbi-datasets-cli_zip:9c97ac7af5591f3e' }"

    input:
    tuple val(meta), path(data_files)

    output:
    tuple val(meta), path("**/*.fna")                  , emit: fasta
    path "versions.yml"                                , emit: versions
    
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # rehydrate the dataset
    datasets rehydrate \\
        ${args} \\
        --directory .

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
