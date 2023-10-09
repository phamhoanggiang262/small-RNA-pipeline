#!/usr/bin/env Rscript
####### Loading library

args = commandArgs(trailingOnly=TRUE)

library(srnadiff)





####### Data preparation sample sheet, bam file and annotation file 


# Sample sheet
sample_sheet <- read.delim(file = args[1], header = T, sep = ",")
FileName = sample_sheet[,1]


# BAM files
#bamFiles <- opt$bamPath

# Annotation file
#annotReg <- readAnnotation(fileName = opt$annotationFile, feature = "opt$feature", source = "opt$source")

# Preparation of srnadiff object

if ( is.null(args[2]) == T ) {
  srnaExp_object <- 
    srnadiffExp(
      FileName, 
      sample_sheet,
) 
  
} else { 
  
  annotReg <- readAnnotation(args[2])
  
  srnaExp_object <- 
    srnadiffExp(
      FileName, 
      sample_sheet, 
      annotReg) 
}

# Detecting DERs and quantifying differential expression

srnaExp <- srnadiff(
  srnaExp_object)




#Visualization of the results

gr <- regions(srnaExp)

df <- data.frame(chr = seqnames(gr),
                 starts = start(gr),
                 ends = end(gr),
                 names = names(gr),
                 scores = -log10(mcols(gr)$padj),
                 strands = strand(gr))

write.table(df, file = "DE_regions.bed", quote = F, sep = "\t",col.names = F, row.names = F)



















