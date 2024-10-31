process RENAME_FASTA {
    tag "$meta.id"
    label 'process_single'

    input:
    tuple val(meta), path(fasta, stageAs: "input.fasta")

    output:
    tuple val(meta), path("*.fasta")           , emit: fasta
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ln -Ls input.fasta ${meta.id}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mv: \$(mv --version | head -n1 | sed 's/.* //g')
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
    touch ${meta.id}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mv: \$(mv --version | head -n1 | sed 's/.* //g')
    END_VERSIONS
    """
}
