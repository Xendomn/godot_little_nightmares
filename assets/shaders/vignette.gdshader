shader_type canvas_item;
render_mode unshaded;
void fragment() {
    vec2 q = UV * 2.0 - 1.0;
    float vignette = smoothstep(0.4, 1.42, length(q * vec2(0.87, 1.0)));
    float noise = fract(sin(dot(UV * vec2(1920.0,1080.0), vec2(12.9898,78.233))) * 43758.5453);
    COLOR = vec4(0.015, 0.027, 0.04, vignette * 0.37 + noise * 0.018);
}
