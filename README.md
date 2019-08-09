# Volume to HCP CIFTI
Python functions (and bash scripts) to project freesurfer/MNI volume space data to HCP CIFTI files and downsample to resolutions < 32k.

## Data input
Structural - Freesurfer recon-all results (white matter boarder visually inspected)  
Functional - Basic preprocessed resting state timeseries and average volumes in MNI space.   

fMRI preprocessing:
 - Motion correction
 - Noise regression
 - Band-pass filtered
 - No smoothing

Optional: 
 - Global signal regression

## Environment setup
Python:
- Python 3.6 and above is required

The following softwares and databases are required:
- [HCP pipeline](https://github.com/Washington-University/HCPpipelines) (minimum: files under HCPpipeline/global/)
- [BALSA_database](https://balsa.wustl.edu/study/show/WG33)
- [Freesurfer](https://surfer.nmr.mgh.harvard.edu/fswiki/DownloadAndInstall)
- [FSL](https://fsl.fmrib.ox.ac.uk)
- [Connectome workbench](https://www.humanconnectome.org/software/connectome-workbench)

After installation, the following environment variables are also needed by Python functions:
- `WB_DIR` = /path/to/workbench/binary/directory
- `HCP_PIPELINES_DIR` = /path/to/hcp/pipelines/repository
- `HCP_STANDARD_MESH_ATLASES_DIR` = /path/to/hcp/standard/meshes (under $HCP_PIPELINES_DIR/global/templates/standard_mesh_atlases by default)
- `HCP_BALSA_DIR` = /path/to/balsa/database

## Python [WIP]
An example of how to use the Python functions is included in `playground.py`

## Bash
The pipeline can be run in the following order
### common space template
Only need to run these files once
1. CreateNewResTemplate.sh
2. DownsampleGroupTemplate.sh

### subject preprocessing
1. GiftiReady.sh
2. GoodvoxelsRibbon.sh
3. NeocorticalResampler.sh
4. SubcorticalResampler.sh
