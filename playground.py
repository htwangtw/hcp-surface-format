from utilities.spherical_template_generator import SphericalTemplateGenerator
from utilities.atlas_rois_generator import AtlasROIsGenerator, AtlasROIVolGenerator
from utilities.mesh_template_generator import MeshTemplateGenerator
from utilities.group_template_resampler import GroupTemplateResampler

output_templates_dir = 'templates'

sphericalTemplateGenerator = SphericalTemplateGenerator(5000, output_templates_dir)
sphericalTemplateGenerator.generate_spheres()

# atlasROIGenerator = AtlasROIsGenerator(
#     sphericalTemplateGenerator.true_num_vertices,
#     sphericalTemplateGenerator.label,
#     output_templates_dir)
# atlasROIGenerator.generate_atlas()

atlasROIVolGenerator = AtlasROIVolGenerator(sphericalTemplateGenerator.label, output_templates_dir)
# atlasROIVolGenerator.generate_roi_vol('/Users/ngohgia/Work/hcp-surface-format/templates/Atlas_ROIs.8k.nn_interp.nii.gz')

meshTemplateGenerator = MeshTemplateGenerator(
    sphericalTemplateGenerator.label,
    sphericalTemplateGenerator.left_sphere_file,
    sphericalTemplateGenerator.right_sphere_file,
    output_templates_dir)
meshTemplateGenerator.generate_shapes()
meshTemplateGenerator.generate_colins()

groupTemplateResampler = GroupTemplateResampler(
    sphericalTemplateGenerator.label,
    sphericalTemplateGenerator.left_sphere_file,
    sphericalTemplateGenerator.right_sphere_file,
    output_templates_dir)
groupTemplateResampler.generate_resampled_templates(
    meshTemplateGenerator.output_lh_shape,
    meshTemplateGenerator.output_rh_shape,
    atlasROIVolGenerator.atlas_rois_vol_file)
