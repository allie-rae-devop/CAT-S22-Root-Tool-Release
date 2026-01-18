/*
 * CAT S22 Root Tool - Portable Windows Executable
 *
 * This is a C# wrapper that bundles the PowerShell scripts into a single
 * portable executable with a graphical user interface.
 *
 * Author: Claude (AI Assistant)
 * License: MIT
 *
 * Build: csc /target:winexe /out:CAT_S22_Root_Tool.exe CAT_S22_Root_Tool_GUI.cs
 * Compatible with: .NET Framework 4.0+ / C# 5
 */

using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace CAT_S22_Root_Tool
{
    public class MainForm : Form
    {
        // UI Controls
        private Panel headerPanel;
        private Label titleLabel;
        private Label subtitleLabel;
        private Panel warningPanel;
        private Label warningLabel;
        private GroupBox statusGroup;
        private Label deviceStatusLabel;
        private Label firmwareStatusLabel;
        private Button detectButton;
        private GroupBox actionsGroup;
        private Button rootButton;
        private Button debloatButton;
        private Button openLogButton;
        private Button githubButton;
        private GroupBox logGroup;
        private RichTextBox logBox;
        private ProgressBar progressBar;
        private Label statusLabel;

        // State
        private string tempPath;
        private string logFilePath;
        private bool isRunning = false;
        private CancellationTokenSource cancellationTokenSource;

        // Constants
        private const string APP_NAME = "CAT S22 Root Tool";
        private const string APP_VERSION = "1.0.0";
        private const string GITHUB_URL = "https://github.com/allie-rae-devop/CAT-S22-Root-Tool-Release";
        private const string PLATFORM_TOOLS_URL = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip";

        public MainForm()
        {
            InitializeComponent();
            InitializePaths();
            this.Load += MainForm_Load;
        }

        private void InitializeComponent()
        {
            // Form settings
            this.Text = string.Format("{0} v{1}", APP_NAME, APP_VERSION);
            this.Size = new Size(800, 700);
            this.MinimumSize = new Size(700, 600);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = Color.FromArgb(245, 245, 245);
            this.Font = new Font("Segoe UI", 9F);

            // Header Panel
            headerPanel = new Panel();
            headerPanel.Dock = DockStyle.Top;
            headerPanel.Height = 80;
            headerPanel.BackColor = Color.FromArgb(44, 62, 80);

            titleLabel = new Label();
            titleLabel.Text = "CAT S22 Flip Root Tool";
            titleLabel.ForeColor = Color.White;
            titleLabel.Font = new Font("Segoe UI", 20F, FontStyle.Bold);
            titleLabel.AutoSize = true;
            titleLabel.Location = new Point(20, 15);
            headerPanel.Controls.Add(titleLabel);

            subtitleLabel = new Label();
            subtitleLabel.Text = "Automated rooting assistant for CAT S22 Flip phones";
            subtitleLabel.ForeColor = Color.FromArgb(189, 195, 199);
            subtitleLabel.Font = new Font("Segoe UI", 10F);
            subtitleLabel.AutoSize = true;
            subtitleLabel.Location = new Point(22, 50);
            headerPanel.Controls.Add(subtitleLabel);

            this.Controls.Add(headerPanel);

            // Warning Panel
            warningPanel = new Panel();
            warningPanel.Location = new Point(15, 95);
            warningPanel.Size = new Size(750, 70);
            warningPanel.BackColor = Color.FromArgb(231, 76, 60);
            warningPanel.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;

            warningLabel = new Label();
            warningLabel.Text = "WARNING: Rooting VOIDS WARRANTY and may BRICK your device!\n" +
                       "Unlocking bootloader ERASES ALL DATA. Backup first!\n" +
                       "Keep phone charged above 50% throughout process.";
            warningLabel.ForeColor = Color.White;
            warningLabel.Font = new Font("Segoe UI", 9F);
            warningLabel.AutoSize = false;
            warningLabel.Size = new Size(730, 60);
            warningLabel.Location = new Point(10, 5);
            warningLabel.TextAlign = ContentAlignment.MiddleCenter;
            warningPanel.Controls.Add(warningLabel);
            this.Controls.Add(warningPanel);

            // Status Group
            statusGroup = new GroupBox();
            statusGroup.Text = "Device Status";
            statusGroup.Location = new Point(15, 175);
            statusGroup.Size = new Size(365, 100);
            statusGroup.Anchor = AnchorStyles.Top | AnchorStyles.Left;

            deviceStatusLabel = new Label();
            deviceStatusLabel.Text = "Device: Not detected";
            deviceStatusLabel.ForeColor = Color.FromArgb(192, 57, 43);
            deviceStatusLabel.Font = new Font("Segoe UI", 10F, FontStyle.Bold);
            deviceStatusLabel.Location = new Point(15, 25);
            deviceStatusLabel.AutoSize = true;
            statusGroup.Controls.Add(deviceStatusLabel);

            firmwareStatusLabel = new Label();
            firmwareStatusLabel.Text = "Firmware: Unknown";
            firmwareStatusLabel.ForeColor = Color.Gray;
            firmwareStatusLabel.Font = new Font("Segoe UI", 9F);
            firmwareStatusLabel.Location = new Point(15, 50);
            firmwareStatusLabel.AutoSize = true;
            statusGroup.Controls.Add(firmwareStatusLabel);

            detectButton = new Button();
            detectButton.Text = "Detect Device";
            detectButton.Size = new Size(120, 30);
            detectButton.Location = new Point(230, 60);
            detectButton.BackColor = Color.FromArgb(52, 152, 219);
            detectButton.ForeColor = Color.White;
            detectButton.FlatStyle = FlatStyle.Flat;
            detectButton.Cursor = Cursors.Hand;
            detectButton.FlatAppearance.BorderSize = 0;
            detectButton.Click += DetectButton_Click;
            statusGroup.Controls.Add(detectButton);

            this.Controls.Add(statusGroup);

            // Actions Group
            actionsGroup = new GroupBox();
            actionsGroup.Text = "Actions";
            actionsGroup.Location = new Point(395, 175);
            actionsGroup.Size = new Size(370, 100);
            actionsGroup.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;

            rootButton = new Button();
            rootButton.Text = "Root Device";
            rootButton.Size = new Size(160, 40);
            rootButton.Location = new Point(15, 30);
            rootButton.BackColor = Color.FromArgb(39, 174, 96);
            rootButton.ForeColor = Color.White;
            rootButton.FlatStyle = FlatStyle.Flat;
            rootButton.Font = new Font("Segoe UI", 11F, FontStyle.Bold);
            rootButton.Cursor = Cursors.Hand;
            rootButton.FlatAppearance.BorderSize = 0;
            rootButton.Click += RootButton_Click;
            actionsGroup.Controls.Add(rootButton);

            debloatButton = new Button();
            debloatButton.Text = "Debloat Device";
            debloatButton.Size = new Size(160, 40);
            debloatButton.Location = new Point(190, 30);
            debloatButton.BackColor = Color.FromArgb(155, 89, 182);
            debloatButton.ForeColor = Color.White;
            debloatButton.FlatStyle = FlatStyle.Flat;
            debloatButton.Font = new Font("Segoe UI", 11F, FontStyle.Bold);
            debloatButton.Cursor = Cursors.Hand;
            debloatButton.FlatAppearance.BorderSize = 0;
            debloatButton.Click += DebloatButton_Click;
            actionsGroup.Controls.Add(debloatButton);

            openLogButton = new Button();
            openLogButton.Text = "Open Log";
            openLogButton.Size = new Size(80, 25);
            openLogButton.Location = new Point(15, 75);
            openLogButton.BackColor = Color.FromArgb(149, 165, 166);
            openLogButton.ForeColor = Color.White;
            openLogButton.FlatStyle = FlatStyle.Flat;
            openLogButton.Font = new Font("Segoe UI", 8F);
            openLogButton.Cursor = Cursors.Hand;
            openLogButton.FlatAppearance.BorderSize = 0;
            openLogButton.Click += OpenLogButton_Click;
            actionsGroup.Controls.Add(openLogButton);

            githubButton = new Button();
            githubButton.Text = "GitHub";
            githubButton.Size = new Size(80, 25);
            githubButton.Location = new Point(105, 75);
            githubButton.BackColor = Color.FromArgb(52, 73, 94);
            githubButton.ForeColor = Color.White;
            githubButton.FlatStyle = FlatStyle.Flat;
            githubButton.Font = new Font("Segoe UI", 8F);
            githubButton.Cursor = Cursors.Hand;
            githubButton.FlatAppearance.BorderSize = 0;
            githubButton.Click += GithubButton_Click;
            actionsGroup.Controls.Add(githubButton);

            this.Controls.Add(actionsGroup);

            // Log Group
            logGroup = new GroupBox();
            logGroup.Text = "Process Log";
            logGroup.Location = new Point(15, 285);
            logGroup.Size = new Size(750, 300);
            logGroup.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;

            logBox = new RichTextBox();
            logBox.Location = new Point(10, 20);
            logBox.Size = new Size(730, 270);
            logBox.BackColor = Color.FromArgb(30, 30, 30);
            logBox.ForeColor = Color.FromArgb(0, 255, 0);
            logBox.Font = new Font("Consolas", 9F);
            logBox.ReadOnly = true;
            logBox.BorderStyle = BorderStyle.None;
            logBox.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
            logGroup.Controls.Add(logBox);

            this.Controls.Add(logGroup);

            // Progress Bar
            progressBar = new ProgressBar();
            progressBar.Location = new Point(15, 595);
            progressBar.Size = new Size(750, 25);
            progressBar.Style = ProgressBarStyle.Continuous;
            progressBar.Anchor = AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
            this.Controls.Add(progressBar);

            // Status Label
            statusLabel = new Label();
            statusLabel.Text = "Ready - Connect your device and click 'Detect Device'";
            statusLabel.Location = new Point(15, 625);
            statusLabel.Size = new Size(750, 25);
            statusLabel.ForeColor = Color.FromArgb(127, 140, 141);
            statusLabel.Font = new Font("Segoe UI", 9F, FontStyle.Italic);
            statusLabel.Anchor = AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
            this.Controls.Add(statusLabel);
        }

        private void InitializePaths()
        {
            tempPath = Path.Combine(Path.GetTempPath(), "CAT_S22_Root");
            logFilePath = Path.Combine(tempPath, "root_tool.log");

            // Create temp directory
            if (!Directory.Exists(tempPath))
            {
                Directory.CreateDirectory(tempPath);
            }
        }

        private void MainForm_Load(object sender, EventArgs e)
        {
            Log("CAT S22 Root Tool v" + APP_VERSION + " started", LogLevel.Info);
            Log("Temporary path: " + tempPath, LogLevel.Debug);

            // Extract embedded resources
            ExtractResources();

            // Check if platform-tools need to be downloaded
            string adbPath = Path.Combine(tempPath, "platform-tools", "adb.exe");
            if (!File.Exists(adbPath))
            {
                Log("Platform-tools not found. Will download on first use.", LogLevel.Warning);
            }
            else
            {
                Log("Platform-tools found at: " + adbPath, LogLevel.Success);
            }

            Log("Ready! Connect your CAT S22 Flip and enable USB debugging.", LogLevel.Info);
        }

        private void ExtractResources()
        {
            try
            {
                string exeDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);

                // Copy PowerShell scripts if they exist next to the EXE
                CopyIfExists(Path.Combine(exeDir, "CAT_S22_Root_Tool.ps1"), Path.Combine(tempPath, "CAT_S22_Root_Tool.ps1"));
                CopyIfExists(Path.Combine(exeDir, "CAT_S22_Enhanced_Debloat.ps1"), Path.Combine(tempPath, "CAT_S22_Enhanced_Debloat.ps1"));

                // Create boot_images directory and copy boot image
                string bootImagesDir = Path.Combine(tempPath, "boot_images");
                if (!Directory.Exists(bootImagesDir))
                {
                    Directory.CreateDirectory(bootImagesDir);
                }
                CopyIfExists(Path.Combine(exeDir, "boot_images", "boot_v30.img"), Path.Combine(bootImagesDir, "boot_v30.img"));

                // Copy Magisk APK to downloads directory
                string downloadsDir = Path.Combine(tempPath, "downloads");
                if (!Directory.Exists(downloadsDir))
                {
                    Directory.CreateDirectory(downloadsDir);
                }
                CopyIfExists(Path.Combine(exeDir, "Magisk-v25.2.apk"), Path.Combine(downloadsDir, "Magisk.apk"));

                Log("Resources extracted successfully", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log("Error extracting resources: " + ex.Message, LogLevel.Error);
            }
        }

        private void CopyIfExists(string source, string dest)
        {
            if (File.Exists(source) && !File.Exists(dest))
            {
                File.Copy(source, dest);
                Log("Copied: " + Path.GetFileName(source), LogLevel.Debug);
            }
        }

        private void EnsurePlatformToolsAsync(Action onComplete, Action<Exception> onError)
        {
            string platformToolsPath = Path.Combine(tempPath, "platform-tools");
            string adbPath = Path.Combine(platformToolsPath, "adb.exe");

            if (File.Exists(adbPath))
            {
                onComplete();
                return;
            }

            Log("Downloading Android Platform Tools...", LogLevel.Info);
            UpdateStatus("Downloading Android Platform Tools (one-time setup)...");
            progressBar.Style = ProgressBarStyle.Marquee;

            string zipPath = Path.Combine(tempPath, "platform-tools.zip");

            WebClient client = new WebClient();
            client.DownloadProgressChanged += (s, e) =>
            {
                this.BeginInvoke((Action)(() =>
                {
                    progressBar.Style = ProgressBarStyle.Continuous;
                    progressBar.Value = e.ProgressPercentage;
                    UpdateStatus(string.Format("Downloading Platform Tools: {0}%", e.ProgressPercentage));
                }));
            };

            client.DownloadFileCompleted += (s, e) =>
            {
                this.BeginInvoke((Action)(() =>
                {
                    if (e.Error != null)
                    {
                        progressBar.Style = ProgressBarStyle.Continuous;
                        onError(e.Error);
                        return;
                    }

                    try
                    {
                        Log("Extracting Platform Tools...", LogLevel.Info);
                        UpdateStatus("Extracting Platform Tools...");

                        ZipFile.ExtractToDirectory(zipPath, tempPath);

                        // Clean up zip file
                        File.Delete(zipPath);

                        Log("Platform Tools installed successfully!", LogLevel.Success);
                        UpdateStatus("Platform Tools ready!");
                        progressBar.Value = 100;
                        progressBar.Style = ProgressBarStyle.Continuous;

                        onComplete();
                    }
                    catch (Exception ex)
                    {
                        progressBar.Style = ProgressBarStyle.Continuous;
                        onError(ex);
                    }
                }));
            };

            try
            {
                client.DownloadFileAsync(new Uri(PLATFORM_TOOLS_URL), zipPath);
            }
            catch (Exception ex)
            {
                progressBar.Style = ProgressBarStyle.Continuous;
                onError(ex);
            }
        }

        private void DetectButton_Click(object sender, EventArgs e)
        {
            if (isRunning) return;

            isRunning = true;
            detectButton.Enabled = false;

            EnsurePlatformToolsAsync(
                () => DoDetectDevice(),
                (ex) =>
                {
                    Log("Failed to download Platform Tools: " + ex.Message, LogLevel.Error);
                    isRunning = false;
                    detectButton.Enabled = true;
                }
            );
        }

        private void DoDetectDevice()
        {
            Log("Detecting device...", LogLevel.Info);
            UpdateStatus("Detecting device...");

            string adbPath = Path.Combine(tempPath, "platform-tools", "adb.exe");

            RunCommandAsync(adbPath, "devices", (result) =>
            {
                this.BeginInvoke((Action)(() =>
                {
                    if (result.Contains("device") && !result.Contains("unauthorized"))
                    {
                        deviceStatusLabel.Text = "Device: Connected";
                        deviceStatusLabel.ForeColor = Color.FromArgb(39, 174, 96);
                        Log("Device connected via ADB", LogLevel.Success);

                        // Try to get firmware version
                        RunCommandAsync(adbPath, "shell getprop ro.build.fingerprint", (buildInfo) =>
                        {
                            this.BeginInvoke((Action)(() =>
                            {
                                if (buildInfo.Contains("S22Flip"))
                                {
                                    if (buildInfo.Contains("0.030"))
                                    {
                                        firmwareStatusLabel.Text = "Firmware: v30 detected";
                                        firmwareStatusLabel.ForeColor = Color.FromArgb(39, 174, 96);
                                        Log("Firmware v30 detected", LogLevel.Success);
                                    }
                                    else if (buildInfo.Contains("0.029"))
                                    {
                                        firmwareStatusLabel.Text = "Firmware: v29 detected";
                                        firmwareStatusLabel.ForeColor = Color.FromArgb(39, 174, 96);
                                        Log("Firmware v29 detected", LogLevel.Success);
                                    }
                                    else
                                    {
                                        firmwareStatusLabel.Text = "Firmware: CAT S22 Flip (version unknown)";
                                        firmwareStatusLabel.ForeColor = Color.FromArgb(230, 126, 34);
                                    }
                                }
                                else
                                {
                                    firmwareStatusLabel.Text = "Firmware: Non-CAT S22 device detected";
                                    firmwareStatusLabel.ForeColor = Color.FromArgb(230, 126, 34);
                                    Log("Warning: Device may not be a CAT S22 Flip", LogLevel.Warning);
                                }

                                UpdateStatus("Device detected! Ready to proceed.");
                                isRunning = false;
                                detectButton.Enabled = true;
                            }));
                        });
                    }
                    else if (result.Contains("unauthorized"))
                    {
                        deviceStatusLabel.Text = "Device: Unauthorized";
                        deviceStatusLabel.ForeColor = Color.FromArgb(230, 126, 34);
                        Log("Device connected but unauthorized - accept prompt on phone", LogLevel.Warning);
                        UpdateStatus("Please accept the USB debugging prompt on your phone!");

                        MessageBox.Show(
                            "Please accept the USB debugging authorization prompt on your phone, then click Detect Device again.",
                            "Authorization Required",
                            MessageBoxButtons.OK,
                            MessageBoxIcon.Information
                        );

                        isRunning = false;
                        detectButton.Enabled = true;
                    }
                    else
                    {
                        deviceStatusLabel.Text = "Device: Not detected";
                        deviceStatusLabel.ForeColor = Color.FromArgb(192, 57, 43);
                        firmwareStatusLabel.Text = "Firmware: Unknown";
                        firmwareStatusLabel.ForeColor = Color.Gray;
                        Log("No device detected", LogLevel.Warning);
                        UpdateStatus("No device detected. Check USB connection and enable USB debugging.");

                        isRunning = false;
                        detectButton.Enabled = true;
                    }
                }));
            });
        }

        private void RootButton_Click(object sender, EventArgs e)
        {
            if (isRunning)
            {
                if (MessageBox.Show("A process is already running. Do you want to cancel it?",
                    "Cancel?", MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes)
                {
                    if (cancellationTokenSource != null)
                    {
                        cancellationTokenSource.Cancel();
                    }
                }
                return;
            }

            var confirmResult = MessageBox.Show(
                "This will start the rooting process for your CAT S22 Flip.\n\n" +
                "WARNING:\n" +
                "- This will VOID your warranty\n" +
                "- Unlocking bootloader ERASES ALL DATA\n" +
                "- Your phone may become bricked if interrupted\n\n" +
                "Make sure you have:\n" +
                "- Backed up all important data\n" +
                "- Phone charged above 50%\n" +
                "- USB debugging enabled\n\n" +
                "Are you sure you want to continue?",
                "Confirm Rooting",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning
            );

            if (confirmResult != DialogResult.Yes) return;

            EnsurePlatformToolsAsync(
                () => RunPowerShellScript("CAT_S22_Root_Tool.ps1"),
                (ex) => Log("Failed to prepare: " + ex.Message, LogLevel.Error)
            );
        }

        private void DebloatButton_Click(object sender, EventArgs e)
        {
            if (isRunning)
            {
                MessageBox.Show("Please wait for the current process to complete.",
                    "Process Running", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            var confirmResult = MessageBox.Show(
                "This will run the debloat tool to remove bloatware and install privacy-focused apps.\n\n" +
                "Requirements:\n" +
                "- Device must already be rooted (run Root Device first if needed)\n" +
                "- USB debugging must be enabled\n" +
                "- Device must be connected\n\n" +
                "This will:\n" +
                "- Remove T-Mobile/Google bloatware\n" +
                "- Offer to install alternative apps (F-Droid, etc.)\n\n" +
                "Continue?",
                "Confirm Debloat",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question
            );

            if (confirmResult != DialogResult.Yes) return;

            EnsurePlatformToolsAsync(
                () => RunPowerShellScript("CAT_S22_Enhanced_Debloat.ps1"),
                (ex) => Log("Failed to prepare: " + ex.Message, LogLevel.Error)
            );
        }

        private void RunPowerShellScript(string scriptName)
        {
            isRunning = true;
            rootButton.Enabled = false;
            debloatButton.Enabled = false;
            detectButton.Enabled = false;
            cancellationTokenSource = new CancellationTokenSource();

            string scriptPath = Path.Combine(tempPath, scriptName);

            // Check if script exists
            if (!File.Exists(scriptPath))
            {
                // Try to copy from exe directory
                string exeDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
                string sourceScript = Path.Combine(exeDir, scriptName);

                if (File.Exists(sourceScript))
                {
                    File.Copy(sourceScript, scriptPath, true);
                }
                else
                {
                    Log("Script not found: " + scriptName, LogLevel.Error);
                    MessageBox.Show("Script not found: " + scriptName + "\n\nPlease ensure the script is in the same folder as the executable.",
                        "Script Not Found", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    ResetButtons();
                    return;
                }
            }

            Log("Starting " + scriptName + "...", LogLevel.Info);
            UpdateStatus("Running " + scriptName + "...");
            progressBar.Style = ProgressBarStyle.Marquee;

            // Modify the script to use our temp path for tools
            string scriptContent = File.ReadAllText(scriptPath);
            string modifiedScript = scriptContent.Replace(
                "$env:USERPROFILE\\CAT_S22_Root",
                tempPath.Replace("\\", "\\\\")
            );

            string modifiedScriptPath = Path.Combine(tempPath, "temp_" + scriptName);
            File.WriteAllText(modifiedScriptPath, modifiedScript);

            // Run PowerShell with bypass execution policy
            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = "powershell.exe";
            psi.Arguments = string.Format("-NoProfile -ExecutionPolicy Bypass -File \"{0}\"", modifiedScriptPath);
            psi.UseShellExecute = false;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.CreateNoWindow = false;
            psi.WorkingDirectory = tempPath;

            Process process = new Process();
            process.StartInfo = psi;
            process.EnableRaisingEvents = true;

            process.OutputDataReceived += (s, args) =>
            {
                if (!string.IsNullOrEmpty(args.Data))
                {
                    this.BeginInvoke((Action)(() => Log(args.Data, LogLevel.Info)));
                }
            };

            process.ErrorDataReceived += (s, args) =>
            {
                if (!string.IsNullOrEmpty(args.Data))
                {
                    this.BeginInvoke((Action)(() => Log(args.Data, LogLevel.Warning)));
                }
            };

            process.Exited += (s, args) =>
            {
                this.BeginInvoke((Action)(() =>
                {
                    if (process.ExitCode == 0)
                    {
                        Log(scriptName + " completed successfully!", LogLevel.Success);
                        UpdateStatus("Process completed successfully!");
                    }
                    else
                    {
                        Log(string.Format("{0} exited with code: {1}", scriptName, process.ExitCode), LogLevel.Warning);
                        UpdateStatus("Process completed with warnings. Check log for details.");
                    }

                    // Clean up temp script
                    try
                    {
                        if (File.Exists(modifiedScriptPath))
                        {
                            File.Delete(modifiedScriptPath);
                        }
                    }
                    catch { }

                    ResetButtons();
                    process.Dispose();
                }));
            };

            try
            {
                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();
            }
            catch (Exception ex)
            {
                Log("Error running script: " + ex.Message, LogLevel.Error);
                UpdateStatus("Error running script. Check log for details.");
                MessageBox.Show("Error: " + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                ResetButtons();
            }
        }

        private void ResetButtons()
        {
            isRunning = false;
            rootButton.Enabled = true;
            debloatButton.Enabled = true;
            detectButton.Enabled = true;
            progressBar.Style = ProgressBarStyle.Continuous;
            progressBar.Value = 100;
            if (cancellationTokenSource != null)
            {
                cancellationTokenSource.Dispose();
                cancellationTokenSource = null;
            }
        }

        private void RunCommandAsync(string command, string arguments, Action<string> callback)
        {
            StringBuilder output = new StringBuilder();

            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = command;
            psi.Arguments = arguments;
            psi.UseShellExecute = false;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.CreateNoWindow = true;

            Process process = new Process();
            process.StartInfo = psi;
            process.EnableRaisingEvents = true;

            process.OutputDataReceived += (s, e) =>
            {
                if (!string.IsNullOrEmpty(e.Data))
                {
                    output.AppendLine(e.Data);
                }
            };

            process.ErrorDataReceived += (s, e) =>
            {
                if (!string.IsNullOrEmpty(e.Data))
                {
                    output.AppendLine(e.Data);
                }
            };

            process.Exited += (s, e) =>
            {
                callback(output.ToString());
                process.Dispose();
            };

            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
        }

        private void OpenLogButton_Click(object sender, EventArgs e)
        {
            // Save current log to file
            try
            {
                File.WriteAllText(logFilePath, logBox.Text);
                Process.Start("notepad.exe", logFilePath);
            }
            catch (Exception ex)
            {
                MessageBox.Show("Error opening log: " + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void GithubButton_Click(object sender, EventArgs e)
        {
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = GITHUB_URL;
                psi.UseShellExecute = true;
                Process.Start(psi);
            }
            catch
            {
                MessageBox.Show("Please visit: " + GITHUB_URL, "GitHub", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }

        private enum LogLevel
        {
            Debug,
            Info,
            Success,
            Warning,
            Error
        }

        private void Log(string message, LogLevel level)
        {
            if (this.InvokeRequired)
            {
                this.BeginInvoke((Action)(() => Log(message, level)));
                return;
            }

            Color color;
            switch (level)
            {
                case LogLevel.Debug:
                    color = Color.FromArgb(150, 150, 150);
                    break;
                case LogLevel.Success:
                    color = Color.FromArgb(0, 255, 0);
                    break;
                case LogLevel.Warning:
                    color = Color.FromArgb(255, 200, 0);
                    break;
                case LogLevel.Error:
                    color = Color.FromArgb(255, 80, 80);
                    break;
                default:
                    color = Color.FromArgb(0, 255, 0);
                    break;
            }

            string timestamp = DateTime.Now.ToString("HH:mm:ss");
            string prefix = string.Format("[{0}] [{1}] ", timestamp, level);

            logBox.SelectionStart = logBox.TextLength;
            logBox.SelectionColor = color;
            logBox.AppendText(prefix + message + Environment.NewLine);
            logBox.ScrollToCaret();

            // Also write to log file
            try
            {
                File.AppendAllText(logFilePath, prefix + message + Environment.NewLine);
            }
            catch { }
        }

        private void UpdateStatus(string message)
        {
            if (this.InvokeRequired)
            {
                this.BeginInvoke((Action)(() => UpdateStatus(message)));
                return;
            }

            statusLabel.Text = message;
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (isRunning)
            {
                var result = MessageBox.Show(
                    "A process is still running. Closing now may cause issues.\n\nAre you sure you want to exit?",
                    "Process Running",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning
                );

                if (result == DialogResult.No)
                {
                    e.Cancel = true;
                    return;
                }

                if (cancellationTokenSource != null)
                {
                    cancellationTokenSource.Cancel();
                }
            }

            base.OnFormClosing(e);
        }
    }

    static class Program
    {
        [STAThread]
        static void Main()
        {
            // Check for admin rights
            if (!IsAdministrator())
            {
                // Relaunch as admin
                try
                {
                    ProcessStartInfo psi = new ProcessStartInfo();
                    psi.FileName = Assembly.GetExecutingAssembly().Location;
                    psi.UseShellExecute = true;
                    psi.Verb = "runas";
                    Process.Start(psi);
                    return;
                }
                catch
                {
                    MessageBox.Show(
                        "This application requires Administrator privileges to install drivers and tools.\n\nPlease run as Administrator.",
                        "Administrator Required",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Warning
                    );
                    return;
                }
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }

        static bool IsAdministrator()
        {
            var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
            var principal = new System.Security.Principal.WindowsPrincipal(identity);
            return principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
        }
    }
}
