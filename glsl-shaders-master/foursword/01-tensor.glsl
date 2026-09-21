// PASS 1/5 - Tensore di struttura (Sobel su RGB).
// Serve a capire, per ogni pixel, in che direzione "corre" la forma:
// le pennellate del pass 3 seguiranno questa direzione invece di
// essere spruzzate a caso sullo schermo.
// Output: vec4(gxx/4, gyy/4, gxy/8 + 0.5, 1).
// I valori sono compressi in 0..1 apposta: cosi' il pass gira anche su un
// framebuffer a 8 bit, senza bisogno di float_framebuffer. Il tensore esce
// scalato di 1/4, ma autovettori e anisotropia non cambiano con la scala,
// quindi il risultato e' identico.

#include "fsa_common.inc"

void main()
{
    vec2 texel = 1.0 / max(InputSize, vec2(1.0));
    vec2 uv = vTexCoord;

    vec3 nw = COMPAT_TEXTURE(Source, uv + vec2(-1.0, -1.0) * texel).rgb;
    vec3 n  = COMPAT_TEXTURE(Source, uv + vec2( 0.0, -1.0) * texel).rgb;
    vec3 ne = COMPAT_TEXTURE(Source, uv + vec2( 1.0, -1.0) * texel).rgb;
    vec3 w  = COMPAT_TEXTURE(Source, uv + vec2(-1.0,  0.0) * texel).rgb;
    vec3 e  = COMPAT_TEXTURE(Source, uv + vec2( 1.0,  0.0) * texel).rgb;
    vec3 sw = COMPAT_TEXTURE(Source, uv + vec2(-1.0,  1.0) * texel).rgb;
    vec3 s  = COMPAT_TEXTURE(Source, uv + vec2( 0.0,  1.0) * texel).rgb;
    vec3 se = COMPAT_TEXTURE(Source, uv + vec2( 1.0,  1.0) * texel).rgb;

    vec3 gx = (ne + 2.0 * e + se - nw - 2.0 * w - sw) * 0.25;
    vec3 gy = (sw + 2.0 * s + se - nw - 2.0 * n - ne) * 0.25;

    FragColor = vec4(dot(gx, gx) * 0.25,
                     dot(gy, gy) * 0.25,
                     dot(gx, gy) * 0.125 + 0.5,
                     1.0);
}

#endif
