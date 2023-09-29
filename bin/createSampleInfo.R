#!/usr/bin/env Rscript

library(optparse)
library(readr)


option_list <- list(
  make_option(
    c("-s", "--samplesheet"),
    type = "character",
    default = NULL,
    help = " CSV-format sample sheet file."),
  make_option(
    c("-p", "--path"),
    type = "character",
    default = NULL,
    help = " CSV-format sample sheet file.")
)

opt_parser <- OptionParser(option_list = option_list);
opt <- parse_args(opt_parser);

# read sample sheet file

samplesheet <- read.csv(opt$samplesheet)

#rename column name
colnames(samplesheet)[2] = "FileName"



#split file name from path
#samplesheet$FileName <- basename(samplesheet$FileName)
samplesheet$FileName<- sub('.*/', '', samplesheet$FileName)

#set to absolute path
samplesheet$FileName <- file.path(opt$path, paste0(samplesheet$sample, ".bam"))


#move FileName in the front
#samplesheet <- relocate(samplesheet$FileName, .before = SampleName) 


samplesheet <- subset(samplesheet, select = c(2,1,3))
write.table(samplesheet, file="sampleInfo.csv", sep=",", row.names = F, col.names = T)


