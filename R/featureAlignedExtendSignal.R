#' extract signals in given ranges from bam files
#' 
#' extract signals in the given feature ranges from bam files (DNAseq only).
#' The reads will be extended to estimated fragement length.
#' 
#' 
#' @param bamfiles The file names of the 'BAM' ('SAM' for asBam) files to be
#' processed.
#' @param index The names of the index file of the 'BAM' file being processed;
#' this is given without the '.bai' extension.
#' @param feature.gr An object of \link[GenomicRanges:GRanges-class]{GRanges}
#' with identical width.
#' @param upstream,downstream upstream or dwonstream from the feature.gr.
#' @param n.tile The number of tiles to generate for each element of
#' feature.gr, default is 100
#' @param fragmentLength Estimated fragment length.
#' @param librarySize Estimated library size.
#' @param pe Pair-end or not. Default auto.
#' @param adjustFragmentLength A numberic vector with length 1. Adjust the
#' fragments/reads length to.
#' @param gal A GAlignmentsList object or a list of GAlignmentPairs. If
#' bamfiles is missing, gal is required.
#' @param \dots Not used.
#' @return A list of matrix. In each matrix, each row record the signals for
#' corresponding feature.
#' @author Jianhong Ou
#' @seealso See Also as \code{\link{featureAlignedSignal}},
#' \code{\link{estLibSize}}, \code{\link{estFragmentLength}}
#' @keywords misc
#' @export
#' @import IRanges
#' @import GenomicRanges
#' @importFrom S4Vectors elementNROWS mcols
#' @importFrom GenomicAlignments readGAlignments readGAlignmentPairs
#' @importFrom Rsamtools testPairedEndBam ScanBamParam scanBamWhat scanBamFlag
#' @examples
#' 
#'  if(interactive() || Sys.getenv("USER")=="jianhongou"){
#'     path <- system.file("extdata", package="MMDiffBamSubset")
#'     if(file.exists(path)){
#'         WT.AB2 <- file.path(path, "reads", "WT_2.bam")
#'         Null.AB2 <- file.path(path, "reads", "Null_2.bam")
#'         Resc.AB2 <- file.path(path, "reads", "Resc_2.bam")
#'         peaks <- file.path(path, "peaks", "WT_2_Macs_peaks.xls")
#'         estLibSize(c(WT.AB2, Null.AB2, Resc.AB2))
#'         feature.gr <- toGRanges(peaks, format="MACS")
#'         feature.gr <- feature.gr[seqnames(feature.gr)=="chr1" & 
#'                              start(feature.gr)>3000000 & 
#'                              end(feature.gr)<75000000]
#'         sig <- featureAlignedExtendSignal(c(WT.AB2, Null.AB2, Resc.AB2), 
#'                                feature.gr=reCenterPeaks(feature.gr, width=1), 
#'                                upstream = 505,
#'                                downstream = 505,
#'                                n.tile=101, 
#'                                fragmentLength=250,
#'                                librarySize=1e9)
#'         featureAlignedHeatmap(sig, reCenterPeaks(feature.gr, width=1010), 
#'                           zeroAt=.5, n.tile=101)
#'     }
#'  }
#' 
featureAlignedExtendSignal <- function(bamfiles, index=bamfiles, 
                                       feature.gr, 
                                       upstream, downstream, 
                                       n.tile=100, 
                                       fragmentLength,
                                       librarySize,
                                       pe=c("auto", "PE", "SE"),
                                       adjustFragmentLength,
                                       gal, ...){
    #message("The signal is being calculated for DNA-seq.")
    if(missing(fragmentLength)){
        stop("fragmentLength is missing")
    }
    if(!missing(adjustFragmentLength)){
      stopifnot(inherits(adjustFragmentLength, c("numeric", "integer")))
      stopifnot(length(adjustFragmentLength)==1)
    }
    if(!missing(bamfiles)){
      stopifnot(is(bamfiles, "character"))
      stopifnot(length(bamfiles)==length(index))
      galInput <- FALSE
    }else{
      if(missing(gal)){
        stop("gal is required if missing bamfiles")
      }else{
        if(!is(gal, "GAlignmentsList")){
          galInput <- sapply(gal, function(.ele){
            inherits(.ele, c("GAlignments", "GAlignmentPairs"))
          })
          if(any(!galInput)){
            stop("gal must be a GAlignmentsList object or ", 
                 "a list of GAlignmentPairs.")
          }
        }
      }
      galInput <- TRUE
    }
    stopifnot(is(feature.gr, "GRanges"))
    if(missing(upstream) | missing(downstream)){
        stop("upstream and downstream is missing")
    }
    stopifnot(inherits(upstream, c("numeric", "integer")))
    stopifnot(inherits(downstream, c("numeric", "integer")))
    stopifnot(inherits(n.tile, c("numeric", "integer")))
    stopifnot(inherits(fragmentLength, c("numeric", "integer")))
    stopifnot(inherits(librarySize, c("numeric", "integer")))
    pe <- match.arg(pe)
    upstream <- as.integer(upstream)
    downstream <- as.integer(downstream)
    n.tile <- as.integer(n.tile)
    fragmentLength <- as.integer(fragmentLength)
    librarySize <- as.integer(librarySize)
    stopifnot(all(width(feature.gr)==1))
    
    totalBPinBin <- floor((upstream + downstream)/n.tile)# * length(feature.gr)
    feature.gr$oid <- 1:length(feature.gr)
    feature.gr.expand <- 
        suppressWarnings(promoters(feature.gr, 
                                   upstream=upstream+max(fragmentLength), 
                                   downstream=downstream+max(fragmentLength)))
    strand(feature.gr.expand) <- "*"
    feature.gr <- suppressWarnings(promoters(feature.gr,
                                             upstream=upstream, 
                                             downstream=downstream))
    
    grL <- tile(feature.gr, n=n.tile)
    ## reorder the tiles for negative strand and set group id for them.
    idx <- as.character(strand(feature.gr))=="-"
    if(sum(idx)>0) {
        grL.rev <- grL[idx]
        grL.rev.len <- lengths(grL.rev)
        grL.rev <- unlist(grL.rev, use.names = FALSE)
        grL.rev$oid <- rep(seq.int(length(grL[idx])), grL.rev.len)
        grL.rev <- rev(grL.rev)
        grL.rev.oid <- grL.rev$oid
        grL.rev$oid <- NULL
        grL.rev <- split(grL.rev, grL.rev.oid)
        grL[idx] <- as(grL.rev, "CompressedGRangesList")
        rm(grL.rev, grL.rev.len, grL.rev.oid)
    }
    grL.eleLen <- elementNROWS(grL)
    grs <- unlist(grL)
    grs$gpid <- unlist(lapply(grL.eleLen, seq_len)) 
    grs$oid <- rep(feature.gr$oid, grL.eleLen)
    if(galInput){
      bams.gr <- mapply(function(ga, .fLen){
        if(is(ga, "GAlignmentPairs")){
          granges(.ele)
        }else{
          qname <- mcols(ga)$qname
          if(pe=="auto"){
            ## check qname
            if(length(qname)==0){
              pe <- FALSE
            }else{
              ## check duplicated qname
              if(all(table(qname)==1)){
                pe <- FALSE
              }else{
                if(all(table(qname)<3)){
                  pe <- TRUE
                }else{
                  pe <- FALSE
                }
              }
            }
          }else{
            pe <- pe=="PE"
          }
          
          if(pe){
            .ele <- split(ga, qname)
            .ele <- granges(.ele, ignore.strand=TRUE)
            .ele
          }else{
            .ele <- granges(ga)
            start(.ele[strand(.ele)=="-"]) <- 
              end(.ele[strand(.ele)=="-"]) - .fLen + 1
            width(.ele) <- .fLen
            .ele
          }
        }
      }, gal, fragmentLength, SIMPLIFY=FALSE)
    }else{
      if(pe=="auto") {
        pe <- mapply(function(file, id) 
          suppressMessages(testPairedEndBam(file, index=id)), 
          bamfiles, index)
      }else{
        pe <- pe=="PE"
      }
      param <- ScanBamParam(which=reduce(feature.gr.expand), 
                            flag=scanBamFlag(isSecondaryAlignment=FALSE,
                                             isNotPassingQualityControls=FALSE),
                            what=scanBamWhat())
      paramp <- ScanBamParam(which=reduce(feature.gr.expand), 
                             flag=scanBamFlag(
                               isProperPair=TRUE,
                               isSecondaryAlignment=FALSE,
                               isNotPassingQualityControls=FALSE),
                             what=scanBamWhat())
      bams.gr <- mapply(function(f, i, p, .fLen) {
        if(!p){
          .ele <- granges(readGAlignments(f, index=i, param=param))
          start(.ele[strand(.ele)=="-"]) <- 
            end(.ele[strand(.ele)=="-"]) - .fLen + 1
          width(.ele) <- .fLen
          .ele
        }else{
          .ele <- readGAlignmentPairs(f, index=i, param=paramp)
          .ele <- granges(.ele)
          .ele
        }
      }, bamfiles, index, pe, fragmentLength, SIMPLIFY=FALSE)
    }
    
    if(!missing(adjustFragmentLength)){
      bams.gr <- lapply(bams.gr, reCenterPeaks, 
                        width=adjustFragmentLength)
      fragmentLength <- adjustFragmentLength
    }
    ## count overlaps
    co <- lapply(bams.gr, countOverlaps, 
                 query=grs, ignore.strand=TRUE)
    
    countTable <- do.call(cbind, co)
    colnames(countTable) <- names(bams.gr)
    stopifnot(nrow(countTable)==length(grs))
#    sumByGpid <- rowsum(countTable, grs$gpid, reorder = FALSE)
#    signal <- t(t(sumByGpid)*1e8/librarySize*100/fragmentLength)/totalBPinBin
    countTable.list <- as.list(as.data.frame(countTable))
    signal <- mapply(function(.ele, .libsize, .fLen){
        tbl <- matrix(nrow=n.tile, ncol=length(feature.gr))
        tbl[(grs$oid-1)*n.tile + grs$gpid] <- .ele
        t(tbl)*1e8/.libsize*100/.fLen/totalBPinBin
    }, countTable.list, librarySize, fragmentLength, SIMPLIFY = FALSE)
    return(signal)
}
