shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Effet de contour Fresnel subtil pour détacher le joueur et les monstres du décor voxel.

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 fresnel_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fresnel_intensity : hint_range(0.0, 1.0) = 0.28;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = roughness;

	// Rehaussement lumineux sur le contour de la silhouette
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO += fresnel_color.rgb * fresnel * fresnel_intensity;
}
