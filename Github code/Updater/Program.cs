using System;
using System.Diagnostics;
using System.IO;
using System.Threading;

//
// Small updater helper. Build as a separate minimal console app (single-file not required).
// Usage: Updater.exe "<downloadedNewExePath>" "<targetExePath>"
//
// Behavior:
// - Wait for the target process to exit (by name / by path).
// - Replace targetExe with downloadedNewExe (move).
// - Start the targetExe (optional).
//
class Program
{
    static int Main(string[] args)
    {
        try
        {
            if (args.Length < 2)
            {
                Console.WriteLine("Usage: Updater <newExe> <targetExe>");
                return 2;
            }

            var newExe = args[0];
            var targetExe = args[1];

            Console.WriteLine($"Updater starting. newExe={newExe} targetExe={targetExe}");

            // Ensure newExe exists
            if (!File.Exists(newExe))
            {
                Console.WriteLine("New exe missing.");
                return 3;
            }

            // Find any running processes that lock the target exe
            var targetName = Path.GetFileNameWithoutExtension(targetExe);
            foreach (var p in Process.GetProcessesByName(targetName))
            {
                try
                {
                    if (p.MainModule?.FileName != null &&
                        string.Equals(Path.GetFullPath(p.MainModule.FileName), Path.GetFullPath(targetExe), StringComparison.OrdinalIgnoreCase))
                    {
                        Console.WriteLine($"Found running process {p.Id} - waiting for exit...");
                        p.WaitForExit(30_000); // wait up to 30s
                        if (!p.HasExited)
                        {
                            Console.WriteLine("Process still running; attempting to close...");
                            try { p.CloseMainWindow(); } catch { }
                            Thread.Sleep(3000);
                            if (!p.HasExited) { p.Kill(); p.WaitForExit(5000); }
                        }
                    }
                }
                catch
                {
                    // Access denied to main module -> still wait briefly
                    Thread.Sleep(2000);
                }
            }

            // Try to replace file. If locked, retry and fallback to move-on-reboot.
            var backup = targetExe + ".bak_" + DateTime.UtcNow.ToString("yyyyMMddHHmmss");
            try
            {
                if (File.Exists(targetExe))
                {
                    // Move old exe to backup
                    File.Move(targetExe, backup);
                    Console.WriteLine($"Moved old exe to {backup}");
                }
                // Move new exe into place
                File.Move(newExe, targetExe);
                Console.WriteLine("Replaced exe successfully.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Replace failed: {ex}. Scheduling replace on reboot.");
                // Schedule move-on-reboot
                bool ok = MoveFileEx(newExe, targetExe, MoveFileFlags.MOVEFILE_REPLACE_EXISTING | MoveFileFlags.MOVEFILE_DELAY_UNTIL_REBOOT);
                Console.WriteLine($"MoveFileEx scheduled: {ok}");
            }

            // Relaunch new exe
            try
            {
                Process.Start(new ProcessStartInfo { FileName = targetExe, UseShellExecute = true });
                Console.WriteLine("Relaunched target exe.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Relaunch failed: {ex}");
            }

            return 0;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Updater exception: {ex}");
            return 1;
        }
    }

    // P/Invoke MoveFileEx for scheduling replacement on reboot
    [System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
    private static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, MoveFileFlags dwFlags);

    [Flags]
    private enum MoveFileFlags : uint
    {
        MOVEFILE_REPLACE_EXISTING = 0x1,
        MOVEFILE_COPY_ALLOWED = 0x2,
        MOVEFILE_DELAY_UNTIL_REBOOT = 0x4,
        MOVEFILE_WRITE_THROUGH = 0x8
    }
}