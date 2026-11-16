shader_type canvas_item;
// The knight's death: knight_death.png fades him out in two key colours used
// nowhere else, white (the base) and magenta (the accent). Both take the
// colours of what killed him (see PuzzleKnight.die and GameOver.FADE_COLORS).

uniform vec4 base : source_color = vec4(1.0);
uniform vec4 accent : source_color = vec4(1.0, 0.0, 1.0, 1.0);

// The sheet's own two key colours.
const vec3 SHEET_BASE = vec3(1.0, 1.0, 1.0);
const vec3 SHEET_ACCENT = vec3(1.0, 0.0, 1.0);

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	if (distance(art.rgb, SHEET_BASE) < 0.05) {
		COLOR.rgb = base.rgb;
	} else if (distance(art.rgb, SHEET_ACCENT) < 0.05) {
		COLOR.rgb = accent.rgb;
	}
}
