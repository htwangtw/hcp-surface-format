#!/bin/bash
#$ -N fs_resample_prep
#$ -o /groups/labs/semwandering/MPsych2018/logs/
#$ -j y
#$ -cwd
#$ -t 1-186
#$ -tc 40

# This script takes individual functional data in fsaverage5 space and resamples it to the fs_LR (conte69) surface mesh.
# We mapped the fsaverage5 group level template to the fs_LR and then downsample to 5k

#The main output of this is a file named '?h.RS.5k_fs_LR_avg.func.gii' in MPsych2018/data/processed/R????/


declare -a SUBJ_LIST=(`cat /groups/labs/semwandering/MPsych2018/data/R_NO.txt`)

i=$(($SGE_TASK_ID - 1))

cd '/groups/labs/semwandering/MPsych2018/'

# Python script to downsample 32k sphere to 5k
# cd ./data/external/
# python decimate_surface_5k/decimate_5k.py

cd '/groups/labs/semwandering/MPsych2018/'

# FS setup
. /etc/freesurfer/5.3/freesurfer.sh
# subject path of structural data
export SUBJECTS_DIR=/groups/labs/semwandering/MPsych2018/data/interim/FreeSurfer_Data_5_3
# initialize fsl
export FSLDIR=/usr/share/fsl-5.0

# analysis

SUBJ=${SUBJ_LIST[$i]}

mkdir -p data/interim/${SUBJ}/surf
mkdir -p data/processed/${SUBJ}/


for h in l r; do

    echo ${h}h
    H=$(echo $h | tr a-z A-Z)

    metric_in=data/interim/${SUBJ}/fsaverage5_${h}h.func.gii
    current_sphere=data/external/fsaverage5/${h}h.sphere.reg.surf.gii
    new_sphere=data/external/decimate_surface_5k/fs_LR-deformed_to-fsaverage.${H}.sphere.5k_fs_LR.surf.gii
    metric_out=data/processed/${SUBJ}/${h}h.RS.5k_fs_LR_avg.func.gii
    current_area=data/external/fsaverage5/${h}h.midthickness.surf.gii
    new_area=data/external/fsaverage5/${h}h.midthickness.5k_fs_LR.surf.gii


    wb_command -metric-resample \
        ${metric_in} \
        ${current_sphere} \
        ${new_sphere} \
        ADAP_BARY_AREA \
        ${metric_out} \
        -area-surfs \
        ${current_area} \
        ${new_area}

done
