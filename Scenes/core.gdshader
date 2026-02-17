shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.0) = 0.4;
uniform float softness : hint_range(0.0, 0.5) = 0.1;

void fragment() {
    float dist = distance(UV, vec2(0.5));
    // smoothstep creates the "fuzzy" transition
    float alpha = 1.0 - smoothstep(radius - softness, radius, dist);
    COLOR = vec4(0.0, 0.0, 0.0, alpha);
}