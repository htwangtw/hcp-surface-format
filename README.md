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
1. CreateNewResTemplate.sh
2. DownsampleGroupTemplate.sh

### subject preprocessing
1. GiftiReady.sh
2. GoodvoxelsRibbon.sh
3. NeocorticalResampler.sh
4. SubcorticalResampler.sh
