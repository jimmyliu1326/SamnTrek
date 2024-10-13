#!/usr/bin/env Rscript

# load pkgs
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(data.table))
suppressPackageStartupMessages(library(purrr))
suppressPackageStartupMessages(library(argparse))

# cli argument parser
parser <- ArgumentParser()
parser$add_argument("files", nargs='+')
parser$add_argument("-o", "--outfile", type="character", default="./SamnTrek_summary.tsv",
    help="Output summary file path [%(default)s]")
args <- parser$parse_args()

# read and combine result files
out <- args$files %>%
  map(~fread(., header = T)) %>%
  purrr::reduce(dplyr::left_join, by = 'id') %>%
  select(id, final_clust,	subjects_n,	top_hits_n, total_hits_n, clusters_n) %>%
  rename('cluster_id' = 'final_clust')

# write output
write.table(
  out,
  file = file.path(args$outfile),
  sep = "\t", row.names = F, col.names = T, quote = F
)