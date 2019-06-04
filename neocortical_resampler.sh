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
  echo " 	  neocortical_resampler.sh <R number> "
  exit 1
}

SURF_SUBJECTS_DIR="/home/hw1012/Project_surface_downsampling/data/surf"
FUNC_SUBJECTS_DIR="/home/hw1012/Project_surface_downsampling/data/vol"
TemplateFolder="/home/hw1012/HCPpipelines/global/templates"
FSL_STANDARD_DIR="/usr/local/fsl/data/standard"
DOWNSAMPLE_MESH=5
SmoothingFWHM=3
Sigma=$(echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l)

export SUBJECTS_DIR=${SURF_SUBJECTS_DIR}
SUBJ=${1}

cd ${FUNC_SUBJECTS_DIR}/${SUBJ}/HCP_pipeline_output

for HEMI in lh rh ; do
  if [ "${HEMI}" == "rh" ]; then
    HEMI_str='RIGHT';
    FS_RL_DIR='fs_R';
    FS_RL_FILE='fs_r';
    FS_RL_FILE2='R';
  elif [ "${HEMI}" == "lh" ]; then
    HEMI_str='LEFT';
    FS_RL_DIR='fs_L';
    FS_RL_FILE='fs_l';
    FS_RL_FILE2='L';
  fi

  ####### 2-3-1) make a cortical roi mask (exclude a medial wall)
  mris_convert \
    -c ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.thickness \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.white \
    ${HEMI}.thickness.native.shape.gii
  wb_command -set-structure \
    ${HEMI}.thickness.native.shape.gii \
    CORTEX_${HEMI_str}
  wb_command -metric-math \
    "var * -1" ${HEMI}.thickness.native.shape.gii \
    -var var \
    ${HEMI}.thickness.native.shape.gii
  wb_command -set-map-names \
    ${HEMI}.thickness.native.shape.gii -map 1 \
    ${HEMI}_Thickness
  wb_command -metric-palette \
    ${HEMI}.thickness.native.shape.gii \
    MODE_AUTO_SCALE_PERCENTAGE \
    -pos-percent 2 98 \
    -palette-name Gray_Interp \
    -disp-pos true -disp-neg true -disp-zero true
  wb_command -metric-math \
    "abs(thickness)" ${HEMI}.thickness.native.shape.gii \
    -var thickness \
    ${HEMI}.thickness.native.shape.gii
  wb_command -metric-palette \
    ${HEMI}.thickness.native.shape.gii \
    MODE_AUTO_SCALE_PERCENTAGE \
    -pos-percent 4 96 \
    -interpolate true \
    -palette-name videen_style \
    -disp-pos true -disp-neg false -disp-zero false

  wb_command -metric-math \
    "thickness > 0" ${HEMI}.roi.native.shape.gii \
    -var thickness \
    ${HEMI}.thickness.native.shape.gii
  wb_command -metric-fill-holes \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.midthickness.MNI.surf.gii \
    ${HEMI}.roi.native.shape.gii \
    ${HEMI}.roi.native.shape.gii
  wb_command -metric-remove-islands \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.midthickness.MNI.surf.gii \
    ${HEMI}.roi.native.shape.gii \
    ${HEMI}.roi.native.shape.gii
  wb_command -set-map-names \
    ${HEMI}.roi.native.shape.gii \
    -map 1 ${HEMI}_ROI

  ####### 2-3-2) concatenate a FS sphere-reg to HCP conte69 sphere to make a left-right symmetric surface template and resample cortical surfaces into the template mesh configuration
  cp -vf \
    ${TemplateFolder}/standard_mesh_atlases/${FS_RL_DIR}/fsaverage.${FS_RL_FILE2}.sphere.164k_${FS_RL_DIR}.surf.gii \
    ${HEMI}.sphere.164k_${FS_RL_FILE}.surf.gii
  cp -vf \
    ${TemplateFolder}/standard_mesh_atlases/${FS_RL_DIR}/${FS_RL_DIR}-to-fs_LR_fsaverage.${FS_RL_FILE2}_LR.spherical_std.164k_${FS_RL_DIR}.surf.gii \
    ${HEMI}.def_sphere.164k_${FS_RL_FILE}.surf.gii
  cp -vf \
    ${TemplateFolder}/standard_mesh_atlases/fsaverage.${FS_RL_FILE2}_LR.spherical_std.164k_fs_LR.surf.gii \
    ${HEMI}.sphere.164k_fs_LR.surf.gii
  cp -vf \
    ${TemplateFolder}/standard_mesh_atlases/${FS_RL_FILE2}.atlasroi.164k_fs_LR.shape.gii \
    ${HEMI}.atlasroi.164k_fs_LR.surf.gii
  cp -vf \
    ${TemplateFolder}/standard_mesh_atlases/${FS_RL_FILE2}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
    ${HEMI}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii
  cp -vf \
    ${TemplateFolder}/91282_Greyordinates/${FS_RL_FILE2}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii \
    ${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii

  mris_convert ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.sphere.reg \
    ${FUNC_SUBJECTS_DIR}/${SUBJ}/HCP_pipeline_output/${HEMI}.sphere.reg.native.surf.gii
  wb_command -set-structure \
    ${HEMI}.sphere.reg.native.surf.gii  \
    CORTEX_${HEMI_str} -surface-type SPHERICAL
  mris_convert ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.sphere \
    ${FUNC_SUBJECTS_DIR}/${SUBJ}/HCP_pipeline_output/${HEMI}.sphere.native.surf.gii
  wb_command -set-structure \
    ${HEMI}.sphere.native.surf.gii \
    CORTEX_${HEMI_str} -surface-type SPHERICAL

  wb_command -surface-sphere-project-unproject \
    ${HEMI}.sphere.reg.native.surf.gii \
    ${HEMI}.sphere.164k_${FS_RL_FILE}.surf.gii \
    ${HEMI}.def_sphere.164k_${FS_RL_FILE}.surf.gii \
    ${HEMI}.sphere.reg.reg_LR.native.surf.gii

  wb_command -surface-resample \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.white.MNI.surf.gii \
    ${HEMI}.sphere.reg.reg_LR.native.surf.gii \
    ${HEMI}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
    BARYCENTRIC \
    ${HEMI}.white.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii

  wb_command -surface-resample \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.midthickness.MNI.surf.gii \
    ${HEMI}.sphere.reg.reg_LR.native.surf.gii \
    ${HEMI}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
    BARYCENTRIC \
    ${HEMI}.mid.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii
  wb_command -surface-resample \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.pial.MNI.surf.gii \
    ${HEMI}.sphere.reg.reg_LR.native.surf.gii \
    ${HEMI}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
    BARYCENTRIC \
    ${HEMI}.pial.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii

  ####### 2-3-3) resample the goodvoxels using a concatenated surface registration field (sampling a goodvoxel, mask it and resample)
  wb_command -volume-to-surface-mapping \
    goodvoxels.nii.gz \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.midthickness.MNI.surf.gii \
    ${HEMI}.goodvoxels.MNI.func.gii \
    -ribbon-constrained \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.white.MNI.surf.gii \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.pial.MNI.surf.gii

  wb_command -metric-mask \
    ${HEMI}.goodvoxels.MNI.func.gii \
    ${HEMI}.roi.native.shape.gii \
    ${HEMI}.goodvoxels.MNI.func.gii

  wb_command -metric-resample \
    ${HEMI}.goodvoxels.MNI.func.gii \
    ${HEMI}.sphere.reg.reg_LR.native.surf.gii \
    ${HEMI}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
    ADAP_BARY_AREA \
    ${HEMI}.goodvoxels.${DOWNSAMPLE_MESH}k_fs_LR.MNI.func.gii \
    -area-surfs \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.midthickness.MNI.surf.gii \
    ${HEMI}.mid.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii \
    -current-roi ${HEMI}.roi.native.shape.gii

  wb_command -metric-mask \
    ${HEMI}.goodvoxels.${DOWNSAMPLE_MESH}k_fs_LR.MNI.func.gii \
    ${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii \
    ${HEMI}.goodvoxels.${DOWNSAMPLE_MESH}k_fs_LR.MNI.func.gii

  ####### 2-3-4) resample the time series using a concatenated surface registration field (sampling time series, mask it and resample)
  wb_command -volume-to-surface-mapping \
    ${FUNC_SUBJECTS_DIR}/${SUBJ}/prepro_functional_MNI.nii.gz \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.midthickness.MNI.surf.gii \
    ${HEMI}.timeseries.MNI.func.gii \
    -ribbon-constrained \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.white.MNI.surf.gii \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.pial.MNI.surf.gii \
    -volume-roi goodvoxels.nii.gz

  wb_command -metric-dilate \
    ${HEMI}.timeseries.MNI.func.gii \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.midthickness.MNI.surf.gii \
    10 \
    ${HEMI}.timeseries.MNI.func.gii \
    -nearest

  wb_command -metric-mask \
    ${HEMI}.timeseries.MNI.func.gii \
    ${HEMI}.roi.native.shape.gii \
    ${HEMI}.timeseries.MNI.func.gii

  wb_command -metric-resample \
    ${HEMI}.timeseries.MNI.func.gii \
    ${HEMI}.sphere.reg.reg_LR.native.surf.gii \
    ${HEMI}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
    ADAP_BARY_AREA \
    ${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
    -area-surfs \
    ${SURF_SUBJECTS_DIR}/${SUBJ}/surf/${HEMI}.midthickness.MNI.surf.gii \
    ${HEMI}.mid.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii \
    -current-roi ${HEMI}.roi.native.shape.gii

  wb_command -metric-mask \
    ${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
    ${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii \
    ${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii


####### 2-3-5) smooth the values
  wb_command -metric-smoothing \
    ${HEMI}.mid.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii \
    ${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
    ${Sigma} \
    ${HEMI}.s${SmoothingFWHM}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
    -roi ${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii

done
