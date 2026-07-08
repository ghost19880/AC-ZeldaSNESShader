#pragma parameter PAINT_STRENGTH "Paint Stroke Strength" 2.0 0.0 2.0 0.05
#pragma parameter PAINT_SOFTEN "Paint Softening" 0.72 0.0 1.0 0.05
#pragma parameter PAINT_TINT "Warm/Cool Tint" 0.38 0.0 1.0 0.05
#pragma parameter PAINT_CONTRAST "Paint Contrast" 1.00 0.5 2.0 0.05
#pragma parameter BRUSH_THRESHOLD "Brush Threshold" 0.38 0.0 1.0 0.05
#pragma parameter BRUSH_DISTORT "Brush Edge Distortion" 0.35 0.0 1.5 0.05
#pragma parameter SOFT_LIGHT "Soft Global Light" 0.22 0.0 1.0 0.05
#pragma parameter BLOOM_STRENGTH "Light Bloom" 0.26 0.0 1.0 0.05
#pragma parameter VIGNETTE_STRENGTH "Edge Shading" 0.24 0.0 1.0 0.05
#pragma parameter GC_COLOR "GameCube Color Grade" 0.42 0.0 1.0 0.05
#pragma parameter SHIMMER_STRENGTH "Water Magic Shimmer" 0.10 0.0 1.0 0.05
#pragma parameter PAINT_ANIM "Paint Texture Animation" 0.06 0.0 0.5 0.01
#pragma parameter BROAD_WASH "Broad Paint Wash" 0.72 0.0 1.0 0.05

#if defined(VERTEX)
#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying
#define COMPAT_ATTRIBUTE attribute
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 COL0;
COMPAT_VARYING vec4 TEX0;

uniform COMPAT_PRECISION mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

void main()
{
    gl_Position = VertexCoord.x * MVPMatrix[0] + VertexCoord.y * MVPMatrix[1] + VertexCoord.z * MVPMatrix[2] + VertexCoord.w * MVPMatrix[3];
    COL0 = COLOR;
    TEX0.xy = TexCoord.xy;
}

#elif defined(FRAGMENT)
#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform COMPAT_PRECISION vec2 ScrollOffset;
uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float PAINT_STRENGTH;
uniform COMPAT_PRECISION float PAINT_SOFTEN;
uniform COMPAT_PRECISION float PAINT_TINT;
uniform COMPAT_PRECISION float PAINT_CONTRAST;
uniform COMPAT_PRECISION float BRUSH_THRESHOLD;
uniform COMPAT_PRECISION float BRUSH_DISTORT;
uniform COMPAT_PRECISION float SOFT_LIGHT;
uniform COMPAT_PRECISION float BLOOM_STRENGTH;
uniform COMPAT_PRECISION float VIGNETTE_STRENGTH;
uniform COMPAT_PRECISION float GC_COLOR;
uniform COMPAT_PRECISION float SHIMMER_STRENGTH;
uniform COMPAT_PRECISION float PAINT_ANIM;
uniform COMPAT_PRECISION float BROAD_WASH;
#else
#define PAINT_STRENGTH 2.0
#define PAINT_SOFTEN 0.72
#define PAINT_TINT 0.38
#define PAINT_CONTRAST 1.00
#define BRUSH_THRESHOLD 0.38
#define BRUSH_DISTORT 0.35
#define SOFT_LIGHT 0.22
#define BLOOM_STRENGTH 0.26
#define VIGNETTE_STRENGTH 0.24
#define GC_COLOR 0.42
#define SHIMMER_STRENGTH 0.10
#define PAINT_ANIM 0.06
#define BROAD_WASH 0.72
#endif

#define vTexCoord TEX0.xy
#define Source Texture

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float color_dist(vec3 a, vec3 b)
{
    return dot(abs(a - b), vec3(0.3333));
}

float brush_noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float brush_fbm(vec2 p)
{
    float n = brush_noise(p) * 0.50;
    n += brush_noise(p * 2.17 + vec2(13.7, -8.3)) * 0.31;
    n += brush_noise(p * 4.41 + vec2(-4.6, 22.9)) * 0.19;
    return n;
}

vec3 brush_mask(vec2 p)
{
    vec2 q = p * vec2(0.055, 0.095);
    float n1 = brush_noise(q);
    float n2 = brush_noise(q * 2.15 + vec2(17.0, -9.0));
    float n3 = brush_noise(q * 4.25 + vec2(-3.0, 29.0));
    float alpha = n1 * 0.55 + n2 * 0.30 + n3 * 0.15;
    alpha = smoothstep(BRUSH_THRESHOLD - 0.22, BRUSH_THRESHOLD + 0.38, alpha);
    vec2 rg = vec2(brush_noise(q + vec2(41.0, 11.0)), brush_noise(q + vec2(-23.0, 37.0)));
    return vec3(rg, alpha);
}

vec3 similarity_smooth(vec2 uv, vec2 texel)
{
    vec3 c = COMPAT_TEXTURE(Source, uv).rgb;
    vec3 n = COMPAT_TEXTURE(Source, uv + vec2(0.0, -1.0) * texel).rgb;
    vec3 s = COMPAT_TEXTURE(Source, uv + vec2(0.0, 1.0) * texel).rgb;
    vec3 e = COMPAT_TEXTURE(Source, uv + vec2(1.0, 0.0) * texel).rgb;
    vec3 w = COMPAT_TEXTURE(Source, uv + vec2(-1.0, 0.0) * texel).rgb;
    vec3 ne = COMPAT_TEXTURE(Source, uv + vec2(1.0, -1.0) * texel).rgb;
    vec3 nw = COMPAT_TEXTURE(Source, uv + vec2(-1.0, -1.0) * texel).rgb;
    vec3 se = COMPAT_TEXTURE(Source, uv + vec2(1.0, 1.0) * texel).rgb;
    vec3 sw = COMPAT_TEXTURE(Source, uv + vec2(-1.0, 1.0) * texel).rgb;

    float wn = smoothstep(0.22, 0.02, color_dist(c, n));
    float ws = smoothstep(0.22, 0.02, color_dist(c, s));
    float we = smoothstep(0.22, 0.02, color_dist(c, e));
    float ww = smoothstep(0.22, 0.02, color_dist(c, w));
    float wne = smoothstep(0.18, 0.02, color_dist(c, ne));
    float wnw = smoothstep(0.18, 0.02, color_dist(c, nw));
    float wse = smoothstep(0.18, 0.02, color_dist(c, se));
    float wsw = smoothstep(0.18, 0.02, color_dist(c, sw));

    vec3 cross = (c * 2.2 + n * wn + s * ws + e * we + w * ww) / (2.2 + wn + ws + we + ww);
    vec3 diag = (ne * wne + nw * wnw + se * wse + sw * wsw) / max(0.001, wne + wnw + wse + wsw);
    float diag_weight = smoothstep(0.02, 0.18, wne + wnw + wse + wsw);
    return mix(cross, diag, diag_weight * 0.18);
}

vec3 soft_bloom(vec2 uv, vec2 texel)
{
    vec3 sum = COMPAT_TEXTURE(Source, uv).rgb * 0.22;
    sum += COMPAT_TEXTURE(Source, uv + vec2(2.0, 0.0) * texel).rgb * 0.11;
    sum += COMPAT_TEXTURE(Source, uv + vec2(-2.0, 0.0) * texel).rgb * 0.11;
    sum += COMPAT_TEXTURE(Source, uv + vec2(0.0, 2.0) * texel).rgb * 0.11;
    sum += COMPAT_TEXTURE(Source, uv + vec2(0.0, -2.0) * texel).rgb * 0.11;
    sum += COMPAT_TEXTURE(Source, uv + vec2(2.0, 2.0) * texel).rgb * 0.085;
    sum += COMPAT_TEXTURE(Source, uv + vec2(-2.0, 2.0) * texel).rgb * 0.085;
    sum += COMPAT_TEXTURE(Source, uv + vec2(2.0, -2.0) * texel).rgb * 0.085;
    sum += COMPAT_TEXTURE(Source, uv + vec2(-2.0, -2.0) * texel).rgb * 0.085;
    float bright = smoothstep(0.54, 0.92, dot(sum, vec3(0.299, 0.587, 0.114)));
    return sum * bright;
}

float soft_stroke(vec2 p, float scale)
{
    float s = 0.7660;
    float c = -0.6428;
    vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y) * scale;
    float warp = brush_noise(q * vec2(0.32, 0.18) + vec2(8.0, 3.0)) * 2.0 - 1.0;
    warp += sin(q.x * 0.23 + brush_noise(q * 0.11) * 6.2831) * 0.55;
    float lane = 0.5 + 0.5 * sin(q.y * 0.72 + warp * 1.35);
    float body = smoothstep(0.42, 0.88, lane);
    vec2 cell_q = q * vec2(0.22, 0.31);
    vec2 cell = floor(cell_q);
    vec2 cell_f = fract(cell_q);
    float h00 = hash(cell);
    float h10 = hash(cell + vec2(1.0, 0.0));
    float h01 = hash(cell + vec2(0.0, 1.0));
    float h11 = hash(cell + vec2(1.0, 1.0));
    vec2 u = cell_f * cell_f * (3.0 - 2.0 * cell_f);
    float smooth_segment = mix(mix(h00, h10, u.x), mix(h01, h11, u.x), u.y);
    float segment = mix(h00, smooth_segment, 0.82);
    segment = smoothstep(0.24, 0.72, segment);
    float bristle_a = 0.5 + 0.5 * sin(q.y * 7.5 + sin(q.x * 0.55) * 1.15);
    float bristle_b = 0.5 + 0.5 * sin(q.y * 12.0 + sin(q.x * 0.27) * 1.8);
    float bristles = smoothstep(0.24, 0.86, bristle_a) * 0.62 + smoothstep(0.34, 0.90, bristle_b) * 0.36;
    vec2 wash_q = q * vec2(0.16, 0.23);
    wash_q += vec2(brush_noise(q * 0.19 + vec2(31.0, 7.0)), brush_noise(q * 0.17 + vec2(-11.0, 29.0))) * 2.1;
    float wash = brush_fbm(wash_q + vec2(19.0, -7.0));
    wash = smoothstep(0.30, 0.78, wash);
    float grain = mix(0.50 + bristles, wash, BROAD_WASH * 0.34);
    return body * segment * grain;
}

float fine_stroke(vec2 p, float scale)
{
    float s = 0.7660;
    float c = -0.6428;
    vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y) * scale;
    float warp = brush_fbm(q * vec2(0.28, 0.18) + vec2(5.0, -17.0)) * 2.0 - 1.0;
    float lane = 0.5 + 0.5 * sin(q.y * 0.82 + warp * 1.35);
    float body = smoothstep(0.46, 0.84, lane);
    float broken = brush_fbm(q * vec2(0.78, 0.92) + vec2(23.0, 9.0));
    broken = smoothstep(0.42, 0.84, broken);
    float dab = brush_fbm(q * vec2(1.18, 0.64) + vec2(-15.0, 37.0));
    dab = smoothstep(0.38, 0.80, dab);
    float bristle = 0.5 + 0.5 * sin(q.y * 11.0 + sin(q.x * 0.62) * 1.45);
    bristle = smoothstep(0.46, 0.88, bristle);
    return body * broken * dab * (0.68 + bristle * 0.32);
}

vec4 canvas_variation(vec2 p, float luma)
{
    float s = 0.7660;
    float c = -0.6428;
    vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
    float weave = brush_fbm(q * vec2(0.18, 0.42) + vec2(3.0, 17.0));
    float small = brush_fbm(q * vec2(0.62, 1.15) + vec2(-21.0, 6.0));
    float pools = brush_fbm(p * vec2(0.028, 0.037) + vec2(41.0, -19.0));
    float cover = brush_fbm(p * vec2(0.020, 0.027) + vec2(-53.0, 18.0));
    cover = smoothstep(0.18, 0.74, cover);
    float grain = (weave - 0.5) * 0.032 + (small - 0.5) * 0.018 + (pools - 0.5) * 0.040;
    grain -= smoothstep(0.62, 0.90, pools) * 0.016;
    float warm_shift = (brush_noise(q * 0.23 + vec2(9.0, -31.0)) - 0.5) * 0.018;
    vec3 value = vec3(grain);
    vec3 chroma = vec3(warm_shift, warm_shift * 0.45, -warm_shift * 0.60);
    return vec4((value + chroma) * (0.68 + luma * 0.28), cover);
}

void main()
{
    vec2 uv = vTexCoord;
    vec2 source_size = max(InputSize, vec2(1.0));
    vec2 texel = 1.0 / source_size;
    vec2 screen_px = uv * source_size;
    vec2 world_px = screen_px + ScrollOffset;
    vec2 px = mix(world_px, floor(world_px / 2.0) * 2.0, 0.42);
    vec3 mask_base = brush_mask(px);
    vec2 indtex_offset = (mask_base.xy * 2.0 - 1.0) * BRUSH_DISTORT * 9.0;
    vec3 mask = brush_mask(px + indtex_offset);
    vec2 paint_uv = uv;

    vec3 color = COMPAT_TEXTURE(Source, paint_uv).rgb;
    vec3 smooth_color = similarity_smooth(paint_uv, texel);

    vec3 blur = smooth_color;

    float detail = length(color - blur);
    float detail_mask = 1.0 - smoothstep(0.10, 0.32, detail);
    float luma = dot(blur, vec3(0.299, 0.587, 0.114));

    float t = float(FrameCount) * 0.016;
    float anim = 1.0 + (brush_noise(world_px * 0.018 + vec2(t * 0.05, -t * 0.035)) - 0.5) * PAINT_ANIM;
    float a = soft_stroke(px + vec2(13.0, 5.0), 0.125);
    float b = soft_stroke(px + vec2(-4.0, 21.0), 0.086);
    float c = soft_stroke(px + vec2(37.0, -11.0), 0.060);
    float d = soft_stroke(px + vec2(-31.0, 43.0), 0.040);
    float fa = fine_stroke(px + vec2(7.0, -3.0), 0.26);
    float fb = fine_stroke(px + vec2(-19.0, 14.0), 0.36);
    float fc = fine_stroke(px + vec2(29.0, 31.0), 0.46);
    vec2 broad_q = px * vec2(0.031, 0.044) + vec2(mask.x * 5.0, mask.y * -5.0);
    broad_q += vec2(brush_noise(px * 0.021 + vec2(71.0, -12.0)), brush_noise(px * 0.024 + vec2(-35.0, 48.0))) * 3.6;
    float broad = brush_fbm(broad_q);
    broad = smoothstep(0.34, 0.74, broad);
    float fine = fa * 0.15 + fb * 0.13 + fc * 0.10;
    float paint = clamp((a * 0.34 + b * 0.30 + c * 0.24 + d * 0.20 + fine + broad * BROAD_WASH * 0.12) * mask.z * (0.50 + detail_mask * 0.50) * PAINT_STRENGTH * anim, 0.0, 1.0);
    vec4 canvas_data = canvas_variation(px + mask.xy * 11.0, luma);
    vec3 canvas = canvas_data.rgb * PAINT_STRENGTH;
    float canvas_cover = mix(0.10, 0.74, canvas_data.a);

    vec3 warm = vec3(1.035, 1.005, 0.945);
    vec3 cool = vec3(0.94, 0.99, 1.035);
    vec3 tint = mix(vec3(1.0), mix(cool, warm, smoothstep(0.28, 0.78, luma)), PAINT_TINT);
    vec3 painted = mix(color, blur * tint, clamp(PAINT_SOFTEN - 0.18, 0.0, 1.0));

    painted += canvas * canvas_cover;
    painted += canvas * paint * 0.65;
    painted += paint * vec3(0.048, 0.034, 0.016);
    painted -= paint * vec3(0.285, 0.235, 0.162);
    painted += (paint - 0.5) * vec3(0.070, 0.052, 0.030);
    painted -= (1.0 - paint) * 0.018 * detail_mask;
    vec3 bloom = soft_bloom(paint_uv, texel);
    float soft_light = smoothstep(0.12, 0.86, luma) * (1.0 - detail * 0.75);
    painted = mix(painted, painted + vec3(0.060, 0.046, 0.026) * soft_light, SOFT_LIGHT);
    painted += bloom * BLOOM_STRENGTH * vec3(1.05, 0.96, 0.82);
    float blue_mask = smoothstep(0.05, 0.32, color.b - max(color.r, color.g) * 0.72) * smoothstep(0.18, 0.78, color.b);
    float magic_mask = smoothstep(0.30, 0.86, max(max(color.r, color.g), color.b)) * smoothstep(0.09, 0.36, color.b - color.r);
    float shimmer = sin((world_px.x * 0.15 - world_px.y * 0.11) + t * 3.1) * 0.5 + 0.5;
    painted += (blue_mask + magic_mask * 0.45) * shimmer * SHIMMER_STRENGTH * vec3(0.045, 0.075, 0.115);
    vec3 gc_grade = vec3(
        painted.r * 1.045 + painted.g * 0.012,
        painted.g * 1.015,
        painted.b * 0.955
    );
    painted = mix(painted, gc_grade, GC_COLOR);
    vec2 centered = uv * 2.0 - 1.0;
    float vignette = smoothstep(1.22, 0.18, dot(centered, centered));
    painted *= mix(1.0 - VIGNETTE_STRENGTH * 0.42, 1.0, vignette);
    painted = (painted - 0.5) * PAINT_CONTRAST + 0.5;
    painted = pow(clamp(painted, 0.0, 1.0), vec3(0.96));

    FragColor = vec4(painted, COMPAT_TEXTURE(Source, paint_uv).a);
}
#endif
