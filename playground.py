from utilities.spherical_template_generator import SphericalTemplateGenerator
from utilities.atlas_rois_generator import AtlasROIsGenerator
from utilities.mesh_template_generator import MeshTemplateGenerator

output_templates_dir = 'templates'

sphericalTemplateGenerator = SphericalTemplateGenerator(8000, output_templates_dir)
sphericalTemplateGenerator.generate_spheres()

atlasROIGenerator = AtlasROIsGenerator(
    sphericalTemplateGenerator.true_num_vertices,
    sphericalTemplateGenerator.label,
    output_templates_dir)
atlasROIGenerator.generate_atlas()

meshTemplateGenerator = MeshTemplateGenerator(
    sphericalTemplateGenerator.label,
    sphericalTemplateGenerator.left_sphere_file,
    sphericalTemplateGenerator.right_sphere_file,
    output_templates_dir)
meshTemplateGenerator.generate_shapes()
meshTemplateGenerator.generate_colins()
