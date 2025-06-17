shader_type canvas_item;

// Simple blink effect shader

uniform float blink_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 blink_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
    COLOR = blink_color;
    COLOR.a = blink_progress;
}