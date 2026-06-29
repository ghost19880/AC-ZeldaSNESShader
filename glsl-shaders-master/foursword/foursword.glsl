#pragma parameter PAINT_STRENGTH "Paint Stroke Strength" 2.0 0.0 2.0 0.05
#pragma parameter PAINT_SOFTEN "Paint Softening" 0.72 0.0 1.0 0.05
#pragma parameter PAINT_TINT "Warm/Cool Tint" 0.38 0.0 1.0 0.05
#pragma parameter PAINT_CONTRAST "Paint Contrast" 1.00 0.5 2.0 0.05

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
#else
#define PAINT_STRENGTH 2.0
#define PAINT_SOFTEN 0.72
#define PAINT_TINT 0.38
#define PAINT_CONTRAST 1.00
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

float soft_stroke(vec2 p, float angle, float scale)
{
    float s = sin(angle);
    float c = cos(angle);
    vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y) * scale;
    float warp = sin(q.x * 0.37 + hash(floor(q.xx * 0.21)) * 6.2831) * 0.46;
    float lane = 0.5 + 0.5 * sin(q.y + warp);
    float body = smoothstep(0.46, 0.84, lane);
    vec2 cell_q = q * vec2(0.46, 0.74);
    vec2 cell = floor(cell_q);
    vec2 cell_f = fract(cell_q);
    float h00 = hash(cell);
    float h10 = hash(cell + vec2(1.0, 0.0));
    float h01 = hash(cell + vec2(0.0, 1.0));
    float h11 = hash(cell + vec2(1.0, 1.0));
    vec2 u = cell_f * cell_f * (3.0 - 2.0 * cell_f);
    float smooth_segment = mix(mix(h00, h10, u.x), mix(h01, h11, u.x), u.y);
    float segment = mix(h00, smooth_segment, 0.65);
    segment = smoothstep(0.22, 0.70, segment);
    float bristle_a = 0.5 + 0.5 * sin(q.y * 13.5 + sin(q.x * 0.92) * 1.35);
    float bristle_b = 0.5 + 0.5 * sin(q.y * 21.0 + sin(q.x * 0.31) * 2.2);
    float bristles = smoothstep(0.24, 0.88, bristle_a) * 0.62 + smoothstep(0.36, 0.94, bristle_b) * 0.38;
    float dry = 0.45 + 0.55 * smoothstep(0.18, 0.76, hash(floor(q * vec2(0.95, 0.12))));
    float grain = 0.42 + 0.58 * bristles * dry;
    return body * segment * grain;
}

void main()
{
    vec2 uv = vTexCoord;
    vec2 source_size = max(InputSize, vec2(1.0));
    vec2 texel = 1.0 / source_size;
    vec2 screen_px = uv * source_size;
    vec2 world_px = screen_px + ScrollOffset;
    vec2 px = mix(world_px, floor(world_px / 2.0) * 2.0, 0.42);

    vec3 color = COMPAT_TEXTURE(Source, uv).rgb;
    vec3 smooth_color = similarity_smooth(uv, texel);

    vec3 blur = smooth_color * 0.46;
    blur += COMPAT_TEXTURE(Source, uv + vec2(1.0, 0.0) * texel).rgb * 0.135;
    blur += COMPAT_TEXTURE(Source, uv + vec2(-1.0, 0.0) * texel).rgb * 0.135;
    blur += COMPAT_TEXTURE(Source, uv + vec2(0.0, 1.0) * texel).rgb * 0.135;
    blur += COMPAT_TEXTURE(Source, uv + vec2(0.0, -1.0) * texel).rgb * 0.135;

    float detail = length(color - blur);
    float detail_mask = 1.0 - smoothstep(0.10, 0.32, detail);
    float luma = dot(blur, vec3(0.299, 0.587, 0.114));

    float a = soft_stroke(px + vec2(13.0, 5.0), 2.3562, 0.235);
    float b = soft_stroke(px + vec2(-4.0, 21.0), 2.3562, 0.175);
    float c = soft_stroke(px + vec2(37.0, -11.0), 2.3562, 0.120);
    float paint = clamp((a * 0.54 + b * 0.38 + c * 0.26) * (0.55 + detail_mask * 0.45) * PAINT_STRENGTH, 0.0, 1.0);

    vec3 warm = vec3(1.035, 1.005, 0.945);
    vec3 cool = vec3(0.94, 0.99, 1.035);
    vec3 tint = mix(vec3(1.0), mix(cool, warm, smoothstep(0.28, 0.78, luma)), PAINT_TINT);
    vec3 painted = mix(color, blur * tint, PAINT_SOFTEN);

    painted += paint * vec3(0.038, 0.027, 0.012);
    painted -= paint * vec3(0.220, 0.184, 0.132);
    painted -= (1.0 - paint) * 0.018 * detail_mask;
    painted = (painted - 0.5) * PAINT_CONTRAST + 0.5;
    painted = pow(clamp(painted, 0.0, 1.0), vec3(0.96));

    FragColor = vec4(painted, COMPAT_TEXTURE(Source, uv).a);
}
#endif
