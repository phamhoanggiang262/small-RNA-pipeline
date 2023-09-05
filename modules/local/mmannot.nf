process MMANNOT {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::mmannot=1.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mmannot:1.1--hdcf5f25_2 ':
        'quay.io/biocontainers/mmannot:1.1--hdcf5f25_2 ' }"

    input:
    tuple val(meta), path(bam), path (annotation)
    path configfile

    output:
    path 'annotation_file.tsv'				, emit: annotation_report
    path 'statistics.txt'				    , emit: out_stats
    path "versions.yml"           			, emit: versions
	
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """ 
    mmannot \\
    	-a $annotation \\
    	-r $bam \\
    	-o annotation_file.tsv \\
    	-c $configfile \\
    	2> statistics.txt
    	
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
   	mmannot : \$(mmannot -v 2>&1 | sed "s/mmannot v//g")
    END_VERSIONS
    
    """
}
