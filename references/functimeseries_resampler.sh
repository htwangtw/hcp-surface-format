#!/bin/sh
#


export FREESURFER_HOME=/export01/local/freesurfer/
source $FREESURFER_HOME/SetUpFreeSurfer.sh

# ex)
CASE=${1}								# 32319
FreeSurferFolder=${2} 				    # /02_file/01_fs_processed/
RS_DIR=${3} 	  						# /02_file/03_fMRI_preprocessed/Outputs/cpac/filt_noglobal/
DOWNSAMPLE_MESH=${4}					# 5
GrayordinatesResolutions=${5} 	        # 3
SmoothingFWHM=${6}					    # 3
SITE=${7}
SUBJECT_ORGID=${8}

WDIR=${FreeSurferFolder}/${CASE}/hcp_processed_global/ # no GSR: ${FreeSurferFolder}/${CASE}/hcp_processed    | GSR: ${FreeSurferFolder}/${CASE}/hcp_processed_global/
onlysmoothing=0

mkdir ${WDIR}

Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`

FuncTimeseriesMeanVolDir=${RS_DIR}/func_mean/
FuncTimeseriesVolDir=${RS_DIR}/func_preproc/

WBDIR=/01_analysis/functional_gradient_project/workbench/bin_linux64/
HCPPIPEDIR=/01_analysis/functional_gradient_project/Pipelines-3.21.0/
HCPPIPEDIR_Config=${HCPPIPEDIR}/global/config/
TemplateFolder=${HCPPIPEDIR}/global/templates/
GrayordinatesSpaceDIR=/01_analysis/functional_gradient_project/Pipelines-3.21.0/global/templates/91282_Greyordinates/
FreeSurferLabels=${HCPPIPEDIR_Config}/FreeSurferAllLut.txt
SubcorticalGrayLabels=${HCPPIPEDIR_Config}/FreeSurferSubcorticalLabelTableLut.txt

#################################################################
# 1. Matlab code for generting gift surface files

#rand_num=$RANDOM
#jobfile=/tmp/tmp_${rand_num}_${CASE}_sampling_timesereis.m
#echo 'register_rs2str_project_surf('"'${CASE}'"', '"'${FreeSurferFolder}'"', '"'${FuncTimeseriesVolDir}'"', '"'${rand_num}'"', '"'${onlysmoothing}'"')' >> ${jobfile}
#echo 'register_rs2str_project_surf('"'${CASE}'"', '"'${FreeSurferFolder}'"', '"'${FuncTimeseriesVolDir}'"', '"'${rand_num}'"', '"'${onlysmoothing}'"')'
#echo 'register_rs2str_project_surf('"'${CASE}'"', '"'${FreeSurferFolder}'"', '"'${FuncTimeseriesVolDir}'"', '"'${rand_num}'"', '"'1'"')' >> ${jobfile}
#echo 'register_rs2str_project_surf('"'${CASE}'"', '"'${FreeSurferFolder}'"', '"'${FuncTimeseriesVolDir}'"', '"'${rand_num}'"', '"'1'"')'
#echo 'matlab -nodisplay < '${jobfile} ' > ' ${FreeSurferFolder}/${CASE}/surf/${CASE}_timeseries_surface_mapping.log
#matlab -nodisplay < ${jobfile} > ${FreeSurferFolder}/${CASE}/surf/${CASE}_timeseries_surface_mapping.log

#rm -rf ${WDIR}/${jobfile}

#################################################################
# 2. Adopting HCP pipeline for sampling time series
# 01) Project pial and white surface into resting-fMRI space (uncomment above few lines)
# 02) Make a cortical ribbon and goodvoxel volume (see RibbonVolumeToSurfaceMapping.sh line 24-66)
# 03) Make sure the name of files for surface registratoin.
#     a. "$Subject"."$Hemisphere".sphere.reg.reg_LR.native.surf.gii (see FreeSurfer2CaretConvertAndRegisterNonlinear.sh line 167-170)
#     b. "$DownsampleFolder"/"$Subject"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii (see FreeSurfer2CaretConvertAndRegisterNonlinear.sh line 298)
#     c. all template files are in /01_analysis/functional_gradient_project/Pipelines-3.21.0/global/templates/standard_mesh_atlases
#     d. To make XXX.roi.native.shape.gii, please see FreeSurfer2CaretConvertAndRegisterNonlinear.sh line 174-192
#     e. L.atlasroi.32k_fs_LR.shape.gii is in the /01_analysis/functional_gradient_project/Pipelines-3.21.0/global/templates/standard_mesh_atlases/
# 04) Sample time series based on cortical ribbon and goodvoxels (see RibbonVolumeToSurfaceMapping.sh line 80, 85)
# 05) Do metric-dilate, metric-mask (see RibbonVolumeToSurfaceMapping.sh line 81-82, 86-87)
# 06) Resample time series (from Freesurfer individual surfaces to HCP fs_LR surf) (see RibbonVolumeToSurfaceMapping.sh line 82, 88)
# 07) Do metric-mask again (see RibbonVolumeToSurfaceMapping.sh line 83, 89)
# 08) Smooth time series using a 2mm FWHM kernel
# 09) Import subcortical ROIs (see FreeSurfer2CaretConvertAndRegisterNonlinear.sh line 104-114, particularly 111)
# 10) Project subcortical ROIs (wmparc) to resting-fMRI space using "-fnirt ' anatfs_vol '_reo2MNI_nlwarp_nii.nii.gz'"
# 11) Sample time series of subcortical structures (see SubcorticalProcessing.h line 39-49)
# 12) Dilate out zeros (see SubcorticalProcessing.h line 51-55)
# 13) Smooth and resample signals of subcorticla structures (see SubcorticalProcessing.h line 61-66)
# 14) Separate the volume of signals (AtlasSubcortical_sXXX.nii.gz) (see SubcorticalProcessing.h line 78)
# 15) Make one cifti file combining cortical and subcortical signals (see CreateDenseTimeSeries.sh line 18) -> "$OutputAtlasDenseTimeseries".dtseries.nii

#SUBJECT_ORGID=00`cat /tmp/${rand_num}_case.txt`
#SITE=`cat /tmp/${rand_num}_site.txt`

#rm -rf ${WDIR}//tmp/${rand_num}_case.txt /tmp/${rand_num}_site.txt

if [ ${onlysmoothing} == 0 ]; then

	####### 2-1. create a cortical ribbon volume
	${WBDIR}/wb_command -create-signed-distance-volume \
	  ${FreeSurferFolder}/${CASE}/surf/lh.white.MNI.gii \
	  ${FuncTimeseriesMeanVolDir}/${SITE}_${SUBJECT_ORGID}_func_mean.nii.gz \
	  ${WDIR}/lh.white.MNI.dist.nii.gz
	${WBDIR}/wb_command -create-signed-distance-volume \
	  ${FreeSurferFolder}/${CASE}/surf/lh.pial.MNI.gii \
	  ${FuncTimeseriesMeanVolDir}/${SITE}_${SUBJECT_ORGID}_func_mean.nii.gz \
	  ${WDIR}/lh.pial.MNI.dist.nii.gz
	fsl5.0-fslmaths ${WDIR}/lh.white.MNI.dist.nii.gz \
	  -thr 0 -bin -mul 255 \
	  ${WDIR}/lh.white_thr0.MNI.dist.nii.gz
	fsl5.0-fslmaths ${WDIR}/lh.white_thr0.MNI.dist.nii.gz \
	  -bin ${WDIR}/lh.white_thr0.MNI.dist.nii.gz
	fsl5.0-fslmaths ${WDIR}/lh.pial.MNI.dist.nii.gz \
	  -uthr 0 -abs -bin \
	  -mul 255 ${WDIR}/lh.pial_uthr0.MNI.dist.nii.gz
	fsl5.0-fslmaths ${WDIR}/lh.pial_uthr0.MNI.dist.nii.gz \
	  -bin ${WDIR}/lh.pial_uthr0.MNI.dist.nii.gz
	fsl5.0-fslmaths ${WDIR}/lh.pial_uthr0.MNI.dist.nii.gz \
	  -mas ${WDIR}/lh.white_thr0.MNI.dist.nii.gz \
	  -mul 255 ${WDIR}/lh.ribbon.nii.gz
	fsl5.0-fslmaths ${WDIR}/lh.ribbon.nii.gz \
	  -bin -mul 1 ${WDIR}/lh.ribbon.nii.gz

	${WBDIR}/wb_command -create-signed-distance-volume \$
	  {FreeSurferFolder}/${CASE}/surf/rh.white.MNI.gii \
	  ${FuncTimeseriesMeanVolDir}/${SITE}_${SUBJECT_ORGID}_func_mean.nii.gz \
	  ${WDIR}/rh.white.MNI.dist.nii.gz
	${WBDIR}/wb_command -create-signed-distance-volume \
	  ${FreeSurferFolder}/${CASE}/surf/rh.pial.MNI.gii \
	  ${FuncTimeseriesMeanVolDir}/${SITE}_${SUBJECT_ORGID}_func_mean.nii.gz \
	  ${WDIR}/rh.pial.MNI.dist.nii.gz
	fsl5.0-fslmaths ${WDIR}/rh.white.MNI.dist.nii.gz \
	  -thr 0 -bin -mul 255 \
	  ${WDIR}/rh.white_thr0.MNI.dist.nii.gz
	fsl5.0-fslmaths \
	  ${WDIR}/rh.white_thr0.MNI.dist.nii.gz \
	  -bin \
	  ${WDIR}/rh.white_thr0.MNI.dist.nii.gz
	fsl5.0-fslmaths ${WDIR}/rh.pial.MNI.dist.nii.gz \
	  -uthr 0 -abs -bin -mul 255 \
	  ${WDIR}/rh.pial_uthr0.MNI.dist.nii.gz
	fsl5.0-fslmaths ${WDIR}/rh.pial_uthr0.MNI.dist.nii.gz -bin \
	  ${WDIR}/rh.pial_uthr0.MNI.dist.nii.gz
	fsl5.0-fslmaths ${WDIR}/rh.pial_uthr0.MNI.dist.nii.gz \
	  -mas ${WDIR}/rh.white_thr0.MNI.dist.nii.gz -mul 255 \
	  ${WDIR}/rh.ribbon.nii.gz
	fsl5.0-fslmaths ${WDIR}/rh.ribbon.nii.gz \
	  -bin -mul 1 \
	  ${WDIR}/rh.ribbon.nii.gz

	fsl5.0-fslmaths ${WDIR}/lh.ribbon.nii.gz \
	  -add ${WDIR}/rh.ribbon.nii.gz \
	  ${WDIR}/ribbon_only.nii.gz

	####### 2-2. create a goodvoxel volume
	fsl5.0-fslmaths ${FuncTimeseriesVolDir}/${SITE}_${SUBJECT_ORGID}_func_preproc.nii.gz \
	  -Tmean ${WDIR}/mean \
	  -odt float
	fsl5.0-fslmaths ${FuncTimeseriesVolDir}/${SITE}_${SUBJECT_ORGID}_func_preproc.nii.gz \
	  -Tstd ${WDIR}/std \
	  -odt float

	fsl5.0-fslmaths ${WDIR}/std \
	  -div ${WDIR}/mean \
	  ${WDIR}/cov
	fsl5.0-fslmaths ${WDIR}/cov \
	  -mas ${WDIR}/ribbon_only.nii.gz \
	  ${WDIR}/cov_ribbon
	fsl5.0-fslmaths ${WDIR}/cov_ribbon \
	  -div `fsl5.0-fslstats ${WDIR}/cov_ribbon -M` \
	  ${WDIR}/cov_ribbon_norm
	fsl5.0-fslmaths ${WDIR}/cov_ribbon_norm \
	  -bin -s 5 \
	  ${WDIR}/SmoothNorm
	fsl5.0-fslmaths ${WDIR}/cov_ribbon_norm \
	  -s 5 \
	  -div ${WDIR}/SmoothNorm -dilD \
	  ${WDIR}/cov_ribbon_norm_s5
	fsl5.0-fslmaths ${WDIR}/cov \
	  -div `fsl5.0-fslstats ${WDIR}/cov_ribbon -M` \
	  -div ${WDIR}/cov_ribbon_norm_s5 \
	  ${WDIR}/cov_norm_modulate

	STD=`fsl5.0-fslstats ${WDIR}/cov_norm_modulate -S`
	MEAN=`fsl5.0-fslstats ${WDIR}/cov_norm_modulate -M`
	Lower=`echo "$MEAN - ($STD * 0.5)" | bc -l`
	Upper=`echo "$MEAN + ($STD * 0.5)" | bc -l`

	fsl5.0-fslmaths ${WDIR}/cov_norm_modulate \
	  -mas ${WDIR}/ribbon_only.nii.gz \
	  ${WDIR}/cov_norm_modulate_ribbon
	fsl5.0-fslmaths \
	  ${FuncTimeseriesMeanVolDir}/${SITE}_${SUBJECT_ORGID}_func_mean.nii.gz \
	  -bin \
	  ${WDIR}/mask
	fsl5.0-fslmaths \
	  ${WDIR}/cov_norm_modulate \
	  -thr $Upper -bin -sub ${WDIR}/mask -mul -1 \
	  ${WDIR}/goodvoxels

fi

####### 2-3. sample neocortical time series data on the surface
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

	if [ ${onlysmoothing} == 0 ]; then

		####### 2-3-1) make a cortical roi mask (exclude a medial wall)
		mris_convert \
		  -c ${FreeSurferFolder}/${CASE}/surf/${HEMI}.thickness \
		  ${FreeSurferFolder}/${CASE}/surf/${HEMI}.white \
		  ${WDIR}/${HEMI}.thickness.native.shape.gii
		${WBDIR}/wb_command -set-structure \
		  ${WDIR}/${HEMI}.thickness.native.shape.gii \
		  CORTEX_${HEMI_str}
		${WBDIR}/wb_command -metric-math \
		  "var * -1" ${WDIR}/${HEMI}.thickness.native.shape.gii \
		  -var var \
		  ${WDIR}/${HEMI}.thickness.native.shape.gii
		${WBDIR}/wb_command -set-map-names \
		  ${WDIR}/${HEMI}.thickness.native.shape.gii -map 1 \
		  ${WDIR}/${HEMI}_Thickness
		${WBDIR}/wb_command -metric-palette \
		  ${WDIR}/${HEMI}.thickness.native.shape.gii \
		  MODE_AUTO_SCALE_PERCENTAGE \
		  -pos-percent 2 98 \
		  -palette-name Gray_Interp \
		  -disp-pos true -disp-neg true -disp-zero true
		${WBDIR}/wb_command -metric-math \
		  "abs(thickness)" ${WDIR}/${HEMI}.thickness.native.shape.gii \
		  -var thickness \
		  ${WDIR}/${HEMI}.thickness.native.shape.gii
		${WBDIR}/wb_command -metric-palette \
		  ${WDIR}/${HEMI}.thickness.native.shape.gii \
		  MODE_AUTO_SCALE_PERCENTAGE \
		  -pos-percent 4 96 \
		  -interpolate true \
		  -palette-name videen_style \
		  -disp-pos true -disp-neg false -disp-zero false

		${WBDIR}/wb_command -metric-math \
		  "thickness > 0" ${WDIR}/${HEMI}.roi.native.shape.gii \
		  -var thickness \
		  ${WDIR}/${HEMI}.thickness.native.shape.gii
		${WBDIR}/wb_command -metric-fill-holes \
		  ${FreeSurferFolder}/${CASE}/surf/${HEMI}.mid.MNI.gii \
		  ${WDIR}/${HEMI}.roi.native.shape.gii \
		  ${WDIR}/${HEMI}.roi.native.shape.gii
		${WBDIR}/wb_command -metric-remove-islands \
		  ${FreeSurferFolder}/${CASE}/surf/${HEMI}.mid.MNI.gii \
		  ${WDIR}/${HEMI}.roi.native.shape.gii \
		  ${WDIR}/${HEMI}.roi.native.shape.gii
		${WBDIR}/wb_command -set-map-names \
		  ${WDIR}/${HEMI}.roi.native.shape.gii \
		  -map 1 ${WDIR}/${HEMI}_ROI

		####### 2-3-2) concatenate a FS sphere-reg to HCP conte69 sphere to make a left-right symmetric surface template and resample cortical surfaces into the template mesh configuration
		\cp -vf \
		  ${TemplateFolder}/standard_mesh_atlases/${FS_RL_DIR}/fsaverage.${FS_RL_FILE2}.sphere.164k_${FS_RL_DIR}.surf.gii \
		  ${WDIR}/${HEMI}.sphere.164k_${FS_RL_FILE}.surf.gii
		\cp -vf \
		  ${TemplateFolder}/standard_mesh_atlases/${FS_RL_DIR}/${FS_RL_DIR}-to-fs_LR_fsaverage.${FS_RL_FILE2}_LR.spherical_std.164k_${FS_RL_DIR}.surf.gii \
		  ${WDIR}/${HEMI}.def_sphere.164k_${FS_RL_FILE}.surf.gii
		\cp -vf \
		  ${TemplateFolder}/standard_mesh_atlases/fsaverage.${FS_RL_FILE2}_LR.spherical_std.164k_fs_LR.surf.gii \
		  ${WDIR}/${HEMI}.sphere.164k_fs_LR.surf.gii
		\cp -vf \
		  ${TemplateFolder}/standard_mesh_atlases/${FS_RL_FILE2}.atlasroi.164k_fs_LR.shape.gii \
		  ${WDIR}/${HEMI}.atlasroi.164k_fs_LR.surf.gii
		\cp -vf \
		  ${TemplateFolder}/standard_mesh_atlases/${FS_RL_FILE2}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
		  ${WDIR}/${HEMI}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii
		\cp -vf \
		  ${TemplateFolder}/91282_Greyordinates/${FS_RL_FILE2}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii \
		  ${WDIR}/${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii

		mris_convert ${FreeSurferFolder}/${CASE}/surf/${HEMI}.sphere.reg \
		  ${WDIR}/${HEMI}.sphere.reg.native.surf.gii
		${WBDIR}/wb_command -set-structure \
		  ${WDIR}/${HEMI}.sphere.reg.native.surf.gii  \
		  CORTEX_${HEMI_str} -surface-type SPHERICAL
		mris_convert ${FreeSurferFolder}/${CASE}/surf/${HEMI}.sphere \
		  ${WDIR}/${HEMI}.sphere.native.surf.gii
		${WBDIR}/wb_command -set-structure \
		  ${WDIR}/${HEMI}.sphere.native.surf.gii \
		  CORTEX_${HEMI_str} -surface-type SPHERICAL

		${WBDIR}/wb_command -surface-sphere-project-unproject \
		  ${WDIR}/${HEMI}.sphere.reg.native.surf.gii \
		  ${WDIR}/${HEMI}.sphere.164k_${FS_RL_FILE}.surf.gii \
		  ${WDIR}/${HEMI}.def_sphere.164k_${FS_RL_FILE}.surf.gii \
		  ${WDIR}/${HEMI}.sphere.reg.reg_LR.native.surf.gii

		${WBDIR}/wb_command -surface-resample \
		  ${FreeSurferFolder}/${CASE}/surf/${HEMI}.white.MNI.gii \
		  ${WDIR}/${HEMI}.sphere.reg.reg_LR.native.surf.gii \
		  ${WDIR}/${HEMI}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
		  BARYCENTRIC \
		  ${WDIR}/${HEMI}.white.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii

		${WBDIR}/wb_command -surface-resample \
		  ${FreeSurferFolder}/${CASE}/surf/${HEMI}.mid.MNI.gii \
		  ${WDIR}/${HEMI}.sphere.reg.reg_LR.native.surf.gii \
		  ${WDIR}/${HEMI}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
		  BARYCENTRIC \
		  ${WDIR}/${HEMI}.mid.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii
		${WBDIR}/wb_command -surface-resample \
		  ${FreeSurferFolder}/${CASE}/surf/${HEMI}.pial.MNI.gii \
		  ${WDIR}/${HEMI}.sphere.reg.reg_LR.native.surf.gii \
		  ${WDIR}/${HEMI}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
		  BARYCENTRIC \
		  ${WDIR}/${HEMI}.pial.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii

		####### 2-3-3) resample the goodvoxels using a concatenated surface registration field (sampling a goodvoxel, mask it and resample)
		${WBDIR}/wb_command -volume-to-surface-mapping \
		  ${WDIR}/goodvoxels.nii.gz \
		  ${FreeSurferFolder}/${CASE}/surf/${HEMI}.mid.MNI.gii \
		  ${WDIR}/${HEMI}.goodvoxels.MNI.func.gii \
		  -ribbon-constrained \
		  ${FreeSurferFolder}/${CASE}/surf/${HEMI}.white.MNI.gii \
		  ${FreeSurferFolder}/${CASE}/surf/${HEMI}.pial.MNI.gii

		${WBDIR}/wb_command -metric-mask \
		  ${WDIR}/${HEMI}.goodvoxels.MNI.func.gii \
		  ${WDIR}/${HEMI}.roi.native.shape.gii \
		  ${WDIR}/${HEMI}.goodvoxels.MNI.func.gii

		${WBDIR}/wb_command -metric-resample \
		  ${WDIR}/${HEMI}.goodvoxels.MNI.func.gii \
		  ${WDIR}/${HEMI}.sphere.reg.reg_LR.native.surf.gii \
		  ${WDIR}/${HEMI}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
		  ADAP_BARY_AREA \
		  ${WDIR}/${HEMI}.goodvoxels.${DOWNSAMPLE_MESH}k_fs_LR.MNI.func.gii \
		  -area-surfs \
		  ${FreeSurferFolder}/${CASE}/surf/${HEMI}.mid.MNI.gii \
		  ${WDIR}/${HEMI}.mid.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii \
		  -current-roi ${WDIR}/${HEMI}.roi.native.shape.gii

		${WBDIR}/wb_command -metric-mask \
		  ${WDIR}/${HEMI}.goodvoxels.${DOWNSAMPLE_MESH}k_fs_LR.MNI.func.gii \
		  ${WDIR}/${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii \
		  ${WDIR}/${HEMI}.goodvoxels.${DOWNSAMPLE_MESH}k_fs_LR.MNI.func.gii

		####### 2-3-4) resample the time series using a concatenated surface registration field (sampling time series, mask it and resample)
		${WBDIR}/wb_command -volume-to-surface-mapping \
		  ${FuncTimeseriesVolDir}/${SITE}_${SUBJECT_ORGID}_func_preproc.nii.gz \
		  ${FreeSurferFolder}/${CASE}/surf/${HEMI}.mid.MNI.gii \
		  ${WDIR}/${HEMI}.timeseries.MNI.func.gii \
		  -ribbon-constrained \
		  ${FreeSurferFolder}/${CASE}/surf/${HEMI}.white.MNI.gii \
		  ${FreeSurferFolder}/${CASE}/surf/${HEMI}.pial.MNI.gii \
		  -volume-roi ${WDIR}/goodvoxels.nii.gz

		${WBDIR}/wb_command -metric-dilate \
		  ${WDIR}/${HEMI}.timeseries.MNI.func.gii \
		  ${FreeSurferFolder}/${CASE}/surf/${HEMI}.mid.MNI.gii \
		  10 \
		  ${WDIR}/${HEMI}.timeseries.MNI.func.gii \
		  -nearest

		${WBDIR}/wb_command -metric-mask \
		  ${WDIR}/${HEMI}.timeseries.MNI.func.gii \
		  ${WDIR}/${HEMI}.roi.native.shape.gii \
		  ${WDIR}/${HEMI}.timeseries.MNI.func.gii

		${WBDIR}/wb_command -metric-resample \
		  ${WDIR}/${HEMI}.timeseries.MNI.func.gii \
		  ${WDIR}/${HEMI}.sphere.reg.reg_LR.native.surf.gii \
		  ${WDIR}/${HEMI}.sphere.${DOWNSAMPLE_MESH}k_fs_LR.surf.gii \
		  ADAP_BARY_AREA \
		  ${WDIR}/${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
		  -area-surfs \
		  ${FreeSurferFolder}/${CASE}/surf/${HEMI}.mid.MNI.gii \
		  ${WDIR}/${HEMI}.mid.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii \
		  -current-roi ${WDIR}/${HEMI}.roi.native.shape.gii

		${WBDIR}/wb_command -metric-mask \
		  ${WDIR}/${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
		  ${WDIR}/${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii \
		  ${WDIR}/${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii

	fi

	####### 2-3-5) smooth the values
	${WBDIR}/wb_command -metric-smoothing \
	  ${WDIR}/${HEMI}.mid.${DOWNSAMPLE_MESH}k_fs_LR.MNI.surf.gii \
	  ${WDIR}/${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
	  "$Sigma" \
	  ${WDIR}/${HEMI}.s${SmoothingFWHM}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
	  -roi ${WDIR}/${HEMI}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii

done

####### 2-4. sample subcortical time series data on the surface
####### 2-4-1) convert FreeSurfer Volumes
for Image in wmparc; do
	if [ -e $FreeSurferFolder/${CASE}/mri/$Image.mgz ] ; then
		mri_convert \
	    -rt nearest \
	    -rl ${FreeSurferFolder}/${CASE}/mri/brain_nii.nii.gz \
	    ${FreeSurferFolder}/${CASE}/mri/$Image.mgz ${WDIR}/$Image.nii.gz \
	    -odt float
		fsl5.0-fslreorient2std ${WDIR}/${Image}.nii.gz ${WDIR}/${Image}_reo.nii.gz
		fsl5.0-applywarp \
		  --rel --interp=nn \
		  -i ${WDIR}/${Image}_reo.nii.gz \
		  -r ${FreeSurferFolder}/${CASE}/mri/brain_reo2MNI_nl_nii.nii.gz \
		  -w ${FreeSurferFolder}/${CASE}/mri/brain_reo2MNI_nlwarp_nii.nii.gz \
		  -o ${WDIR}/${Image}_reo2MNI_nlwarp_nii.nii.gz
		${WBDIR}/wb_command -volume-label-import \
		  ${WDIR}/${Image}_reo.nii.gz \
		  $FreeSurferLabels ${WDIR}/${Image}_reo.nii.gz \
		  -drop-unused-labels
		${WBDIR}/wb_command -volume-label-import \
		  ${WDIR}/${Image}_reo2MNI_nlwarp_nii.nii.gz \
		  $FreeSurferLabels ${WDIR}/${Image}_reo2MNI_nlwarp_nii.nii.gz \
		  -drop-unused-labels
	fi
done

####### 2-4-2) import Subcortical ROIs
for GrayordinatesResolution in ${GrayordinatesResolutions}; do

  \cp $GrayordinatesSpaceDIR/Atlas_ROIs.${GrayordinatesResolution}.nii.gz \
  ${WDIR}/Atlas_ROIs.${GrayordinatesResolution}.nii.gz
  fsl5.0-applywarp \
    --interp=nn \
    -i ${WDIR}/wmparc_reo2MNI_nlwarp_nii.nii.gz \
    -r ${WDIR}/Atlas_ROIs.$GrayordinatesResolution.nii.gz \
    -o ${WDIR}/wmparc_reo2MNI_nlwarp.$GrayordinatesResolution.nii.gz
  ${WBDIR}/wb_command -volume-label-import \
    ${WDIR}/wmparc_reo2MNI_nlwarp.$GrayordinatesResolution.nii.gz \
    $FreeSurferLabels \
    ${WDIR}/wmparc_reo2MNI_nlwarp.$GrayordinatesResolution.nii.gz \
    -drop-unused-labels
  fsl5.0-applywarp \
    --interp=nn -i \
    ${TemplateFolder}/standard_mesh_atlases/Avgwmparc.nii.gz \
    -r ${WDIR}/wmparc_reo2MNI_nlwarp.$GrayordinatesResolution.nii.gz \
    -o ${WDIR}/Atlas_wmparc.$GrayordinatesResolution.nii.gz
  ${WBDIR}/wb_command -volume-label-import \
    ${WDIR}/Atlas_wmparc.$GrayordinatesResolution.nii.gz \
    ${FreeSurferLabels} \
    ${WDIR}/Atlas_wmparc.$GrayordinatesResolution.nii.gz \
    -drop-unused-labels
  ${WBDIR}/wb_command -volume-label-import \
    ${WDIR}/wmparc_reo2MNI_nlwarp.$GrayordinatesResolution.nii.gz \
    ${SubcorticalGrayLabels} \
    ${WDIR}/ROIs.$GrayordinatesResolution.nii.gz \
    -discard-others

done

####### 2-4-3) create subject-roi subcortical cifti at same resolution as output
${WBDIR}/wb_command -volume-affine-resample \
  ${WDIR}/ROIs.$GrayordinatesResolution.nii.gz \
  $FSLDIR/etc/flirtsch/ident.mat ${FuncTimeseriesVolDir}/${SITE}_${SUBJECT_ORGID}_func_preproc.nii.gz \
  ENCLOSING_VOXEL \
  ${WDIR}/ROIs.${GrayordinatesResolution}.func.nii.gz
${WBDIR}/wb_command -cifti-create-dense-timeseries \
  ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp.dtseries.nii \
  -volume \
  ${FuncTimeseriesVolDir}/${SITE}_${SUBJECT_ORGID}_func_preproc.nii.gz \
  ${WDIR}/ROIs.${GrayordinatesResolution}.func.nii.gz

echo "${WBDIR}/wb_command: Dilating out zeros"
${WBDIR}/wb_command -cifti-dilate \
  ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp.dtseries.nii \
  COLUMN 0 10 \
  ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_dilate.dtseries.nii

echo "${WBDIR}/wb_command: Generate atlas subcortical template cifti"
${WBDIR}/wb_command -cifti-create-label \
  ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_template.dlabel.nii \
  -volume \
  ${WDIR}/Atlas_ROIs.${GrayordinatesResolution}.nii.gz \
  ${WDIR}/Atlas_ROIs.${GrayordinatesResolution}.nii.gz

if [[ `echo "${Sigma} > 0" | bc -l | cut -f1 -d.` == "1" ]]
then
  echo "${WBDIR}/wb_command: Smoothing and resampling"
  #this is the whole timeseries, so don't overwrite, in order to allow on-disk writing, then delete temporary
  ${WBDIR}/wb_command -cifti-smoothing \
    ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_dilate.dtseries.nii 0 \
    ${Sigma} COLUMN ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_subject_smooth.dtseries.nii \
    -fix-zeros-volume
  #resample, delete temporary
  ${WBDIR}/wb_command -cifti-resample \
    ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_subject_smooth.dtseries.nii \
    COLUMN \
    ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_template.dlabel.nii \
    COLUMN ADAP_BARY_AREA CUBIC \
    ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_atlas.dtseries.nii \
    -volume-predilate 10
  rm -f ${ResultsFolder}/${NameOffMRI}_temp_subject_smooth.dtseries.nii
else
  echo "${script_name}: Resampling"
  ${WBDIR}/wb_command -cifti-resample \
    ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_dilate.dtseries.nii \
    COLUMN \
    ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_template.dlabel.nii \
    COLUMN \
    ADAP_BARY_AREA \
    CUBIC \
    ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_atlas.dtseries.nii \
    -volume-predilate 10
fi

####### 2-4-4) write output volume, delete temporary
${WBDIR}/wb_command -cifti-separate \
  ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_atlas.dtseries.nii \
  COLUMN \
  -volume-all \
  ${WDIR}/${SITE}_${SUBJECT_ORGID}_func_AtlasSubcortical_s${SmoothingFWHM}.nii.gz

####### 2-4-5) concate cortical and subcortical time series
TR_vol=`fslval ${FuncTimeseriesVolDir}/${SITE}_${SUBJECT_ORGID}_func_preproc.nii.gz pixdim4 | cut -d " " -f 1`

${WBDIR}/wb_command -cifti-create-dense-timeseries \
  ${WDIR}/${SITE}_${SUBJECT_ORGID}_func.dtseries.nii
  -volume ${WDIR}/${SITE}_${SUBJECT_ORGID}_func_AtlasSubcortical_s${SmoothingFWHM}.nii.gz \
  ${WDIR}/Atlas_ROIs.${GrayordinatesResolution}.nii.gz \
  -left-metric ${WDIR}/lh.s${SmoothingFWHM}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
  -roi-left ${WDIR}/lh.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii \
  -right-metric ${WDIR}/rh.s${SmoothingFWHM}.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.func.gii \
  -roi-right ${WDIR}/rh.atlasroi.${DOWNSAMPLE_MESH}k_fs_LR.shape.gii \
  -timestep $TR_vol

rm -rf ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_atlas.dtseries.nii
rm -rf ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_dilate.dtseries.nii
rm -rf ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp.dtseries.nii
rm -rf ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_subject_smooth.dtseries.nii
rm -rf ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_template.dlabel.nii
rm -rf ${WDIR}/${SITE}_${SUBJECT_ORGID}_temp_template.dlabel.nii

rm -rf ${WDIR}/cov.nii.gz
rm -rf ${WDIR}/cov_norm_modulate.nii.gz
rm -rf ${WDIR}/cov_norm_modulate_ribbon.nii.gz
rm -rf ${WDIR}/cov_ribbon.nii.gz
rm -rf ${WDIR}/cov_ribbon_norm.nii.gz
rm -rf ${WDIR}/cov_ribbon_norm_s5.nii.gz
rm -rf ${WDIR}/mean.nii.gz
rm -rf ${WDIR}/std.nii.gz
rm -rf ${WDIR}/goodvoxels.nii.gz
rm -rf ${WDIR}/ribbon_only.nii.gz
rm -rf ${WDIR}/ROIs.3.nii.gz
rm -rf ${WDIR}/ROIs.3.func.nii.gz
rm -rf ${WDIR}/SmoothNorm.nii.gz
rm -rf ${WDIR}/mask.nii.gz
rm -rf ${WDIR}/Atlas_wmparc.3.nii.gz
rm -rf ${WDIR}/wmparc.nii.gz
rm -rf ${WDIR}/wmparc_reo2MNI_nlwarp.3.nii.gz
rm -rf ${WDIR}/wmparc_reo2MNI_nlwarp_nii.nii.gz
rm -rf ${WDIR}/wmparc_reo.nii.gz

rm -rf ${WDIR}/lh.atlasroi.164k_fs_LR.surf.gii
rm -rf ${WDIR}/lh.def_sphere.164k_fs_l.surf.gii
rm -rf ${WDIR}/lh.goodvoxels.10k_fs_LR.MNI.func.gii
rm -rf ${WDIR}/lh.goodvoxels.MNI.func.gii
rm -rf ${WDIR}/lh.pial.MNI.dist.nii.gz
rm -rf ${WDIR}/lh.pial_uthr0.MNI.dist.nii.gz
rm -rf ${WDIR}/lh.ribbon.nii.gz
rm -rf ${WDIR}/lh.roi.native.shape.gii
rm -rf ${WDIR}/lh.thickness.native.shape.gii
rm -rf ${WDIR}/lh.timeseries.MNI.func.gii
rm -rf ${WDIR}/lh.white.MNI.dist.nii.gz
rm -rf ${WDIR}/lh.white_thr0.MNI.dist.nii.gz

rm -rf ${WDIR}/rh.atlasroi.164k_fs_LR.surf.gii
rm -rf ${WDIR}/rh.def_sphere.164k_fs_r.surf.gii
rm -rf ${WDIR}/rh.goodvoxels.10k_fs_LR.MNI.func.gii
rm -rf ${WDIR}/rh.goodvoxels.MNI.func.gii
rm -rf ${WDIR}/rh.pial.MNI.dist.nii.gz
rm -rf ${WDIR}/rh.pial_uthr0.MNI.dist.nii.gz
rm -rf ${WDIR}/rh.ribbon.nii.gz
rm -rf ${WDIR}/rh.roi.native.shape.gii
rm -rf ${WDIR}/rh.thickness.native.shape.gii
rm -rf ${WDIR}/rh.timeseries.MNI.func.gii
rm -rf ${WDIR}/rh.white.MNI.dist.nii.gz
rm -rf ${WDIR}/rh.white_thr0.MNI.dist.nii.gz
