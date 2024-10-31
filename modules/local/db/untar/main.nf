process DB_UNTAR {
    tag "$meta.id"
    label 'process_low'
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'oras://community.wave.seqera.io/library/curl_tar:60e3944a1138432b':
    //     'community.wave.seqera.io/library/curl_tar:7cc34f46f9969d3a' }"

    input:
    tuple val(meta), path(version), path(db_file), path(db_path)

    output:
    tuple val(meta), path("*/v*", type: 'dir')          , emit: db
    path "versions.yml"                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    version=\$(cat ${version})
    mkdir -p ${prefix}
    tar ${args} -xzvmf ${db_file} -C ${prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tar: \$(tar --version | head -n1 | sed 's/tar //g' | sed 's/.* //g')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // TODO nf-core: A stub section should mimic the execution of the original module as best as possible
    //               Have a look at the following examples:
    //               Simple example: https://github.com/nf-core/modules/blob/818474a292b4860ae8ff88e149fbcda68814114d/modules/nf-core/bcftools/annotate/main.nf#L47-L63
    //               Complex example: https://github.com/nf-core/modules/blob/818474a292b4860ae8ff88e149fbcda68814114d/modules/nf-core/bedtools/split/main.nf#L38-L54
    """
    mkdir -p ${prefix}/v1/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tar: \$(tar --version | head -n1 | sed 's/tar //g' | sed 's/.* //g')
    END_VERSIONS
    """
}
