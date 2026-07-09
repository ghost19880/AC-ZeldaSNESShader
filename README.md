# Zelda 3 Four Swords Adventures Painterly Shader

<img width="800" height="510" alt="Before" src="https://github.com/user-attachments/assets/3bda14c8-2edb-4b26-9164-0dc857091414" />
<img width="800" height="510" alt="After" src="https://github.com/user-attachments/assets/e1ac2da2-0885-41cb-ac2a-684961ac13d7" />




A GLSL post-processing shader for **Zelda 3 PC** that tries to recreate the soft painterly look used in **The Legend of Zelda: Four Swords Adventures** on GameCube.

The shader adds a stylized brush-stroke layer over the original SNES-style image, with softened pixel edges, subtle color grading, light bloom, edge shading, and animated painterly variation.

## Features

- Painterly brush-stroke overlay inspired by Four Swords Adventures
- World-anchored brush pattern
- Soft global lighting
- Light bloom on bright pixels
- Subtle vignette / edge darkening
- Warmer GameCube-like color grading
- Selective smoothing and blur
- Slight shimmer on water / magic-like colors
- Configurable shader parameters through GLSL `#pragma parameter`

## Important: Zelda3.exe Must Be Patched

By default, Zelda 3 PC shaders only receive the final screen image.  
That means a shader can see the pixels on screen, but it does **not** know where the camera is in the game world.

For this shader, the brush texture must stay anchored to the map.  
Without the patch, the brush pattern moves with the screen when the camera scrolls, which looks distracting.

To fix this, `zelda3.exe` must be rebuilt with one extra shader uniform:

```glsl
ScrollOffset
```

This uniform passes the current background scroll/camera offset to the shader, allowing the brush pattern to remain fixed to the world.

## What the Patch Changes

The patch modifies:

```text
src/glsl_shader.c
src/glsl_shader.h
```

It adds support for the `ScrollOffset` uniform and sends the current Zelda 3 background scroll values to the active GLSL shader.

The shader then uses:

```glsl
uniform vec2 ScrollOffset;
```

to calculate world-space brush coordinates.

## Patcher Tool

This repository includes a small Windows patcher:

```text
tools/Zelda3ScrollOffsetPatcher/Zelda3ScrollOffsetPatcher.exe
```

Usage:

1. Run `Zelda3ScrollOffsetPatcher.exe`
2. Select your `zelda3.exe`
3. The patcher automatically finds:
   - `src/glsl_shader.c`
   - `src/glsl_shader.h`
   - `radzprower.bat`
4. It creates backup files:
   - `glsl_shader.c.bak`
   - `glsl_shader.h.bak`
5. It applies the `ScrollOffset` patch
6. It launches `radzprower.bat` to rebuild `zelda3.exe`

The folder structure must match the standard Zelda 3 PC layout.

Example:

```text
Zelda 3/
├─ zelda3.exe
├─ radzprower.bat
├─ src/
│  ├─ glsl_shader.c
│  └─ glsl_shader.h
└─ glsl-shaders-master/
   └─ foursword/
      ├─ foursword.glsl
      └─ foursword.glslp
```

## Shader Files

The shader preset is:

```text
glsl-shaders-master/foursword/foursword.glslp
```

The main shader file is:

```text
glsl-shaders-master/foursword/foursword.glsl
```

In `zelda3.ini`, the shader should point to the `.glslp` preset:

```ini
Shader = C:\path\to\Zelda 3\glsl-shaders-master\foursword\foursword.glslp
```

OpenGL output must be enabled:

```ini
OutputMethod = OpenGL
```

## Shader Parameters

The shader exposes several adjustable parameters:

```glsl
PAINT_STRENGTH
PAINT_SOFTEN
PAINT_TINT
PAINT_CONTRAST
BRUSH_THRESHOLD
BRUSH_DISTORT
SOFT_LIGHT
BLOOM_STRENGTH
VIGNETTE_STRENGTH
GC_COLOR
SHIMMER_STRENGTH
PAINT_ANIM
```

These control the strength of the painterly layer, smoothing, tinting, bloom, vignette, color grading, and animated texture variation.

## Notes

This is not a true GameCube renderer replacement.  
It is a post-process shader applied to the final Zelda 3 PC frame.

Because of that, it cannot perfectly separate terrain, characters, HUD, water, shadows, or effects. The shader estimates visual areas from color, brightness, and screen-space detail.

The `ScrollOffset` patch is what makes the effect usable during camera movement.

## Limitations

- Requires patched/rebuilt `zelda3.exe`
- Requires OpenGL output
- The shader affects the whole final image, including HUD and sprites
- Some effects are approximations, not real GameCube TEV/material rendering
- Without `ScrollOffset`, the brush pattern will move with the camera

## Credits

Inspired by the painterly visual style of **The Legend of Zelda: Four Swords Adventures** for GameCube.

Built for use with **Zelda 3 PC** and its GLSL shader support.
