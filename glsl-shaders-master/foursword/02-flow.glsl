// PASS 2/5 - Sfoca il tensore e ne estrae il campo di flusso.
// La sfocatura serve a rendere la direzione coerente su zone larghe:
// senza, ogni pixel avrebbe una direzione diversa e le pennellate
// verrebbero fuori come rumore.
// Output: vec4(tangente.x * 0.5 + 0.5, tangente.y * 0.5 + 0.5, anisotropia, 1).
// Anche qui la tangente e' rimappata in 0..1 per stare in 8 bit; chi la
// legge (pass 3 e 5) la riporta in -1..1.

#pragma parameter FSA_FLOW_BLUR "Coerenza direzione pennellate" 2.20 0.5 6.0 0.10

#include "fsa_common.inc"

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float FSA_FLOW_BLUR;
#else
#define FSA_FLOW_BLUR 2.20
#endif

void main()
{
    vec2 texel = 1.0 / max(InputSize, vec2(1.0));
    vec2 uv = vTexCoord;

    // Gaussiana 7x7 sul tensore (il tensore e' lineare: si puo' mediare).
    float sigma = max(FSA_FLOW_BLUR, 0.25);
    float two_sigma_sq = 2.0 * sigma * sigma;

    vec3 sum = vec3(0.0);
    float norm = 0.0;
    for (int j = -3; j <= 3; j++) {
        for (int i = -3; i <= 3; i++) {
            vec2 o = vec2(float(i), float(j));
            float wgt = exp(-dot(o, o) / two_sigma_sq);
            sum += COMPAT_TEXTURE(Source, uv + o * texel).rgb * wgt;
            norm += wgt;
        }
    }
    // La sfocatura e' lineare e la codifica e' affine, quindi si puo'
    // decodificare dopo aver mediato.
    vec3 enc = sum / max(norm, 0.0001);
    vec3 g = vec3(enc.x, enc.y, (enc.z - 0.5) * 2.0);

    // Autovalori del tensore [[g.x, g.z], [g.z, g.y]].
    float d = g.x - g.y;
    float root = sqrt(d * d + 4.0 * g.z * g.z);
    float lambda1 = 0.5 * (g.x + g.y + root);
    float lambda2 = 0.5 * (g.x + g.y - root);

    // Autovettore minore = tangente al bordo = direzione della pennellata.
    vec2 v = vec2(lambda1 - g.x, -g.z);
    vec2 t = (dot(v, v) > 1e-12) ? normalize(v) : vec2(0.0, 1.0);

    // Anisotropia: 0 = zona piatta, 1 = bordo netto.
    float aniso = (lambda1 + lambda2 > 1e-8)
                ? (lambda1 - lambda2) / (lambda1 + lambda2)
                : 0.0;

    FragColor = vec4(t * 0.5 + 0.5, aniso, 1.0);
}

#endif
