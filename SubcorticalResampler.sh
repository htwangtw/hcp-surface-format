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

SUBJ=${1}

HOME="/home/hw1012"
WDIR="${HOME}/HCP_downsampling"
DATA_DIR="${WDIR}/data"
HCP_STANDARD_DIR="/home/hw1012/HCPpipelines/global/templates"
HCP_CONFIG_DIR="/home/hw1012/HCPpipelines/global/config"
FSL_STANDARD_DIR="/usr/local/fsl/data/standard"
SURF_DIR="${DATA_DIR}/interim/${SUBJ}/Freesurfer"
FUNC_DIR="${DATA_DIR}/interim/${SUBJ}"
TMPDIR="${DATA_DIR}/tmp"
OUTDIR="${DATA_DIR}/processed/${SUBJ}"

cd ${WDIR}
DOWNSAMPLE_MESH=5
SmoothingFWHM=3
Sigma=$(echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l)
####### 2-4. sample subcortical time series data on the surface
####### 2-4-1) convert FreeSurfer Volumes
mri_convert \
  -rt nearest \
  -rl ${OUTDIR}/fs_highres.nii.gz \
  ${SURF_DIR}/mri/wmparc.mgz \
  ${TMPDIR}/wmparc.nii.gz \
  -odt float
fslreorient2std ${TMPDIR}/wmparc.nii.gz ${TMPDIR}/wmparc_reo.nii.gz
applywarp \
  --rel --interp=nn \
  -i ${TMPDIR}/wmparc_reo.nii.gz \
  -r ${OUTDIR}/fs_highres2MNI.nii.gz \
  -w ${OUTDIR}/fs_highres2standard_warp.nii.gz \
  -o ${TMPDIR}/wmparc_reo2MNI_nlwarp_nii.nii.gz
wb_command -volume-label-import \
  ${TMPDIR}/wmparc_reo.nii.gz \
  ${HCP_CONFIG_DIR}/FreeSurferAllLut.txt \
  ${TMPDIR}/wmparc_reo.nii.gz \
  -drop-unused-labels
wb_command -volume-label-import \
  ${TMPDIR}/wmparc_reo2MNI_nlwarp_nii.nii.gz \
  ${HCP_CONFIG_DIR}/FreeSurferAllLut.txt \
  ${TMPDIR}/wmparc_reo2MNI_nlwarp_nii.nii.gz \
  -drop-unused-labels


####### 2-4-2) import Subcortical ROIs
applywarp \
  --interp=nn \
  -i ${TMPDIR}/wmparc_reo2MNI_nlwarp_nii.nii.gz \
  -r ${HCP_STANDARD_DIR}/91282_Greyordinates/Atlas_ROIs.5.nii.gz \
  -o ${TMPDIR}/wmparc_reo2MNI_nlwarp.5.nii.gz
wb_command -volume-label-import \
  ${TMPDIR}/wmparc_reo2MNI_nlwarp.5.nii.gz \
  ${HCP_CONFIG_DIR}/FreeSurferAllLut.txt \
  ${TMPDIR}/wmparc_reo2MNI_nlwarp.5.nii.gz \
  -drop-unused-labels
applywarp \
  --interp=nn -i \
  ${HCP_STANDARD_DIR}/standard_mesh_atlases/Avgwmparc.nii.gz \
  -r ${TMPDIR}/wmparc_reo2MNI_nlwarp.5.nii.gz \
  -o ${TMPDIR}/Atlas_wmparc.5.nii.gz
wb_command -volume-label-import \
  ${TMPDIR}/Atlas_wmparc.5.nii.gz \
  ${HCP_CONFIG_DIR}/FreeSurferAllLut.txt \
  ${TMPDIR}/Atlas_wmparc.5.nii.gz \
  -drop-unused-labels
wb_command -volume-label-import \
  ${TMPDIR}/wmparc_reo2MNI_nlwarp.5.nii.gz \
  ${HCP_CONFIG_DIR}/FreeSurferSubcorticalLabelTableLut.txt \
  ${TMPDIR}/ROIs.5.nii.gz \
  -discard-others

####### 2-4-3) create subject-roi subcortical cifti at same resolution as output
wb_command -volume-affine-resample \
  ${TMPDIR}/ROIs.5.nii.gz \
  ${FSLDIR}/etc/flirtsch/ident.mat \
  ${FUNC_DIR}/prepro_func_MNI.nii \
  ENCLOSING_VOXEL \
  ${TMPDIR}/ROIs.5.func.nii.gz
wb_command -cifti-create-dense-timeseries \
  ${TMPDIR}/_temp.dtseries.nii \
  -volume \
  ${FUNC_DIR}/prepro_func_MNI.nii \
  ${TMPDIR}/ROIs.5.func.nii.gz

echo "wb_command: Dilating out zeros"
wb_command -cifti-dilate \
  ${TMPDIR}/_temp.dtseries.nii \
  COLUMN 0 10 \
  ${TMPDIR}/_temp_dilate.dtseries.nii

echo "wb_command: Generate atlas subcortical template cifti"
wb_command -cifti-create-label \
  ${TMPDIR}/_temp_template.dlabel.nii \
  -volume \
  ${HCP_STANDARD_DIR}/91282_Greyordinates/Atlas_ROIs.5.nii.gz  \
  ${HCP_STANDARD_DIR}/91282_Greyordinates/Atlas_ROIs.5.nii.gz

echo "wb_command: Smoothing and resampling"
#this is the whole timeseries, so don't overwrite, in order to allow on-disk writing, then delete temporary
wb_command -cifti-smoothing \
  ${TMPDIR}/_temp_dilate.dtseries.nii 0 \
  ${Sigma} COLUMN ${TMPDIR}/_temp_subject_smooth.dtseries.nii \
  -fix-zeros-volume
#resample
wb_command -cifti-resample \
  ${TMPDIR}/_temp_subject_smooth.dtseries.nii \
  COLUMN \
  ${TMPDIR}/_temp_template.dlabel.nii \
  COLUMN ADAP_BARY_AREA CUBIC \
  ${TMPDIR}/_temp_atlas.dtseries.nii \
  -volume-predilate 10

####### 2-4-4) write output volume
wb_command -cifti-separate \
  ${TMPDIR}/_temp_atlas.dtseries.nii \
  COLUMN \
  -volume-all \
  ${OUTDIR}/func_AtlasSubcortical_s${SmoothingFWHM}.nii.gz

####### 2-4-5) concate cortical and subcortical time series
TR_vol=`fslval ${FUNC_DIR}/prepro_func_MNI.nii pixdim4 | cut -d " " -f 1`

wb_command -cifti-create-dense-timeseries \
  ${OUTDIR}/func.dtseries.nii \
  -volume ${OUTDIR}/func_AtlasSubcortical_s${SmoothingFWHM}.nii.gz \
  ${HCP_STANDARD_DIR}/91282_Greyordinates/Atlas_ROIs.5.nii.gz \
  -left-metric ${OUTDIR}/lh.s${SmoothingFWHM}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
  -roi-left ${HCP_STANDARD_DIR}/91282_Greyordinates/L.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii \
  -right-metric ${OUTDIR}/rh.s${SmoothingFWHM}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
  -roi-right ${HCP_STANDARD_DIR}/91282_Greyordinates/R.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii \
  -timestep $TR_vol

# clean files

# rm -rf ${TMPDIR}/*