# Modified HCP pipeline
This project project freesurfer/MNI volume space data to HCP CIFTI files and downsample to resolutions < 32k.

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
HCP pipeline (minimum: files under HCPpipeline/global/)
BALSA_database
Freesurfer
FSL
Connectome workbench

## Order
### common space template
Only need to run these files once
1. createNewTemplateSpace.sh
2. downsample_template_generator.sh

### subject preprocessing
1. prep_fs_gifti.sh
2. goodvoxels_ribbon.sh
3. neocortical_resampler.sh
4. subcortical_resampler.sh

## To do
 - documantations
 - SPM output competablility
 - Batch processing script
 - Environment setup details
 - Test on YNiC server