shader_type canvas_item;

// Reflet de la couronne de leader (LeaderCrown) : une bande claire en
// diagonale balaie la couronne de gauche a droite quand `shine` va de 0 a 1,
// et `flash` eclaircit toute la couronne. Applique au SubViewportContainer :
// COLOR est le pixel du rendu 3D (fond transparent), seuls les pixels de la
// couronne s'eclairent.

uniform float shine = -1.0;
uniform float flash = 0.0;
uniform float band_width = 0.16;

void fragment() {
	vec4 color = COLOR;
	// Position le long de la diagonale, de 0 (haut gauche) a 1 (bas droite),
	// avec de la marge pour que la bande entre et sorte entierement.
	float along = (UV.x + UV.y * 0.45) / 1.45;
	float center = mix(-band_width, 1.0 + band_width, shine);
	float band = 1.0 - smoothstep(0.0, band_width, abs(along - center));
	band *= step(0.0, shine) * step(shine, 1.0);
	color.rgb += (band * 0.85 + flash * 0.35) * vec3(1.0, 0.95, 0.8) * color.a;
	COLOR = color;
}
