#!/bin/bash
set -e
#
#  environment: FSL and freesurfer binary added to path
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
  echo " 	  prep_fs_gifti.sh <R number> "
  exit 1
}


SURF_SUBJECTS_DIR="/home/hw1012/Project_surface_downsampling/data/surf"
HCP_STANDARD_DIR="/home/hw1012/HCPpipelines/global/templates/standard_mesh_atlases"
FSL_STANDARD_DIR="/usr/local/fsl/data/standard"
export SUBJECTS_DIR=${SURF_SUBJECTS_DIR}
SUBJ=${1}

cd ${SURF_SUBJECTS_DIR}/${SUBJ}
echo "Preprocessing ${SUBJ}..."
# 1.1 Get freesurfer data to MNI space warp field
# convert the mgz file to nifti
mri_convert mri/brain.mgz mri/brain.nii.gz

# reorienting the image to match the approximate 
# orientation of the standard template images (MNI152)
fslreorient2std mri/brain.nii.gz mri/brain.nii.gz 

echo "generate transformation matrix...."
flirt -in mri/brain.nii.gz \
  -ref ${FSL_STANDARD_DIR}/MNI152_T1_1mm_brain.nii.gz \
  -omat mri/transforms/fs_highres2standard.mat

echo "generate nonlinear warpfield..."
fnirt --ref=${FSL_STANDARD_DIR}/MNI152_T1_1mm_brain.nii.gz \
  --in=mri/brain.nii.gz \
  --aff=mri/transforms/fs_highres2standard.mat \
  --iout=mri/brain2MNI.nii.gz \
  --fout=mri/transforms/fs_highres2standard_warp.nii.gz
echo "generate inverse warpfield..."
invwarp -w mri/transforms/fs_highres2standard_warp.nii.gz \
  -o mri/transforms/standard2fs_highres_warp.nii.gz \
  -r mri/brain.nii.gz

#Find c_ras offset between FreeSurfer surface and volume and generate matrix to transform surfaces
cras=($(mri_info --cras mri/brain.nii.gz))
echo "1 0 0 ""${cras[0]}" > mri/c_ras.mat
echo "0 1 0 ""${cras[1]}" >> mri/c_ras.mat
echo "0 0 1 ""${cras[2]}" >> mri/c_ras.mat
echo "0 0 0 1" >> mri/c_ras.mat

for HEMI in lh rh ; do

  if [ "${HEMI}" == "rh" ]; then
    FS_RL_FILE2='R'
  elif [ "${HEMI}" == "lh" ]; then
    FS_RL_FILE2='L'
  fi

  # 1.2 generate white, pial, and mid-thickness gifti
  wb_shortcuts -freesurfer-resample-prep \
    surf/${HEMI}.white \
    surf/${HEMI}.pial \
    surf/${HEMI}.sphere.reg \
    ${HCP_STANDARD_DIR}/resample_fsaverage/fs_LR-deformed_to-fsaverage.${FS_RL_FILE2}.sphere.164k_fs_LR.surf.gii \
    surf/${HEMI}.midthickness.surf.gii \
    surf/${HEMI}.midthickness.164k_fs_LR.surf.gii \
    surf/${HEMI}.sphere.reg.surf.gii
  mris_convert surf/${HEMI}.pial surf/${HEMI}.pial.surf.gii
  mris_convert surf/${HEMI}.white surf/${HEMI}.white.surf.gii

  # apply cras
  wb_command -surface-apply-affine \
    surf/${HEMI}.pial.surf.gii \
    mri/c_ras.mat \
    surf/${HEMI}.pial.surf.gii
  wb_command -surface-apply-affine \
    surf/${HEMI}.white.surf.gii \
    mri/c_ras.mat \
    surf/${HEMI}.white.surf.gii
  wb_command -surface-apply-affine \
    surf/${HEMI}.midthickness.surf.gii \
    mri/c_ras.mat \
    surf/${HEMI}.midthickness.surf.gii

  # 1.3 register native space surface files to MNI space
  wb_command -surface-apply-warpfield \
    surf/${HEMI}.midthickness.surf.gii \
    mri/transforms/standard2fs_highres_warp.nii.gz \
    surf/${HEMI}.midthickness.MNI.surf.gii \
    -fnirt mri/transforms/fs_highres2standard_warp.nii.gz
  wb_command -surface-apply-warpfield \
    surf/${HEMI}.pial.surf.gii \
    mri/transforms/standard2fs_highres_warp.nii.gz \
    surf/${HEMI}.pial.MNI.surf.gii \
    -fnirt mri/transforms/fs_highres2standard_warp.nii.gz
  wb_command -surface-apply-warpfield \
    surf/${HEMI}.white.surf.gii \
    mri/transforms/standard2fs_highres_warp.nii.gz \
    surf/${HEMI}.white.MNI.surf.gii \
    -fnirt mri/transforms/fs_highres2standard_warp.nii.gz
done