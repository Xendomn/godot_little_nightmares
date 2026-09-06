shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

void vertex() {
	VERTEX.x += sin(VERTEX.y * 4.0 + TIME * 3.0) * .12 * UV.y;
}
void fragment() {
	float wisps = sin(UV.x * 31.0 + sin(UV.y * 18.0 - TIME * 4.0) * 2.0) * .5 + .5;
	float edge = sin(UV.x * 3.14159) * sin(UV.y * 3.14159);
	ALBEDO = vec3(.66, .79, .8);
	ALPHA = edge * (.18 + wisps * .5);
}
