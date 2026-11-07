shader_type spatial;
// HD-2D depth lens (the Octopath look): a full-screen quad drawn first in the transparent pass, so it sees the
// finished opaque frame (world + sprites) and its depth. It adds
//  - depth of field by real distance: a sharp band around the hero, foreground and background melt away,
//  - normal-aware SSAO: contact shadows where walls meet the ground, under eaves, around feet and props.
// Transparent things (name tags, bubbles, rain, light shafts) draw after it and stay crisp.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float focus_dist = 16.0;    // camera -> hero (set every frame by CameraRig)
uniform float focus_range = 2.2;    // half-width of the sharp band (m)
uniform float near_blur = 5.0;      // metres in front of the band to full blur
uniform float far_blur = 34.0;      // metres behind the band to full blur
uniform float far_range = 11.0;      // the band reaches further behind the hero (shop fronts stay readable)
uniform float max_radius = 4.5;     // blur radius in pixels at full blur (at 800 px tall)
uniform float near_strength = 1.0;
uniform float ao_strength = 0.9;
uniform float ao_radius = 0.9;      // metres
uniform vec3 ao_tint : source_color = vec3(0.18, 0.14, 0.3);  // AO darkens toward a cool purple, not black

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

vec3 view_pos(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return v.xyz / v.w;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float res = VIEWPORT_SIZE.y / 800.0;
	vec3 p = view_pos(uv, INV_PROJECTION_MATRIX);
	float z = -p.z;
	// --- depth of field ---
	float dz = z - focus_dist;
	float coc = dz < 0.0
		? smoothstep(focus_range, focus_range + near_blur, -dz) * near_strength
		: smoothstep(far_range, far_range + far_blur, dz);
	coc = clamp(coc, 0.0, 1.0);
	vec3 col = texture(screen_tex, uv).rgb;
	if (coc > 0.03) {
		float r = coc * max_radius * res;
		vec3 acc = col;
		float w = 1.0;
		for (int i = 0; i < 12; i++) {
			float fi = float(i);
			float a = fi * 2.39996;  // golden angle spiral
			float rr = sqrt((fi + 0.5) / 12.0) * r;
			vec2 o = vec2(cos(a), sin(a)) * rr * px;
			vec3 s = texture(screen_tex, uv + o).rgb;
			float bright = 1.0 + max(max(s.r, s.g), s.b) * 1.5;  // bright points bloom into bokeh discs
			acc += s * bright;
			w += bright;
		}
		col = acc / w;
	}
	// --- SSAO (normal-oriented, flat ground gets none) ---
	if (z < 80.0 && ao_strength > 0.0) {
		vec3 pr = view_pos(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
		vec3 pu = view_pos(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
		vec3 n = normalize(cross(pr - p, pu - p));
		if (dot(n, -p) < 0.0) {
			n = -n;
		}
		// pixels per metre at this depth (fov ~32 deg): H / (2 z tan(16 deg))
		float ppm = VIEWPORT_SIZE.y / (0.573 * max(z, 1.0));
		float occ = 0.0;
		for (int i = 0; i < 8; i++) {
			float fi = float(i);
			float a = fi * 2.39996 + 0.7;
			float s = (fi + 1.0) / 8.0;
			vec2 o = vec2(cos(a), sin(a)) * ao_radius * ppm * s * px;
			vec3 q = view_pos(uv + o, INV_PROJECTION_MATRIX);
			vec3 v = q - p;
			float dist = length(v);
			occ += max(0.0, dot(n, v) / (dist + 0.0001) - 0.15) * (1.0 - smoothstep(ao_radius, ao_radius * 3.0, dist));
		}
		float ao = clamp(occ / 8.0 * 1.6, 0.0, 1.0) * ao_strength;
		col = mix(col, col * ao_tint * 1.4, ao);
	}
	ALBEDO = col;
	ALPHA = 1.0;
}
