shader_type sky;

// Ciel procédural dynamique avec dégradé jour/nuit, soleil visible et nuages procéduraux dérivants.

uniform vec3 day_top_color : source_color = vec3(0.22, 0.58, 0.96);
uniform vec3 day_horizon_color : source_color = vec3(0.72, 0.86, 0.98);
uniform vec3 night_top_color : source_color = vec3(0.02, 0.03, 0.08);
uniform vec3 night_horizon_color : source_color = vec3(0.06, 0.10, 0.20);
uniform vec3 sunset_color : source_color = vec3(0.95, 0.48, 0.20);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);

uniform float day_factor : hint_range(0.0, 1.0) = 1.0;
uniform float sunset_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);

float hash2(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float cloud_fbm(vec2 p) {
	float v = 0.0;
	v += noise2(p) * 0.5;
	v += noise2(p * 2.03) * 0.25;
	v += noise2(p * 4.01) * 0.125;
	return v;
}

void sky() {
	float eye_y = clamp(EYEDIR.y, -1.0, 1.0);

	// Dégradé céleste
	vec3 top_col = mix(night_top_color, day_top_color, day_factor);
	vec3 horiz_col = mix(night_horizon_color, day_horizon_color, day_factor);
	horiz_col = mix(horiz_col, sunset_color, sunset_factor * day_factor);

	vec3 sky_col = mix(top_col, horiz_col, clamp(1.0 - max(eye_y, 0.0) * 1.5, 0.0, 1.0));
	if (eye_y < 0.0) {
		sky_col = mix(horiz_col, vec3(0.12, 0.10, 0.08), clamp(-eye_y * 2.0, 0.0, 1.0));
	}

	// Soleil visible
	vec3 sun_dir = normalize(sun_direction);
	float sun_dot = max(dot(EYEDIR, sun_dir), 0.0);
	float sun_disc = smoothstep(0.997, 0.999, sun_dot);
	float sun_glow = pow(sun_dot, 32.0) * 0.6;
	vec3 sun_light_col = mix(vec3(1.0, 0.6, 0.3), vec3(1.0, 1.0, 0.9), day_factor);
	sky_col += (sun_disc * 2.5 + sun_glow) * sun_light_col * day_factor;

	// Nuages procéduraux dérivants au-dessus de l'horizon
	if (eye_y > 0.03) {
		vec2 plane_uv = (EYEDIR.xz / max(eye_y, 0.05)) * 0.15;
		vec2 wind_offset = vec2(TIME * 0.012, TIME * 0.006);
		float c = cloud_fbm(plane_uv + wind_offset);
		float cloud_alpha = smoothstep(0.42, 0.68, c) * clamp(eye_y * 3.5, 0.0, 1.0);

		vec3 c_tint = mix(vec3(0.08, 0.10, 0.16), cloud_color, day_factor);
		c_tint = mix(c_tint, sunset_color * 1.2, sunset_factor * 0.7 * day_factor);
		sky_col = mix(sky_col, c_tint, cloud_alpha * 0.75);
	}

	COLOR = sky_col;
}
