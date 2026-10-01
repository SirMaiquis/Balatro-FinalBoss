// FinalBoss screen vignette: darkens and tints the screen edges with the boss colour.
extern number fb_intensity; // 0 = off, 1 = strongest
extern vec3 fb_tint;        // boss colour, 0..1

vec4 effect(vec4 colour, Image tex, vec2 uv, vec2 screen_coords)
{
    vec4 px = Texel(tex, uv);
    float d = distance(uv, vec2(0.5, 0.5));
    float v = smoothstep(0.30, 0.80, d) * fb_intensity;
    vec3 tinted = mix(px.rgb, px.rgb * 0.4 + fb_tint * 0.6, v);
    return vec4(tinted * (1.0 - v * 0.25), px.a) * colour;
}
