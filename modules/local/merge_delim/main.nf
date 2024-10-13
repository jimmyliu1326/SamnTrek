process MERGE_DELIM {
    tag "$meta.id"
    label 'process_single'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/curl_tar:60e3944a1138432b':
        'community.wave.seqera.io/library/curl_tar:7cc34f46f9969d3a' }"

    input:
    tuple val(meta), path(delim_files, stageAs: "?.txt" )       
    val(ext)

    output:
    path "*.${ext}"                                                 , emit: combined
    path "versions.yml"                                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    awk 'NR == 1 || FNR > 1' \\
        *.txt \\
        > ${prefix}.${ext}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version | head -n1 | sed 's/.* Awk //g' | sed 's/, .*//g')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version | head -n1 | sed 's/.* Awk //g' | sed 's/, .*//g')
    END_VERSIONS
    """
}
