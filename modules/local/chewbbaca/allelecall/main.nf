process CHEWBBACA_ALLELECALL {
    tag "$task.process"
    label 'process_low'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/jimmyliu1326/samnsorter:0.1.0':
        'jimmyliu1326/samnsorter:0.1.0' }"

    input:
    tuple val(meta), path(fasta)                        

    output:
    tuple val(meta), path("**/results_alleles_hashed.tsv") , emit: alleles_hashed
    tuple val(meta), path("**/results_alleles.tsv")        , emit: alleles
    path "versions.yml"                                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def date = new Date()
    def timestamp = date.getTime()
    """
    mkdir -p ./genomes
    find -L \$PWD -maxdepth 1 -type f \\( -name '*.fasta' -or -name '*.fna' -or -name '*.fa' \\) -exec sh -c 'f={}; basename=\$(basename \$f); ln -Lfs \$f genomes/\$(echo \${basename%.*} | tr "." "@").fa' \\;

    chewBBACA.py AlleleCall \
        -i ./genomes/ \
        -o results_${timestamp} \
        --cpu ${task.cpus} \
        ${args}

    sed -i 's/@/./g' results_${timestamp}/*

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chewbbaca: v\$(chewBBACA.py -v | tail -n1 | sed 's/chewBBACA version: //g')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch results_alleles_hashed.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chewbbaca: v\$(chewBBACA.py -v | tail -n1 | sed 's/chewBBACA version: //g')
    END_VERSIONS
    """
}