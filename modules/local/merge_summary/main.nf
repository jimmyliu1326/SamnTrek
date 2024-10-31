process MERGE_SUMMARY {
    tag "$meta.id"
    label 'process_low'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/jimmyliu1326/samntrek-dist2ngbrs:latest':
        'docker.io/jimmyliu1326/samntrek-dist2ngbrs:latest' }"

    input:
    tuple val(meta), path(results)

    output:
    tuple val(meta), path("*.tsv")             , emit: summary
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    merge_summary.R \\
        -o ${prefix}.tsv \\
        ${results}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R: \$(R --version | head -n1 | sed 's/R version //g' | sed 's/ .*//g')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R: \$(R --version | head -n1 | sed 's/R version //g' | sed 's/ .*//g')
    END_VERSIONS
    """
}
