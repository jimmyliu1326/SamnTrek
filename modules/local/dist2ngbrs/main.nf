process DIST2NGBRS {
    tag "$meta.id"
    label 'process_low'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/jimmyliu1326/samntrek-dist2ngbrs:latest':
        'jimmyliu1326/samntrek-dist2ngbrs:latest' }"

    input:
    tuple val(meta), path(tsv)

    output:
    tuple val(meta), path("*.txt")                               , emit: hits
    tuple val(meta), path("core_accessory_plot.png")             , emit: core_accessory_png, optional: true
    tuple val(meta), path("hdbscan_cluster_score.png")           , emit: cluster_score_png, optional: true
    tuple val(meta), path("*.tsv")                               , emit: stats
    path "versions.yml"                                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    dist2ngbrs.R \
        -o . \
        -t ${task.cpus} \
        ${args} \
        ${tsv}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R: \$(R --version | head -n1 | sed 's/R version //g' | sed 's/ .*//g')
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
    touch ${prefix}.tsv
    mkdir -p logs
    touch logs/samnsorter.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samnsorter: \$(SamnSorter.R --version |& sed '1!d ; s/samnsorter v//')
    END_VERSIONS
    """
}
