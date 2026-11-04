shader_type spatial;

// Seconde passe de l'estompage des logos du carrousel (voir
// GameLogo3D.set_opacity()). Le logo est d'abord rendu opaque ; ce masque le
// redessine ensuite en blanc, en multiplication : les couleurs de l'image
// restent intactes et seul son alpha est multiplie par l'opacite. Le masque
// n'ecrit pas la profondeur, et le test de profondeur ne laisse passer que la
// surface la plus proche : les faces internes du logo, cachees par la
// premiere passe, ne comptent pas. Le SubViewportContainer compose ensuite
// l'image avec le fond selon cet alpha.
render_mode unshaded, blend_mul, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	ALBEDO = vec3(1.0);
	ALPHA = opacity;
}
