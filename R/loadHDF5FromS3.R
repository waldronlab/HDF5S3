options(
    pkgName = "HDF5S3"
)

.download_from_url <-
    function(url, location = ".")
{
    local_dir <- file.path(location, basename(url))
    if (!dir.exists(local_dir))
        dir.create(local_dir)
}

.download_from_s3 <-
    function(bucket = "multiassayexperiments", dataname, location = ".")
{
    STD_FILES <- c("se.rds", "assays.h5")

    local_dir <- file.path(location, dataname)
    if (!dir.exists(local_dir))
        dir.create(local_dir)

    for (i in STD_FILES) {
        aws.s3::save_object(
            object = file.path(dataname, i),
            bucket = bucket,
            file = file.path(local_dir, i)
        )
    }

    normalizePath(local_dir)
}

.files_exist <- function(bfc, rname) {
    file.exists(bfcrpath(bfc, paste0(rname, ".h5")),
        bfcrpath(bfc, paste0(rname, ".rds")))
}

.manage_local_file <- function(datafolder) {
    bfc <- getCache()
    dataname <- basename(datafolder)
    rids <- bfcquery(bfc, dataname, "rname")$rid
    if (!length(rids))
        stop("Can't update non-existing cache item(s)")

    cachedir <- bfccache(bfc)
    foldername <- paste0(gsub("file", "", basename(tempfile())), "_",
        dataname)
    fnames <- c("assays.h5", "se.rds")
    datacache <- file.path(cachedir, foldername)
    fileLoc <- file.path(datacache, fnames)
    if (!dir.exists(datacache))
        dir.create(datacache)
    inpaths <- file.path(datafolder, c("assays.h5", "se.rds"))
    file.copy(inpaths, fileLoc)

    suppressWarnings(
        bfcupdate(bfc, rids = rids, rpath = fileLoc)
    )

    unlink(datafolder, recursive = TRUE)

    bfcrpath(bfc, rids = rids)
}

.add_from_bucket <- function(
    bucket="multiassayexperiments", dataname="example", verbose = FALSE,
        force = FALSE)
{
    bfc <- cacheur::getCache()
    rids <- bfcquery(bfc, dataname, "rname")$rid
    if (!length(rids)) {
        file1 <- file.path("s3:/", bucket, dataname, "assays.h5")
        file2 <- file.path("s3:/", bucket, dataname, "se.rds")
        rids <- stats::setNames(c(
        names(bfcadd(bfc, paste0(dataname, ".h5"), file1, rtype = "web",
            download = FALSE)),
        names(bfcadd(bfc, paste0(dataname, ".rds"), file2, rtype = "web",
            download = FALSE))),
        c("assays.h5", "se.rds"))
    }
    if (!.files_exist(bfc, dataname) || force) {
        if (verbose)
            message("Downloading data for: ", dataname)
            dfolder <- .download_from_s3(bucket = bucket, dataname = dataname)
            .manage_local_file(dfolder)
    } else
        message("Data in cache: ", dataname)

    bfcrpath(bfc, rids = rids)
}
#' Pull HDF5Array files from the associated S3 bucket
#'
#' This function downloads and caches data from an Amazon S3 bucket and
#' loads it as a SummarizedExperiment with an HDF5Array
#'
#' @param bucket A string indicating the S3 bucket name
#' @param dataname The name of the folder as part of the bucket path
#' @param verbose logical (default FALSE) whether to report procedural steps
#' during download and load
#' @param force logical (default FALSE) whether to re-download and force load
#' resources from S3
#'
#'
#' @export loadDelayedSEFromS3
loadDelayedSEFromS3 <-
    function(bucket = "multiassayexperiments", dataname = "example",
        verbose = FALSE, force = FALSE)
{
    paths <- .add_from_bucket(bucket = bucket, dataname = dataname,
        verbose = verbose, force = force)
    path <- unique(dirname(paths))
    stopifnot(S4Vectors::isSingleString(path))
    HDF5Array::loadHDF5SummarizedExperiment(path)
}
