from .base_generator import BaseFslGenerator, BaseWorkbenchGenerator
import os
import os.path as op
import subprocess

class AtlasROIsGenerator(BaseFslGenerator):
    def __init__(self, num_vertices, label, output_dir):
        super(AtlasROIsGenerator, self).__init__(output_dir)

        self.num_vertices = num_vertices
        self.label = label
        self.hcp_standard_mesh_atlases_dir = os.getenv('HCP_STANDARD_MESH_ATLASES_DIR')
        self.avgwmparc_file = op.join(self.hcp_standard_mesh_atlases_dir, 'Avgwmparc.nii.gz')

        self.output_dir = op.abspath(output_dir)
        self.spline_interp_roi_atlas_file = op.join(self.output_dir, "Atlas_ROIs.%s.spline_interp.nii.gz" % self.label)
        self.nn_interp_roi_atlas_file = op.join(self.output_dir, "Atlas_ROIs.%s.nn_interp.nii.gz" % self.label)

    def generate_atlas(self):
        print("Generating ROIs atlas (this would take 30 minutes or more)")
        flirt_kwargs = {
            'interp': 'spline',
            'in': self.avgwmparc_file,
            'ref': self.avgwmparc_file,
            'applyisoxfm': self.num_vertices,
            'out': self.spline_interp_roi_atlas_file
        }
        self.run("flirt", **flirt_kwargs)

        warp_args = ['--rel', '--interp=nn', "--premat=%s" % self.identity_mat_file]
        warp_kwargs = {
            'i': self.avgwmparc_file,
            'r': self.spline_interp_roi_atlas_file,
            'o': self.nn_interp_roi_atlas_file
        }
        self.run("applywarp", *warp_args, **warp_kwargs)

class AtlasROIVolGenerator(BaseWorkbenchGenerator):
    def __init__(self, res_label, output_dir):
        super(AtlasROIVolGenerator, self).__init__(output_dir)

        self.freesurfer_subcortical_label = op.join(self.hcp_pipelines_dir,
                "global", "config", "FreeSurferSubcorticalLabelTableLut.txt")

        self.res_label = res_label
        self.atlas_rois_vol_file = op.join(self.output_dir, "Atlas_ROIs.%s.nii.gz" % (self.res_label))

    def generate_roi_vol(self, input_atlas_vol_file):
        self.run("volume-label-import", input_atlas_vol_file,
                self.freesurfer_subcortical_label,
                self.atlas_rois_vol_file,
                "-discard-others", "-drop-ununsed-labels")
