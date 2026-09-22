# Source–sink dynamics

Analysis code for **“Long-term biomass growth unimpeded by short-term
photosynthetic decoupling”** by Ngoc B. Nguyen, Miao Zhang, and Trevor F. Keenan.
This repository contains a TRENDY extraction notebook and four standalone R scripts for the main figures.

## Prepare the model inputs

From the repository root, create the notebook environment and launch Jupyter:

```sh
conda env create -f environment.yml
conda activate source-sink-dynamics
jupyter lab code/TRENDY_extraction_flux_locations.ipynb
```

If an environment with this name already exists, update it with
`conda env update -n source-sink-dynamics -f environment.yml`.
Select its Python kernel in Jupyter. If needed, register it from the activated
environment with `python -m ipykernel install --user --name source-sink-dynamics`.

Obtain the **TRENDYv10 / Global Carbon Budget 2021** gridded NetCDF files via the
[Global Carbon Budget Data Hub](https://globalcarbonbudget.org/datahub/) and its
linked [model-data browser](https://mdosullivan.github.io/GCB/). Follow the
provider's access instructions for files not directly available. Select v10,
not a newer TRENDY release, and download/unpack files into `DATA_DIR`.
The notebook does not download files or require credentials in the repository.
See [data/README.md](data/README.md) for the required layout and variables.

Edit the notebook's **Configuration** cell before running all cells:

| Setting | Default and purpose |
| --- | --- |
| `PROJECT` | Repository root; detected from a notebook started in the root or `code/`. Can be an explicit `Path("/your/project")`. |
| `DATA_DIR` | `PROJECT/data/TRENDYv10/downloads`; location of downloaded, unpacked NetCDF inputs. May point to an external drive. |
| `SITE_FILE` | `PROJECT/data/cabon/Cabonetal_site_info.csv`; observed site coordinates and selection flags. |
| `OUTPUT_DIR` | `PROJECT/results/TRENDYv10/31_site_weighted`; default matches all four R scripts. |
| `INPUT_TEMPLATE` | `{model}/{model}_{scenario}_{variable}.nc`, relative to `DATA_DIR`; customize for another download layout. |
| `MODELS` | ISBA-CTRIP, LPX-Bern, CABLE-POP, ORCHIDEE, covering current figure defaults. |
| `SCENARIOS` | S0, S1, S2. |
| `VARIABLES` | cLeaf, cRoot, cWood, gpp, ra. |
| `START_YEAR` | `None` includes all available years; an integer is an inclusive lower limit. Keep `None` for the default figures. |
| `N_JOBS` | At most two worker processes; set 1 for sequential execution or increase if memory and disk capacity permit. |

Optional environment overrides are `SOURCE_SINK_ROOT`, `TRENDY_DATA_DIR`,
`TRENDY_SITE_FILE`, and `TRENDY_OUTPUT_DIR`. The latter three configure the
notebook only; the R scripts use their standard layout under `SOURCE_SINK_ROOT`.
If you redirect extraction outputs, copy them into that layout or set the R
root to a directory containing that layout before running figures.

Run the notebook from top to bottom. Its preflight checks all requested files,
columns and grids. It writes annual variable CSVs, `<MODEL>_site_info.csv`
mappings for Figure 1, `coordinate_audit.csv`, and `extraction_manifest.json`.
Check successful completion before running the R scripts. Rerunning replaces
matching outputs; a failed parallel run can leave a mixture of old and newly
completed files. Use a separate `OUTPUT_DIR` when testing new inputs.

Extraction preserves the supplied notebook's equal-weight annual means,
nearest-cell selection and multiplication by cell area. Source units are
multiplied by m²; fluxes are not integrated over the year. The notebook explains
coordinate normalization, calendars, area approximations and unsupported grids.

## Run the figures

Install R, clone or download this repository, and open a terminal in its root:

```sh
Rscript install-r-packages.R
Rscript tests/check_helpers.R
# First complete the extraction notebook (or supply its prepared CSVs), then run:
Rscript code/Figure1_code.R
Rscript code/Figure2_code.R
Rscript code/Figure3_code.R
Rscript code/Figure4_code.R
```

The figures are independent: they can run in any order. Each script creates its
own derived tables and figures; Figure 4 creates its own site lists. Existing
outputs with the same names are overwritten. Package installation happens only
when the installer is run, never implicitly during an analysis.

In RStudio, open the repository as a project or set its root as the working
directory, then run `source("code/Figure1_code.R")` (and similarly for Figures
2–4). You can also run `Rscript Figure1_code.R` from `code/`, or give Rscript an
absolute script path from another directory. For line-by-line interactive use,
set the working directory to the repository root or `code/` before the setup block.

By default, data and results are located relative to the scripts' repository.
To use a separate directory with the same input layout:

```sh
SOURCE_SINK_ROOT=/path/to/analysis-data Rscript code/Figure4_code.R
```

In R, use `Sys.setenv(SOURCE_SINK_ROOT = "/path/to/analysis-data")` before
sourcing a script. This override controls **both inputs and outputs**. Remove it
with `Sys.unsetenv("SOURCE_SINK_ROOT")` to return to the repository defaults.

## Required inputs

The R scripts start from **annual, area-multiplied TRENDYv10 CSVs**. Generate
these with `code/TRENDY_extraction_flux_locations.ipynb` from downloaded NetCDF
files, or supply equivalent prepared CSVs. The notebook uses the historical
`31_site_weighted` naming convention; it counts each occupied grid cell once.

```text
source_sink_dynamics/
├── code/
│   ├── TRENDY_extraction_flux_locations.ipynb
│   ├── common.R
│   └── Figure1_code.R ... Figure4_code.R
├── data/cabon/
│   ├── Cabonetal_site_info.csv
│   ├── flux_onsite.csv
│   └── rw_onsite.csv
└── results/TRENDYv10/31_site_weighted/
    ├── <MODEL>_site_info.csv
    └── <MODEL>/
        ├── gpp_<SCENARIO>_31_site_weighted_yearly_mean.csv
        ├── cWood_<SCENARIO>_31_site_weighted_yearly_mean.csv
        ├── ra_S1_31_site_weighted_yearly_mean.csv
        ├── cLeaf_S1_31_site_weighted_yearly_mean.csv
        └── cRoot_S1_31_site_weighted_yearly_mean.csv
```

`<SCENARIO>` is `S0`, `S1`, or `S2`. Filenames and model names are case-sensitive.
The scripts treat these scenario labels as supplied by TRENDYv10; they do not
create simulations. See [data/README.md](data/README.md) for schemas and provenance.

| Script | Annual variables | Scenarios | Other inputs |
| --- | --- | --- | --- |
| Figure 1 | `gpp`, `cWood` | S0, S1, S2 | All three Cabon tables and each model's site mapping |
| Figure 2 | `gpp`, `cWood` | S1 | None |
| Figure 3 | `gpp`, `ra`, `cWood`, `cLeaf`, `cRoot` | S1 | None |
| Figure 4 | `gpp`, `cWood` | S0, S1, S2 | None |

Annual tables must contain numeric `year`, `lat`, `lon`, and a column named for
the variable. Each `(year, lat, lon)` key must be unique. Extra columns such as
old CSV row indices are ignored. Coordinates must agree exactly across files.
The extraction multiplies source values by cell area (m²). For source fluxes
in kg C m⁻² s⁻¹ and pools in kg C m⁻², the resulting CSV units are kg C s⁻¹ and
kg C respectively. The R ratios assume consistent source carbon units and
spatial weighting, with fluxes on a per-second basis. No unit normalization is
performed: inspect `source_units` in the audit and check the downloaded files.
Values and units are not inferred or repaired automatically.

## Configuration and scientific methods

All four scripts use the same sections: setup, parameters, analysis helpers,
input processing, and plot/export. Edit the **Parameters** section to select
models and scientific thresholds. Existing model choices are preserved:
Figure 1 uses ISBA-CTRIP, LPX-Bern, CABLE-POP; Figures 2 and 4 add ORCHIDEE;
Figure 3 uses CABLE-POP, ISBA-CTRIP, ORCHIDEE, LPX-Bern in that order.
Other models require the corresponding inputs before they can be added.

- **Figure 1:** matches model output to on-site ring-width observations and each
  site's inclusive `Start`–`End` measurement interval. CLM5.0 uses years before
  2020. Joins GPP and nonzero wood stocks before calculating wood increments.
  Pearson correlation is calculated after linearly detrending both series
  against observation positions, with at least four finite paired observations.
  Observed GPP is averaged by year after `QC > 0.7`; correlations with detrended
  ring width are averaged across ring series within each site. Paired t-tests
  match model and observed correlations by `SITE_ID`. The displayed sample size
  is the number of S2 model sites, not necessarily the number of paired test
  observations. Stars mean p < 0.05, 0.01, and 0.001; no multiple-test adjustment
  is applied. Too few pairs or an undefined test yields no star.
- **Figure 2:** uses S1 after 1950; CLM5.0 additionally ends before 2020.
  Zero GPP and wood stocks are removed. Correlation requires at least 40 paired
  finite increments. The response ratio preserves the original formula:
  `log(fitted GPP end / start) / log(fitted cWood end / start)`, with linear
  fits against year. Nonpositive fitted endpoints, a zero denominator, and
  nonfinite results are excluded. Retains beta in [-5, 10]. The annotation
  reports a regression over individual site values; plotted points and whiskers
  are model medians and interquartile ranges.
- **Figure 3:** uses S1 after 1950, excluding zero and missing values separately
  for each variable; CLM5.0 ends before 2020. Panel a divides mean respiration
  or mean annual pool increments by mean GPP, multiplying by 100. Pool
  increments are converted to per-second units using a fixed 365-day year.
  Panel b fits each variable against observation positions and reports the
  fitted first-to-last percent change. Historical `p_*` CSV columns are
  **binary indicators** of slope p < 0.05, not p-values. Fewer than three points
  or a zero fitted starting value produces NA. Panel b pools sites complete
  across all five variables and retains the original LPJ-GUESS plotting
  exclusion. The label describes available years; an end year of 2020 is not
  imposed for other models.
- **Figure 4:** uses years after 1900. Calculates wood increments before joining
  to GPP, removes missing increments and zero wood stocks, and removes annual
  increments outside each site's mean ± 3 SD separately for each scenario.
  Computes `increment / GPP * 100` with increments converted to per-second
  units. Shaded bands are normal-approximation 95% intervals across sites:
  mean ± `qnorm(0.975) * sd / sqrt(n)`. Site membership may differ by year and
  scenario. The site CSV and displayed n are unique S2 coordinates retained
  after this filtering. **No −10% whole-site ratio screen is applied.** A site
  with fewer than two increments has undefined SD and is dropped by the filter.
  Trend stars use unrounded slope p-values. CSVs are computed from current
  parameters; the `3sd` filename assumes the default threshold of 3.

All increments are differences between consecutive *retained* observations.
The first retained observation at each site has no increment. Missing years are
not filled, and increments spanning gaps are not divided by the gap length.
Use continuous annual inputs to interpret them as one-year increments. Detrend
and Figure 3 trend fits retain the original use of row positions rather than
elapsed calendar time. These assumptions matter if upstream data have gaps.

## Outputs and checks

See [results/README.md](results/README.md) for filenames. Tables have headers and
no synthetic row-number column. Scripts retain intermediate results in memory,
read each needed annual file once per script, and use a fixed random seed for
plot jitter and label placement. They fail with descriptive messages for missing
files, missing columns, duplicate annual keys, and required empty analysis data.
Check inputs rather than replacing missing model results with zeros.

Each completed script saves `FigureN_sessionInfo.txt` with its R and loaded
package versions. The refactor was exercised with the available repository
inputs under R 4.5.0. Dependencies tested: dplyr 1.2.1, ggplot2 4.0.3, ggrepel
0.9.6, patchwork 1.3.2, purrr 1.2.2, tibble 3.2.1, tidyr 1.3.2. dplyr >= 1.1.0
is required. `install-r-packages.R` installs missing dependencies from CRAN and
updates dplyr only when below this minimum; it does not lock all versions.
For an archival release, record a reviewed `renv.lock` from the final analysis
environment and archive the required input tables. Session logs describe a run
but are not a substitute for a dependency lockfile or archived inputs.

`environment.yml` declares the extraction notebook's Python dependencies
(Python 3.11, JupyterLab, ipykernel, numpy, pandas, xarray, netCDF4 and joblib).
It is not an exact lockfile; the extraction manifest records actual package
versions. Python is needed for raw-data extraction, but not for rerunning R
figures from existing CSVs.

## Changes affecting interpretation

The refactor removes redundant libraries and repeated reads, unifies paths, and
fixes Figure 1's inconsistent intermediate filenames. It also corrects handling
of missing paired values during detrending and explicitly matches sites for
Figure 1 paired tests; those corrections can change Figure 1 correlations and
significance labels. Invalid regressions no longer silently become zero change.
Figure 4 significance thresholds use unrounded p-values, and plot axes adapt to
the selected number of models. Numerical results should be reviewed before a
publication release; these are documented fixes, not a claim of bitwise identity
with every older script output.

## Release checklist

- Archive the exact input datasets and final generated tables; add precise data
  accessions, checksums and processing metadata. The extraction notebook is included.
- Confirm the final manuscript citation and add `CITATION.cff`.
- Choose a software license and document upstream data licenses.
- Review model selections, figures, and statistical corrections; lock the final
  R environment and archive a tagged release.

Correspondence: ngoc.nguyen@berkeley.edu and trevorkeenan@berkeley.edu.
