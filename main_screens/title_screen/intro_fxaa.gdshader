shader_type canvas_item;

// FXAA (version "console" de T. Lottes) applique a la texture de la couche
// 3D de l'intro. Le renderer Compatibility utilise sur la carte n'a pas
// d'AA d'ecran, et son MSAA coute ~11 ms par frame sur le Mali-G610 (30 FPS
// au lieu de 60). Calcule en alpha premultiplie, avec l'alpha dans la
// luminance, pour lisser aussi le contour des objets sur le fond transparent.

const float EDGE_THRESHOLD_MIN = 0.0312;
const float EDGE_THRESHOLD = 0.125;
const float REDUCE_MIN = 1.0 / 128.0;
const float REDUCE_MUL = 1.0 / 8.0;
const float SPAN_MAX = 8.0;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

// TEXTURE n'est accessible que dans fragment() : macro plutot que fonction.
#define SAMPLE(uv) premul(texture(TEXTURE, uv))

vec4 premul(vec4 c) {
	return vec4(c.rgb * c.a, c.a);
}

float luma(vec4 p) {
	return dot(p.rgb, vec3(0.299, 0.587, 0.114)) * 0.75 + p.a * 0.25;
}

vec4 unpremul(vec4 p) {
	return vec4(p.a > 0.0 ? p.rgb / p.a : vec3(0.0), p.a);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 m = SAMPLE(UV);
	vec4 nw = SAMPLE(UV + vec2(-1.0, -1.0) * px);
	vec4 ne = SAMPLE(UV + vec2(1.0, -1.0) * px);
	vec4 sw = SAMPLE(UV + vec2(-1.0, 1.0) * px);
	vec4 se = SAMPLE(UV + vec2(1.0, 1.0) * px);
	float l_m = luma(m);
	float l_nw = luma(nw);
	float l_ne = luma(ne);
	float l_sw = luma(sw);
	float l_se = luma(se);
	float l_min = min(l_m, min(min(l_nw, l_ne), min(l_sw, l_se)));
	float l_max = max(l_m, max(max(l_nw, l_ne), max(l_sw, l_se)));

	vec4 p = m;
	if (l_max - l_min >= max(EDGE_THRESHOLD_MIN, l_max * EDGE_THRESHOLD)) {
		vec2 dir = vec2(-((l_nw + l_ne) - (l_sw + l_se)), (l_nw + l_sw) - (l_ne + l_se));
		float reduce = max((l_nw + l_ne + l_sw + l_se) * 0.25 * REDUCE_MUL, REDUCE_MIN);
		float rcp_dir_min = 1.0 / (min(abs(dir.x), abs(dir.y)) + reduce);
		dir = clamp(dir * rcp_dir_min, vec2(-SPAN_MAX), vec2(SPAN_MAX)) * px;
		vec4 a = 0.5 * (SAMPLE(UV + dir * (1.0 / 3.0 - 0.5))
				+ SAMPLE(UV + dir * (2.0 / 3.0 - 0.5)));
		vec4 b = a * 0.5 + 0.25 * (SAMPLE(UV - dir * 0.5)
				+ SAMPLE(UV + dir * 0.5));
		float l_b = luma(b);
		p = (l_b < l_min || l_b > l_max) ? a : b;
	}
	COLOR = unpremul(p) * modulate;
}
