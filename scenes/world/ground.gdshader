shader_type spatial;
render_mode cull_back, diffuse_burley;

// Procedural grassy ground: layered value noise blends several green tones
// so the floor reads as a natural meadow instead of a flat color. No textures.

uniform vec3 grass_dark : source_color = vec3(0.16, 0.27, 0.11);
uniform vec3 grass_mid  : source_color = vec3(0.27, 0.40, 0.17);
uniform vec3 grass_light: source_color = vec3(0.42, 0.55, 0.26);
uniform vec3 dirt_color : source_color = vec3(0.34, 0.28, 0.17);
uniform float macro_scale = 0.06;   // large color patches
uniform float detail_scale = 0.9;   // fine speckle
uniform float dirt_amount = 0.12;   // how much bare-earth shows through
uniform float roughness_val = 0.95;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * value_noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz;

	// Large-scale variation: clear dark <-> mid <-> light green patches.
	float macro = fbm(uv * macro_scale);
	macro = clamp((macro - 0.5) * 1.8 + 0.5, 0.0, 1.0); // boost contrast
	vec3 col = mix(grass_dark, grass_mid, smoothstep(0.2, 0.5, macro));
	col = mix(col, grass_light, smoothstep(0.5, 0.8, macro));

	// Medium clumps so the meadow has visible texture at walking distance.
	float clump = fbm(uv * macro_scale * 4.0 + 17.0);
	col = mix(col, grass_dark, smoothstep(0.6, 0.85, clump) * 0.5);

	// Fine speckle so it isn't smooth up close.
	float detail = value_noise(uv * detail_scale);
	col *= mix(0.82, 1.15, detail);

	// Occasional patches of bare dirt.
	float dirt = smoothstep(1.0 - dirt_amount, 1.0, fbm(uv * macro_scale * 1.7 + 50.0));
	col = mix(col, dirt_color, dirt);

	ALBEDO = col;
	ROUGHNESS = roughness_val;
	SPECULAR = 0.1;
}
