#!/usr/bin/env Rscript

# load pkgs
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(data.table))
suppressPackageStartupMessages(library(dbscan))
suppressPackageStartupMessages(library(cluster))
suppressPackageStartupMessages(library(argparse))
suppressPackageStartupMessages(library(furrr))
suppressPackageStartupMessages(library(ggpubr))

# cli argument parser
parser <- ArgumentParser()
parser$add_argument("file")
parser$add_argument("-o", "--outdir", type="character", default=".",
    help="Directory path to where output files will be written to [%(default)s]")
parser$add_argument("--prefilter", type="character", default="0.001,0.15",
    help="Pre-filter any values above this distance threshold. Set parameter to 0 to disable prefiltering. Value format: core_dist,accessory_dist e.g. 0.001,0.01 [%(default)s]")
parser$add_argument("--top_hits", type="double", default="2000",
    help="Maximum number of top hits to return. [%(default)s]")
parser$add_argument("--distance", type="character", default="auto",
    help="Maximum core and accessory distance. Specify 'auto' to automatically determine the most optimal values. Value format: core,accessory e.g. 0.05,0.01 [%(default)s]")
parser$add_argument("--minPts", type="character", default="auto",
    help="Range of minPts to explore to optimize HDBSCAN cluster search. Specify 'auto' to automatically choose the range of minPts to test. Value format: min,max,step [%(default)s]")
parser$add_argument("--subsample", type="double", default=10000,
    help="Subsample the search space to speed up HDBSCAN clustering. Specifying values larger than 20,000 is not recommended. [%(default)s]")
parser$add_argument("-t", metavar="THREADS", dest="threads", type="integer", default=2,
    help="Number of threads to use [%(default)s]")
args <- parser$parse_args()

# set global options
options(future.rng.onMisuse = 'ignore')

# set up parallel backend
c <- availableCores()
cat("Number of cores available in the environment:", c, "\n")
plan(multicore, workers = args$threads)

# HDBSCAN optimization
hdbscan_opt <- function(mat, minpts) {
  clust_stats <- future_map(minpts, function(x) {
    clust <- hdbscan(as.data.frame(mat[,c('core', 'accessory')]), minPts = x)
    nonzero_clust <- which(clust$cluster != 0)
    if (length(nonzero_clust) == 0) { 
      return(
        list(
          'score' = NA,
          'clusters_n' = 0
        ) 
      )
      
    }
    sil <- silhouette(
        clust$cluster[nonzero_clust], 
        dist(mat[nonzero_clust,c('core', 'accessory')])
    )
    score <- mean(sil[,3])
    clusters_n <- clust$cluster %>% subset(. != 0) %>% unique() %>% length()
    # low_count <- length(clust$membership_prob[which(clust$membership_prob < 0.05)])
		# total_count <- length(clust$membership_prob)
		# score <- low_count/total_count
    return(
      list(
        'score' = score,
        'clusters_n' = clusters_n
      )
    )
  }, .progress = T)
  return(
    list(
      'score' = map_dbl(clust_stats, ~return(.[['score']])),
      'clusters_n' = map_dbl(clust_stats, ~return(.[['clusters_n']]))
    )
  )
}

# HDBSCAN search
hdbscan_search <- function(
    mat=NULL, # two column matrix of core and accessory distances
    minpts=seq(5,15,1), # range of minPts to search
    outfile = NULL # output file path
) {
    cat("Optimizing HDBSCAN hyperparameter...\n")
    cat("Tuning minPts from =", min(minpts), "to =", max(minpts), "steps =", minpts[2]-minpts[1], "\n")
    clust_stats <- hdbscan_opt(mat, minpts)
    clust_stats_df <- data.frame(
      minpts = minpts,
      sil = clust_stats[['score']],
      clusters_n = clust_stats[['clusters_n']]
    )
    # plot minPts vs silhouette score
    p <- clust_stats_df %>%
      ggplot(aes(x = as.numeric(minpts), y = sil, group = 1)) +
      geom_point() +
      geom_line() +
      theme_bw(15) +
      labs(x = "minPts",
           y = "Cluster score")
    p2 <- clust_stats_df %>%
      ggplot(aes(x = as.numeric(minpts), y = clusters_n, group = 1)) +
      geom_point() +
      geom_line() +
      theme_bw(15) +
      labs(x = "minPts",
           y = "Number of clusters")
    p3 <- ggarrange(p, p2, ncol = 2)
    if (!is.null(outfile)) { ggsave(outfile, p3) } # save plot
    # fit hdbscan using optimal minPts
    opt_minpts <- tryCatch(
      clust_stats_df %>% filter(clusters_n > 2) %>% filter(sil == max(sil)) %>% pull(minpts) %>% min(), 
      error = function(e) {
        clust_stats_df$minpts[which.max(clust_stats_df$sil)]
      }
    )
    cat("Optimal minPts: ", opt_minpts, "\n")
    cat("Fitting HDBSCAN using optimal minPts...\n")
    dbscan.fit <- hdbscan(mat[,c('core', 'accessory')], minPts = opt_minpts)
    # return list obj
    return(
      list(
        'fit' = dbscan.fit,
        'opt_minpts' = opt_minpts
      )
    )
}

distance_search <- function(
    mat, # two column matrix of core and accessory distances
    max_core, # maximum core distance
    max_accessory, # maximum accessory distance,
    top_hits = 2000 # maximum number of top hits to return
) {
  cat("Searching by distance...\n")
  mat.filt <- mat %>% 
    filter(core <= max_core, 
           accessory <= -1*max_accessory/max_core+max_accessory) %>%
    mutate(dist = sqrt(core^2+accessory^2)) %>%
    arrange(dist) %>%
    slice(1:if_else(nrow(.) >= top_hits, top_hits, nrow(.)))
  return(mat.filt)
}

main_search <- function(
    mat = NULL, # two column matrix of core and accessory distances
    prefilter_dist = c(0.01, 0.005), # prefiltering threshold
    max_dist = c(0.025, 0.0005), # maximum distance threshold
    minPts = seq(5, 15, 1), # range of minPts to search
    outdir = ".", # output directory
    subsample = 10000, # subsample size
    top_hits = 2000 # maximum number of top hits to return
) {
    # initialize output obj
    res <- list(
      mat = mat,
      hdbscan_mat = c(),
      cluster_id = c(),
      centroids = c(),
      ngbrs_ids = c(),
      core = c(),
      accessory = c(),
      subsample = c(),
      clusters_n = c(),
      total_hits = c(),
      opt_minpts = c()
    )
    # perform prefiltering
    if (length(prefilter_dist) == 2) {
        res[['mat']] <- filter(mat, core <= prefilter_dist[1], accessory <= prefilter_dist[2])
        cat("Number of subject IDs after prefiltering:", nrow(res[['mat']]), "\n")
        # stop if no candidates remain
      if (nrow(res[['mat']]) == 0) {
          writeLines(character(0), con = file.path(outdir, "SamnTrek_hits.txt"))
          quit("No rows found after prefiltering. Exiting...\n")
      }
    }
    # subsample size
    if (nrow(res[['mat']]) > as.numeric(subsample)) {
      res[['subsample']] <- as.numeric(args$subsample)
    } else {
      res[['subsample']] <- NULL
    }
    # execute search
    if (max_dist != 'auto') {
        # verify distance format
        if (length(unlist(str_split(args$distance, ','))) != 2) {
          stop("Invalid distance format. Please specify core and accessory distances separated by a comma e.g. 0.05,0.01\n")
          core_dist <- as.numeric(unlist(str_split(args$distance, ','))[1])
          accessory_dist <- as.numeric(unlist(str_split(args$distance, ','))[2])
        }
        m <- distance_search(res[['mat']], core_dist, accessory_dist, top_hits)
        res[['ngbrs_ids']] <- as.character(m$id)
        res[['core']] <- as.numeric(core_dist)
        res[['accessory']] <- as.numeric(accessory_dist)
    } else {
        set.seed(123) # set seed
        # subsampling
        if ( !is.null(res[['subsample']]) ) { 
            cat("Subsampling", subsample, "subject sequences...\n")
            res[['hdbscan_mat']] <- sample_n(res[['mat']], res[['subsample']])
        } else {
            res[['hdbscan_mat']] <- res[['mat']]
        }
        dbscan.fit <- hdbscan_search(
          res[['hdbscan_mat']],
          minPts,
          outfile = file.path(outdir, 'hdbscan_cluster_score.png')
        )
        res[['opt_minpts']] <- dbscan.fit[['opt_minpts']]
        res[['cluster']] <- if_else(dbscan.fit[['fit']]$cluster == 0, NA, dbscan.fit[['fit']]$cluster)
        # find cluster with minimum distance to origin
        res[['centroids']] <- res[['hdbscan_mat']] %>% 
          cbind(cluster = res[['cluster']]) %>%
          filter(!is.na(cluster)) %>% 
          group_by(cluster) %>% 
          summarize(avg_core = mean(core),
                    avg_accessory = mean(accessory))
        # stop if there are no valid centroids
        if ( nrow(res[['centroids']]) == 0 ) {
          cat("No valid centroids found...\n")
          res[['accessory']] <- 0.025
          res[['core']] <- 0.0005
          res[['clusters_n']] <- 0
          cat("Setting core distance threshold to: ", res[['core']], "\n")
          cat("Setting accessory distance threshold to: ", res[['accessory']], "\n")
          cat("To override this, please specify a value using --distance\n")
        } else {
          res[['cluster_id']] <- res[['centroids']] %>% 
            ungroup() %>% 
            mutate(dist = sqrt(avg_core^2+avg_accessory^2)) %>% 
            arrange(dist) %>% 
            slice(1) %>% 
            pull(cluster)
          cat("Nearest cluster ID to origin:", res[['cluster_id']], "\n")
          res[['clusters_n']] <- nrow(res[['centroids']])
          # maximum coordinate of the nearest cluster
          idx <- res[['cluster']] == res[['cluster_id']]
          max_core <- res[['hdbscan_mat']] %>% 
            filter(idx) %>% 
            pull(core) %>%
            max()
          max_accessory <- res[['hdbscan_mat']] %>% 
            filter(idx) %>% 
            pull(accessory) %>%
            max()
          # update accessory threshold based on the max accessory 
          # coordinate of the nearest cluster
          res[['accessory']] <- max_accessory
          res[['core']] <- max_core
        }
        # Filter IDs within the max coordinates
        mat.filt <- res[['mat']] %>% 
            filter(
              core <= res[['core']], 
              #accessory <= -1*res[['accessory']]/res[['core']]*core+res[['accessory']]
              accessory <= res[['accessory']]
            )
        res[['total_hits']] <- nrow(mat.filt)        
        res[['ngbrs_ids']] <- mat.filt %>% 
          mutate(dist = sqrt(core^2+accessory^2)) %>%
          arrange(dist) %>%
          slice(1:if_else(nrow(.) >= top_hits, top_hits, nrow(.))) %>%
          pull(id) %>%
          as.character()
    }
    # return results
    return(res)
}

# Plot visualization of core and accessory distances
plot_dist <- function(
    mat = NULL, # two column matrix of core and accessory distances
    maxDist = c(0.01, 0.005), # maximum distance threshold
    centroids = NULL, # cluster centroids coordinates
    clusters = NULL, # cluster assignments
    opt_minpts = NULL, # optimal minPts
    outfile = NULL, # output file path
    subsample = NULL # subsample size
) {
  # bind cluster assigments if available
  if (!is.null(centroids)) {
    mat <- cbind(mat, cluster = clusters)
  }
  # base plot
  p <- mat %>%
    ggplot(aes(x = core, y = accessory)) +
    theme_bw(15) +
    labs(x = "Core distance",
         y = "Accessory distance") +
    guides(color = 'none', fill = 'none') +
    # geom_abline(intercept = maxDist[2], slope = -1*maxDist[2]/maxDist[1], linetype = "dashed", color = 'red')
    geom_vline(xintercept = maxDist[1], linetype = "dashed", color = 'red') +
    geom_hline(yintercept = maxDist[2], linetype = "dashed", color = 'red')
  # add layers dependent on search method
  if ( is.null(centroids)) {
    p <- p +
      geom_point(alpha = 0.5) 
  } else {
    p <- p +
      geom_point(aes(color = as.factor(cluster)), alpha = 0.5) +
      # geom_vline(xintercept = maxDist[1], linetype = "dashed", color = 'red') +
      # geom_hline(yintercept = maxDist[2], linetype = "dashed", color = 'red') +
      scale_colour_discrete(na.value="gray") +
      stat_ellipse(data = filter(mat, !is.na(cluster)), 
                  aes(colour = as.factor(cluster)),
                  linewidth = 1,
                  show.legend = F,
                  level = 0.8) +
      geom_label(data = centroids,
                aes(x = avg_core, y = avg_accessory,
                    label = as.factor(cluster)),
                show.legend = F)
  }
  # add footnote
  footer <- paste0('Cutoff: [', signif(maxDist[1], 3), ', ', signif(maxDist[2], 3), ']')
  if ( !is.null(subsample) ) {
    footer <- paste0(footer, '\nSubsampled: ', subsample)
  }
  if ( !is.null(opt_minpts) ) {
    footer <- paste0(footer, '\nMinPts: ', opt_minpts)
  }
  p <- p + labs(caption = footer) + theme(plot.caption = element_text(hjust = 0)) # set to left alignment
  # save plot
  if (!is.null(outfile)) { ggsave(outfile, p, width = 8, height = 8) }
}

# main script
mat <- fread(args$file, sep = "\t", header = T)
# hdbscan search range
if (args$minPts == "auto" & args$distance == "auto") {
  min_minpts <- 15
  max_minpts <- 155
  step_minpts <- 10
  if ( nrow(mat) >= max_minpts) {
    minpts_range <- c(seq(min_minpts, max_minpts, step_minpts))
  } else {
    minpts_range <- seq(min_minpts, nrow(mat), step_minpts)
  }
  # disable clustering if fewer than min_n subject IDs
  min_n <- 100
  if ( nrow(mat) < min_n ) {
    cat("Detected less than", min_n, "subject IDs, insufficient data for reliable unsupervised clustering...")
    args$distance <- c(0.025, 0.0005)
    cat("Setting core distance threshold to: ", args$distance[1], "\n")
    cat("Setting accessory distance threshold to: ", args$distance[2], "\n")
    cat("To override this, please specify a value using --distance\n")
  }
} else if (args$distance == "auto" & args$minPts != "auto") {
  max_minpts <- as.numeric(unlist(str_split(args$minPts, ','))[2])
  if ( nrow(mat) >= max_minpts) {
    minpts_range <- seq(
      as.numeric(unlist(str_split(args$minPts, ','))[1]),
      max_minpts,
      as.numeric(unlist(str_split(args$minPts, ','))[3])
    )
  } else {
    minpts_range <- seq(
      as.numeric(unlist(str_split(args$minPts, ','))[1]),
      nrow(mat),
      as.numeric(unlist(str_split(args$minPts, ','))[3])
    )
  }
  
}
# main search
search_res <- main_search(
  mat, # three column matrix of id, core and accessory distances
  prefilter_dist = as.numeric(unlist(str_split(args$prefilter, ','))), # prefiltering threshold
  max_dist = args$distance, # maximum distance threshold: "core,accessory"
  minPts = minpts_range, # range of minPts to search
  outdir = args$outdir, # output directory
  subsample = as.numeric(args$subsample), #  subsample size
  top_hits = as.numeric(args$top_hits) # maximum number of top hits to return
)
# plot analytical results
cat("Plotting clustering results...\n")
if (is.null(search_res[['centroids']])) {
  plot_mat <- search_res[['mat']]
} else {
  plot_mat <- search_res[['hdbscan_mat']]
}
plot_dist(
  mat = plot_mat, # two column matrix of core and accessory distances
  maxDist = c(search_res[['core']], search_res[['accessory']]), # maximum distance threshold
  centroids = search_res[['centroids']], # cluster centroids coordinates
  clusters = search_res[['cluster']], # cluster assignments
  outfile = file.path(args$outdir, 'core_accessory_plot.png'), # output file path
  subsample = search_res[['subsample']] # subsample size
)
# write neighbour accessions
cat("Writing out neighbour accessions...\n")
writeLines(as.character(search_res[['ngbrs_ids']]),
           con = file.path(args$outdir, "SamnTrek_hits.txt"))
cat("Writing out search stats...\n")
data.frame(
  'id' = sub("\\.[^\\.]*$", "", (basename(args$file))),
  'subjects_n' = nrow(mat),
  'top_hits_n' = length(search_res[['ngbrs_ids']]),
  'total_hits_n' = search_res[['total_hits']],
  "clusters_n" = search_res[['clusters_n']]
) %>%
  write.table(file = file.path(args$outdir, "SamnTrek_search_stats.tsv"),
              sep = "\t", row.names = F, col.names = T, quote = F)
cat("Analysis complete.\n")