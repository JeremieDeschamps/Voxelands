shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

// Shader d'eau procédurale semi-transparente avec vagues animées et écume côtière.

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

uniform vec4 shallow_color : source_color = vec4(0.18, 0.68, 0.95, 0.75);
uniform vec4 deep_color : source_color = vec4(0.06, 0.24, 0.60, 0.92);
uniform vec4 foam_color : source_color = vec4(0.88, 0.96, 1.0, 0.88);

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave1 = sin(TIME * 2.0 + v_world_pos.x * 2.2 + v_world_pos.z * 1.6) * 0.04;
	float wave2 = cos(TIME * 1.4 + v_world_pos.x * 1.1 - v_world_pos.z * 1.9) * 0.025;
	VERTEX.y += wave1 + wave2;
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 pixel_pos = upos.xyz / upos.w;
	float depth_diff = -pixel_pos.z - VERTEX.z;

	// Gradient de teinte selon la profondeur de l'eau
	float depth_factor = clamp(depth_diff * 0.45, 0.0, 1.0);
	vec3 water_col = mix(shallow_color.rgb, deep_color.rgb, depth_factor);

	// Liseré d'écume blanche sur les rivages et berges
	float foam_edge = clamp(1.0 - smoothstep(0.05, 0.28, depth_diff), 0.0, 1.0);
	float foam_ripple = sin(TIME * 3.2 + v_world_pos.x * 4.5 + v_world_pos.z * 4.5) * 0.5 + 0.5;
	float foam = foam_edge * foam_ripple;

	ALBEDO = mix(water_col, foam_color.rgb, foam * 0.65);
	ALPHA = mix(shallow_color.a, deep_color.a, depth_factor);
	ROUGHNESS = 0.12;
	SPECULAR = 0.80;
}
