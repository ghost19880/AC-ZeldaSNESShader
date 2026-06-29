# Four Swords Adventures Paint Shader for Zelda 3 PC

Shader GLSL per Zelda 3 PC pensato per avvicinare l’aspetto visivo al layer pittorico di *The Legend of Zelda: Four Swords Adventures* / versione GameCube.

L’effetto aggiunge sopra la pixel art originale un layer di pennellate semi-trasparenti, irregolari e striate, simulando un tratto di pennello asciutto. Lo shader cerca di ammorbidire leggermente i pixel, fondere alcune aree di colore simile e dare alla scena un aspetto più “dipinto”, senza sostituire completamente la grafica originale.

## Caratteristiche

- Pennellate diagonali ancorate al mondo di gioco.
- Texture pittorica irregolare con striature interne.
- Smoothing leggero dei pixel e dei dettagli ad alta frequenza.
- Fusione dei colori simili per ridurre l’aspetto troppo digitale della pixel art.
- Effetto post-process GLSL compatibile con il sistema shader di Zelda 3 PC.
- Preset `.glslp` caricabile dal launcher.

## Nota importante

Per mantenere le pennellate ferme rispetto alla mappa, lo shader usa un uniform custom chiamato:

```glsl
ScrollOffset
```
Questo richiede una piccola modifica al renderer OpenGL di Zelda 3 PC, così il gioco può passare allo shader l’offset della camera (BG2HOFS_copy2, BG2VOFS_copy2).
Senza questa modifica, lo shader può comunque essere caricato, ma il pattern non resterà correttamente ancorato al mondo durante lo scrolling.
File principali
foursword.glsl
Shader principale.

foursword.glslp
Preset da selezionare nel launcher.

glsl_shader.c / glsl_shader.h
Modifica al renderer per esporre ScrollOffset.

## Uso
Nel launcher di Zelda 3 PC:
Impostare il renderer su OpenGL.
Abilitare Use GLSL Shader.
Selezionare il file:
foursword.glslp
Poi avviare il gioco normalmente.
Obiettivo visivo
Lo shader non vuole creare un filtro CRT o un semplice blur. L’obiettivo è imitare il layer pittorico visto in Four Swords Adventures: una texture morbida, irregolare, leggermente granulosa/striated, che cambia l’intensità del colore come se fosse applicata con un pennello poco carico.
