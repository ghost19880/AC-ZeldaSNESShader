using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;
using System.Windows.Forms;

internal static class Program
{
    // Blocco inserito in glsl_shader.c. Non si puo' includere "variables.h":
    // quell'header definisce le macro R12 e R14, che collidono con i campi
    // omonimi di _JUMP_BUFFER in <setjmp.h> e fanno fallire la compilazione
    // con MSVC. Le versioni precedenti del patcher aggiungevano l'include, ed
    // e' il motivo per cui il progetto non si compilava con Visual Studio.
    private const string RamAccessors =
        "// Lo scroll dei BG serve per ancorare al mondo gli effetti degli shader.\r\n" +
        "// Non si puo' includere \"variables.h\" qui: definisce le macro R12 e R14, che\r\n" +
        "// collidono con i campi omonimi di _JUMP_BUFFER in <setjmp.h> e fanno fallire\r\n" +
        "// la compilazione con MSVC. Bastano le poche voci qui sotto.\r\n" +
        "extern uint8 g_ram[131072];\r\n" +
        "#define ZELDA_BG2HOFS (*(uint16 *)(g_ram + 0xE2))\r\n" +
        "#define ZELDA_BG2VOFS (*(uint16 *)(g_ram + 0xE8))\r\n" +
        "// Modulo di gioco corrente: 14 = inventario, 0-5 = intro e selezione file.\r\n" +
        "// Serve allo shader per spegnersi nei menu.\r\n" +
        "#define ZELDA_MAIN_MODULE (*(uint8 *)(g_ram + 0x10))\r\n" +
        "\r\n";

    private static readonly List<string> Applied = new List<string>();
    private static readonly List<string> Skipped = new List<string>();

    [STAThread]
    private static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        OpenFileDialog dialog = new OpenFileDialog();
        dialog.Title = "Seleziona zelda3.exe";
        dialog.Filter = "zelda3.exe|zelda3.exe|Eseguibili (*.exe)|*.exe";
        dialog.CheckFileExists = true;
        dialog.Multiselect = false;

        if (dialog.ShowDialog() != DialogResult.OK)
            return;

        try
        {
            string exePath = Path.GetFullPath(dialog.FileName);
            string? gameDir = Path.GetDirectoryName(exePath);
            if (gameDir == null)
                throw new InvalidOperationException("Percorso non valido.");

            string srcDir = Path.Combine(gameDir, "src");
            string cPath = Path.Combine(srcDir, "glsl_shader.c");
            string hPath = Path.Combine(srcDir, "glsl_shader.h");
            string ppuPath = Path.Combine(gameDir, "snes", "ppu.c");
            string batPath = Path.Combine(gameDir, "radzprower.bat");

            if (!File.Exists(cPath) || !File.Exists(hPath))
                throw new FileNotFoundException("Non trovo src\\glsl_shader.c e src\\glsl_shader.h accanto a zelda3.exe.");
            if (!File.Exists(ppuPath))
                throw new FileNotFoundException("Non trovo snes\\ppu.c accanto a zelda3.exe. Serve per escludere sprite e HUD dall'effetto.");

            PatchHeader(hPath);
            PatchShaderSource(cPath);
            PatchPpu(ppuPath);

            string report = BuildReport();

            if (!File.Exists(batPath))
            {
                MessageBox.Show(
                    report + "\r\n\r\nradzprower.bat non e' stato trovato accanto a zelda3.exe: ricompila a mano.",
                    "Zelda 3 Shader Patcher", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = "cmd.exe";
            psi.Arguments = "/c \"" + batPath + "\"";
            psi.WorkingDirectory = gameDir;
            psi.UseShellExecute = true;

            Process.Start(psi);
            MessageBox.Show(report + "\r\n\r\nLa compilazione e' stata avviata.",
                "Zelda 3 Shader Patcher", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "Zelda 3 Shader Patcher", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private static string BuildReport()
    {
        string report = "";
        if (Applied.Count > 0)
            report += "Applicate:\r\n  - " + string.Join("\r\n  - ", Applied);
        if (Skipped.Count > 0)
        {
            if (report.Length > 0) report += "\r\n\r\n";
            report += "Gia' presenti:\r\n  - " + string.Join("\r\n  - ", Skipped);
        }
        return report.Length > 0 ? report : "Nessuna modifica necessaria.";
    }

    private static void BackupOnce(string path)
    {
        string backup = path + ".bak";
        if (!File.Exists(backup))
            File.Copy(path, backup);
    }

    // Applica una sostituzione solo se non risulta gia' fatta. `marker` e' il
    // testo che, se presente, significa che la modifica c'e' gia'.
    private static string Apply(string text, string label, string marker, string pattern, string replacement)
    {
        if (text.Contains(marker))
        {
            Skipped.Add(label);
            return text;
        }

        string patched = Regex.Replace(text, pattern, replacement, RegexOptions.Multiline);
        if (patched == text)
            throw new InvalidOperationException(
                "Non riesco ad applicare la modifica \"" + label + "\": il sorgente non corrisponde a quello atteso.\r\n" +
                "Se hai gia' modificato questi file a mano, ripristinali dai .bak o da una copia pulita di zelda3.");

        Applied.Add(label);
        return patched;
    }

    private static void PatchHeader(string path)
    {
        BackupOnce(path);
        string text = File.ReadAllText(path);

        text = Apply(text, "glsl_shader.h: uniform ScrollOffset", "int ScrollOffset;",
            @"(  int FrameCount, FrameDirection;)",
            "$1\r\n  int ScrollOffset;");

        text = Apply(text, "glsl_shader.h: uniform GameModule", "int GameModule;",
            @"(  int ScrollOffset;)",
            "$1\r\n  int GameModule;");

        File.WriteAllText(path, text);
    }

    private static void PatchShaderSource(string path)
    {
        BackupOnce(path);
        string text = File.ReadAllText(path);

        // Le versioni vecchie del patcher aggiungevano #include "variables.h",
        // che rompe la compilazione con MSVC. Se c'e', si toglie.
        string withoutInclude = Regex.Replace(text, "[ \t]*#include \"variables\\.h\"[ \t]*\r?\n", "");
        if (withoutInclude != text)
        {
            text = withoutInclude;
            Applied.Add("glsl_shader.c: rimosso #include \"variables.h\" (rompeva la build MSVC)");
        }

        // Le versioni vecchie usavano direttamente le macro di variables.h.
        text = text.Replace("(float)BG2HOFS_copy2", "(float)ZELDA_BG2HOFS")
                   .Replace("(float)BG2VOFS_copy2", "(float)ZELDA_BG2VOFS");

        text = Apply(text, "glsl_shader.c: accesso alla RAM del gioco", "ZELDA_BG2HOFS (",
            @"(#include <string\.h>\r?\n)",
            "$1" + RamAccessors);

        text = Apply(text, "glsl_shader.c: lettura uniform ScrollOffset",
            "glGetUniformLocation(program, \"ScrollOffset\")",
            "(    p->unif\\.FrameDirection = glGetUniformLocation\\(program, \"FrameDirection\"\\);)",
            "$1\r\n    p->unif.ScrollOffset = glGetUniformLocation(program, \"ScrollOffset\");");

        text = Apply(text, "glsl_shader.c: lettura uniform GameModule",
            "glGetUniformLocation(program, \"GameModule\")",
            "(    p->unif\\.ScrollOffset = glGetUniformLocation\\(program, \"ScrollOffset\"\\);)",
            "$1\r\n    p->unif.GameModule = glGetUniformLocation(program, \"GameModule\");");

        text = Apply(text, "glsl_shader.c: invio dello scroll allo shader", "p->unif.ScrollOffset >= 0",
            "(  if \\(p->unif\\.FrameDirection >= 0\\)\r?\n\\s*glUniform1i\\(p->unif\\.FrameDirection, 1\\);)",
            "$1\r\n" +
            "  if (p->unif.ScrollOffset >= 0) {\r\n" +
            "    float scroll_offset[2] = { (float)ZELDA_BG2HOFS, (float)ZELDA_BG2VOFS };\r\n" +
            "    glUniform2fv(p->unif.ScrollOffset, 1, scroll_offset);\r\n" +
            "  }");

        text = Apply(text, "glsl_shader.c: invio del modulo di gioco allo shader", "p->unif.GameModule >= 0",
            "(    glUniform2fv\\(p->unif\\.ScrollOffset, 1, scroll_offset\\);\r?\n  \\})",
            "$1\r\n" +
            "  if (p->unif.GameModule >= 0)\r\n" +
            "    // +1 cosi che 0 significhi \"uniform non valorizzato\" (exe vecchio):\r\n" +
            "    // altrimenti lo shader confonderebbe quel caso col modulo 0 (intro).\r\n" +
            "    glUniform1f(p->unif.GameModule, (float)(ZELDA_MAIN_MODULE + 1));");

        File.WriteAllText(path, text);
    }

    // Scrive nei bit 24-27 di ogni pixel l'indice del layer da cui viene
    // (0=BG1, 1=BG2, 2=BG3/HUD, 3=BG4, 4=OBJ/sprite, 5=sfondo). Quel byte era
    // inutilizzato e la texture viene caricata come BGRA, quindi lo shader lo
    // legge come canale alpha e sa cosa non deve dipingere.
    private static void PatchPpu(string path)
    {
        BackupOnce(path);
        string text = File.ReadAllText(path);

        // Ramo veloce di PpuDrawWholeLine (color math disattivata).
        text = Apply(text, "ppu.c: indice del layer nel pixel (ramo veloce)",
            "uint32 z = ppu->bgBuffers[0].data[i];",
            "        uint32 color = ppu->cgram\\[ppu->bgBuffers\\[0\\]\\.data\\[i\\] & 0xff\\];\r?\n" +
            "        dst\\[0\\] = ppu->brightnessMult\\[color & clip_color_mask\\] << 16 \\|",
            "        uint32 z = ppu->bgBuffers[0].data[i];\r\n" +
            "        uint32 color = ppu->cgram[z & 0xff];\r\n" +
            "        // Nei bit 24-27 finisce l'indice del layer da cui viene il pixel\r\n" +
            "        // (0=BG1, 1=BG2, 2=BG3, 3=BG4, 4=OBJ/sprite, 5=backdrop). Il byte\r\n" +
            "        // alto era inutilizzato; la texture viene caricata come BGRA, quindi\r\n" +
            "        // lo shader lo legge come canale alpha e sa cosa non deve dipingere.\r\n" +
            "        dst[0] = (z & 0xf00) << 16 |\r\n" +
            "                 ppu->brightnessMult[color & clip_color_mask] << 16 |");

        // Ramo lento (color math attiva): qui main_layer e' gia' calcolato.
        text = Apply(text, "ppu.c: indice del layer nel pixel (ramo con color math)",
            "(uint32)main_layer << 24",
            "        dst\\[0\\] = color_map\\[b\\] \\| color_map\\[g\\] << 8 \\| color_map\\[r\\] << 16;",
            "        // Vedi sopra: bit 24-27 = layer di provenienza, per lo shader.\r\n" +
            "        dst[0] = (uint32)main_layer << 24 |\r\n" +
            "                 color_map[b] | color_map[g] << 8 | color_map[r] << 16;");

        File.WriteAllText(path, text);
    }
}
