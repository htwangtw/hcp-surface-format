import os
import subprocess

class BaseWorkbenchGenerator:
    def __init__(self, output_dir):
        self.wb_dir = os.getenv('WB_DIR')
        self.hcp_pipelines_dir = os.getenv('HCP_PIPELINES_DIR')
        self.hcp_standard_mesh_atlases_dir = os.getenv('HCP_STANDARD_MESH_ATLASES_DIR')
        self.hcp_balsa_dir = os.getenv('HCP_BALSA_DIR')

        self.wb_command = os.path.join(self.wb_dir, "wb_command")

        self.output_dir = os.path.abspath(output_dir)
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)

    def run(self, subcommand, *args, **kwargs):
        cmd = "%s -%s %s" % (self.wb_command, subcommand, " ".join(args))
        try:
            proc = subprocess.run(cmd, check=True, shell=True, stdout=subprocess.PIPE)
            return proc.stdout.decode('utf-8')
        except subprocess.SubprocessError as e:
            print(e.stderr)

class BaseFslGenerator:
    def __init__(self, output_dir):
        # TODO: check existence of these directories
        self.fsl_dir = os.getenv('FSLDIR')
        self.fsl_bin_dir = os.path.join(self.fsl_dir, 'bin')
        self.identity_mat_file = os.path.join(self.fsl_dir, 'etc', 'flirtsch', 'ident.mat')
        
        self.output_dir = os.path.abspath(output_dir)
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)

    def run(self, command, *args, **kwargs):
        command_exec = os.path.join(self.fsl_bin_dir, command)
        cmd_args = ["-%s %s" % (key, str(value)) for (key, value) in kwargs.items()]
        cmd = "%s %s %s" % (command_exec, " ".join(args), " ".join(cmd_args))
        print(cmd)

        try:
            proc = subprocess.run(cmd, check=True, shell=True, stdout=subprocess.PIPE)
            return proc.stdout.decode('utf-8')
        except subprocess.SubprocessError as e:
            print(e.stderr)

