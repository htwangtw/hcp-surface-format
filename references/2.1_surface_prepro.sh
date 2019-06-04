#!/bin/bash

#This script first runs bbregister, mri_vol2surf (for each hemisphere) and then mri_surf2surf (for each hemisphere)

#bbregister creates parameter files that are used in the registration of functional data to surface space in the next step(vol2surf)

cd '/groups/labs/semwandering/MPsych2018'

#subject path to functional data
FUN_SUBJECTS_DIR="/groups/labs/semwandering/MPsych2018/data/interim"
SUBJ_LIST=$(cat /groups/labs/semwandering/MPsych2018/data/R_NO.txt)
# SUBJ_LIST=$1

for SUBJ in $SUBJ_LIST; do
	cd '/groups/labs/semwandering/MPsych2018'
	echo "${SUBJ}: running"

	qsub -N surface_prepro_${SUBJ} -o logs/ -e logs/ -cwd << EOF

	#initialize freesurfer
	. /etc/freesurfer/5.3/freesurfer.sh

	#initialize fsl
	export FSLDIR="/usr/share/fsl-5.0"

	#subject path of structural data
	export SUBJECTS_DIR="/groups/labs/semwandering/MPsych2018/data/interim/FreeSurfer_Data_5_3"

	cd ${SUBJECTS_DIR}

	#run bbregister (--mov is input, --reg is output)
	bbregister --s ${SUBJ} \
	           --mov ${FUN_SUBJECTS_DIR}/${SUBJ}/RS.feat/mean_func.nii.gz \
	           --init-fsl \
	           --reg ${FUN_SUBJECTS_DIR}/${SUBJ}/reg/freesurfer/anat2exf.register.dat \
	           --bold

	#run mri_vol2surf for left hemi (--src is input from functional data, --out is output, --src is output of bbregister)
	mri_vol2surf --src ${FUN_SUBJECTS_DIR}/${SUBJ}/filtered_func_data_compcor_bp.nii.gz \
	             --out ${FUN_SUBJECTS_DIR}/${SUBJ}/native_lh.mgh \
	             --srcreg ${FUN_SUBJECTS_DIR}/${SUBJ}/reg/freesurfer/anat2exf.register.dat \
	             --hemi lh --projfrac 0.5 --surf-fwhm 5

	#run mri_vol2surf for right hemi (--src is input from functional data, --out is output, --src is output of bbregister)
	mri_vol2surf --src ${FUN_SUBJECTS_DIR}/${SUBJ}/filtered_func_data_compcor_bp.nii.gz \
	             --out ${FUN_SUBJECTS_DIR}/${SUBJ}/native_rh.mgh \
	             --srcreg ${FUN_SUBJECTS_DIR}/${SUBJ}/reg/freesurfer/anat2exf.register.dat \
	             --hemi rh --projfrac 0.5 --surf-fwhm 5

	#run mri_surf2surf conver to fsaverage5 standard space
	mri_surf2surf --srcsubject ${SUBJ} --srcsurfval ${FUN_SUBJECTS_DIR}/${SUBJ}/native_lh.mgh --trgsubject fsaverage5 --trgsurfval ${FUN_SUBJECTS_DIR}/${SUBJ}/fsaverage5_lh.mgh --hemi lh
	mri_surf2surf --srcsubject ${SUBJ} --srcsurfval ${FUN_SUBJECTS_DIR}/${SUBJ}/native_rh.mgh --trgsubject fsaverage5 --trgsurfval ${FUN_SUBJECTS_DIR}/${SUBJ}/fsaverage5_rh.mgh --hemi rh

	cd ${FUN_SUBJECTS_DIR}
    # This converts native space surface files from .mgh to .gii. This is important to convert to fs_LR mesh, files must already be in gifti format.
	mri_convert ${SUBJ}/native_lh.mgh ${SUBJ}/native_lh.func.gii
	mri_convert ${SUBJ}/native_rh.mgh ${SUBJ}/native_rh.func.gii

    # This converts native space surface files from .mgh to .gii. This is important to convert to fs_LR mesh, files must already be in gifti format.
	mri_convert ${SUBJ}/fsaverage5_lh.mgh ${SUBJ}/fsaverage5_lh.func.gii
	mri_convert ${SUBJ}/fsaverage5_rh.mgh ${SUBJ}/fsaverage5_rh.func.gii

EOF

done




