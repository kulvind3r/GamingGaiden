using System.Reflection;
using System.Runtime.InteropServices;
using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

// General Information about an assembly
[assembly: AssemblyTitle("Gaming Gaiden: Gameplay Time Tracker")]
[assembly: AssemblyCompany("Kulvinder Singh")]
[assembly: AssemblyProduct("Gaming Gaiden")]
[assembly: AssemblyCopyright("© 2023 Kulvinder Singh")]

// Version information
[assembly: AssemblyFileVersion("2026.02.22")]

// Setting ComVisible to false makes the types in this assembly not visible to COM components
[assembly: ComVisible(false)]

class Program {
    static void Main(string[] args) {
        // 1. Locate the script file relative to the EXE location
        string exePath = AppDomain.CurrentDomain.BaseDirectory;
        string scriptPath = Path.Combine(exePath, "GamingGaiden.ps1");

        if (!File.Exists(scriptPath)) {
            Console.WriteLine("Error: GamingGaiden.ps1 not found in: " + exePath);
            return;
        }

        // 2. Set the window title for the process
        Console.Title = "Gaming Gaiden";

        // 3. Create the PowerShell runspace inside this process
        using (Runspace rs = RunspaceFactory.CreateRunspace()) {
            rs.Open();
            using (PowerShell ps = PowerShell.Create()) {
                ps.Runspace = rs;

                // Load and execute the external script file
                string scriptContent = File.ReadAllText(scriptPath);
                ps.AddScript(scriptContent);

                // Pass through any command line arguments to the script
                if (args.Length > 0) {
                    ps.AddArgument(args);
                }

                // Execute in-process
                ps.Invoke();
            }
        }
    }
}