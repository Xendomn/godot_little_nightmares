shader_type spatial;
uniform float powered = 0.0;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float belt = fract((world_pos.x - TIME * powered * 0.55) * 2.5);
    float seam = smoothstep(0.01, 0.06, belt) * (1.0 - smoothstep(0.93,0.99,belt));
    float scratch = sin(world_pos.z * 165.0) * 0.018;
    ALBEDO = mix(vec3(0.09,0.12,0.13), vec3(0.25,0.31,0.32), seam) + scratch;
    METALLIC = 0.35;
    ROUGHNESS = 0.77;
}
