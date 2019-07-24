#!/bin/bash
set -e
#
# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------
show_usage() {
  echo " create goodvoxel and ribbon mask for surface resampling"
  echo ""
  echo " Usage:"
  echo " 	  goodvoxels_ribbon.sh <R number> "
  exit 1
}

SUBJ=${1}

WDIR="/groups/labs/semwandering/Cohort_HCPpipeline"
DATA_DIR="${WDIR}/data"
HCP_STANDARD_DIR="${DATA_DIR}/external/HCPpipelines_global/templates/standard_mesh_atlases"
FSL_STANDARD_DIR="/usr/share/fsl-5.0/data/standard"
SURF_DIR="${DATA_DIR}/interim/${SUBJ}/Freesurfer"
FUNC_DIR="${DATA_DIR}/interim/${SUBJ}"
TMPDIR="${DATA_DIR}/tmp/${SUBJ}"
OUTDIR="${DATA_DIR}/processed/${SUBJ}"
FSLDIR="/usr/share/fsl-5.0"
. $FSLDIR/etc/fslconf/fsl.sh

cd ${WDIR}

echo "Preprocessing ${SUBJ}..."

echo "Creating cortical ribbons for ${SUBJ}..."

mkdir -p ${TMPDIR}

for HEMI in lh rh ; do
  echo "${HEMI}..."
  echo "signed distance volume - white"
  wb_command -create-signed-distance-volume \
    ${OUTDIR}/${HEMI}.white.MNI.surf.gii \
    ${FUNC_DIR}/mean_func_MNI.nii \
    ${TMPDIR}/${HEMI}.white.MNI.dist.nii.gz
    
  echo "signed distance volume - pial"
  wb_command -create-signed-distance-volume \
    ${OUTDIR}/${HEMI}.pial.MNI.surf.gii \
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
  
  echo "ribbon created"
  fslmaths ${TMPDIR}/${HEMI}.ribbon.nii.gz \
    -bin -mul 1 ${TMPDIR}/${HEMI}.ribbon.nii.gz
done

echo "Combine the voxel ribbons as ribbon_only.nii.gz"
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
  
echo "goodvoxels and ribbon created"
