from .base_generator import BaseFslGenerator
import os
import subprocess

class AtlasROIsGenerator(BaseFslGenerator):
    def __init__(self, num_vertices, label, output_dir):
        super(AtlasROIsGenerator, self).__init__(output_dir)

        self.num_vertices = num_vertices
        self.label = label
        self.hcp_standard_mesh_atlases_dir = os.getenv('HCP_STANDARD_MESH_ATLASES_DIR')
        self.avgwmparc_file = os.path.join(self.hcp_standard_mesh_atlases_dir, 'Avgwmparc.nii.gz')

        self.output_dir = os.path.abspath(output_dir)
        self.new_roi_atlas_file = os.path.join(self.output_dir, "Atlas_ROIs.%s.spline_interp.nii.gz" % self.label)
        self.nn_interp_roi_atlas_file = os.path.join(self.output_dir, "Atlas_ROIs.%s.nn_interp.nii.gz" % self.label)

    def generate_atlas(self):
        print("Generating ROIs atlas (this would take 30 minutes or more)")
        flirt_kwargs = {
            'interp': 'spline',
            'in': self.avgwmparc_file,
            'ref': self.avgwmparc_file,
            'applyisoxfm': self.num_vertices,
            'out': self.new_roi_atlas_file
        }
        self.run("flirt", **flirt_kwargs)

        warp_args = ['--rel', '--interp=nn', "--premat=%s" % self.identity_mat_file]
        warp_kwargs = {
            'i': self.avgwmparc_file,
            'r': self.new_roi_atlas_file,
            'o': self.nn_interp_roi_atlas_file
        }
        self.run("applywarp", *warp_args, **warp_kwargs)
