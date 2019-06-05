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

SUBJ=${1}

HOME="/home/hw1012"
WDIR="${HOME}/HCP_downsampling"
DATA_DIR="${WDIR}/data"
HCP_STANDARD_DIR="${DATA_DIR}/external/HCPpipelines_global/templates/standard_mesh_atlases"
FSL_STANDARD_DIR="/usr/local/fsl/data/standard"
SURF_DIR="${DATA_DIR}/interim/${SUBJ}/Freesurfer"
FUNC_DIR="${DATA_DIR}/interim/${SUBJ}"
TMPDIR="${DATA_DIR}/tmp"

cd ${WDIR}

echo "Preprocessing ${SUBJ}..."

echo "Creating cortical ribbons for ${SUBJ}..."
for HEMI in lh rh ; do

  wb_command -create-signed-distance-volume \
    ${TMPDIR}/${HEMI}.white.MNI.surf.gii \
    ${FUNC_DIR}/mean_func_MNI.nii \
    ${TMPDIR}/${HEMI}.white.MNI.dist.nii.gz
  wb_command -create-signed-distance-volume \
    ${TMPDIR}/${HEMI}.pial.MNI.surf.gii \
    ${FUNC_DIR}/mean_func_MNI.nii \
    ${TMPDIR}/${HEMI}.pial.MNI.dist.nii.gz
  fslmaths ${TMPDIR}/${HEMI}.white.MNI.dist.nii.gz \
    -thr 0 -bin -mul 255 \
    ${TMPDIR}/${HEMI}.white_thr0.MNI.dist.nii.gz
  fslmaths ${TMPDIR}/${HEMI}.white_thr0.MNI.dist.nii.gz \
    -bin ${TMPDIR}/${HEMI}.white_thr0.MNI.dist.nii.gz
  fslmaths ${TMPDIR}/${HEMI}.pial.MNI.dist.nii.gz \
    -uthr 0 -abs -bin \
    -mul 255 ${TMPDIR}/${HEMI}.pial_uthr0.MNI.dist.nii.gz
  fslmaths ${TMPDIR}/${HEMI}.pial_uthr0.MNI.dist.nii.gz \
    -bin ${TMPDIR}/${HEMI}.pial_uthr0.MNI.dist.nii.gz
  fslmaths ${TMPDIR}/${HEMI}.pial_uthr0.MNI.dist.nii.gz \
    -mas ${TMPDIR}/${HEMI}.white_thr0.MNI.dist.nii.gz \
    -mul 255 ${TMPDIR}/${HEMI}.ribbon.nii.gz
  fslmaths ${TMPDIR}/${HEMI}.ribbon.nii.gz \
    -bin -mul 1 ${TMPDIR}/${HEMI}.ribbon.nii.gz
done

fslmaths ${TMPDIR}/lh.ribbon.nii.gz \
  -add ${TMPDIR}/rh.ribbon.nii.gz \
  ${TMPDIR}/ribbon_only.nii.gz
 
####### 2-2. create a goodvoxel volume

echo "create a goodvoxel volume..."
fslmaths ${FUNC_DIR}/prepro_func_MNI.nii \
  -Tmean ${TMPDIR}/mean \
  -odt float
fslmaths ${FUNC_DIR}/prepro_func_MNI.nii \
  -Tstd ${TMPDIR}/std \
  -odt float

fslmaths ${TMPDIR}/std \
  -div ${TMPDIR}/mean \
  ${TMPDIR}/cov
fslmaths ${TMPDIR}/cov \
  -mas ${TMPDIR}/ribbon_only.nii.gz \
  ${TMPDIR}/cov_ribbon
fslmaths ${TMPDIR}/cov_ribbon \
  -div `fslstats ${TMPDIR}/cov_ribbon -M` \
  ${TMPDIR}/cov_ribbon_norm
fslmaths ${TMPDIR}/cov_ribbon_norm \
  -bin -s 5 \
  ${TMPDIR}/SmoothNorm
fslmaths ${TMPDIR}/cov_ribbon_norm \
  -s 5 \
  -div ${TMPDIR}/SmoothNorm -dilD \
  ${TMPDIR}/cov_ribbon_norm_s5
fslmaths ${TMPDIR}/cov \
  -div `fslstats ${TMPDIR}/cov_ribbon -M` \
  -div ${TMPDIR}/cov_ribbon_norm_s5 \
  ${TMPDIR}/cov_norm_modulate

STD=`fslstats ${TMPDIR}/cov_norm_modulate -S`
MEAN=`fslstats ${TMPDIR}/cov_norm_modulate -M`
Lower=`echo "$MEAN - ($STD * 0.5)" | bc -l`
Upper=`echo "$MEAN + ($STD * 0.5)" | bc -l`

fslmaths ${TMPDIR}/cov_norm_modulate \
  -mas ${TMPDIR}/ribbon_only.nii.gz \
  ${TMPDIR}/cov_norm_modulate_ribbon

fslmaths \
  ${TMPDIR}/mean \
  -abs \
  -bin \
  ${TMPDIR}/mask

fslmaths \
  ${TMPDIR}/cov_norm_modulate \
  -thr $Upper -bin -sub ${TMPDIR}/mask -mul -1 \
  ${TMPDIR}/goodvoxels