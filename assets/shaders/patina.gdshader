shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color = vec4(0.25, 0.2, 0.15, 1.0);
uniform float grain = 0.0;
uniform float metal = 0.0;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898,78.233,39.425))) * 43758.5453); }
void fragment() {
    vec3 p = world_pos;
    float fleck = hash(floor(p * 170.0));
    float broad = sin(p.x * 4.1 + sin(p.z * 1.7)) * sin(p.y * 2.8 + p.z * 1.4);
    float streak = sin(p.x * 94.0 + 2.0 * sin(p.z * 1.8) + sin(p.x * 7.0));
    float tone = 0.9 + broad * 0.06 + (fleck - 0.5) * 0.13 + streak * grain * 0.1;
    ALBEDO = base_color.rgb * tone;
    ROUGHNESS = 0.82 + fleck * 0.13;
    METALLIC = metal;
}
