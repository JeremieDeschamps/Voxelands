shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Shader de terrain voxel avec variation aléatoire de teinte par bloc (±5%)
// et ondulation fluide au vent sur la végétation.

uniform float voxel_size : hint_range(0.1, 2.0) = 0.5;

varying vec3 v_world_pos;
varying vec4 v_vertex_color;

float hash3d(vec3 p) {
	vec3 b = floor(p / voxel_size + 0.05);
	float n = sin(dot(b, vec3(12.9898, 78.233, 45.164))) * 43758.5453;
	return fract(n);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_vertex_color = COLOR;

	// Balancement du vent sur la végétation (feuilles, fleurs, herbes)
	if (COLOR.g > 0.40 && (COLOR.g > COLOR.r * 1.1 || COLOR.r > 0.8)) {
		float wind = sin(TIME * 2.2 + v_world_pos.x * 0.9 + v_world_pos.z * 0.9) * 0.04;
		VERTEX.x += wind * min(VERTEX.y * 0.25, 0.08);
		VERTEX.z += wind * 0.6 * min(VERTEX.y * 0.25, 0.08);
	}
}

void fragment() {
	// Micro-variation déterministe de luminosité et de teinte de ±5% basée sur la position monde
	float noise_shift = (hash3d(v_world_pos) - 0.5) * 0.10;
	vec3 col = clamp(v_vertex_color.rgb * (1.0 + noise_shift), 0.0, 1.0);

	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.12;
}
