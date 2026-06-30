using System;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;
using System.Windows.Forms;

internal static class Program
{
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
            string gameDir = Path.GetDirectoryName(exePath);
            if (gameDir == null)
                throw new InvalidOperationException("Percorso non valido.");

            string srcDir = Path.Combine(gameDir, "src");
            string cPath = Path.Combine(srcDir, "glsl_shader.c");
            string hPath = Path.Combine(srcDir, "glsl_shader.h");
            string batPath = Path.Combine(gameDir, "radzprower.bat");

            if (!File.Exists(cPath) || !File.Exists(hPath))
                throw new FileNotFoundException("Non trovo src\\glsl_shader.c e src\\glsl_shader.h accanto a zelda3.exe.");

            PatchHeader(hPath);
            PatchSource(cPath);

            if (!File.Exists(batPath))
            {
                MessageBox.Show("Patch applicata, ma radzprower.bat non è stato trovato accanto a zelda3.exe.", "Zelda 3 Shader Patcher", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = "cmd.exe";
            psi.Arguments = "/c \"" + batPath + "\"";
            psi.WorkingDirectory = gameDir;
            psi.UseShellExecute = true;

            Process.Start(psi);
            MessageBox.Show("Patch applicata. La compilazione è stata avviata.", "Zelda 3 Shader Patcher", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "Zelda 3 Shader Patcher", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private static void BackupOnce(string path)
    {
        string backup = path + ".bak";
        if (!File.Exists(backup))
            File.Copy(path, backup);
    }

    private static void PatchHeader(string path)
    {
        BackupOnce(path);
        string text = File.ReadAllText(path);
        if (!text.Contains("int ScrollOffset;"))
            text = text.Replace("  int FrameCount, FrameDirection;", "  int FrameCount, FrameDirection;\r\n  int ScrollOffset;");
        File.WriteAllText(path, text);
    }

    private static void PatchSource(string path)
    {
        BackupOnce(path);
        string text = File.ReadAllText(path);

        if (!text.Contains("#include \"variables.h\""))
            text = text.Replace("#include \"config.h\"", "#include \"config.h\"\r\n#include \"variables.h\"");

        if (!text.Contains("p->unif.ScrollOffset = glGetUniformLocation(program, \"ScrollOffset\");"))
            text = text.Replace(
                "    p->unif.FrameDirection = glGetUniformLocation(program, \"FrameDirection\");",
                "    p->unif.FrameDirection = glGetUniformLocation(program, \"FrameDirection\");\r\n    p->unif.ScrollOffset = glGetUniformLocation(program, \"ScrollOffset\");");

        if (!text.Contains("BG2HOFS_copy2") || !text.Contains("BG2VOFS_copy2"))
            text = Regex.Replace(
                text,
                "(  if \\(p->unif\\.FrameDirection >= 0\\)\\s*\\r?\\n\\s*glUniform1i\\(p->unif\\.FrameDirection, 1\\);)",
                "$1\r\n  if (p->unif.ScrollOffset >= 0) {\r\n    float scroll_offset[2] = { (float)BG2HOFS_copy2, (float)BG2VOFS_copy2 };\r\n    glUniform2fv(p->unif.ScrollOffset, 1, scroll_offset);\r\n  }");

        File.WriteAllText(path, text);
    }
}
