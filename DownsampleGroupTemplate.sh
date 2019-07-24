#!/bin/bash - 


cd /groups/labs/semwandering/Cohort_HCPpipeline/data/external/BALSA_database
HCPPIPEDIR=/groups/labs/semwandering/Cohort_HCPpipeline/data/external/HCPpipelines_global

mkdir 5k_cifti_separate_Gordon333
# resample S900.?.midthickness_MSMAll.32k_fs_LR.surf.gii to 5k
wb_command -surface-resample \
	S900.L.midthickness_MSMAll.32k_fs_LR.surf.gii \
  ${HCPPIPEDIR}/templates/standard_mesh_atlases/L.sphere.32k_fs_LR.surf.gii \
  ${HCPPIPEDIR}/templates/standard_mesh_atlases/L.sphere.5k_fs_LR.surf.gii \
	BARYCENTRIC \
	5k_cifti_separate_Gordon333/S900.L.midthickness_MSMAll.5k_fs_LR.surf.gii

wb_command -surface-resample \
	S900.R.midthickness_MSMAll.32k_fs_LR.surf.gii \
  ${HCPPIPEDIR}/templates/standard_mesh_atlases/R.sphere.32k_fs_LR.surf.gii \
  ${HCPPIPEDIR}/templates/standard_mesh_atlases/R.sphere.5k_fs_LR.surf.gii \
	BARYCENTRIC \
	5k_cifti_separate_Gordon333/S900.R.midthickness_MSMAll.5k_fs_LR.surf.gii

# create resampled cifti labels
wb_command -cifti-separate \
  Gordon333_FreesurferSubcortical.32k_fs_LR.dlabel.nii \
  COLUMN \
  -label CORTEX_LEFT \
  5k_cifti_separate_Gordon333/Gordon333_Freesurfer.Neocortical.L.32k_fs_LR.label.gii \
  -label CORTEX_RIGHT \
  5k_cifti_separate_Gordon333/Gordon333_Freesurfer.Neocortical.R.32k_fs_LR.label.gii

wb_command -label-resample \
  5k_cifti_separate_Gordon333/Gordon333_Freesurfer.Neocortical.L.32k_fs_LR.label.gii \
  ${HCPPIPEDIR}/templates/standard_mesh_atlases/L.sphere.32k_fs_LR.surf.gii \
  ${HCPPIPEDIR}/templates/standard_mesh_atlases/L.sphere.5k_fs_LR.surf.gii \
  ADAP_BARY_AREA \
  5k_cifti_separate_Gordon333/Gordon333_Freesurfer.Neocortical.L.5k_fs_LR.label.gii \
  -area-surfs \
	S900.L.midthickness_MSMAll.32k_fs_LR.surf.gii \
  5k_cifti_separate_Gordon333/S900.L.midthickness_MSMAll.5k_fs_LR.surf.gii \
  -current-roi ${HCPPIPEDIR}/templates/standard_mesh_atlases/L.atlasroi.32k_fs_LR.shape.gii

wb_command -label-resample \
  5k_cifti_separate_Gordon333/Gordon333_Freesurfer.Neocortical.R.32k_fs_LR.label.gii \
  ${HCPPIPEDIR}/templates/standard_mesh_atlases/R.sphere.32k_fs_LR.surf.gii \
  ${HCPPIPEDIR}/templates/standard_mesh_atlases/R.sphere.5k_fs_LR.surf.gii \
  ADAP_BARY_AREA \
  5k_cifti_separate_Gordon333/Gordon333_Freesurfer.Neocortical.R.5k_fs_LR.label.gii \
  -area-surfs \
	S900.R.midthickness_MSMAll.32k_fs_LR.surf.gii \
  5k_cifti_separate_Gordon333/S900.R.midthickness_MSMAll.5k_fs_LR.surf.gii \
  -current-roi ${HCPPIPEDIR}/templates/standard_mesh_atlases/R.atlasroi.32k_fs_LR.shape.gii

wb_command -cifti-create-label \
  5k_cifti_separate_Gordon333/Gordon333_FreesurferSubcortical.5k_fs_LR.dlabel.nii \
  -volume ${HCPPIPEDIR}/templates/91282_Greyordinates/Atlas_ROIs.5.nii.gz \
  ${HCPPIPEDIR}/templates/91282_Greyordinates/Atlas_ROIs.5.nii.gz \
  -left-label 5k_cifti_separate_Gordon333/Gordon333_Freesurfer.Neocortical.L.5k_fs_LR.label.gii \
  -roi-left ${HCPPIPEDIR}/templates/standard_mesh_atlases/L.atlasroi.5k_fs_LR.shape.gii \
  -right-label 5k_cifti_separate_Gordon333/Gordon333_Freesurfer.Neocortical.R.5k_fs_LR.label.gii \
  -roi-right ${HCPPIPEDIR}/templates/standard_mesh_atlases/R.atlasroi.5k_fs_LR.shape.gii
