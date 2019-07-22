#!/bin/bash - 
#===============================================================================
#
#          FILE: GiftiReady.sh
# 
#         USAGE: ./GiftiReady.sh 
# 
#   DESCRIPTION: Convert Freesurfer recon_all output  to GIFTI format 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Hao-Ting Wang (PostDoc), htwangtw@gmail.com
#  ORGANIZATION: University of York
#       CREATED: 08/06/19 12:52:11
#      REVISION:  ---
#===============================================================================

show_usage() {
  echo " This is a basic script to prepare freesurfer files ready for HCP pipeline."
  echo " The freesurfer files should be created through recon_all"
  echo " and the white mater surface should have been manually checked. "
  echo " The output files will be generated under the tmp/ directory"
  echo ""
  echo " Usage:"
  echo " 	  GiftiReady.sh <R number> "
  exit 1
}

SUBJ=${1}

HOME="/home/hw1012"
WDIR="${HOME}/HCP_downsampling"
DATA_DIR="${WDIR}/data"
HCP_STANDARD_DIR="${DATA_DIR}/external/HCPpipelines_global/templates/standard_mesh_atlases"
FSL_STANDARD_DIR="/usr/local/fsl/data/standard"
SURF_DIR="${DATA_DIR}/interim/${SUBJ}/Freesurfer"
TMPDIR="${DATA_DIR}/tmp"
OUTDIR="${DATA_DIR}/processed/${SUBJ}"

mkdir -p ${TMPDIR}
mkdir -p ${OUTDIR}

cd ${WDIR}

echo "Preprocessing ${SUBJ}..."

# 1.1 Get freesurfer data to MNI space warp field
# convert the mgz file to nifti
mri_convert  ${SURF_DIR}/mri/brain.mgz  ${OUTDIR}/fs_highres.nii.gz

# reorienting the image to match the approximate 
# orientation of the standard template images (MNI152)
fslreorient2std ${OUTDIR}/fs_highres.nii.gz ${OUTDIR}/fs_highres.nii.gz 

echo "generate transformation matrix...."
flirt -in ${OUTDIR}/fs_highres.nii.gz \
  -ref ${FSL_STANDARD_DIR}/MNI152_T1_1mm_brain.nii.gz \
  -omat ${OUTDIR}/fs_highres2standard.mat

echo "generate nonlinear warpfield..."
fnirt --ref=${FSL_STANDARD_DIR}/MNI152_T1_1mm_brain.nii.gz \
  --in=${OUTDIR}/fs_highres.nii.gz \
  --aff=${OUTDIR}/fs_highres2standard.mat \
  --iout=${OUTDIR}/fs_highres2MNI.nii.gz \
  --fout=${OUTDIR}/fs_highres2standard_warp.nii.gz
echo "generate inverse warpfield..."
invwarp -w ${OUTDIR}/fs_highres2standard_warp.nii.gz \
  -o ${OUTDIR}/standard2fs_highres_warp.nii.gz \
  -r ${OUTDIR}/fs_highres.nii.gz

#Find c_ras offset between FreeSurfer surface and volume and generate matrix to transform surfaces
cras=($(mri_info --cras ${OUTDIR}/fs_highres.nii.gz))
echo "1 0 0 ""${cras[0]}" >> ${OUTDIR}/c_ras.mat
echo "0 1 0 ""${cras[1]}" >> ${OUTDIR}/c_ras.mat
echo "0 0 1 ""${cras[2]}" >> ${OUTDIR}/c_ras.mat
echo "0 0 0 1" >> ${OUTDIR}/c_ras.mat

for HEMI in lh rh ; do

  if [ "${HEMI}" == "rh" ]; then
    FS_RL='R'
  elif [ "${HEMI}" == "lh" ]; then
    FS_RL='L'
  fi

  # 1.2 generate white, pial, and mid-thickness gifti
  wb_shortcuts -freesurfer-resample-prep \
    ${SURF_DIR}/surf/${HEMI}.white \
    ${SURF_DIR}/surf/${HEMI}.pial \
    ${SURF_DIR}/surf/${HEMI}.sphere.reg \
    ${HCP_STANDARD_DIR}/resample_fsaverage/fs_LR-deformed_to-fsaverage.${FS_RL}.sphere.164k_fs_LR.surf.gii \
    ${OUTDIR}/${HEMI}.midthickness.surf.gii \
    ${OUTDIR}/${HEMI}.midthickness.164k_fs_LR.surf.gii \
    ${OUTDIR}/${HEMI}.sphere.reg.surf.gii
  mris_convert ${SURF_DIR}/surf/${HEMI}.pial ${OUTDIR}/${HEMI}.pial.surf.gii
  mris_convert ${SURF_DIR}/surf/${HEMI}.white ${OUTDIR}/${HEMI}.white.surf.gii

  # apply cras
  wb_command -surface-apply-affine \
    ${OUTDIR}/${HEMI}.pial.surf.gii \
    ${OUTDIR}/c_ras.mat \
    ${OUTDIR}/${HEMI}.pial.surf.gii
  wb_command -surface-apply-affine \
    ${OUTDIR}/${HEMI}.white.surf.gii \
    ${OUTDIR}/c_ras.mat \
    ${OUTDIR}/${HEMI}.white.surf.gii
  wb_command -surface-apply-affine \
    ${OUTDIR}/${HEMI}.midthickness.surf.gii \
    ${OUTDIR}/c_ras.mat \
    ${OUTDIR}/${HEMI}.midthickness.surf.gii

  # 1.3 register native space surface files to MNI space
  wb_command -surface-apply-warpfield \
    ${OUTDIR}/${HEMI}.midthickness.surf.gii \
    ${OUTDIR}/standard2fs_highres_warp.nii.gz \
    ${OUTDIR}/${HEMI}.midthickness.MNI.surf.gii \
    -fnirt ${OUTDIR}/fs_highres2standard_warp.nii.gz
  wb_command -surface-apply-warpfield \
    ${OUTDIR}/${HEMI}.pial.surf.gii \
    ${OUTDIR}/standard2fs_highres_warp.nii.gz \
    ${OUTDIR}/${HEMI}.pial.MNI.surf.gii \
    -fnirt ${OUTDIR}/fs_highres2standard_warp.nii.gz
  wb_command -surface-apply-warpfield \
    ${OUTDIR}/${HEMI}.white.surf.gii \
    ${OUTDIR}/standard2fs_highres_warp.nii.gz \
    ${OUTDIR}/${HEMI}.white.MNI.surf.gii \
    -fnirt ${OUTDIR}/fs_highres2standard_warp.nii.gz
done
