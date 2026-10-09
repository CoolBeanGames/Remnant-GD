shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

uniform sampler2D portal_view : filter_linear;

void fragment() {
	ALBEDO = texture(portal_view, SCREEN_UV).rgb;
}
