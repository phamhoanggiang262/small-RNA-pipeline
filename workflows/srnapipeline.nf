/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowSrnapipeline.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config, params.fasta ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

params.schema_ignore_params = "configfile,annotation"

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//

include { SRNAMAPPERSAMTOOLSVIEW         } from '../modules/local/srnamappersamtoolsview'
include { SRNAMAPPER                     } from '../modules/local/srnamapper'
include { MMQUANT                        } from '../modules/local/mmquant'
include { MMANNOT                        } from '../modules/local/mmannot'
include { CREATESAMPLEINFO 		         } from '../modules/local/createsampleinfo'
include { SRNADIFF	 		             } from '../modules/local/srnadiff'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                      } from '../modules/nf-core/fastqc/main'
include { FASTP 		              } from '../modules/nf-core/fastp/main'
include { BWA_INDEX		              } from '../modules/nf-core/bwa/index/main'
include { SAMTOOLS_VIEW               } from '../modules/nf-core/samtools/view/main' 
include { SAMTOOLS_SORT               } from '../modules/nf-core/samtools/sort/main'
include { DESEQ2_DIFFERENTIAL                               } from '../modules/nf-core/deseq2/differential/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow SRNAPIPELINE {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // MODULE: Run FastQC
    //
    FASTQC (
        INPUT_CHECK.out.reads
    )
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: Run fastp
    //

    FASTP (
    	INPUT_CHECK.out.reads, [], [], []
    )

    ch_versions = ch_versions.mix(FASTP.out.versions.first())

    //
    // MODULE: Run BWA_INDEX
    //	

    if (params.fasta) {
                    Channel.from([
	                [["id" : "bwa_index"], file(params.fasta)]])
	                .set {fasta_ch}
						
    BWA_INDEX (
        fasta_ch
    )

    BWA_INDEX.out.index
	     .map { meta, index -> [index] }
	     .set { bwa_index_ch 	           }
    } 
    
    ch_versions = ch_versions.mix(BWA_INDEX.out.versions.first())

    //
    // MODULE: Run srnaMapper
    //	
    
    map_ch = FASTP.out.reads
                  .combine(bwa_index_ch)

    SRNAMAPPERSAMTOOLSVIEW (map_ch)
	
/*
	SRNAMAPPER (
        map_ch
    )
    
*/

   // SRNAMAPPER.out.sam.view()
    //
    // MODULE: Run srnaMapper
    //	
   
   // map_output = SRNAMAPPER.out.sam.map{it -> it + [ [] ] }
    //map_output.view()
    


    //
    // MODULE: Run samtools_view
    //	
/*
    SAMTOOLS_VIEW (
        map_output, [[],[]], []
    )
*/
    //SAMTOOLS_VIEW.out.bam.view()


    //
    // MODULE: Run samtools_sort
    //	
    SAMTOOLS_SORT (
        SRNAMAPPERSAMTOOLSVIEW.out.bam
    )

    SAMTOOLS_SORT.out.bam.view()

	annotation_ch = channel.fromPath(params.annotation)
	SAMTOOLS_SORT.out.bam   | map { meta, bam -> [ [ "id":"test" ], bam ] }
			   				| groupTuple ()
			  				| combine(annotation_ch)
		           			| set { bam_ch } 


    SAMTOOLS_SORT.out.bam.view()
    
    //bam_ch.view()


    // SRNADIFF PREPARATION
    // MODULE: Run createsampleinfo
    //	   

    samplesheet_ch = Channel.fromPath(params.input)
    CREATESAMPLEINFO(samplesheet_ch)



    //
    // MODULE: Run mmquant, srnadiff, mmannot
    //	    






	if (params.annotation != "NO_FILE")
	{
		if(params.configfile){

			configfile_ch = channel.fromPath(params.configfile)
			MMANNOT(bam_ch, configfile_ch)
			SRNADIFF (CREATESAMPLEINFO.out.sampleInfo, SAMTOOLS_SORT.out.bam, annotation_ch )
			MMQUANT (bam_ch)
		}

		else{
			SRNADIFF (CREATESAMPLEINFO.out.sampleInfo, SAMTOOLS_SORT.out.bam, annotation_ch )
			MMQUANT (bam_ch)
		}

	}



    // DESEQ2 PREPARATION
    // MODULE: Run expression contrast
    //	   

    ch_empty_spikes = [[],[]]

    expression_contrasts = file(params.contrasts)
    expression_sample_sheet = file(params.input)
     
    MMQUANT.out.count_matrix.map{meta, count_matrix -> count_matrix}.set{expression_matrix}
    expression_matrix.view()
    

    Channel.fromPath(expression_contrasts)
        .splitCsv ( header:true, sep:',' )
        .map{
            tuple(it, it.variable, it.reference, it.target)
        }
        .set{
            ch_contrasts
        }

    ch_matrix = channel.from( [
        [[id: 'differential_expression'], expression_sample_sheet]])
        .combine(expression_matrix)

    ch_matrix.view() 

       
    
    //
    // MODULE: MultiQC
    //

        DESEQ2_DIFFERENTIAL (
        ch_contrasts,
        ch_matrix,
        ch_empty_spikes
    )


    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowSrnapipeline.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowSrnapipeline.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
