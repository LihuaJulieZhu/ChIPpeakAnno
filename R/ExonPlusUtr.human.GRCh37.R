#' Gene model with exon, 5' UTR and 3' UTR information for human sapiens
#' (GRCh37) obtained from biomaRt
#' 
#' Gene model with exon, 5' UTR and 3' UTR information for human sapiens
#' (GRCh37) obtained from biomaRt
#' 
#' used in the examples Annotation data obtained by: mart = useMart(biomart =
#' "ensembl", dataset = "hsapiens_gene_ensembl") ExonPlusUtr.human.GRCh37 =
#' getAnnotation(mart=human, featureType="ExonPlusUtr")
#' 
#' @name ExonPlusUtr.human.GRCh37
#' @docType data
#' @format GRanges with slot start holding the start position of the exon, slot
#' end holding the end position of the exon, slot rownames holding ensembl
#' transcript id and slot space holding the chromosome location where the gene
#' is located. In addition, the following variables are included.  \describe{
#' \item{list("strand")}{1 for positive strand and -1 for negative strand}
#' \item{list("description")}{description of the transcript}
#' \item{list("ensembl_gene_id")}{gene id} \item{list("utr5start")}{5' UTR
#' start} \item{list("utr5end")}{5' UTR end} \item{list("utr3start")}{3' UTR
#' start} \item{list("utr3end")}{3' UTR end}}
#' @keywords datasets
#' @examples
#' 
#' data(ExonPlusUtr.human.GRCh37)
#' slotNames(ExonPlusUtr.human.GRCh37)
#' 
"ExonPlusUtr.human.GRCh37"