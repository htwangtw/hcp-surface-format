from .base_generator import BaseWorkbenchGenerator
import os
import subprocess

class MeshTemplateGenerator(BaseWorkbenchGenerator):
    def __init__(self, label, lh_sphere_file, rh_sphere_file, output_dir):
        super(MeshTemplateGenerator, self).__init__(output_dir)
        # TODO: these should be objects
        self.label = label
        self.lh_sphere_file = lh_sphere_file
        self.rh_sphere_file = rh_sphere_file

        self.lh_fs_LR_164k_shape = os.path.join(self.hcp_standard_mesh_atlases_dir,
                'L.atlasroi.164k_fs_LR.shape.gii')
        self.rh_fs_LR_164k_shape = os.path.join(self.hcp_standard_mesh_atlases_dir,
                'R.atlasroi.164k_fs_LR.shape.gii')

        self.lh_fs_LR_164k_colin = os.path.join(self.hcp_standard_mesh_atlases_dir,
                'colin.cerebral.L.flat.164k_fs_LR.surf.gii')
        self.rh_fs_LR_164k_colin = os.path.join(self.hcp_standard_mesh_atlases_dir,
                'colin.cerebral.R.flat.164k_fs_LR.surf.gii')

        self.lh_fs_LR_164k_fsaverage = os.path.join(self.hcp_standard_mesh_atlases_dir,
                'fsaverage.L_LR.spherical_std.164k_fs_LR.surf.gii')
        self.rh_fs_LR_164k_fsaverage = os.path.join(self.hcp_standard_mesh_atlases_dir,
                'fsaverage.R_LR.spherical_std.164k_fs_LR.surf.gii')
   
        self.output_lh_shape = os.path.join(self.output_dir,
                "L.atlasroi.%s_fs_LR.shape.gii" % self.label)
        self.output_rh_shape = os.path.join(self.output_dir,
                "R.atlasroi.%s_fs_LR.shape.gii" % self.label)
        self.output_lh_colin = os.path.join(self.output_dir,
                "colin.cerebral.L.flat.%s_fs_LR.surf.gii" % self.label)
        self.output_rh_colin = os.path.join(self.output_dir,
                "colin.cerebral.R.flat.%s_fs_LR.surf.gii" % self.label)


    def generate_shapes(self):
        print("Generating new shapes")
        self.run("metric-resample", self.lh_fs_LR_164k_shape,
                self.lh_fs_LR_164k_fsaverage, self.lh_sphere_file,
                'BARYCENTRIC', self.output_lh_shape, '-largest')
        self.run("metric-resample", self.rh_fs_LR_164k_shape,
                self.rh_fs_LR_164k_fsaverage, self.rh_sphere_file,
                'BARYCENTRIC', self.output_rh_shape, '-largest')

    def generate_colins(self):
        print("Generating new Colin27 meshes")
        self.run("surface-cut-resample", self.lh_fs_LR_164k_colin,
                self.lh_fs_LR_164k_fsaverage, self.lh_sphere_file,
                self.output_lh_colin)
        self.run("surface-cut-resample", self.rh_fs_LR_164k_colin,
                self.rh_fs_LR_164k_fsaverage, self.rh_sphere_file,
                self.output_rh_colin)
