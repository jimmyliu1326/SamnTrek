process COMBINE_HITS {
    tag "$task.process"
    label 'process_single'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/curl_tar:60e3944a1138432b':
        'community.wave.seqera.io/library/curl_tar:7cc34f46f9969d3a' }"

    input:
    path(hits)                         , stageAs: 'SamnTrek_hits?.txt'

    output:
    path "all_hits.txt"                , emit: all_hits
    path "uniq_hits.txt"               , emit: uniq_hits
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    // def prefix = task.ext.prefix ?: "${meta.id}"
    """
    cat \\
        ./*.txt \\
        ${args} \\
        > all_hits.txt
    
    cat all_hits.txt | \\
        sort -u \\
        ${args} \\
        > uniq_hits.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cat: \$(cat --version | head -n1 | sed 's/.* //g')
        sort: \$(sort --version | head -n1 | sed 's/.* //g')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    // def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch all_hits.txt
    touch uniq_hits.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cat: \$(cat --version | head -n1 | sed 's/.* //g')
        sort: \$(sort --version | head -n1 | sed 's/.* //g')
    END_VERSIONS
    """
}
