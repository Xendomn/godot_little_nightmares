shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform bool surface = false;
varying float height_fraction;
varying vec3 water_position;
void vertex() {
	height_fraction = VERTEX.y;
	water_position = VERTEX;
}
void fragment() {
	if (surface) {
		float ripple = sin(water_position.x * 3.1 + TIME * .7) * sin(water_position.z * 4.8 - TIME * .5);
		ALBEDO = mix(vec3(.055,.23,.25), vec3(.15,.39,.40), ripple * .16 + .5);
		NORMAL_MAP = vec3(.5 + ripple * .025, .5 + cos(water_position.x * 4.0 + TIME) * .025, 1.0);
		ROUGHNESS = .24;
		ALPHA = .44;
	} else {
		float depth = 1.0 - clamp(height_fraction, 0.0, 1.0);
		ALBEDO = mix(vec3(.09,.33,.35), vec3(.025,.13,.16), depth);
		ROUGHNESS = .38;
		ALPHA = mix(.32,.65,depth);
		EMISSION = ALBEDO * .16;
	}
	METALLIC = .05;
}
