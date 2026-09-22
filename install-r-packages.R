# Install only missing dependencies (or dplyr older than the required API).
# Usage from the repository root: Rscript install-r-packages.R
script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
installer <- if (length(script_arg)) sub("^--file=", "", script_arg[1]) else "install-r-packages.R"
source(file.path(dirname(normalizePath(installer)), "code", "common.R"))
missing <- ANALYSIS_PACKAGES[!vapply(ANALYSIS_PACKAGES, requireNamespace, logical(1), quietly = TRUE)]
if (requireNamespace("dplyr", quietly = TRUE) && packageVersion("dplyr") < "1.1.0") {
  missing <- union(missing, "dplyr")
}
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
unavailable <- ANALYSIS_PACKAGES[!vapply(ANALYSIS_PACKAGES, requireNamespace, logical(1), quietly = TRUE)]
if (length(unavailable)) stop("Installation failed for: ", paste(unavailable, collapse = ", "))
if (packageVersion("dplyr") < "1.1.0") stop("dplyr >= 1.1.0 is required.")
message("All figure dependencies are installed.")
