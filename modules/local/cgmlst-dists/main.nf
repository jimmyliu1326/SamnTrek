process CGMLST_DISTS {
    tag "$task.process"
    label 'process_low'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/jimmyliu1326/samnsorter:0.1.0':
        'docker.io/jimmyliu1326/samnsorter:0.1.0' }"

    input:
    tuple val(meta), path(alleles)

    output:
    path "*.tsv"                       , emit: matrix
    path "*.phylip"                       , emit: matrix_phylip
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    /cgmlst-dists/cgmlst-dists \
        ${alleles} \
        ${args} \
        > ${prefix}.tsv

    # convert distance matrix to phylip format
    N=\$(tail -n +2 ${prefix}.tsv | wc -l)
    cat <(echo \$N) <(tail -n +2 ${prefix}.tsv) > ${prefix}.phylip

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cgmlst-dists: v\$(/cgmlst-dists/cgmlst-dists -v | tail -n1 | sed 's/cgmlst-dists //g')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cgmlst-dists: v\$(/cgmlst-dists/cgmlst-dists -v | tail -n1 | sed 's/cgmlst-dists //g')
    END_VERSIONS
    """
}
