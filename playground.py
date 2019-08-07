from utilities.spherical_template_generator import SphericalTemplateGenerator
from utilities.atlas_rois_generator import AtlasROIsGenerator

output_templates_dir = 'templates'

sphericalTemplateGenerator = SphericalTemplateGenerator(8000, output_templates_dir)
# sphericalTemplateGenerator.generate_spheres()
sphericalTemplateGenerator.true_num_vertices = 7842

atlasROIGenerator = AtlasROIsGenerator(sphericalTemplateGenerator.true_num_vertices, output_templates_dir)
atlasROIGenerator.generate_atlas()
