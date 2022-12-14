#' @include utils.R
#' @import dplyr Seurat SeuratWrappers
#' @importFrom grDevices dev.off pdf
#' @importFrom utils read.csv tail
NULL

#' @section Seurat CCA:
#' * source code: <https://github.com/satijalab/seurat>
#' * quick start: <https://satijalab.org/seurat/articles/integration_introduction.html#performing-integration-on-datasets-normalized-with-sctransform-1>
#' @md
#'
#' @import Seurat
#' @export
#' @rdname Integration
#' @method Integration SeuratCCA
#' @concept integration
#' 
Integration.SeuratCCA <- function(csv, outdir, used){
  projects <- MergeFileData(csv) 
  projects <- lapply(projects, FUN = function(x) {
      Seurat::NormalizeData(x) %>% 
        Seurat::FindVariableFeatures(selection.method = "vst", nfeatures = 2000)
    })
  features <- Seurat::SelectIntegrationFeatures(object.list = projects)
  combined.data <- projects %>% 
    Seurat::FindIntegrationAnchors(anchor.features = features) %>% 
    Seurat::IntegrateData() %>% 
    Seurat::ScaleData() %>% 
    Seurat::RunPCA(npcs = 30, verbose = FALSE) %>% 
    Seurat::RunUMAP(reduction = "pca", dims = 1:30)
  saveRDS(combined.data, file.path(outdir, "integration.seurat-cca.rds"))
  pdf(file.path(outdir, "integration.seurat-cca.pdf"))
  p1 <- Seurat::DimPlot(combined.data, reduction = "pca", group.by = "dataset")
  print(p1)
  p2 <- Seurat::DimPlot(combined.data, reduction = "umap", group.by = "dataset") 
  print(p2)
  dev.off()
  return(combined.data)
}

#' @section Seurat Large Data:
#' For very large datasets, Seruat provide two options that can improve efficiency and runtimes:
#' * Reciprocal PCA (RPCA): faster and more conservative 
#' * Reference-based integration
#' - quick start: <https://satijalab.org/seurat/articles/integration_large_datasets.html>
#' - RPCA: <https://satijalab.org/seurat/articles/integration_rpca.html>
#' @md
#' 
#' @param reference Sample IDs to used as integration 
#' @import Seurat
#' @export
#' @rdname Integration
#' @method Integration SeuratLargeData
#' @concept integration
#' 
Integration.SeuratLargeData <- function(csv, outdir, used, 
                                        reference = c(1,2)
                                        ){
  projects <- MergeFileData(csv) 
  projects <- lapply(projects, FUN = function(x) {
    Seurat::NormalizeData(x) %>% 
      Seurat::FindVariableFeatures(selection.method = "vst", nfeatures = 2000)
  })
  features <- Seurat::SelectIntegrationFeatures(object.list = projects)
  # difference with SeruatCCA, run PCA first then 
  projects <- lapply(projects, FUN = function(x) {
    x <- ScaleData(x, features = features, verbose = FALSE)
    x <- RunPCA(x, features = features, verbose = FALSE)
  })
  anchors <- FindIntegrationAnchors(projects, dims = 1:50,
                                    reference = reference, reduction = "rpca")
  combined.data <- IntegrateData(anchorset = anchors, dims = 1:50) %>%
    ScaleData(verbose = FALSE) %>%
    RunPCA(verbose = FALSE) %>%
    RunUMAP(dims = 1:50)
  DefaultAssay(combined.data) <- "integrated"
  saveRDS(combined.data, file.path(outdir, "integration.seurat-largedata.rds"))
  pdf(file.path(outdir, "integration.seurat-largedata.pdf"))
  p1 <- Seurat::DimPlot(combined.data, reduction = "pca", group.by = "dataset")
  print(p1)
  p2 <- Seurat::DimPlot(combined.data, reduction = "umap", group.by = "dataset") 
  print(p2)
  dev.off()
  return(combined.data) 
}


#' @section SCTransform Integration:
#' * source code: <https://github.com/satijalab/seurat>
#' * quick start: <https://satijalab.org/seurat/articles/integration_introduction.html#performing-integration-on-datasets-normalized-with-sctransform-1>
#'
#' @import Seurat
#' @export
#' @method Integration SCTransform 
#' @rdname Integration
#' 
Integration.SCTransform <- function(csv, outdir, used){
  projects <- MergeFileData(csv) %>% lapply(SCTransform)
  features <- Seurat::SelectIntegrationFeatures(object.list = projects, nfeatures = 5000)
  pojects <- Seurat::PrepSCTIntegration(object.list = projects, anchor.features = features)
  anchors <- Seurat::FindIntegrationAnchors(object.list = pojects, normalization.method = "SCT", anchor.features = features)
  combined.data <- Seurat::IntegrateData(anchorset = anchors, normalization.method = "SCT") %>%
    Seurat::RunPCA(verbose = FALSE)  %>%
    Seurat::RunUMAP(reduction = "pca", dims = 1:30)
  saveRDS(combined.data, file.path(outdir, "integration.sctransform.rds"))
  pdf(file.path(outdir, "integration.sctransform.pdf"))
  p1 <- Seurat::DimPlot(combined.data, reduction = "pca", group.by = "dataset")
  print(p1)
  p2 <- Seurat::DimPlot(combined.data, reduction = "umap", group.by = "dataset") 
  print(p2)
  dev.off()
  return(combined.data)
}


#' @section Integration Using Harmony:
#' * source code: <https://github.com/immunogenomics/harmony>
#' * quick start: <https://portals.broadinstitute.org/harmony/articles/quickstart.html>
#' @md
#'
#' @import Seurat
#' @importFrom harmony RunHarmony
#' @export
#' @rdname Integration
#' 
Integration.Harmony <- function(csv, outdir,used){
  projects <- MergeFileData(csv)
  combined.data <- merge(projects[[1]], tail(projects, length(projects)-1)) %>%
    Seurat::NormalizeData()  %>% 
    Seurat::FindVariableFeatures(selection.method = "vst", nfeatures = 2000) %>% 
    Seurat::ScaleData() %>% 
    Seurat::RunPCA()  %>%
    harmony::RunHarmony("dataset") 
  combined.data <- Seurat::RunUMAP(combined.data,
                                   dims = 1:ncol(combined.data[["harmony"]]), reduction = "harmony")
  saveRDS(combined.data, file.path(outdir, "integration.harmony.rds"))
  pdf(file.path(outdir, "integration.harmony.pdf"))
  p1 <- Seurat::DimPlot(object = combined.data, reduction = "pca", group.by = "dataset")
  p2 <- Seurat::VlnPlot(object = combined.data, features = "PC_1", group.by = "dataset")
  print(p1 + p2)
  p3 <- Seurat::DimPlot(object = combined.data, reduction = "harmony", group.by = "dataset")
  p4 <- Seurat::VlnPlot(object = combined.data, features = "harmony_1", group.by = "dataset")
  print(p3 + p4)
  dev.off()
  return(combined.data)
}


#' @section Integration Using Liger: 
#' * source code: <https://github.com/welch-lab/liger>
#' * quick start: <https://htmlpreview.github.io/?https://github.com/satijalab/seurat.wrappers/blob/master/docs/liger.html>
#' 
#' @import rliger
#' @import Seurat
#' @import SeuratWrappers
#' @export
#' @method Integration Liger
#' @rdname Integration
#' 
Integration.Liger <- function(csv, outdir, used){
  projects <- MergeFileData(csv)
  combined.data <- merge(projects[[1]], tail(projects, length(projects)-1)) %>%
    Seurat::NormalizeData()  %>% 
    Seurat::FindVariableFeatures() %>% 
    Seurat::ScaleData(split.by = "dataset", do.center = FALSE) %>% 
    SeuratWrappers::RunOptimizeALS(k = 20, lambda = 5, split.by = "dataset")  %>% 
    SeuratWrappers::RunQuantileNorm(split.by = "dataset") %>%
    Seurat::FindNeighbors(reduction = "iNMF", dims = 1:20) %>%
    Seurat::FindClusters(resolution = 0.55)
  combined.data <- Seurat::RunUMAP(combined.data,
                                   dims = 1:ncol(combined.data[["iNMF"]]), reduction = "iNMF")
  saveRDS(combined.data, file.path(outdir, "integration.liger.rds"))
  pdf(file.path(outdir, "integration.liger.pdf"))
  p1 <- Seurat::DimPlot(combined.data, reduction = "umap", group.by = c("dataset", "ident"), ncol = 2)
  print(p1)
  p2 <- Seurat::DimPlot(object = combined.data, reduction = "iNMF", group.by = c("dataset", "ident"), ncol = 2)
  print(p2)
  p3 <- Seurat::VlnPlot(object = combined.data, features = "iNMF_1", group.by = "dataset")
  print(p3)
  dev.off()
  return(combined.data)
}
