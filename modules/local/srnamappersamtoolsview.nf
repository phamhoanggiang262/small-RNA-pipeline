process SRNAMAPPERSAMTOOLSVIEW {
   tag "$meta.id"
   label 'process_long'

   //conda "${moduleDir}/environment.yml"
   container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
   'https://depot.galaxyproject.org/singularity/mulled-v2-0a27fd3aa225aee0af83fad683ed048c99243e30:1b4dcc74db40feefa57dc3648be9fae418b65ad8-0':
   'biocontainers/mulled-v2-0a27fd3aa225aee0af83fad683ed048c99243e30:1b4dcc74db40feefa57dc3648be9fae418b65ad8-0' }"

   input:
   tuple val(meta) , path(reads), path(index)

   output:
   tuple val(meta), path("*.bam")		, emit: bam
   path "versions.yml"           		, emit: versions

   when:
   task.ext.when == null || task.ext.when

   script:
   def args = task.ext.args ?: ''
   def args2 = task.ext.args2 ?: ''
   def prefix = task.ext.prefix ?: "${meta.id}"

   """
   INDEX=`find -L ./ -name "*.amb" | sed 's/\\.amb\$//'`
   gunzip -c $reads > ${prefix}.fastq

    srnaMapper \\
         -r ${prefix}.fastq \\
         -g \$INDEX \\
	 -o ${prefix}_align.sam \\
	 $args

    samtools \\
        view \\
	${prefix}_align.sam \\
	-o ${prefix}.viewed.bam \\
    $args2

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        srnamapper: \$(srnaMapper -v | sed -e "s/srnaMapper v//g") 
	samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """

}
