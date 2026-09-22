# Input data and schemas

The figure scripts consume prepared CSVs. Generate the model CSVs with
`code/TRENDY_extraction_flux_locations.ipynb` after downloading the raw files.
Upstream datasets and annual model summaries are excluded from Git. No script
downloads data. Keep original inputs unchanged and record their provenance.

## Downloaded TRENDY inputs

Use the [Global Carbon Budget Data Hub](https://globalcarbonbudget.org/datahub/)
and its linked [model-data browser](https://mdosullivan.github.io/GCB/) to obtain
**TRENDYv10 (Global Carbon Budget 2021)** model outputs. Follow the provider's
access instructions if the required files are not directly downloadable. Obtain
global gridded fields rather than regional aggregates or budget spreadsheets.

Set `DATA_DIR` in the notebook to the directory containing the unpacked files:

```text
DATA_DIR/
├── CABLE-POP/
│   ├── CABLE-POP_S0_gpp.nc
│   ├── CABLE-POP_S0_cWood.nc
│   └── ...
├── ISBA-CTRIP/
├── LPX-Bern/
└── ORCHIDEE/
```

The default configuration requests all combinations of four models, three
scenarios (S0, S1, S2), and five variables (gpp, ra, cWood, cLeaf, cRoot): **60
files**. Change the model/variable/scenario lists to match your intended analysis
and update the R model selections accordingly. Each variable must have time,
latitude and longitude dimensions only, on a rectilinear grid with coordinate
units in degrees and valid time units/calendar metadata. Compressed archives
must be unpacked first. Custom directory layouts are supported by editing
`INPUT_TEMPLATE`, whose default is `{model}/{model}_{scenario}_{variable}.nc`.

`PROJECT`, `DATA_DIR`, `SITE_FILE`, and `OUTPUT_DIR` can all be customized in one
configuration cell. `DATA_DIR` may be outside the repository. Leave `OUTPUT_DIR`
at its default if you want the R scripts to find outputs automatically.

## Cabon observational tables (Figure 1 only)

Place the following under `data/cabon/`:

| File | Required columns | Meaning |
| --- | --- | --- |
| `Cabonetal_site_info.csv` | `Site`, `Start`, `End`, `On-site RW` | Site ID, inclusive observed year range, and on-site ring-width flag |
| `flux_onsite.csv` | `Site`, `Year`, `QC`, `GPP_dtrd` | Monthly detrended GPP; rows with QC > 0.7 are averaged by site/year |
| `rw_onsite.csv` | `Site`, `Year`, `IDcrn`, `RWI_dtrd` | Detrended ring-width series; first six IDcrn characters identify the site |

R's `read.csv()` converts `On-site RW` to `On.site.RW`; the script uses this
normalized name. Site IDs must match the model site mappings. Keep the original
Cabon columns: the observational join retains the original complete-case rule
(`na.omit()` across the joined table), so missing values in additional columns
can affect which observations are retained.

## Annual TRENDY tables (all figures)

Under `results/TRENDYv10/31_site_weighted/<MODEL>/`, supply
`<VARIABLE>_<SCENARIO>_31_site_weighted_yearly_mean.csv` with columns:

- `year`: numeric calendar year;
- `lat`, `lon`: numeric model coordinates, identical across variables/scenarios;
- `<VARIABLE>`: numeric `gpp`, `ra`, `cWood`, `cLeaf`, or `cRoot` as appropriate.

Rows are unique by `(year, lat, lon)`. Missing measurements may be `NA`, but keys
must not be missing. Additional CSV columns are ignored. See the main README
for the variables/scenarios required by each figure and the assumed units.
The included notebook performs nearest-cell selection, coordinate normalization,
equal-weight annual averaging and multiplication by cell area. It does not
regrid, normalize source units, or integrate fluxes over time. NetCDF inputs must
already have the required variable dimensions. CSV units are source units × m².

Figure 1 additionally needs
`results/TRENDYv10/31_site_weighted/<MODEL>_site_info.csv` with `lat`, `lon`, and
`SITE_ID`. Several sites may share a model grid cell. Each site must map to only
one distinct model coordinate for an unambiguous paired comparison. This is a
site-to-grid mapping, not Figure 4's generated S2 site list.

## Provenance and release requirements

The existing project identifies the observations as Cabon et al. (2022),
combining FLUXNET2015 and AmeriFlux observations at 31 sites, and the models as
TRENDYv10 / Global Carbon Budget. Source entry points recorded by the project:

- [Global Carbon Budget data](https://globalcarbonbudgetdata.org/)
- [Global Carbon Budget documentation](https://mdosullivan.github.io/GCB/)
- [FLUXNET2015](https://fluxnet.org/data/fluxnet2015-dataset/)
- [AmeriFlux](https://ameriflux.lbl.gov/)

These entry points do not identify an exact downloadable copy of the prepared
inputs. Before release, add the Cabon dataset accession, exact TRENDY experiment
metadata and access terms, and an archive DOI or checksums for the figure-ready
tables. The included notebook provides the extraction/weighting code and saves
a run manifest, but input files and exact dataset accessions must still be supplied.
