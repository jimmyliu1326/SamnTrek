process RAPIDNJ {
    label 'process_medium'

    // WARN: Version information not provided by tool on CLI. Please update version string below when bumping container versions.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-805c6e0f138f952f9c61cdd57c632a1a263ea990:3c52e4c8da6b3e4d69b9ca83fa4d366168898179-0' :
        'biocontainers/mulled-v2-805c6e0f138f952f9c61cdd57c632a1a263ea990:3c52e4c8da6b3e4d69b9ca83fa4d366168898179-0' }"

    input:
    path alignment

    output:
    path "*.nwk"       , emit: phylogeny
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def VERSION = '2.3.2' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    def prefix = task.ext.prefix ?: "rapidnj_tree"
    """
    rapidnj \\
        ${alignment} \\
        ${args} \\
        -c ${task.cpus} \\
        -x ${prefix}.nwk

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rapidnj: $VERSION
    END_VERSIONS
    """
}