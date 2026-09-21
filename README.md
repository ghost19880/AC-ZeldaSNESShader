# Zelda 3 Four Swords Adventures Painterly Shader

<img width="800" height="510" alt="Before" src="https://github.com/user-attachments/assets/3bda14c8-2edb-4b26-9164-0dc857091414" />
<img width="800" height="510" alt="image" src="https://github.com/user-attachments/assets/42593ef2-4a42-4b71-a521-630c5d75a66b" />
A GLSL post-processing shader for **Zelda 3 PC** that recreates the soft painterly
look of **The Legend of Zelda: Four Swords Adventures** on GameCube.

It is a five-pass pipeline. The texture is derived from the image itself rather
than sprayed on top of it, and sprites, HUD and menus can be excluded from the
effect entirely.

## Requirements

- **Zelda 3 PC with its source tree**, and `zelda3.exe` rebuilt — the shader
  needs three extra pieces of information the stock build does not provide
  ([details](#patching-zelda3exe)). The patcher below does this for you.
- In `zelda3.ini`: `OutputMethod = OpenGL` and `NewRenderer = 1` (the default).
- To run `Zelda3ScrollOffsetPatcher.exe`: the
  [.NET 9 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/9.0).
  If it is missing, the patcher will say so on launch and offer a download
  button — it does not fail silently.

## What it can and cannot do

Comparing an original SNES frame with the same scene in Four Swords Adventures
shows two different things layered on top of each other:

1. **The finish** — soft edges, surfaces that look painted, warmer and more
   saturated colours, diffuse light. That is what this shader does.
2. **The artwork** — Four Swords **redrew** the tiles at a higher resolution.
   On the roof of the house, the golden trim and the four studs are not blurred,
   they are *gone*. No shader can invent art that is not in the frame. That
   difference stays.

## How it works

| # | File | What it does |
|---|------|--------------|
| 1 | `01-tensor.glsl` | Structure tensor: which direction each shape runs in |
| 2 | `02-flow.glsl` | Blurs the tensor, extracts direction and anisotropy |
| 3 | `03-paint.glsl` | **Anisotropic Kuwahara** at 3x resolution — the brushwork |
| 4 | `04-bloom.glsl` | Soft halo on bright areas |
| 5 | `05-final.glsl` | Outlines, glaze, colour grade, layer masking |

Pass 3 is the core. Around every pixel it takes an ellipse oriented along the
direction found in pass 2, splits it into 8 sectors, and keeps the mean colour
of the **most uniform** sector. Flat colour areas collapse into patches that
follow the shape — brushwork — while edges stay crisp.

This is different from overlaying procedural noise: the texture comes from the
image, so it does not swim over the game as Link walks. The glaze added in pass
5 is anchored to the world through `ScrollOffset` for the same reason.

## Calibration

The numbers are measured, not eyeballed. Comparing the SNES frame against the
Four Swords reference:

| | SNES | Four Swords |
|---|---|---|
| mean saturation | 0.428 | 0.496 |
| mean luminance | 96.0 | 86.4 |

Hence saturation +16%, gamma ~1.05, green and blue slightly below red. With the
defaults, the roof comes out at RGB (150, 72, 70) against the reference's
(152, 72, 68), and the grass at (64, 97, 49) against (65, 97, 50).

The surface glaze was calibrated by autocorrelating the luminance of a flat
roof area, with the slow shading trend removed:

| | strength (std. dev.) | texture scale |
|---|---|---|
| bare SNES | 2.34 | 1.0 px |
| Four Swords | 5.65 | 2.5 px horiz, 3.2 vert |
| current shader | 6.16 | 2.2 px horiz, 2.5 vert |

An earlier version of this shader measured 9.45 and 1.0 px: **2.5x too fine and
1.7x too strong**, which read as hair rather than brushwork. Four Swords has
broad, soft, nearly isotropic blotches.

That version also rotated the glaze to follow the flow field. Between two
adjacent areas with different directions the texture changed abruptly, and flat
surfaces showed **visible rectangles**. The brush direction is now fixed and
anchored to the world, so there is nothing to snap.

## Patching zelda3.exe

Shaders in Zelda 3 PC only receive the final screen image. Three pieces of
information are missing, so `zelda3.exe` has to be rebuilt.

### 1. `ScrollOffset` — anchoring the glaze to the world

Without it the brush pattern moves with the screen when the camera scrolls,
which is distracting. The uniform carries the current background scroll offset.

### 2. Layer index — excluding sprites and HUD

In the finished frame, sprites, HUD and background are already blended: a
shader cannot tell them apart. The PPU can, for every pixel:

```c
uint8 main_layer = (ppu->bgBuffers[0].data[i] >> 8) & 0xf;
```

and the output pixel only uses 24 of its 32 bits. So the free high byte carries
the layer index through to the shader:

| value | layer |
|---|---|
| 0 | BG1 |
| 1 | BG2 |
| 2 | BG3 — the Link to the Past HUD |
| 3 | BG4 |
| 4 | **OBJ — Link, NPCs, enemies** |
| 5 | backdrop |

The texture is uploaded as `GL_BGRA`, so that byte arrives as the alpha channel
and pass 5 reads it.

### 3. `GameModule` — excluding menus

Menus are not distinguishable by layer, so the current game module index is
passed as a uniform (14 is the inventory, 0-5 are intro and file select).

### Bonus: an MSVC build fix

Earlier versions of the patcher added `#include "variables.h"` to
`glsl_shader.c` to read the scroll registers. That header defines the macros
`R12` and `R14`, which collide with the identically named fields of
`_JUMP_BUFFER` in `<setjmp.h>` and break the build under MSVC. The patcher now
declares only the few entries it needs.

The shader still works with an unpatched executable: alpha stays 0, the mask
stays empty, and it behaves as it did before. Nothing breaks.

## Patcher tool

```text
Zelda3ScrollOffsetPatcher/Zelda3ScrollOffsetPatcher.exe
```

1. Run it and select your `zelda3.exe`
2. It locates `src/glsl_shader.c`, `src/glsl_shader.h`, `snes/ppu.c` and
   `radzprower.bat`
3. It creates `.bak` backups of each source file
4. It applies the patches, reports what it changed, and launches
   `radzprower.bat` to rebuild

The patcher is idempotent: running it twice is harmless, and it repairs sources
left in the old state by previous versions.

> **Requires the [.NET 9 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/9.0).**
> Earlier releases of this tool were built against .NET Framework and ran on any
> Windows install; it is now built from the `.csproj`, which targets
> `net9.0-windows`.
>
> Without it, launching the patcher opens a dialog reading *"You must install or
> update .NET to run this application"* with a **Download it now** button
> pointing at the correct version. Nothing happens silently.

To rebuild it yourself:

```
dotnet publish Zelda3ScrollOffsetPatcher/Zelda3ScrollOffsetPatcher.csproj ^
  -c Release -r win-x64 --self-contained false ^
  -p:PublishSingleFile=true -p:DebugType=None
```

### Building zelda3 without the patcher

`zelda3.vcxproj` expects two SDL2 NuGet packages, but SDL2 is already present in
`third_party/SDL2-2.26.3`. It compiles directly:

```bat
call "...\VC\Auxiliary\Build\vcvars64.bat"
cd "...\zelda3"
cl /nologo /O2 /MD /W0 ^
   /I . /I third_party\SDL2-2.26.3\include ^
   /DSYSTEM_VOLUME_MIXER_AVAILABLE=0 /D_CRT_SECURE_NO_WARNINGS ^
   /Fe:zelda3.exe src\*.c snes\*.c ^
   third_party\gl_core\gl_core_3_1.c ^
   third_party\opus-1.3.1-stripped\opus_decoder_amalgam.c ^
   /link /SUBSYSTEM:CONSOLE /LIBPATH:third_party\SDL2-2.26.3\lib\x64 ^
   SDL2.lib SDL2main.lib shell32.lib user32.lib gdi32.lib advapi32.lib ^
   ole32.lib oleaut32.lib imm32.lib version.lib setupapi.lib winmm.lib
```

## Installation

```text
Zelda 3/
├─ zelda3.exe
├─ radzprower.bat
├─ zelda3.ini
├─ src/
│  ├─ glsl_shader.c
│  └─ glsl_shader.h
├─ snes/
│  └─ ppu.c
└─ glsl-shaders-master/
   └─ foursword/
      ├─ foursword.glslp      <- preset, entry point
      ├─ fsa_common.inc       <- shared boilerplate
      ├─ 01-tensor.glsl
      ├─ 02-flow.glsl
      ├─ 03-paint.glsl
      ├─ 04-bloom.glsl
      └─ 05-final.glsl
```

`fsa_common.inc` is included by every pass and deliberately leaves its
`#elif defined(FRAGMENT)` block open — each pass continues from there and closes
it with its own `#endif`. Keep that in mind when editing the passes.

In `zelda3.ini`:

```ini
OutputMethod = OpenGL
NewRenderer = 1
Shader = C:\path\to\Zelda 3\glsl-shaders-master\foursword\foursword.glslp
```

`NewRenderer = 1` is the default and is required: the old renderer does not
write the layer index, so sprite and HUD exclusion will not work.

## Parameters

Tunable values are listed, commented out, at the bottom of `foursword.glslp`.
Uncomment a line and change the number.

**The `parameters = "..."` line must stay above the values** — it is what
registers the names. Without it, zelda3 ignores them with an `Unknown key` on
stderr.

| Parameter | Default | |
|---|---|---|
| `FSA_PAINT_RADIUS` | 1.90 | Brush size in SNES pixels. Above ~2.5 small details vanish |
| `FSA_PAINT_SHARP` | 3.00 | High = crisp patches, low = blended |
| `FSA_STROKE_LEN` | 1.00 | How much strokes stretch along edges |
| `FSA_PAINT_MIX` | 0.88 | 0 = no paint, 1 = full paint. Set it to 0 to see the game with the rest of the finish but no brushwork |
| `FSA_PIXEL_SHARP` | 2.60 | Sharpness of the source pixels |
| `FSA_FLOW_BLUR` | 2.20 | Coherence of the stroke direction |
| `FSA_CANVAS` | 1.00 | Glaze strength — the most visible knob on flat surfaces. Four Swords is deliberately subtle here; raise it for heavier blotches |
| `FSA_CANVAS_SCALE` | 1.00 | Below 1.0 the blotches widen into visible strokes |
| `FSA_OUTLINE` | 0.28 | Outline strength |
| `FSA_OUTLINE_WARM` | 0.55 | Brown outlines instead of black |
| `FSA_SOFTEN` | 0.18 | Overall softness |
| `FSA_SATURATION` | 1.08 | |
| `FSA_GAMMA` | 1.05 | |
| `FSA_WARMTH` | 0.35 | |
| `FSA_CONTRAST` | 0.18 | Gentle S-curve |
| `FSA_BLOOM` | 0.22 | |
| `FSA_BLOOM_THRESHOLD` | 0.62 | |
| `FSA_VIGNETTE` | 0.06 | |
| `FSA_KEEP_SPRITES` | 1.00 | Link, NPCs and enemies stay sharp |
| `FSA_KEEP_HUD` | 1.00 | Hearts, rupees and text stay sharp (BG3) |
| `FSA_SKIP_MENUS` | 1.00 | Inventory and file select get no effect at all |

The last three are continuous, not switches: `0.5` paints Link halfway.

Sprites and the HUD stay sharp **but keep the colour grade**, so Link does not
look pasted onto a differently coloured background. Menus come out completely
untouched.

If some dungeon background looks too sharp, try `FSA_KEEP_HUD = 0` — in Link to
the Past, BG3 is not used for the HUD alone.

## Performance

Pass 3 runs at 3x native resolution with ~37 samples per pixel. If the frame
rate drops, in `foursword.glslp` change:

```
scale2 = 3.0   ->   scale2 = 2.0
```

That roughly halves the cost. Below 2.0 the brush gets coarser than the SNES
pixel and it shows.

## Limitations

- The redrawn Four Swords artwork cannot be recovered (see above)
- A faint halo can remain around sprites: pass 3 has already blended their
  colours into the background before the mask restores them
- The world map is drawn in mode 7 on BG1, so it is excluded neither by layer
  nor by module
- The glaze is anchored to `BG2HOFS/BG2VOFS`; on screens that do not use those
  registers it can stay fixed relative to the screen
- Requires OpenGL output and `NewRenderer = 1`
- This is a post-process shader, not a GameCube TEV/material renderer

## Credits

Inspired by the painterly visual style of **The Legend of Zelda: Four Swords
Adventures** for GameCube.

Built for use with **Zelda 3 PC** and its GLSL shader support.
