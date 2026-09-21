// PASS 5/5 - Composizione finale.
// Pittura (pass 3) + contorni morbidi + grana di tela + bloom + color grade.
//
// I numeri del color grade non sono a occhio: vengono dal confronto fra
// snes.png e foursword.png (saturazione +16%, luminanza -10%, verde e blu
// piu' bassi del rosso).

#pragma parameter FSA_OUTLINE      "Forza contorni"            0.28 0.00 1.50 0.05
#pragma parameter FSA_OUTLINE_WARM "Contorni caldi (no nero)"  0.55 0.00 1.00 0.05
#pragma parameter FSA_CANVAS       "Velatura a pennello"       1.00 0.00 2.00 0.05
#pragma parameter FSA_CANVAS_SCALE "Finezza grana"             1.00 0.30 3.00 0.05
#pragma parameter FSA_BLOOM        "Bloom"                     0.22 0.00 1.00 0.02
#pragma parameter FSA_SATURATION   "Saturazione"               1.08 0.50 2.00 0.02
#pragma parameter FSA_GAMMA        "Gamma"                     1.05 0.60 1.60 0.02
#pragma parameter FSA_WARMTH       "Tinta calda"               0.35 0.00 1.50 0.05
#pragma parameter FSA_CONTRAST     "Contrasto a S"             0.18 0.00 0.80 0.02
#pragma parameter FSA_VIGNETTE     "Vignettatura"              0.06 0.00 0.60 0.02
#pragma parameter FSA_SOFTEN       "Morbidezza"                0.18 0.00 1.00 0.02
#pragma parameter FSA_KEEP_SPRITES "Lascia nitidi gli sprite"  1.00 0.00 1.00 0.05
#pragma parameter FSA_KEEP_HUD     "Lascia nitido l'HUD (BG3)" 1.00 0.00 1.00 0.05
#pragma parameter FSA_SKIP_MENUS   "Spegni l'effetto nei menu" 1.00 0.00 1.00 1.00

#include "fsa_common.inc"

uniform sampler2D OrigTexture;
uniform COMPAT_PRECISION vec2 OrigTextureSize;
uniform sampler2D Pass3Texture;
uniform COMPAT_PRECISION vec2 Pass3TextureSize;
uniform COMPAT_PRECISION vec2 ScrollOffset;
// Modulo di gioco + 1 (0 = uniform non valorizzato, cioe' eseguibile vecchio).
uniform COMPAT_PRECISION float GameModule;

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float FSA_OUTLINE;
uniform COMPAT_PRECISION float FSA_OUTLINE_WARM;
uniform COMPAT_PRECISION float FSA_CANVAS;
uniform COMPAT_PRECISION float FSA_CANVAS_SCALE;
uniform COMPAT_PRECISION float FSA_BLOOM;
uniform COMPAT_PRECISION float FSA_SATURATION;
uniform COMPAT_PRECISION float FSA_GAMMA;
uniform COMPAT_PRECISION float FSA_WARMTH;
uniform COMPAT_PRECISION float FSA_CONTRAST;
uniform COMPAT_PRECISION float FSA_VIGNETTE;
uniform COMPAT_PRECISION float FSA_SOFTEN;
uniform COMPAT_PRECISION float FSA_KEEP_SPRITES;
uniform COMPAT_PRECISION float FSA_KEEP_HUD;
uniform COMPAT_PRECISION float FSA_SKIP_MENUS;
uniform COMPAT_PRECISION float FSA_PIXEL_SHARP;
#else
#define FSA_OUTLINE      0.28
#define FSA_OUTLINE_WARM 0.55
#define FSA_CANVAS       1.00
#define FSA_CANVAS_SCALE 1.00
#define FSA_BLOOM        0.22
#define FSA_SATURATION   1.08
#define FSA_GAMMA        1.05
#define FSA_WARMTH       0.35
#define FSA_CONTRAST     0.18
#define FSA_VIGNETTE     0.06
#define FSA_SOFTEN       0.18
#define FSA_KEEP_SPRITES 1.00
#define FSA_KEEP_HUD     1.00
#define FSA_SKIP_MENUS   1.00
#define FSA_PIXEL_SHARP  2.60
#endif

float hash21(vec2 p)
{
    p = fract(p * vec2(233.34, 851.73));
    p += dot(p, p + 23.45);
    return fract(p.x * p.y);
}

float vnoise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p)
{
    return vnoise(p) * 0.55
         + vnoise(p * 2.03 + vec2(11.3, -7.1)) * 0.30
         + vnoise(p * 4.11 + vec2(-5.7, 19.4)) * 0.15;
}

// --- Maschera dei layer ---------------------------------------------------
// Il PPU di zelda3 e' stato modificato per scrivere, nel canale alpha di ogni
// pixel, l'indice del layer da cui quel pixel viene:
//   0 = BG1   1 = BG2   2 = BG3 (HUD)   3 = BG4   4 = OBJ (sprite)   5 = sfondo
// Con un eseguibile non modificato l'alpha e' sempre 0, quindi la maschera
// resta vuota e lo shader si comporta come prima: niente si rompe.

float layer_at(vec2 uv)
{
    return floor(COMPAT_TEXTURE(OrigTexture, uv).a * 255.0 + 0.5);
}

// 1 = pixel da lasciare stare.
float protect_of(float layer)
{
    float sprite = step(3.5, layer) * step(layer, 4.5);  // layer == 4
    float hud    = step(1.5, layer) * step(layer, 2.5);  // layer == 2
    return clamp(sprite * FSA_KEEP_SPRITES + hud * FSA_KEEP_HUD, 0.0, 1.0);
}

// Il confronto va fatto sui singoli texel e interpolato DOPO. Interpolando
// l'indice di layer si otterrebbero valori intermedi che non esistono
// (fra BG3=2 e OBJ=4 uscirebbe 3, cioe' BG4: un layer sbagliato).
float protect_mask(vec2 uv, vec2 sz)
{
    vec2 p = uv * sz - 0.5;
    vec2 i = floor(p);
    vec2 f = p - i;
    f = f * f * (3.0 - 2.0 * f);
    vec2 base = (i + 0.5) / sz;
    vec2 tx = vec2(1.0 / sz.x, 0.0);
    vec2 ty = vec2(0.0, 1.0 / sz.y);

    float m00 = protect_of(layer_at(base));
    float m10 = protect_of(layer_at(base + tx));
    float m01 = protect_of(layer_at(base + ty));
    float m11 = protect_of(layer_at(base + tx + ty));
    return mix(mix(m00, m10, f.x), mix(m01, m11, f.x), f.y);
}

// Stesso campionamento "nitido" del pass 3, per restituire lo sprite come
// sarebbe senza pittura.
vec3 sample_sharp(vec2 uv, vec2 sz, float sharp)
{
    vec2 p = uv * sz - 0.5;
    vec2 i = floor(p);
    vec2 f = p - i;
    f = clamp((f - 0.5) * sharp + 0.5, 0.0, 1.0);
    f = f * f * (3.0 - 2.0 * f);
    return COMPAT_TEXTURE(OrigTexture, (i + 0.5 + f) / sz).rgb;
}

// Moduli di gioco da lasciare intatti. GameModule arriva incrementato di 1,
// quindi 0 significa "non lo so" (eseguibile vecchio) e non spegne niente.
//   1-6  = intro, selezione/copia/cancellazione/nome file, caricamento
//   15   = inventario (Module0E_Interface)
//   28   = scelta punto di partenza
float menu_amount()
{
    float known = step(0.5, GameModule);
    float m = GameModule;
    float menu = step(m, 6.5)
               + step(14.5, m) * step(m, 15.5)
               + step(27.5, m) * step(m, 28.5);
    return known * clamp(menu, 0.0, 1.0) * FSA_SKIP_MENUS;
}

void main()
{
    vec2 uv = vTexCoord;
    vec2 paint_texel = 1.0 / max(Pass3TextureSize, vec2(1.0));
    vec2 src_size = max(OrigTextureSize, vec2(1.0));

    // Sprite e HUD: niente pittura, ma restano nel color grade, altrimenti
    // Link sembrerebbe incollato sopra a uno sfondo di un altro colore.
    float protect = protect_mask(uv, src_size);
    // I menu invece escono completamente intatti, grade compreso.
    float menu = menu_amount();
    vec3 sharp = sample_sharp(uv, src_size, FSA_PIXEL_SHARP);

    vec3 paint = COMPAT_TEXTURE(Pass3Texture, uv).rgb;

    // Ammorbidimento: Four Swords girava a 480i, niente e' perfettamente netto.
    vec3 soft = paint * 0.36;
    soft += COMPAT_TEXTURE(Pass3Texture, uv + vec2( 1.0,  0.0) * paint_texel).rgb * 0.16;
    soft += COMPAT_TEXTURE(Pass3Texture, uv + vec2(-1.0,  0.0) * paint_texel).rgb * 0.16;
    soft += COMPAT_TEXTURE(Pass3Texture, uv + vec2( 0.0,  1.0) * paint_texel).rgb * 0.16;
    soft += COMPAT_TEXTURE(Pass3Texture, uv + vec2( 0.0, -1.0) * paint_texel).rgb * 0.16;
    vec3 color = mix(paint, soft, FSA_SOFTEN);

    // --- Contorni -----------------------------------------------------
    // Sobel sulla pittura: i contorni seguono le forme gia' ripulite.
    vec3 gx = COMPAT_TEXTURE(Pass3Texture, uv + vec2( 1.0, 0.0) * paint_texel).rgb
            - COMPAT_TEXTURE(Pass3Texture, uv + vec2(-1.0, 0.0) * paint_texel).rgb;
    vec3 gy = COMPAT_TEXTURE(Pass3Texture, uv + vec2(0.0,  1.0) * paint_texel).rgb
            - COMPAT_TEXTURE(Pass3Texture, uv + vec2(0.0, -1.0) * paint_texel).rgb;
    float edge = sqrt(dot(gx, gx) + dot(gy, gy));
    edge = smoothstep(0.10, 0.70, edge);

    // Scurisce il contorno verso un bruno caldo invece che verso il nero.
    vec3 ink = mix(vec3(0.0), vec3(0.16, 0.10, 0.07), FSA_OUTLINE_WARM);
    color = mix(color, ink, edge * FSA_OUTLINE * 0.55);

    // --- Velatura a pennello -----------------------------------------
    // Misurata per autocorrelazione sul tetto di foursword.png: la texture
    // di Four Swords ha una scala di ~2.5 px SNES ed e' quasi isotropa
    // (2.5 orizzontale contro 3.2 verticale). Sono macchie larghe di una
    // velatura, non fibre: le frequenze qui sotto puntano a quel numero.
    //
    // La grana NON ruota piu' con il campo di flusso. Ruotandola, fra due
    // zone adiacenti con direzioni diverse la texture cambiava di scatto e
    // si vedevano rettangoli netti sulle superfici piatte.
    //
    // Ancorata al mondo tramite ScrollOffset: non "nuota" sullo schermo
    // mentre Link cammina.
    vec2 world = uv * max(OrigTextureSize, vec2(1.0)) + ScrollOffset;
    vec2 bdir = normalize(vec2(0.42, 0.91));
    vec2 q = vec2(dot(world, bdir), dot(world, vec2(-bdir.y, bdir.x))) * FSA_CANVAS_SCALE;

    // Allungamento gentile (1.4:1) lungo la direzione del pennello, che in
    // Four Swords corre in diagonale ripida (la texture misura 2.5 px in
    // orizzontale contro 3.2 in verticale). Appena
    // abbastanza da far leggere il tratto, non tanto da fare le righe.
    float blotch = (fbm(q * vec2(0.105, 0.150)) - 0.5) * 2.0;
    float tooth  = (fbm(q * vec2(0.300, 0.400) + vec2(41.0, 17.0)) - 0.5) * 2.0;
    float grain = blotch * 0.80 + tooth * 0.32;

    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    // La velatura copre anche le bande di colore interne, si tira indietro
    // solo sui contorni veri. Prima si spegneva troppo presto e i bordi
    // delle bande piatte restavano disegnati sulla texture.
    float flat_area = mix(0.40, 1.0, 1.0 - smoothstep(0.16, 0.62, edge));
    float amp = FSA_CANVAS * 0.102 * flat_area * smoothstep(0.03, 0.30, luma);
    color += grain * amp * vec3(1.05, 1.0, 0.92);

    // Qui sprite e HUD tornano nitidi: si scarta tutto quello che e' stato
    // fatto sopra (pittura, contorni, velatura) e si riprende il pixel
    // originale. Bloom e color grade qui sotto valgono ancora per tutti.
    color = mix(color, sharp, protect);

    // --- Bloom --------------------------------------------------------
    vec3 bloom = COMPAT_TEXTURE(Source, uv).rgb;
    color += bloom * FSA_BLOOM * vec3(1.04, 0.99, 0.88);

    // --- Color grade --------------------------------------------------
    color = clamp(color, 0.0, 1.0);
    float l = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(l), color, FSA_SATURATION);
    color = clamp(color, 0.0, 1.0);

    color = pow(color, vec3(FSA_GAMMA));
    color *= mix(vec3(1.0), vec3(1.035, 0.995, 0.945), FSA_WARMTH);

    // Curva a S delicata: alza il contrasto senza bruciare le alte luci.
    color = clamp(color, 0.0, 1.0);
    color = mix(color, color * color * (3.0 - 2.0 * color), FSA_CONTRAST);

    vec2 centered = uv * 2.0 - 1.0;
    float vig = 1.0 - FSA_VIGNETTE * 0.55 * dot(centered, centered) * 0.5;
    color *= vig;

    // Nei menu si restituisce il frame originale e basta.
    color = mix(clamp(color, 0.0, 1.0), sharp, menu);

    FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}

#endif
