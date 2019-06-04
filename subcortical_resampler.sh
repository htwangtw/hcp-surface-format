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
HCPPIPEDIR="/home/hw1012/HCPpipelines"
FSL_STANDARD_DIR="/usr/local/fsl/data/standard"
DOWNSAMPLE_MESH=5
SmoothingFWHM=3
Sigma=$(echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l)

export SUBJECTS_DIR=${SURF_SUBJECTS_DIR}
SUBJ=${1}
WDIR=${FUNC_SUBJECTS_DIR}/${SUBJ}/HCP_pipeline_output

cd ${WDIR}
####### 2-4. sample subcortical time series data on the surface
####### 2-4-1) convert FreeSurfer Volumes
mri_convert \
  -rt nearest \
  -rl ${SURF_SUBJECTS_DIR}/${SUBJ}/mri/brain.nii.gz \
  ${SURF_SUBJECTS_DIR}/${SUBJ}/mri/wmparc.mgz ${WDIR}/wmparc.nii.gz \
  -odt float
fslreorient2std ${WDIR}/wmparc.nii.gz ${WDIR}/wmparc_reo.nii.gz
applywarp \
  --rel --interp=nn \
  -i ${WDIR}/wmparc_reo.nii.gz \
  -r ${SURF_SUBJECTS_DIR}/${SUBJ}/mri/brain2MNI.nii.gz \
  -w ${SURF_SUBJECTS_DIR}/${SUBJ}/mri/transforms/fs_highres2standard_warp.nii.gz \
  -o ${WDIR}/wmparc_reo2MNI_nlwarp_nii.nii.gz
wb_command -volume-label-import \
  ${WDIR}/wmparc_reo.nii.gz \
  ${HCPPIPEDIR}/global/config/FreeSurferAllLut.txt \
  ${WDIR}/wmparc_reo.nii.gz \
  -drop-unused-labels
wb_command -volume-label-import \
  ${WDIR}/wmparc_reo2MNI_nlwarp_nii.nii.gz \
  ${HCPPIPEDIR}/global/config/FreeSurferAllLut.txt \
  ${WDIR}/wmparc_reo2MNI_nlwarp_nii.nii.gz \
  -drop-unused-labels


####### 2-4-2) import Subcortical ROIs
applywarp \
  --interp=nn \
  -i ${WDIR}/wmparc_reo2MNI_nlwarp_nii.nii.gz \
  -r ${TemplateFolder}/91282_Greyordinates/Atlas_ROIs.5.nii.gz \
  -o ${WDIR}/wmparc_reo2MNI_nlwarp.5.nii.gz
wb_command -volume-label-import \
  ${WDIR}/wmparc_reo2MNI_nlwarp.5.nii.gz \
  ${HCPPIPEDIR}/global/config/FreeSurferAllLut.txt \
  ${WDIR}/wmparc_reo2MNI_nlwarp.5.nii.gz \
  -drop-unused-labels
applywarp \
  --interp=nn -i \
  ${TemplateFolder}/standard_mesh_atlases/Avgwmparc.nii.gz \
  -r ${WDIR}/wmparc_reo2MNI_nlwarp.5.nii.gz \
  -o ${WDIR}/Atlas_wmparc.5.nii.gz
wb_command -volume-label-import \
  ${WDIR}/Atlas_wmparc.5.nii.gz \
  ${HCPPIPEDIR}/global/config/FreeSurferAllLut.txt \
  ${WDIR}/Atlas_wmparc.5.nii.gz \
  -drop-unused-labels
wb_command -volume-label-import \
  ${WDIR}/wmparc_reo2MNI_nlwarp.5.nii.gz \
  ${HCPPIPEDIR}/global/config/FreeSurferSubcorticalLabelTableLut.txt \
  ${WDIR}/ROIs.5.nii.gz \
  -discard-others

####### 2-4-3) create subject-roi subcortical cifti at same resolution as output
wb_command -volume-affine-resample \
  ${WDIR}/ROIs.5.nii.gz \
  $FSLDIR/etc/flirtsch/ident.mat \
  ${FUNC_SUBJECTS_DIR}/${SUBJ}/prepro_functional_MNI.nii.gz \
  ENCLOSING_VOXEL \
  ${WDIR}/ROIs.5.func.nii.gz
wb_command -cifti-create-dense-timeseries \
  ${WDIR}/_temp.dtseries.nii \
  -volume \
  ${FUNC_SUBJECTS_DIR}/${SUBJ}/prepro_functional_MNI.nii.gz \
  ${WDIR}/ROIs.5.func.nii.gz

echo "wb_command: Dilating out zeros"
wb_command -cifti-dilate \
  ${WDIR}/_temp.dtseries.nii \
  COLUMN 0 10 \
  ${WDIR}/_temp_dilate.dtseries.nii

echo "wb_command: Generate atlas subcortical template cifti"
wb_command -cifti-create-label \
  ${WDIR}/_temp_template.dlabel.nii \
  -volume \
  ${TemplateFolder}/91282_Greyordinates/Atlas_ROIs.5.nii.gz  \
  ${TemplateFolder}/91282_Greyordinates/Atlas_ROIs.5.nii.gz

echo "wb_command: Smoothing and resampling"
#this is the whole timeseries, so don't overwrite, in order to allow on-disk writing, then delete temporary
wb_command -cifti-smoothing \
  ${WDIR}/_temp_dilate.dtseries.nii 0 \
  ${Sigma} COLUMN ${WDIR}/_temp_subject_smooth.dtseries.nii \
  -fix-zeros-volume
#resample
wb_command -cifti-resample \
  ${WDIR}/_temp_subject_smooth.dtseries.nii \
  COLUMN \
  ${WDIR}/_temp_template.dlabel.nii \
  COLUMN ADAP_BARY_AREA CUBIC \
  ${WDIR}/_temp_atlas.dtseries.nii \
  -volume-predilate 10

####### 2-4-4) write output volume
wb_command -cifti-separate \
  ${WDIR}/_temp_atlas.dtseries.nii \
  COLUMN \
  -volume-all \
  ${WDIR}/func_AtlasSubcortical_s${SmoothingFWHM}.nii.gz

####### 2-4-5) concate cortical and subcortical time series
TR_vol=`fslval ${FUNC_SUBJECTS_DIR}/${SUBJ}/prepro_functional_MNI.nii.gz pixdim4 | cut -d " " -f 1`

wb_command -cifti-create-dense-timeseries \
  ${WDIR}/func.dtseries.nii \
  -volume ${WDIR}/_func_AtlasSubcortical_s${SmoothingFWHM}.nii.gz \
  ${TemplateFolder}/91282_Greyordinates/Atlas_ROIs.5.nii.gz \
  -left-metric ${WDIR}/lh.s${SmoothingFWHM}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
  -roi-left ${WDIR}/lh.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii \
  -right-metric ${WDIR}/rh.s${SmoothingFWHM}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
  -roi-right ${WDIR}/rh.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii \
  -timestep $TR_vol

# clean files

rm -rf ${WDIR}/_temp*

rm -rf ${WDIR}/cov*
rm -rf ${WDIR}/mean.nii.gz
rm -rf ${WDIR}/std.nii.gz
rm -rf ${WDIR}/goodvoxels.nii.gz
rm -rf ${WDIR}/ribbon_only.nii.gz
rm -rf ${WDIR}/ROIs.5.nii.gz
rm -rf ${WDIR}/ROIs.5.func.nii.gz
rm -rf ${WDIR}/SmoothNorm.nii.gz
rm -rf ${WDIR}/mask.nii.gz
rm -rf ${WDIR}/Atlas_wmparc.5.nii.gz
rm -rf ${WDIR}/wmparc*

rm -rf ${WDIR}/?h.atlasroi.164k_fs_LR.surf.gii
rm -rf ${WDIR}/?h.def_sphere.164k_fs_l.surf.gii
rm -rf ${WDIR}/?h.goodvoxels.5k_fs_LR.MNI.func.gii
rm -rf ${WDIR}/?h.goodvoxels.MNI.func.gii
rm -rf ${WDIR}/?h.pial.MNI.dist.nii.gz
rm -rf ${WDIR}/?h.pial_uthr0.MNI.dist.nii.gz
rm -rf ${WDIR}/?h.ribbon.nii.gz
rm -rf ${WDIR}/?h.roi.native.shape.gii
rm -rf ${WDIR}/?h.thickness.native.shape.gii
rm -rf ${WDIR}/?h.timeseries.MNI.func.gii
rm -rf ${WDIR}/?h.white.MNI.dist.nii.gz
rm -rf ${WDIR}/?h.white_thr0.MNI.dist.nii.gz

rm -rf ?h.sphere.164k_*.surf.gii
rm -rf ?h.def_sphere.164k_*.surf.gii
rm -rf ?h.sphere.164k_fs_LR.surf.gii
rm -rf ?h.atlasroi.164k_fs_LR.surf.gii
rm -rf ?h.sphere.5k_fs_LR.surf.gii
rm -rf ?h.atlasroi.5k_fs_LR.shape.gii