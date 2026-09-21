// PASS 3/5 - Kuwahara anisotropo: QUESTA e' la pennellata vera.
//
// Come funziona: attorno a ogni pixel si prende un'ellisse orientata
// lungo la direzione calcolata al pass 2, la si divide in 8 spicchi, e
// si tiene il colore medio dello spicchio piu' UNIFORME. Il risultato e'
// che le zone di colore si appiattiscono in macchie che seguono la forma
// (= pennellate) mentre i contorni restano netti.
//
// Differenza rispetto a sovrapporre rumore procedurale: qui la texture
// nasce dall'immagine stessa, quindi non "nuota" sopra al gioco.
//
// Gira a 3x la risoluzione nativa, cosi' il pennello e' piu' fine del
// pixel SNES invece di divorarlo.

#pragma parameter FSA_PAINT_RADIUS "Dimensione pennello (px SNES)" 1.90 0.30 3.00 0.05
#pragma parameter FSA_PAINT_SHARP  "Durezza pennellata"            3.00 1.00 12.00 0.25
#pragma parameter FSA_STROKE_LEN   "Allungamento pennellata"       1.00 0.00 2.00 0.05
#pragma parameter FSA_PIXEL_SHARP  "Nitidezza pixel sorgente"      2.60 1.00 8.00 0.10
#pragma parameter FSA_PAINT_MIX    "Quantita' di pittura"          0.88 0.00 1.00 0.02

#include "fsa_common.inc"

uniform sampler2D OrigTexture;
uniform COMPAT_PRECISION vec2 OrigTextureSize;

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float FSA_PAINT_RADIUS;
uniform COMPAT_PRECISION float FSA_PAINT_SHARP;
uniform COMPAT_PRECISION float FSA_STROKE_LEN;
uniform COMPAT_PRECISION float FSA_PIXEL_SHARP;
uniform COMPAT_PRECISION float FSA_PAINT_MIX;
#else
#define FSA_PAINT_RADIUS 1.90
#define FSA_PAINT_SHARP  3.00
#define FSA_STROKE_LEN   1.00
#define FSA_PIXEL_SHARP  2.60
#define FSA_PAINT_MIX    0.88
#endif

#define FSA_PI 3.14159265359

// Bilineare "nitida": interpola solo nell'ultimo pezzo di texel, cosi' i
// pixel restano definiti come in Four Swords ma senza scalettature dure.
vec3 sample_sharp(vec2 uv, vec2 sz, float sharp)
{
    vec2 p = uv * sz - 0.5;
    vec2 i = floor(p);
    vec2 f = p - i;
    f = clamp((f - 0.5) * sharp + 0.5, 0.0, 1.0);
    f = f * f * (3.0 - 2.0 * f);
    return COMPAT_TEXTURE(OrigTexture, (i + 0.5 + f) / sz).rgb;
}

void main()
{
    vec2 uv = vTexCoord;
    vec2 src_size = max(OrigTextureSize, vec2(1.0));
    vec2 src_texel = 1.0 / src_size;

    vec3 flow = COMPAT_TEXTURE(Source, uv).rgb;
    vec2 t = flow.xy * 2.0 - 1.0;
    if (dot(t, t) < 1e-8) t = vec2(0.0, 1.0);
    t = normalize(t);
    float aniso = clamp(flow.z, 0.0, 1.0);

    // L'ellisse si allunga lungo il bordo e si stringe di traverso:
    // e' quello che trasforma una macchia tonda in una pennellata.
    float stretch = 1.0 + aniso * FSA_STROKE_LEN;
    float major = FSA_PAINT_RADIUS * stretch;
    float minor = FSA_PAINT_RADIUS / stretch;

    mat2 rot = mat2(t.x, -t.y, t.y, t.x);
    mat2 ellipse = rot * mat2(major, 0.0, 0.0, minor);

    vec3 mean[8];
    vec3 moment[8];
    float wsum[8];
    for (int k = 0; k < 8; k++) {
        mean[k] = vec3(0.0);
        moment[k] = vec3(0.0);
        wsum[k] = 0.0;
    }

    const int N = 3;
    for (int j = -N; j <= N; j++) {
        for (int i = -N; i <= N; i++) {
            vec2 v = vec2(float(i), float(j)) / float(N);
            float r2 = dot(v, v);
            if (r2 > 1.0) continue;

            vec3 c = sample_sharp(uv + (ellipse * v) * src_texel, src_size, FSA_PIXEL_SHARP);
            float wr = exp(-2.0 * r2);

            if (r2 < 1e-6) {
                // Il centro appartiene a tutti gli spicchi.
                float wc = wr * 0.125;
                for (int k = 0; k < 8; k++) {
                    mean[k] += c * wc;
                    moment[k] += c * c * wc;
                    wsum[k] += wc;
                }
                continue;
            }

            // Ogni campione pesa su due spicchi adiacenti: niente bande.
            float s = (atan(v.y, v.x) + FSA_PI) * (4.0 / FSA_PI);
            int k0 = int(floor(s)) & 7;
            int k1 = (k0 + 1) & 7;
            float fr = fract(s);
            fr = fr * fr * (3.0 - 2.0 * fr);

            float w0 = wr * (1.0 - fr);
            float w1 = wr * fr;
            mean[k0] += c * w0;  moment[k0] += c * c * w0;  wsum[k0] += w0;
            mean[k1] += c * w1;  moment[k1] += c * c * w1;  wsum[k1] += w1;
        }
    }

    // Lo spicchio piu' uniforme vince.
    vec3 acc = vec3(0.0);
    float acc_w = 0.0;
    for (int k = 0; k < 8; k++) {
        if (wsum[k] <= 1e-6) continue;
        vec3 mk = mean[k] / wsum[k];
        vec3 vk = max(moment[k] / wsum[k] - mk * mk, vec3(0.0));
        float sigma2 = vk.r + vk.g + vk.b;
        float w = pow(1.0 + sigma2 * 100.0, -FSA_PAINT_SHARP);
        acc += mk * w;
        acc_w += w;
    }

    vec3 painted = (acc_w > 1e-6) ? acc / acc_w : sample_sharp(uv, src_size, FSA_PIXEL_SHARP);
    vec3 plain = sample_sharp(uv, src_size, FSA_PIXEL_SHARP);

    FragColor = vec4(mix(plain, painted, FSA_PAINT_MIX), 1.0);
}

#endif
