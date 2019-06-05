#!/bin/bash - 
#===============================================================================
#
#          FILE: createNewTemplateSpace.sh
# 
#         USAGE: ./createNewTemplateSpace.sh 5125 5
# 
#   DESCRIPTION: Basic function to add new resolution templates to HCP pipeline 
#		 repository.
# 
#       OPTIONS: ---
#  REQUIREMENTS: FSL 5.0, wb_command; In path: FSLDIR, HCPPIPEDIR 
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Hao-Ting Wang (PostDoc), htwangtw@gmail.com
#  ORGANIZATION: University of York
#       CREATED: 05/06/19 00:19:45
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
  echo " This is a basic script to add new resolution-templates to an HCP Pipelines repository"
  echo " NOTE: This would have to be done on each machine and/or the generated files copied "
  echo "       from the Pipelines/global/templates/standard_mesh_atlases dir"
  echo ""
  echo " Usage:"
  echo " 	  CreateNewTemplateSpace.sh TargetNumberOfVertices ShortNameForTargetVolume (e.g., 32 for 32492 or 10 for 10248)"
  echo "    i.e.: CreateNewTemplateSpace.sh 8000 8"
  exit 1
}


if [ $# -eq 0 ] ; then show_usage; exit 0; fi

HCPPIPEDIR=~/HCPpipelines
WBDIR=/usr/bin

NumberOfVertices=${1}                           # per hamishpere
NewMesh=${2}                                    # ?k

TemplateFolder="${HCPPIPEDIR}/global/templates/standard_mesh_atlases"
OriginalMesh="164"                              # keep it this way
SubcorticalLabelTable="${HCPPIPEDIR}/global/config/FreeSurferSubcorticalLabelTableLut.txt"

${WBDIR}/wb_command -surface-create-sphere \
  ${NumberOfVertices} \
  ${TemplateFolder}/R.sphere.${NewMesh}k_fs_LR.surf.gii

${WBDIR}/wb_command -surface-flip-lr \
  ${TemplateFolder}/R.sphere.${NewMesh}k_fs_LR.surf.gii \
  ${TemplateFolder}/L.sphere.${NewMesh}k_fs_LR.surf.gii

${WBDIR}/wb_command -set-structure \
  ${TemplateFolder}/R.sphere.${NewMesh}k_fs_LR.surf.gii \
  CORTEX_RIGHT
${WBDIR}/wb_command -set-structure \
  ${TemplateFolder}/L.sphere.${NewMesh}k_fs_LR.surf.gii \
  CORTEX_LEFT

echo ""
echo "The new resolution-template labeled
  ${NewMesh}k_fs_LR will have the following characteristics:"

${WBDIR}/wb_command -surface-information \
  ${TemplateFolder}/R.sphere.${NewMesh}k_fs_LR.surf.gii \
  | sed -n '3,4p'
${WBDIR}/wb_command -surface-information \
  ${TemplateFolder}/R.sphere.${NewMesh}k_fs_LR.surf.gii \
  | sed -n '7,10p'

echo ""

NewResolution=$(${WBDIR}/wb_command -surface-information \
		${TemplateFolder}/R.sphere.${NewMesh}k_fs_LR.surf.gii \
		| grep Mean | awk '{print $2}' | awk -F "." '{print $1}')

echo NewResolution is ${NewResolution}

flirt -interp spline \
  -in ${TemplateFolder}/Avgwmparc.nii.gz \
  -ref ${TemplateFolder}/Avgwmparc.nii.gz \
  -applyisoxfm ${NewResolution} \
  -out ${TemplateFolder}/Atlas_ROIs.${NewResolution}.nii.gz
applywarp --rel --interp=nn \
  -i ${TemplateFolder}/Avgwmparc.nii.gz
  -r ${TemplateFolder}/Atlas_ROIs.${NewResolution}.nii.gz \
  --premat=$FSLDIR/etc/flirtsch/ident.mat \
  -o ${TemplateFolder}/Atlas_ROIs.${NewResolution}.nii.gz

${WBDIR}/wb_command -volume-label-import \
  ${TemplateFolder}/Atlas_ROIs.${NewResolution}.nii.gz \
  ${SubcorticalLabelTable} \
  ${TemplateFolder}/Atlas_ROIs.${NewResolution}.nii.gz \
  -discard-others \
  -drop-unused-labels

cp ${TemplateFolder}/Atlas_ROIs.${NewResolution}.nii.gz \
  ${HCPPIPEDIR}/global/templates/91282_Greyordinates/Atlas_ROIs.${NewResolution}.nii.gz


for Hemisphere in L R; do
  ${WBDIR}/wb_command -metric-resample \
    ${TemplateFolder}/${Hemisphere}.atlasroi.${OriginalMesh}k_fs_LR.shape.gii \
    ${TemplateFolder}/fsaverage.${Hemisphere}_LR.spherical_std.${OriginalMesh}k_fs_LR.surf.gii \
    ${TemplateFolder}/${Hemisphere}.sphere.${NewMesh}k_fs_LR.surf.gii \
    BARYCENTRIC \
    ${TemplateFolder}/${Hemisphere}.atlasroi.${NewMesh}k_fs_LR.shape.gii \
    -largest
  ${WBDIR}/wb_command -surface-cut-resample \
    ${TemplateFolder}/colin.cerebral.${Hemisphere}.flat.${OriginalMesh}k_fs_LR.surf.gii \
    ${TemplateFolder}/fsaverage.${Hemisphere}_LR.spherical_std.${OriginalMesh}k_fs_LR.surf.gii \
    ${TemplateFolder}/${Hemisphere}.sphere.${NewMesh}k_fs_LR.surf.gii \
    ${TemplateFolder}/colin.cerebral.${Hemisphere}.flat.${NewMesh}k_fs_LR.surf.gii
  cp ${TemplateFolder}/${Hemisphere}.atlasroi.${NewMesh}k_fs_LR.shape.gii \
     ${HCPPIPEDIR}/global/templates/91282_Greyordinates/${Hemisphere}.atlasroi.${NewMesh}k_fs_LR.shape.gii
done
