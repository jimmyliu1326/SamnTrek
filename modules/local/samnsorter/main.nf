process SAMNSORTER {
    tag "$meta.id"
    label 'process_low'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/jimmyliu1326/samnsorter:v0.4.0':
        'jimmyliu1326/samnsorter:v0.4.0' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("samnsorter_res.tsv"), emit: results
    tuple val(meta), path("dist_matrix.tsv")   , emit: distance
    tuple val(meta), path("logs/*.log")        , emit: log
    tuple val(meta), env(CLUSTER)              , emit: cluster
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    SamnSorter.R \\
        ${args} \\
        -t ${task.cpus} \\
        --outdir . \\
        ${fasta}

    # parse final cluster prediction
    CLUSTER=\$(tail -n +2 samnsorter_res.tsv | cut -f4)

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samnsorter: \$(SamnSorter.R --version |& sed '1!d ; s/SamnSorter v//')
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
    touch samnsorter_res.tsv
    touch dist_matrix.tsv
    mkdir -p logs
    touch logs/samnsorter.log
    CLUSTER=1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samnsorter: \$(SamnSorter.R --version |& sed '1!d ; s/samnsorter v//')
    END_VERSIONS
    """
}
