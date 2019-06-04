#!/bin/bash
#
# generate cifti template for the downsampled functional data
#
#

cd ~/masks_atlas/BALSA_database
mkdir 5k_cifti_separate_Gordon333
# resample S900.?.midthickness_MSMAll.32k_fs_LR.surf.gii to 5k
wb_command -surface-resample \
	S900.L.midthickness_MSMAll.32k_fs_LR.surf.gii \
  ~/HCPpipelines/global/templates/standard_mesh_atlases/L.sphere.32k_fs_LR.surf.gii \
  ~/HCPpipelines/global/templates/standard_mesh_atlases/L.sphere.5k_fs_LR.surf.gii \
	BARYCENTRIC \
	5k_cifti_separate_Gordon333/S900.L.midthickness_MSMAll.5k_fs_LR.surf.gii

wb_command -surface-resample \
	S900.R.midthickness_MSMAll.32k_fs_LR.surf.gii \
  ~/HCPpipelines/global/templates/standard_mesh_atlases/R.sphere.32k_fs_LR.surf.gii \
  ~/HCPpipelines/global/templates/standard_mesh_atlases/R.sphere.5k_fs_LR.surf.gii \
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
  ~/HCPpipelines/global/templates/standard_mesh_atlases/L.sphere.32k_fs_LR.surf.gii \
  ~/HCPpipelines/global/templates/standard_mesh_atlases/L.sphere.5k_fs_LR.surf.gii \
  ADAP_BARY_AREA \
  5k_cifti_separate_Gordon333/Gordon333_Freesurfer.Neocortical.L.5k_fs_LR.label.gii \
  -area-surfs \
	S900.L.midthickness_MSMAll.32k_fs_LR.surf.gii \
  5k_cifti_separate_Gordon333/S900.L.midthickness_MSMAll.5k_fs_LR.surf.gii \
  -current-roi ~/HCPpipelines/global/templates/standard_mesh_atlases/L.atlasroi.32k_fs_LR.shape.gii

wb_command -label-resample \
  5k_cifti_separate_Gordon333/Gordon333_Freesurfer.Neocortical.R.32k_fs_LR.label.gii \
  ~/HCPpipelines/global/templates/standard_mesh_atlases/R.sphere.32k_fs_LR.surf.gii \
  ~/HCPpipelines/global/templates/standard_mesh_atlases/R.sphere.5k_fs_LR.surf.gii \
  ADAP_BARY_AREA \
  5k_cifti_separate_Gordon333/Gordon333_Freesurfer.Neocortical.R.5k_fs_LR.label.gii \
  -area-surfs \
	S900.R.midthickness_MSMAll.32k_fs_LR.surf.gii \
  5k_cifti_separate_Gordon333/S900.R.midthickness_MSMAll.5k_fs_LR.surf.gii \
  -current-roi ~/HCPpipelines/global/templates/standard_mesh_atlases/R.atlasroi.32k_fs_LR.shape.gii

wb_command -cifti-create-label \
  5k_cifti_separate_Gordon333/Gordon333_FreesurferSubcortical.5k_fs_LR.dlabel.nii \
  -volume ~/HCPpipelines/global/templates/91282_Greyordinates/Atlas_ROIs.3.nii.gz \
  ~/HCPpipelines/global/templates/91282_Greyordinates/Atlas_ROIs.3.nii.gz \
  -left-label 5k_cifti_separate_Gordon333/Gordon333_Freesurfer.Neocortical.L.5k_fs_LR.label.gii \
  -roi-left ~/HCPpipelines/global/templates/standard_mesh_atlases/L.atlasroi.5k_fs_LR.shape.gii \
  -right-label 5k_cifti_separate_Gordon333/Gordon333_Freesurfer.Neocortical.R.5k_fs_LR.label.gii \
  -roi-right ~/HCPpipelines/global/templates/standard_mesh_atlases/R.atlasroi.5k_fs_LR.shape.gii

CASES=${1}

WDIR= "" # 'YOUR OWN DIRECTORY WHERE YOU SAVE HCP FILES'
FILEIDX_SET=( 1_LR 1_RL 2_LR 2_RL )
for ID in `cat ${CASES}`; do
  for FILEIDX in "${FILEIDX_SET[@]}"; do

		echo 'case: '${ID}'_'${FILEIDX}

		wb_command -cifti-convert -to-nifti
		  ${WDIR}/${ID}/rfMRI_REST${FILEIDX}_Atlas_MSMAll_hp2000_clean.dtseries.nii \
		  ${WDIR}/${ID}/rfMRI_REST${FILEIDX}_Atlas_MSMAll_hp2000_clean.FAKENIFTI.nii.gz
		/local_raid/seokjun/03_downloads/linux_ubuntu_16_64/3dBandpass -dt 0.72 \
		  -input ${WDIR}/${ID}/rfMRI_REST${FILEIDX}_Atlas_MSMAll_hp2000_clean.FAKENIFTI.nii.gz \
		  -band 0.008 0.08 \
		  -prefix ${WDIR}/${ID}/rfMRI_REST${FILEIDX}_Atlas_MSMAll_hp2000_clean_flt.FAKENIFTI.nii.gz
		wb_command -cifti-convert \
		  -from-nifti ${WDIR}/${ID}/rfMRI_REST${FILEIDX}_Atlas_MSMAll_hp2000_clean_flt.FAKENIFTI.nii.gz \
		  ${WDIR}/${ID}/rfMRI_REST${FILEIDX}_Atlas_MSMAll_hp2000_clean.dtseries.nii \
		  ${WDIR}/${ID}/rfMRI_REST${FILEIDX}_Atlas_MSMAll_hp2000_clean_flt.dtseries.nii

		# Which one is more valid?
		# 1) ~/masks_atlas/BALSA_database/S900.corrThickness_MSMAll.5k_fs_LR.dscalar.nii (without subcortical structues) or
		# 2) ~/masks_atlas/BALSA_database/5k_cifti_separate_Gordon333/Gordon333_FreesurferSubcortical.5k_fs_LR.dlabel.nii (with subcortical structues)
		# If prefer 1), uncomment the line 86 to 102, and if prefer 2), uncomment the line 104 to 120.

		# wb_command -cifti-resample \
		#   ${WDIR}/${ID}/rfMRI_REST${FILEIDX}_Atlas_MSMAll_hp2000_clean.dtseries.nii \
		#   COLUMN ~/masks_atlas/BALSA_database/5k_cifti_separate_Gordon333/Gordon333_FreesurferSubcortical.5k_fs_LR.dlabel.nii \
		#   COLUMN ADAP_BARY_AREA TRILINEAR \
		#   ${WDIR}/${ID}/rfMRI_REST${FILEIDX}_Atlas_MSMAll_hp2000_clean.5k.dtseries.nii \
		#   -left-spheres \
		#   ~/HCPpipelines/global/templates/standard_mesh_atlases/L.sphere.32k_fs_LR.surf.gii \
		#   ~/HCPpipelines/global/templates/standard_mesh_atlases/L.sphere.5k_fs_LR.surf.gii \
		#   -left-area-surfs \
		#   ~/masks_atlas/BALSA_database/S900.L.midthickness_MSMAll.32k_fs_LR.surf.gii \
		#   ~/masks_atlas/BALSA_database/5k_cifti_separate_Gordon333/S900.L.midthickness_MSMAll.5k_fs_LR.surf.gii \
		#   -right-spheres \
		#   ~/HCPpipelines/global/templates/standard_mesh_atlases/R.sphere.32k_fs_LR.surf.gii \
		#   ~/HCPpipelines/global/templates/standard_mesh_atlases/R.sphere.5k_fs_LR.surf.gii \
		#   -right-area-surfs \
		#   ~/masks_atlas/BALSA_database/S900.R.midthickness_MSMAll.32k_fs_LR.surf.gii \
		#   ~/masks_atlas/BALSA_database/5k_cifti_separate_Gordon333/S900.R.midthickness_MSMAll.5k_fs_LR.surf.gii

		# wb_command -cifti-resample \
		#   ${WDIR}/${ID}/rfMRI_REST${FILEIDX}_Atlas_MSMAll_hp2000_clean_flt.dtseries.nii \
		#   COLUMN ~/masks_atlas/BALSA_database/5k_cifti_separate_Gordon333/Gordon333_FreesurferSubcortical.5k_fs_LR.dlabel.nii \
		#   COLUMN ADAP_BARY_AREA TRILINEAR \
		#   ${WDIR}/${ID}/rfMRI_REST${FILEIDX}_Atlas_MSMAll_hp2000_clean_flt2.5k.dtseries.nii \
		#   -left-spheres \
		#   ~/HCPpipelines/global/templates/standard_mesh_atlases/L.sphere.32k_fs_LR.surf.gii \
		#   ~/HCPpipelines/global/templates/5k_cifti_separate_Gordon333/standard_mesh_atlases/L.sphere.5k_fs_LR.surf.gii \
		#   -left-area-surfs \
		#   ~/masks_atlas/BALSA_database/S900.L.midthickness_MSMAll.32k_fs_LR.surf.gii \
		#   ~/masks_atlas/BALSA_database/5k_cifti_separate_Gordon333/S900.L.midthickness_MSMAll.5k_fs_LR.surf.gii \
		#   -right-spheres \
		#   ~/HCPpipelines/global/templates/standard_mesh_atlases/R.sphere.32k_fs_LR.surf.gii \
		#   ~/HCPpipelines/global/templates/standard_mesh_atlases/R.sphere.5k_fs_LR.surf.gii \
		#   -right-area-surfs \
		#   ~/masks_atlas/BALSA_database/S900.R.midthickness_MSMAll.32k_fs_LR.surf.gii \
		#   ~/masks_atlas/BALSA_database/5k_cifti_separate_Gordon333/S900.R.midthickness_MSMAll.5k_fs_LR.surf.gii
	done
done
