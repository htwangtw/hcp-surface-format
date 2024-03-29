#!/bin/bash
set -e
#
# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------
show_usage() {
  echo " Sample neocortical time series data to HCP format"
  echo ""
  echo " Usage:"
  echo " 	  neocortical_resampler.sh <R number> "
  exit 1
}
SUBJ=${1}

WDIR="/groups/labs/semwandering/Cohort_HCPpipeline"
DATA_DIR="${WDIR}/data"
HCP_STANDARD_DIR="${DATA_DIR}/external/HCPpipelines_global/templates/"
FSL_STANDARD_DIR="/usr/share/fsl-5.0/data/standard"
SURF_DIR="${DATA_DIR}/interim/${SUBJ}/Freesurfer"
FUNC_DIR="${DATA_DIR}/interim/${SUBJ}/prepro_func_MNI.nii" # change here if you want a GSR version
TMPDIR="${DATA_DIR}/tmp/${SUBJ}"
OUTDIR="${DATA_DIR}/processed/${SUBJ}"
FSLDIR="/usr/share/fsl-5.0"
. $FSLDIR/etc/fslconf/fsl.sh

# initialise freesurfer
. /etc/freesurfer/5.3/freesurfer.sh
# initialize fsl
export FSLDIR="/usr/share/fsl-5.0"


cd ${WDIR}
DOWNSAMPLE_MESH=5
SmoothingFWHM=3
Sigma=$(echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l)

mkdir -p $OUTDIR

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
  echo "$HEMI"
  echo "make a cortical roi mask (exclude a medial wall)"
  mris_convert \
    -c ${SURF_DIR}/surf/${HEMI}.thickness \
    ${SURF_DIR}/surf/${HEMI}.white \
    ${TMPDIR}/${HEMI}.thickness.native.shape.gii
  wb_command -set-structure \
    ${TMPDIR}/${HEMI}.thickness.native.shape.gii \
    CORTEX_${HEMI_str}
  wb_command -metric-math \
    "var * -1" ${TMPDIR}/${HEMI}.thickness.native.shape.gii \
    -var var \
    ${TMPDIR}/${HEMI}.thickness.native.shape.gii
  wb_command -set-map-names \
    ${TMPDIR}/${HEMI}.thickness.native.shape.gii -map 1 \
    ${HEMI}_Thickness
  wb_command -metric-palette \
    ${TMPDIR}/${HEMI}.thickness.native.shape.gii \
    MODE_AUTO_SCALE_PERCENTAGE \
    -pos-percent 2 98 \
    -palette-name Gray_Interp \
    -disp-pos true -disp-neg true -disp-zero true
  wb_command -metric-math \
    "abs(thickness)" ${TMPDIR}/${HEMI}.thickness.native.shape.gii \
    -var thickness \
    ${TMPDIR}/${HEMI}.thickness.native.shape.gii
  wb_command -metric-palette \
    ${TMPDIR}/${HEMI}.thickness.native.shape.gii \
    MODE_AUTO_SCALE_PERCENTAGE \
    -pos-percent 4 96 \
    -interpolate true \
    -palette-name videen_style \
    -disp-pos true -disp-neg false -disp-zero false

  wb_command -metric-math \
    "thickness > 0" ${TMPDIR}/${HEMI}.roi.native.shape.gii \
    -var thickness \
    ${TMPDIR}/${HEMI}.thickness.native.shape.gii
  wb_command -metric-fill-holes \
    ${OUTDIR}/${HEMI}.midthickness.MNI.surf.gii \
    ${TMPDIR}/${HEMI}.roi.native.shape.gii \
    ${TMPDIR}/${HEMI}.roi.native.shape.gii
  wb_command -metric-remove-islands \
    ${OUTDIR}/${HEMI}.midthickness.MNI.surf.gii \
    ${TMPDIR}/${HEMI}.roi.native.shape.gii \
    ${TMPDIR}/${HEMI}.roi.native.shape.gii
  wb_command -set-map-names \
    ${TMPDIR}/${HEMI}.roi.native.shape.gii \
    -map 1 ${HEMI}_ROI

  # concatenate a FS sphere-reg to HCP conte69 sphere 
  # to make a left-right symmetric surface template 
  # and resample cortical surfaces into the template mesh configuration
  echo "concatenate a FS sphere-reg to HCP conte69 sphere"
  mris_convert ${SURF_DIR}/surf/${HEMI}.sphere.reg \
    ${OUTDIR}/${HEMI}.sphere.reg.native.surf.gii
  wb_command -set-structure \
    ${OUTDIR}/${HEMI}.sphere.reg.native.surf.gii  \
    CORTEX_${HEMI_str} -surface-type SPHERICAL
  mris_convert ${SURF_DIR}/surf/${HEMI}.sphere \
    ${OUTDIR}/${HEMI}.sphere.native.surf.gii
  wb_command -set-structure \
    ${OUTDIR}/${HEMI}.sphere.native.surf.gii \
    CORTEX_${HEMI_str} -surface-type SPHERICAL

  wb_command -surface-sphere-project-unproject \
    ${OUTDIR}/${HEMI}.sphere.reg.native.surf.gii \
    ${HCP_STANDARD_DIR}/standard_mesh_atlases/${FS_RL_DIR}/fsaverage.${FS_RL_FILE2}.sphere.164k_${FS_RL_DIR}.surf.gii \
    ${HCP_STANDARD_DIR}/standard_mesh_atlases/${FS_RL_DIR}/${FS_RL_DIR}-to-fs_LR_fsaverage.${FS_RL_FILE2}_LR.spherical_std.164k_${FS_RL_DIR}.surf.gii \
    ${OUTDIR}/${HEMI}.sphere.reg.reg_LR.native.surf.gii

  wb_command -surface-resample \
    ${OUTDIR}/${HEMI}.white.MNI.surf.gii \
    ${OUTDIR}/${HEMI}.sphere.reg.reg_LR.native.surf.gii \
    ${HCP_STANDARD_DIR}/standard_mesh_atlases/${FS_RL_FILE2}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
    BARYCENTRIC \
    ${OUTDIR}/${HEMI}.white.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii

  wb_command -surface-resample \
    ${OUTDIR}/${HEMI}.midthickness.MNI.surf.gii \
    ${OUTDIR}/${HEMI}.sphere.reg.reg_LR.native.surf.gii \
    ${HCP_STANDARD_DIR}/standard_mesh_atlases/${FS_RL_FILE2}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
    BARYCENTRIC \
    ${OUTDIR}/${HEMI}.mid.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii
  wb_command -surface-resample \
    ${OUTDIR}/${HEMI}.pial.MNI.surf.gii \
    ${OUTDIR}/${HEMI}.sphere.reg.reg_LR.native.surf.gii \
    ${HCP_STANDARD_DIR}/standard_mesh_atlases/${FS_RL_FILE2}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
    BARYCENTRIC \
    ${OUTDIR}/${HEMI}.pial.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii
    
  echo "resample the goodvoxels"
  # using a concatenated surface registration field (sampling a goodvoxel, mask it and resample)
  wb_command -volume-to-surface-mapping \
    ${TMPDIR}/goodvoxels.nii.gz \
    ${OUTDIR}/${HEMI}.midthickness.MNI.surf.gii \
    ${TMPDIR}/${HEMI}.goodvoxels.MNI.func.gii \
    -ribbon-constrained \
    ${OUTDIR}/${HEMI}.white.MNI.surf.gii \
    ${OUTDIR}/${HEMI}.pial.MNI.surf.gii

  wb_command -metric-mask \
    ${TMPDIR}/${HEMI}.goodvoxels.MNI.func.gii \
    ${TMPDIR}/${HEMI}.roi.native.shape.gii \
    ${TMPDIR}/${HEMI}.goodvoxels.MNI.func.gii

  wb_command -metric-resample \
    ${TMPDIR}/${HEMI}.goodvoxels.MNI.func.gii \
    ${OUTDIR}/${HEMI}.sphere.reg.reg_LR.native.surf.gii \
    ${HCP_STANDARD_DIR}/standard_mesh_atlases/${FS_RL_FILE2}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
    ADAP_BARY_AREA \
    ${TMPDIR}/${HEMI}.goodvoxels.${DOWNSAMPLE_MESH}k_fs_LR.MNI.func.gii \
    -area-surfs \
    ${OUTDIR}/${HEMI}.midthickness.MNI.surf.gii \
    ${OUTDIR}/${HEMI}.mid.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii \
    -current-roi ${TMPDIR}/${HEMI}.roi.native.shape.gii

  wb_command -metric-mask \
    ${TMPDIR}/${HEMI}.goodvoxels.${DOWNSAMPLE_MESH}k_fs_LR.MNI.func.gii \
    ${HCP_STANDARD_DIR}/91282_Greyordinates/${FS_RL_FILE2}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii  \
    ${TMPDIR}/${HEMI}.goodvoxels.${DOWNSAMPLE_MESH}k_fs_LR.MNI.func.gii

  echo "resample the time series"
  # using a concatenated surface registration field (sampling time series, mask it and resample)
  wb_command -volume-to-surface-mapping \
    ${FUNC_DIR} \
    ${OUTDIR}/${HEMI}.midthickness.MNI.surf.gii \
    ${TMPDIR}/${HEMI}.timeseries.MNI.func.gii \
    -ribbon-constrained \
    ${OUTDIR}/${HEMI}.white.MNI.surf.gii \
    ${OUTDIR}/${HEMI}.pial.MNI.surf.gii \
    -volume-roi ${TMPDIR}/goodvoxels.nii.gz

  wb_command -metric-dilate \
    ${TMPDIR}/${HEMI}.timeseries.MNI.func.gii \
    ${OUTDIR}/${HEMI}.midthickness.MNI.surf.gii \
    10 \
    ${TMPDIR}/${HEMI}.timeseries.MNI.func.gii \
    -nearest

  wb_command -metric-mask \
    ${TMPDIR}/${HEMI}.timeseries.MNI.func.gii \
    ${TMPDIR}/${HEMI}.roi.native.shape.gii \
    ${TMPDIR}/${HEMI}.timeseries.MNI.func.gii

  wb_command -metric-resample \
    ${TMPDIR}/${HEMI}.timeseries.MNI.func.gii \
    ${OUTDIR}/${HEMI}.sphere.reg.reg_LR.native.surf.gii \
    ${HCP_STANDARD_DIR}/standard_mesh_atlases/${FS_RL_FILE2}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
    ADAP_BARY_AREA \
    ${OUTDIR}/${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
    -area-surfs \
    ${OUTDIR}/${HEMI}.midthickness.MNI.surf.gii \
    ${OUTDIR}/${HEMI}.mid.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii \
    -current-roi ${TMPDIR}/${HEMI}.roi.native.shape.gii

  wb_command -metric-mask \
    ${OUTDIR}/${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
    ${HCP_STANDARD_DIR}/91282_Greyordinates/${FS_RL_FILE2}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii \
    ${OUTDIR}/${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii


  echo "smooth the values"
  wb_command -metric-smoothing \
    ${OUTDIR}/${HEMI}.mid.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii \
    ${OUTDIR}/${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
    ${Sigma} \
    ${OUTDIR}/${HEMI}.s${SmoothingFWHM}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
    -roi ${HCP_STANDARD_DIR}/91282_Greyordinates/${FS_RL_FILE2}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii 

done

echo "Neocortical preprocessing complete."
