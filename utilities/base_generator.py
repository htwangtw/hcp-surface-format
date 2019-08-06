import os
import subprocess

class BaseWorkbenchGenerator:
    def __init__(self, output_dir):
        self.wb_dir = os.getenv('WB_DIR')
        self.hcppipeline_dir = os.getenv('HCP_PIPELINE_DIR')
        self.wb_command = os.path.join(self.wb_dir, "wb_command")

        self.output_dir = os.path.abspath(output_dir)
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)

    def run(self, subcommand, args):
        try:
            cmd = "%s -%s %s" % (self.wb_command, subcommand, args)
            proc = subprocess.run(cmd, check=True, shell=True, stdout=subprocess.PIPE)
            return proc.stdout.decode('utf-8')
        except subprocess.SubprocessError as e:
            print(e.stderr)

