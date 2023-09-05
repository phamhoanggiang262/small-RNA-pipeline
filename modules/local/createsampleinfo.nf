
process CREATESAMPLEINFO {
    tag '$bam'
    label 'process_single'

input:
	path samplesheet
	
	output:
	path 'sampleInfo.csv'			,emit: sampleInfo
	
	script:
	"""
	createSampleInfo.R --samplesheet $samplesheet --path $baseDir/results/samtools/sort
	"""	
}

