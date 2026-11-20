shader_type canvas_item;
// Mixes whatever is drawn toward pure white by `flash` (0: as drawn, 1: white),
// keeping its shape. For hit flashes on dark sprites, which brightening can't
// turn white.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash);
}
