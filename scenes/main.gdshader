shader_type canvas_item;
uniform vec4  fog_color : source_color = vec4(0.0,0.0,0.0,0.90);
uniform float radius_px   = 360.0;
uniform float softness_px = 140.0;
uniform vec2  center_px   = vec2(0.0,0.0);
uniform vec2  screen_size = vec2(1152.0,648.0);
void fragment(){
    vec2 p = SCREEN_UV * screen_size;
    float d = distance(p, center_px);
    float a = smoothstep(radius_px, radius_px + softness_px, d);
    COLOR = vec4(fog_color.rgb, a * fog_color.a);
}
