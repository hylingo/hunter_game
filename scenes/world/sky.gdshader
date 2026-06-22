shader_type sky;

// Blue-sky gradient + drifting fractal clouds, all procedural (no textures).

uniform vec3 sky_top    : source_color = vec3(0.25, 0.50, 0.85);
uniform vec3 sky_horizon: source_color = vec3(0.70, 0.82, 0.92);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow: source_color = vec3(0.62, 0.68, 0.78);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_sharpness : hint_range(1.0, 8.0) = 3.0;
uniform float cloud_speed = 0.006;
uniform float cloud_scale : hint_range(0.05, 2.0) = 0.25; // smaller = bigger clouds

// --- value noise + fbm ---
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
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
	for (int i = 0; i < 5; i++) {
		v += amp * noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void sky() {
	// Vertical gradient based on view direction height.
	float h = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 base = mix(sky_horizon, sky_top, pow(h, 0.5));

	// Project the view direction onto a "cloud plane" above the camera.
	// Skip clouds when looking near/below the horizon.
	vec3 col = base;
	if (EYEDIR.y > 0.02) {
		// Gentle dome projection: divide by a softened height so clouds stay
		// round overhead AND near the horizon (plain /y stretches them into streaks).
		float hh = max(EYEDIR.y, 0.30);
		vec2 uv = EYEDIR.xz / hh;
		uv *= cloud_scale * 6.0;                 // scale back up (hh floor shrank it)
		uv += TIME * cloud_speed * vec2(1.0, 0.3); // drift

		// Domain warping makes the noise clump into big billowy masses
		// instead of scattered speckles.
		vec2 q = vec2(fbm(uv), fbm(uv + vec2(5.2, 1.3)));
		vec2 r = vec2(fbm(uv + 4.0 * q + vec2(1.7, 9.2)),
		              fbm(uv + 4.0 * q + vec2(8.3, 2.8)));
		float n = fbm(uv + 4.0 * r);

		// Threshold the warped noise: only peaks above (1 - coverage) become
		// clouds, leaving clear blue gaps between distinct puffy masses.
		float thresh = 1.0 - cloud_coverage;
		float edge = 0.18 / cloud_sharpness;
		float c = smoothstep(thresh, thresh + edge, n);
		c = clamp(c, 0.0, 1.0);

		// fade clouds out toward the horizon so they don't smear
		float horizon_fade = smoothstep(0.02, 0.30, EYEDIR.y);
		c *= horizon_fade;

		// Shade: bright sunlit cores, shadowed thinner edges.
		vec3 cloud = mix(cloud_shadow, cloud_color, smoothstep(thresh, 1.0, n));
		col = mix(base, cloud, c);
	}

	COLOR = col;
}
