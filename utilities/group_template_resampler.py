from .base_generator import BaseWorkbenchGenerator
import os
import os.path as op
import subprocess

class GroupTemplateResampler(BaseWorkbenchGenerator):
    def __init__(self, res_label, targ_lh_sphere, targ_rh_sphere, output_dir):
        super(GroupTemplateResampler, self).__init__(output_dir)

        self.res_label = res_label

        self.lh_s900_32k = op.join(self.hcp_balsa_dir, 'S900.L.midthickness_MSMAll.32k_fs_LR.surf.gii')
        self.rh_s900_32k = op.join(self.hcp_balsa_dir, 'S900.R.midthickness_MSMAll.32k_fs_LR.surf.gii')
        self.lh_fs_LR_32k_shape = os.path.join(self.hcp_standard_mesh_atlases_dir,
                'L.atlasroi.32k_fs_LR.shape.gii')
        self.rh_fs_LR_32k_shape = os.path.join(self.hcp_standard_mesh_atlases_dir,
                'R.atlasroi.32k_fs_LR.shape.gii')

        self.lh_sphere_32k = op.join(self.hcp_standard_mesh_atlases_dir, 'L.sphere.32k_fs_LR.surf.gii')
        self.rh_sphere_32k = op.join(self.hcp_standard_mesh_atlases_dir, 'R.sphere.32k_fs_LR.surf.gii')

        self.gordon333_32k = op.join(self.hcp_balsa_dir, "Gordon333_FreesurferSubcortical.32k_fs_LR.dlabel.nii")

        self.targ_lh_sphere = targ_lh_sphere
        self.targ_rh_sphere = targ_rh_sphere

        self.lh_gordon333_32k = op.join(self.output_dir, "Gordon333_Freesurfer.Neocortical.L.32k_fs_LR.label.gii")
        self.rh_gordon333_32k = op.join(self.output_dir, "Gordon333_Freesurfer.Neocortical.R.32k_fs_LR.label.gii")
        self.lh_s900_resampled = op.join(self.output_dir, "S900.L.midthickness_MSMALL.%s_fs_LR.surf.gii" % self.res_label)
        self.rh_s900_resampled = op.join(self.output_dir, "S900.R.midthickness_MSMALL.%s_fs_LR.surf.gii" % self.res_label)

        self.gordon333_subcortical_resampled = op.join(self.output_dir, "Gordon333_FreesurferSubcortical.%s_fs_LR.dlabel.nii" % self.res_label)
        self.lh_gordon333_neocortical_resampled = op.join(self.output_dir, "Gordon333_Freesurfer.Neocortical.L.%s_fs_LR.label.gii" % self.res_label)
        self.rh_gordon333_neocortical_resampled = op.join(self.output_dir, "Gordon333_Freesurfer.Neocortical.R.%s_fs_LR.label.gii" % self.res_label)

    def resample_s900(self):
        print("Resampling S900 surf")
        self.run("surface-resample", self.lh_s900_32k,
                self.lh_sphere_32k, self.targ_lh_sphere,
                'BARYCENTRIC', self.lh_s900_resampled)
        self.run("surface-resample", self.rh_s900_32k,
                self.rh_sphere_32k, self.targ_rh_sphere,
                'BARYCENTRIC', self.rh_s900_resampled)

    def resample_cifti_labels(self, lh_atlas_roi_resampled_surf, rh_atlas_roi_resampled_surf, atlas_rois_resampled_vol):
        print("Resample CIFTI neocortical labels")
        self.run("cifti-separate",
                self.gordon333_32k, "COLUMN",
                "-label CORTEX_LEFT", self.lh_gordon333_32k,
                "-label CORTEX_RIGHT", self.rh_gordon333_32k)

        self.run("label-resample",
                self.lh_gordon333_32k,
                self.lh_sphere_32k,
                self.targ_lh_sphere,
                "ADAP_BARY_AREA", self.lh_gordon333_neocortical_resampled,
                "-area-surfs", self.lh_s900_32k,
                self.lh_s900_resampled,
                "-current-roi", self.lh_fs_LR_32k_shape)
        self.run("label-resample",
                self.rh_gordon333_32k,
                self.rh_sphere_32k,
                self.targ_rh_sphere,
                "ADAP_BARY_AREA", self.rh_gordon333_neocortical_resampled,
                "-area-surfs", self.rh_s900_32k,
                self.rh_s900_resampled,
                "-current-roi", self.rh_fs_LR_32k_shape)
        self.run("cifti-create-label",
                self.gordon333_subcortical_resampled,
                "-volume", atlas_rois_resampled_vol, atlas_rois_resampled_vol,
                "-left-label", self.lh_gordon333_neocortical_resampled,
                "-roi-left", lh_atlas_roi_resampled_surf,
                "-right-label", self.rh_gordon333_neocortical_resampled,
                "-roi-right", rh_atlas_roi_resampled_surf)

    def generate_resampled_templates(self, lh_atlas_roi_resampled_surf, rh_atlas_roi_resampled_surf, atlas_rois_resampled_vol):
        self.resample_s900()
        self.resample_cifti_labels(lh_atlas_roi_resampled_surf, rh_atlas_roi_resampled_surf, atlas_rois_resampled_vol)
