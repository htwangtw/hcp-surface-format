import os
import subprocess

class NewTemplateGenerator:
    def __init__(self, num_vertices, output_dir):
        self.wb_dir = os.getenv('WB_DIR')
        self.hcppipeline_dir = os.getenv('HCP_PIPELINE_DIR')
        self.num_vertices = num_vertices

        self.output_dir = os.path.abspath(output_dir)
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)
        
        self.right_sphere_file = os.path.join(self.output_dir, 'R.sphere.%d_fs_LR.surf.gii' % (self.num_vertices))
        self.left_sphere_file = os.path.join(self.output_dir, 'L.sphere.%d_fs_LR.surf.gii' % (self.num_vertices))

    def wb_command(self, arg):
        return "%s/wb_command %s" % (self.wb_dir, arg)

    def run(self, arg):
        subprocess.run(self.wb_command(arg), shell=True)

    def generate_spheres(self):
        self.run("-surface-create-sphere %d %s" % (self.num_vertices, self.right_sphere_file))
        self.run("-surface-flip-lr %s %s" % (self.right_sphere_file, self.left_sphere_file))
        self.run("-set-structure %s CORTEX_RIGHT" %(self.right_sphere_file))
        self.run("-set-structure %s CORTEX_LEFT" %(self.left_sphere_file))
