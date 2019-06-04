#!/bin/bash
set -e
#
#  environment: FSL and freesurfer binary added to path
# need to make this file spm competible
# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------
show_usage() {
  echo " This is a basic script to prepare freesurfer files ready for HCP pipeline."
  echo " The freesurfer files should be created through recon_all"
  echo " and the white mater surface should have been manually checked. "
  echo " The output files will be generated under the freesurfer directory surf/ and mri/"
  echo ""
  echo " Usage:"
  echo " 	  goodvoxels_ribbon.sh <R number> "
  exit 1
}


SURF_SUBJECTS_DIR="/home/hw1012/Project_surface_downsampling/data/surf"
FUNC_SUBJECTS_DIR="/home/hw1012/Project_surface_downsampling/data/vol"

export SUBJECTS_DIR=${SURF_SUBJECTS_DIR}
SUBJ=${1}

cd ${FUNC_SUBJECTS_DIR}/${SUBJ}
# mean_func.nii.gz to MNI space
applywarp -i RS.feat/mean_func.nii.gz \
  -o mean_func_MNI.nii.gz \
  -r RS.feat/reg/standard.nii.gz \
  -w RS.feat/reg/highres2standard_warp.nii.gz \
  --premat=RS.feat/reg/example_func2highres.mat

mkdir HCP_pipeline_output

echo "Creating cortical ribbons for ${SUBJ}..."
for HEMI in lh rh ; do

  wb_command -create-signed-distance-volume \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.white.MNI.surf.gii \
    ${FUNC_SUBJECTS_DIR}/${SUBJ}/mean_func_MNI.nii.gz \
    HCP_pipeline_output/${HEMI}.white.MNI.dist.nii.gz
  wb_command -create-signed-distance-volume \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.pial.MNI.surf.gii \
    ${FUNC_SUBJECTS_DIR}/${SUBJ}/mean_func_MNI.nii.gz \
    HCP_pipeline_output/${HEMI}.pial.MNI.dist.nii.gz
  fslmaths HCP_pipeline_output/${HEMI}.white.MNI.dist.nii.gz \
    -thr 0 -bin -mul 255 \
    HCP_pipeline_output/${HEMI}.white_thr0.MNI.dist.nii.gz
  fslmaths HCP_pipeline_output/${HEMI}.white_thr0.MNI.dist.nii.gz \
    -bin HCP_pipeline_output/${HEMI}.white_thr0.MNI.dist.nii.gz
  fslmaths HCP_pipeline_output/${HEMI}.pial.MNI.dist.nii.gz \
    -uthr 0 -abs -bin \
    -mul 255 HCP_pipeline_output/${HEMI}.pial_uthr0.MNI.dist.nii.gz
  fslmaths HCP_pipeline_output/${HEMI}.pial_uthr0.MNI.dist.nii.gz \
    -bin HCP_pipeline_output/${HEMI}.pial_uthr0.MNI.dist.nii.gz
  fslmaths HCP_pipeline_output/${HEMI}.pial_uthr0.MNI.dist.nii.gz \
    -mas HCP_pipeline_output/${HEMI}.white_thr0.MNI.dist.nii.gz \
    -mul 255 HCP_pipeline_output/${HEMI}.ribbon.nii.gz
  fslmaths HCP_pipeline_output/${HEMI}.ribbon.nii.gz \
    -bin -mul 1 HCP_pipeline_output/${HEMI}.ribbon.nii.gz
done

fslmaths HCP_pipeline_output/lh.ribbon.nii.gz \
  -add HCP_pipeline_output/rh.ribbon.nii.gz \
  HCP_pipeline_output/ribbon_only.nii.gz
 
####### 2-2. create a goodvoxel volume

echo "create a goodvoxel volume..."
fslmaths ${FUNC_SUBJECTS_DIR}/${SUBJ}/prepro_functional_MNI.nii.gz \
  -Tmean HCP_pipeline_output/mean \
  -odt float
fslmaths ${FUNC_SUBJECTS_DIR}/${SUBJ}/prepro_functional_MNI.nii.gz \
  -Tstd HCP_pipeline_output/std \
  -odt float

fslmaths HCP_pipeline_output/std \
  -div HCP_pipeline_output/mean \
  HCP_pipeline_output/cov
fslmaths HCP_pipeline_output/cov \
  -mas HCP_pipeline_output/ribbon_only.nii.gz \
  HCP_pipeline_output/cov_ribbon
fslmaths HCP_pipeline_output/cov_ribbon \
  -div `fslstats HCP_pipeline_output/cov_ribbon -M` \
  HCP_pipeline_output/cov_ribbon_norm
fslmaths HCP_pipeline_output/cov_ribbon_norm \
  -bin -s 5 \
  HCP_pipeline_output/SmoothNorm
fslmaths HCP_pipeline_output/cov_ribbon_norm \
  -s 5 \
  -div HCP_pipeline_output/SmoothNorm -dilD \
  HCP_pipeline_output/cov_ribbon_norm_s5
fslmaths HCP_pipeline_output/cov \
  -div `fslstats HCP_pipeline_output/cov_ribbon -M` \
  -div HCP_pipeline_output/cov_ribbon_norm_s5 \
  HCP_pipeline_output/cov_norm_modulate

STD=`fslstats HCP_pipeline_output/cov_norm_modulate -S`
MEAN=`fslstats HCP_pipeline_output/cov_norm_modulate -M`
Lower=`echo "$MEAN - ($STD * 0.5)" | bc -l`
Upper=`echo "$MEAN + ($STD * 0.5)" | bc -l`

fslmaths HCP_pipeline_output/cov_norm_modulate \
  -mas HCP_pipeline_output/ribbon_only.nii.gz \
  HCP_pipeline_output/cov_norm_modulate_ribbon
fslmaths \
  ${FUNC_SUBJECTS_DIR}/${SUBJ}/mean_func_MNI.nii.gz \
  -bin \
  HCP_pipeline_output/mask
fslmaths \
  HCP_pipeline_output/cov_norm_modulate \
  -thr $Upper -bin -sub HCP_pipeline_output/mask -mul -1 \
  HCP_pipeline_output/goodvoxels