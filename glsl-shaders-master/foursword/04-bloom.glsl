// PASS 4/5 - Prepara il bloom: isola le zone chiare e le sfoca.
// In Four Swords le superfici illuminate "sbordano" leggermente sui
// contorni scuri. Gira a risoluzione ridotta, tanto e' tutto sfocato.

#pragma parameter FSA_BLOOM_THRESHOLD "Soglia bloom" 0.62 0.20 1.00 0.02

#include "fsa_common.inc"

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float FSA_BLOOM_THRESHOLD;
#else
#define FSA_BLOOM_THRESHOLD 0.62
#endif

void main()
{
    vec2 texel = 1.0 / max(InputSize, vec2(1.0));
    vec2 uv = vTexCoord;

    vec3 sum = vec3(0.0);
    float norm = 0.0;
    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            vec2 o = vec2(float(i), float(j));
            float wgt = exp(-dot(o, o) / 4.5);
            vec3 c = COMPAT_TEXTURE(Source, uv + o * texel * 1.5).rgb;
            float l = dot(c, vec3(0.299, 0.587, 0.114));
            float bright = smoothstep(FSA_BLOOM_THRESHOLD, min(FSA_BLOOM_THRESHOLD + 0.30, 1.0), l);
            sum += c * bright * wgt;
            norm += wgt;
        }
    }

    FragColor = vec4(sum / max(norm, 0.0001), 1.0);
}

#endif
