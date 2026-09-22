# OVERVIEW
* This repository contains code for extracting annual GPP, cWood, cLeaf, and cRoot from TRENDYv10 datasets obtained from the Global Carbon Budget (https://globalcarbonbudgetdata.org/) under scenarios S0, S1, and S2, covering 31 flux locations with on-site ring-width measurements. This repository contains a TRENDY extraction notebook and four R scripts for the main figures in the paper below:

Ngoc B. Nguyen, Miao Zhang, and Trevor F. Keenan (2026). **“Long-term biomass growth unimpeded by short-term
photosynthetic decoupling”** Nature Plants. https://www.nature.com/articles/s41477-026-02418-1

# DATA AVAILABILITY
* Eddy-covariance GPP and tree-ring width data are obtained from the compilation provided by Antoine Cabon et al., Cross-biome synthesis of source versus sink limits to tree growth. Science 376, 758-761 (2022). DOI:10.1126/science.abm4875, which compiles eddy-covariance GPP from FLUXNET2015 (https://fluxnet.org/data/fluxnet2015-dataset) and AmeriFlux datasets (https://ameriflux.lbl.gov) with on-site Ring Width data observations at 31 sites. TRENDYv10 datasets are obtained from the Global Carbon Budget (https://mdosullivan.github.io/GCB/). All data used in this study are publicly available.

# AUTHORSHIP
* Ngoc B. Nguyen [1], Miao Zhang [1],[3],[4], Trevor F. Keenan [1],[2] (*corresponding authors: ngoc.nguyen@berkeley.edu; trevorkeenan@berkeley.edu)
* [1] Department of Environmental Science, Policy, and Management, University of California, Berkeley, CA, USA
* [2] Climate and Ecosystem Sciences Division, Lawrence Berkeley National Laboratory, Berkeley, CA, USA
* [3] School of Hydrology and Water Resources, Nanjing University of Information Science and Technology, Nanjing, 210044, China
* [4] Key Laboratory of Hydrometeorological Disaster Mechanism and Warning of Ministry of Water Resources, Nanjing University of Information Science and Technology, Nanjing, 210044, China

# CITATION
Ngoc B. Nguyen, Miao Zhang, and Trevor F. Keenan (2026). **“Long-term biomass growth unimpeded by short-term
photosynthetic decoupling”** Nature Plants. https://www.nature.com/articles/s41477-026-02418-1

## Prepare the model inputs

From the repository root, create the notebook environment and launch Jupyter:

```sh
conda env create -f environment.yml
conda activate source-sink-dynamics
jupyter lab code/TRENDY_extraction_flux_locations.ipynb
```


Obtain the **TRENDYv10 / Global Carbon Budget 2021** gridded NetCDF files via the
[Global Carbon Budget Data Hub](https://globalcarbonbudget.org/datahub/) and [model-data browser](https://mdosullivan.github.io/GCB/). Download/unpack files into `DATA_DIR`.
The notebook does not download files or require credentials in the repository.

Edit the notebook's **Configuration** cell before running all cells:

| Setting | Default and purpose |
| --- | --- |
| `PROJECT` | Repository root; detected from a notebook started in the root or `code/`. |
| `DATA_DIR` | `PROJECT/data/TRENDYv10/downloads`; location of downloaded, unpacked NetCDF inputs. |
| `SITE_FILE` | `PROJECT/data/cabon/Cabonetal_site_info.csv`; observed site coordinates. |
| `OUTPUT_DIR` | `PROJECT/results/TRENDYv10/31_site_weighted`; default matches all four R scripts. |
| `INPUT_TEMPLATE` | `{model}/{model}_{scenario}_{variable}.nc`, relative to `DATA_DIR`; customize for another download layout. |
| `MODELS` | ISBA-CTRIP, LPX-Bern, CABLE-POP, ORCHIDEE, ORCHIDEEv3, CLM5.0, LPJ-GUESS, CLASSIC, CLASSIC-N |
| `SCENARIOS` | S0, S1, S2. |
| `VARIABLES` | cLeaf, cRoot, cWood, gpp, ra. |
| `START_YEAR` | `None` includes all available years; an integer is an inclusive lower limit. Keep `None` for the default figures. |
| `N_JOBS` | At most two worker processes; set 1 for sequential execution or increase if memory and disk capacity permit. |


## Run the figures

Install R, clone or download this repository, and open a terminal in its root:

```sh
Rscript install-r-packages.R
# First complete the extraction notebook (or supply its prepared CSVs), then run:
Rscript code/Figure1_code.R
Rscript code/Figure2_code.R
Rscript code/Figure3_code.R
Rscript code/Figure4_code.R
```

The figures can run in any order. Each script creates its
own derived tables and figures

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

| Script | Annual variables | Scenarios | Other inputs |
| --- | --- | --- | --- |
| Figure 1 | `gpp`, `cWood` | S0, S1, S2 | All three Cabon et al. tables and each model's site mapping |
| Figure 2 | `gpp`, `cWood` | S1 | None |
| Figure 3 | `gpp`, `ra`, `cWood`, `cLeaf`, `cRoot` | S1 | None |
| Figure 4 | `gpp`, `cWood` | S0, S1, S2 | None |


## Configuration and scientific methods

All four scripts use the same sections: setup, parameters, analysis helpers,
input processing, and plot/export. Edit the **Parameters** section to select
models and scientific thresholds. 


  




