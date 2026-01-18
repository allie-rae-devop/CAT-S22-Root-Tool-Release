/*
 * CAT S22 Root Tool - Self-Contained Portable Executable
 *
 * This version embeds all scripts and resources directly in the executable
 * for true single-file distribution.
 *
 * Author: Claude (AI Assistant)
 * License: MIT
 *
 * Build: Run build_selfcontained.ps1
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
        private Button cleanupButton;
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
        private const string GITHUB_URL = "https://github.com/user/CAT_S22_Root_Tool";
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
            this.Text = $"{APP_NAME} v{APP_VERSION}";
            this.Size = new Size(850, 750);
            this.MinimumSize = new Size(750, 650);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = Color.FromArgb(245, 245, 245);
            this.Font = new Font("Segoe UI", 9F);

            // Header Panel
            headerPanel = new Panel
            {
                Dock = DockStyle.Top,
                Height = 80,
                BackColor = Color.FromArgb(44, 62, 80)
            };

            titleLabel = new Label
            {
                Text = "CAT S22 Flip Root Tool",
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 20F, FontStyle.Bold),
                AutoSize = true,
                Location = new Point(20, 15)
            };
            headerPanel.Controls.Add(titleLabel);

            subtitleLabel = new Label
            {
                Text = "Automated rooting assistant - Portable Edition",
                ForeColor = Color.FromArgb(189, 195, 199),
                Font = new Font("Segoe UI", 10F),
                AutoSize = true,
                Location = new Point(22, 50)
            };
            headerPanel.Controls.Add(subtitleLabel);

            this.Controls.Add(headerPanel);

            // Warning Panel
            warningPanel = new Panel
            {
                Location = new Point(15, 95),
                Size = new Size(800, 70),
                BackColor = Color.FromArgb(231, 76, 60),
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right
            };

            warningLabel = new Label
            {
                Text = "WARNING: Rooting VOIDS WARRANTY and may BRICK your device!\n" +
                       "Unlocking bootloader ERASES ALL DATA. Backup first!\n" +
                       "Keep phone charged above 50% throughout process.",
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 9F),
                AutoSize = false,
                Size = new Size(780, 60),
                Location = new Point(10, 5),
                TextAlign = ContentAlignment.MiddleCenter
            };
            warningPanel.Controls.Add(warningLabel);
            this.Controls.Add(warningPanel);

            // Status Group
            statusGroup = new GroupBox
            {
                Text = "Device Status",
                Location = new Point(15, 175),
                Size = new Size(400, 110),
                Anchor = AnchorStyles.Top | AnchorStyles.Left
            };

            deviceStatusLabel = new Label
            {
                Text = "Device: Not detected",
                ForeColor = Color.FromArgb(192, 57, 43),
                Font = new Font("Segoe UI", 10F, FontStyle.Bold),
                Location = new Point(15, 25),
                AutoSize = true
            };
            statusGroup.Controls.Add(deviceStatusLabel);

            firmwareStatusLabel = new Label
            {
                Text = "Firmware: Unknown",
                ForeColor = Color.Gray,
                Font = new Font("Segoe UI", 9F),
                Location = new Point(15, 50),
                AutoSize = true
            };
            statusGroup.Controls.Add(firmwareStatusLabel);

            detectButton = new Button
            {
                Text = "Detect Device",
                Size = new Size(140, 35),
                Location = new Point(240, 65),
                BackColor = Color.FromArgb(52, 152, 219),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 9F, FontStyle.Bold),
                Cursor = Cursors.Hand
            };
            detectButton.FlatAppearance.BorderSize = 0;
            detectButton.Click += DetectButton_Click;
            statusGroup.Controls.Add(detectButton);

            this.Controls.Add(statusGroup);

            // Actions Group
            actionsGroup = new GroupBox
            {
                Text = "Actions",
                Location = new Point(430, 175),
                Size = new Size(385, 110),
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right
            };

            rootButton = new Button
            {
                Text = "Root Device",
                Size = new Size(170, 45),
                Location = new Point(15, 25),
                BackColor = Color.FromArgb(39, 174, 96),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 11F, FontStyle.Bold),
                Cursor = Cursors.Hand
            };
            rootButton.FlatAppearance.BorderSize = 0;
            rootButton.Click += RootButton_Click;
            actionsGroup.Controls.Add(rootButton);

            debloatButton = new Button
            {
                Text = "Debloat Device",
                Size = new Size(170, 45),
                Location = new Point(200, 25),
                BackColor = Color.FromArgb(155, 89, 182),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 11F, FontStyle.Bold),
                Cursor = Cursors.Hand
            };
            debloatButton.FlatAppearance.BorderSize = 0;
            debloatButton.Click += DebloatButton_Click;
            actionsGroup.Controls.Add(debloatButton);

            openLogButton = new Button
            {
                Text = "Open Log",
                Size = new Size(80, 28),
                Location = new Point(15, 75),
                BackColor = Color.FromArgb(149, 165, 166),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 8F),
                Cursor = Cursors.Hand
            };
            openLogButton.FlatAppearance.BorderSize = 0;
            openLogButton.Click += OpenLogButton_Click;
            actionsGroup.Controls.Add(openLogButton);

            githubButton = new Button
            {
                Text = "GitHub",
                Size = new Size(80, 28),
                Location = new Point(105, 75),
                BackColor = Color.FromArgb(52, 73, 94),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 8F),
                Cursor = Cursors.Hand
            };
            githubButton.FlatAppearance.BorderSize = 0;
            githubButton.Click += GithubButton_Click;
            actionsGroup.Controls.Add(githubButton);

            cleanupButton = new Button
            {
                Text = "Cleanup",
                Size = new Size(80, 28),
                Location = new Point(195, 75),
                BackColor = Color.FromArgb(230, 126, 34),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 8F),
                Cursor = Cursors.Hand
            };
            cleanupButton.FlatAppearance.BorderSize = 0;
            cleanupButton.Click += CleanupButton_Click;
            actionsGroup.Controls.Add(cleanupButton);

            this.Controls.Add(actionsGroup);

            // Log Group
            logGroup = new GroupBox
            {
                Text = "Process Log",
                Location = new Point(15, 295),
                Size = new Size(800, 330),
                Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right
            };

            logBox = new RichTextBox
            {
                Location = new Point(10, 20),
                Size = new Size(780, 300),
                BackColor = Color.FromArgb(30, 30, 30),
                ForeColor = Color.FromArgb(0, 255, 0),
                Font = new Font("Consolas", 9F),
                ReadOnly = true,
                BorderStyle = BorderStyle.None,
                Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right
            };
            logGroup.Controls.Add(logBox);

            this.Controls.Add(logGroup);

            // Progress Bar
            progressBar = new ProgressBar
            {
                Location = new Point(15, 635),
                Size = new Size(800, 25),
                Style = ProgressBarStyle.Continuous,
                Anchor = AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right
            };
            this.Controls.Add(progressBar);

            // Status Label
            statusLabel = new Label
            {
                Text = "Ready - Connect your device and click 'Detect Device'",
                Location = new Point(15, 665),
                Size = new Size(800, 25),
                ForeColor = Color.FromArgb(127, 140, 141),
                Font = new Font("Segoe UI", 9F, FontStyle.Italic),
                Anchor = AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right
            };
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

        private async void MainForm_Load(object sender, EventArgs e)
        {
            Log("CAT S22 Root Tool v" + APP_VERSION + " (Self-Contained) started", LogLevel.Info);
            Log("Temporary path: " + tempPath, LogLevel.Debug);

            // Extract embedded resources
            await Task.Run(() => ExtractEmbeddedResources());

            Log("Ready! Connect your CAT S22 Flip and enable USB debugging.", LogLevel.Info);
        }

        private void ExtractEmbeddedResources()
        {
            try
            {
                // Write embedded PowerShell scripts
                WriteEmbeddedScript("CAT_S22_Root_Tool.ps1", EmbeddedScripts.RootToolScript);
                WriteEmbeddedScript("CAT_S22_Enhanced_Debloat.ps1", EmbeddedScripts.DebloatScript);

                // Create boot_images directory
                string bootImagesDir = Path.Combine(tempPath, "boot_images");
                if (!Directory.Exists(bootImagesDir))
                {
                    Directory.CreateDirectory(bootImagesDir);
                }

                // Note: Boot image and Magisk APK should be provided separately due to size
                // They will be copied from EXE directory if available

                string exeDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);

                // Copy boot image if exists
                string bootImgSource = Path.Combine(exeDir, "boot_images", "boot_v30.img");
                string bootImgDest = Path.Combine(bootImagesDir, "boot_v30.img");
                if (File.Exists(bootImgSource) && !File.Exists(bootImgDest))
                {
                    File.Copy(bootImgSource, bootImgDest);
                    Log("Copied boot_v30.img", LogLevel.Debug);
                }

                // Copy Magisk APK if exists
                string magiskSource = Path.Combine(exeDir, "Magisk-v25.2.apk");
                string magiskDest = Path.Combine(tempPath, "downloads", "Magisk.apk");
                if (File.Exists(magiskSource))
                {
                    string downloadsDir = Path.Combine(tempPath, "downloads");
                    if (!Directory.Exists(downloadsDir))
                    {
                        Directory.CreateDirectory(downloadsDir);
                    }
                    if (!File.Exists(magiskDest))
                    {
                        File.Copy(magiskSource, magiskDest);
                        Log("Copied Magisk APK", LogLevel.Debug);
                    }
                }

                Log("Resources extracted successfully", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log("Error extracting resources: " + ex.Message, LogLevel.Error);
            }
        }

        private void WriteEmbeddedScript(string filename, string content)
        {
            string scriptPath = Path.Combine(tempPath, filename);

            // Modify script to use temp path
            string modifiedContent = content.Replace(
                "$env:USERPROFILE\\CAT_S22_Root",
                tempPath.Replace("\\", "\\\\")
            );

            File.WriteAllText(scriptPath, modifiedContent, Encoding.UTF8);
            Log("Extracted: " + filename, LogLevel.Debug);
        }

        private async Task EnsurePlatformTools()
        {
            string platformToolsPath = Path.Combine(tempPath, "tools", "platform-tools");
            string adbPath = Path.Combine(platformToolsPath, "adb.exe");

            if (File.Exists(adbPath))
            {
                return;
            }

            // Create tools directory
            string toolsDir = Path.Combine(tempPath, "tools");
            if (!Directory.Exists(toolsDir))
            {
                Directory.CreateDirectory(toolsDir);
            }

            Log("Downloading Android Platform Tools...", LogLevel.Info);
            UpdateStatus("Downloading Android Platform Tools (one-time setup)...");
            progressBar.Style = ProgressBarStyle.Marquee;

            try
            {
                string zipPath = Path.Combine(tempPath, "platform-tools.zip");

                using (WebClient client = new WebClient())
                {
                    client.DownloadProgressChanged += (s, e) =>
                    {
                        this.Invoke((Action)(() =>
                        {
                            progressBar.Style = ProgressBarStyle.Continuous;
                            progressBar.Value = e.ProgressPercentage;
                            UpdateStatus($"Downloading Platform Tools: {e.ProgressPercentage}%");
                        }));
                    };

                    await client.DownloadFileTaskAsync(new Uri(PLATFORM_TOOLS_URL), zipPath);
                }

                Log("Extracting Platform Tools...", LogLevel.Info);
                UpdateStatus("Extracting Platform Tools...");

                ZipFile.ExtractToDirectory(zipPath, toolsDir);

                // Clean up zip file
                File.Delete(zipPath);

                Log("Platform Tools installed successfully!", LogLevel.Success);
                UpdateStatus("Platform Tools ready!");
                progressBar.Value = 100;
            }
            catch (Exception ex)
            {
                Log("Failed to download Platform Tools: " + ex.Message, LogLevel.Error);
                throw;
            }
            finally
            {
                progressBar.Style = ProgressBarStyle.Continuous;
            }
        }

        private async void DetectButton_Click(object sender, EventArgs e)
        {
            if (isRunning) return;

            isRunning = true;
            detectButton.Enabled = false;

            try
            {
                await EnsurePlatformTools();

                Log("Detecting device...", LogLevel.Info);
                UpdateStatus("Detecting device...");

                string adbPath = Path.Combine(tempPath, "tools", "platform-tools", "adb.exe");

                var result = await RunCommandAsync(adbPath, "devices");

                if (result.Contains("device") && !result.Contains("unauthorized"))
                {
                    deviceStatusLabel.Text = "Device: Connected";
                    deviceStatusLabel.ForeColor = Color.FromArgb(39, 174, 96);
                    Log("Device connected via ADB", LogLevel.Success);

                    // Try to get firmware version
                    var buildInfo = await RunCommandAsync(adbPath, "shell getprop ro.build.fingerprint");

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
                        firmwareStatusLabel.Text = "Warning: May not be CAT S22 Flip";
                        firmwareStatusLabel.ForeColor = Color.FromArgb(230, 126, 34);
                        Log("Warning: Device may not be a CAT S22 Flip", LogLevel.Warning);
                    }

                    UpdateStatus("Device detected! Ready to proceed.");
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
                }
                else
                {
                    deviceStatusLabel.Text = "Device: Not detected";
                    deviceStatusLabel.ForeColor = Color.FromArgb(192, 57, 43);
                    firmwareStatusLabel.Text = "Firmware: Unknown";
                    firmwareStatusLabel.ForeColor = Color.Gray;
                    Log("No device detected", LogLevel.Warning);
                    UpdateStatus("No device detected. Check USB connection and enable USB debugging.");
                }
            }
            catch (Exception ex)
            {
                Log("Error detecting device: " + ex.Message, LogLevel.Error);
                UpdateStatus("Error detecting device. Check logs for details.");
            }
            finally
            {
                isRunning = false;
                detectButton.Enabled = true;
            }
        }

        private async void RootButton_Click(object sender, EventArgs e)
        {
            if (isRunning)
            {
                if (MessageBox.Show("A process is already running. Cancel?",
                    "Cancel?", MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes)
                {
                    cancellationTokenSource?.Cancel();
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
                "Continue?",
                "Confirm Rooting",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning
            );

            if (confirmResult != DialogResult.Yes) return;

            await RunPowerShellScript("CAT_S22_Root_Tool.ps1");
        }

        private async void DebloatButton_Click(object sender, EventArgs e)
        {
            if (isRunning)
            {
                MessageBox.Show("Please wait for the current process to complete.",
                    "Process Running", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            var confirmResult = MessageBox.Show(
                "This will run the debloat tool.\n\n" +
                "Requirements:\n" +
                "- Device must already be rooted\n" +
                "- USB debugging must be enabled\n\n" +
                "This will:\n" +
                "- Remove T-Mobile/Google bloatware\n" +
                "- Offer to install alternative apps\n\n" +
                "Continue?",
                "Confirm Debloat",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question
            );

            if (confirmResult != DialogResult.Yes) return;

            await RunPowerShellScript("CAT_S22_Enhanced_Debloat.ps1");
        }

        private async Task RunPowerShellScript(string scriptName)
        {
            isRunning = true;
            rootButton.Enabled = false;
            debloatButton.Enabled = false;
            detectButton.Enabled = false;
            cancellationTokenSource = new CancellationTokenSource();

            try
            {
                await EnsurePlatformTools();

                string scriptPath = Path.Combine(tempPath, scriptName);

                if (!File.Exists(scriptPath))
                {
                    Log($"Script not found: {scriptName}", LogLevel.Error);
                    MessageBox.Show($"Script not found: {scriptName}",
                        "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }

                Log($"Starting {scriptName}...", LogLevel.Info);
                UpdateStatus($"Running {scriptName}...");
                progressBar.Style = ProgressBarStyle.Marquee;

                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{scriptPath}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = false,
                    WorkingDirectory = tempPath
                };

                using (Process process = new Process())
                {
                    process.StartInfo = psi;
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

                    process.Start();
                    process.BeginOutputReadLine();
                    process.BeginErrorReadLine();

                    await Task.Run(() =>
                    {
                        while (!process.HasExited)
                        {
                            if (cancellationTokenSource.Token.IsCancellationRequested)
                            {
                                process.Kill();
                                break;
                            }
                            Thread.Sleep(100);
                        }
                    });

                    if (process.ExitCode == 0)
                    {
                        Log($"{scriptName} completed successfully!", LogLevel.Success);
                        UpdateStatus("Process completed successfully!");
                    }
                    else
                    {
                        Log($"{scriptName} exited with code: {process.ExitCode}", LogLevel.Warning);
                        UpdateStatus("Process completed with warnings.");
                    }
                }
            }
            catch (Exception ex)
            {
                Log($"Error: {ex.Message}", LogLevel.Error);
                UpdateStatus("Error. Check log for details.");
            }
            finally
            {
                isRunning = false;
                rootButton.Enabled = true;
                debloatButton.Enabled = true;
                detectButton.Enabled = true;
                progressBar.Style = ProgressBarStyle.Continuous;
                progressBar.Value = 100;
                cancellationTokenSource?.Dispose();
                cancellationTokenSource = null;
            }
        }

        private async Task<string> RunCommandAsync(string command, string arguments)
        {
            StringBuilder output = new StringBuilder();

            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = command,
                Arguments = arguments,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using (Process process = new Process())
            {
                process.StartInfo = psi;
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

                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();

                await Task.Run(() => process.WaitForExit(10000));

                return output.ToString();
            }
        }

        private void OpenLogButton_Click(object sender, EventArgs e)
        {
            try
            {
                File.WriteAllText(logFilePath, logBox.Text);
                Process.Start("notepad.exe", logFilePath);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void GithubButton_Click(object sender, EventArgs e)
        {
            try
            {
                Process.Start(new ProcessStartInfo { FileName = GITHUB_URL, UseShellExecute = true });
            }
            catch
            {
                MessageBox.Show($"Please visit: {GITHUB_URL}", "GitHub", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }

        private void CleanupButton_Click(object sender, EventArgs e)
        {
            if (isRunning)
            {
                MessageBox.Show("Cannot cleanup while a process is running.",
                    "Process Running", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            var result = MessageBox.Show(
                "This will delete all temporary files including:\n" +
                "- Downloaded platform-tools\n" +
                "- Extracted scripts\n" +
                "- Logs\n\n" +
                "Continue?",
                "Cleanup",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question
            );

            if (result == DialogResult.Yes)
            {
                try
                {
                    if (Directory.Exists(tempPath))
                    {
                        Directory.Delete(tempPath, true);
                    }
                    Directory.CreateDirectory(tempPath);
                    logBox.Clear();
                    Log("Cleanup complete. Resources will be re-extracted on next action.", LogLevel.Success);
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Cleanup failed: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }

        private enum LogLevel { Debug, Info, Success, Warning, Error }

        private void Log(string message, LogLevel level)
        {
            if (this.InvokeRequired)
            {
                this.BeginInvoke((Action)(() => Log(message, level)));
                return;
            }

            Color color = level switch
            {
                LogLevel.Debug => Color.FromArgb(150, 150, 150),
                LogLevel.Success => Color.FromArgb(0, 255, 0),
                LogLevel.Warning => Color.FromArgb(255, 200, 0),
                LogLevel.Error => Color.FromArgb(255, 80, 80),
                _ => Color.FromArgb(0, 255, 0)
            };

            string timestamp = DateTime.Now.ToString("HH:mm:ss");
            string prefix = $"[{timestamp}] [{level}] ";

            logBox.SelectionStart = logBox.TextLength;
            logBox.SelectionColor = color;
            logBox.AppendText(prefix + message + Environment.NewLine);
            logBox.ScrollToCaret();

            try { File.AppendAllText(logFilePath, prefix + message + Environment.NewLine); } catch { }
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
                if (MessageBox.Show("A process is still running. Exit anyway?",
                    "Process Running", MessageBoxButtons.YesNo, MessageBoxIcon.Warning) == DialogResult.No)
                {
                    e.Cancel = true;
                    return;
                }
                cancellationTokenSource?.Cancel();
            }
            base.OnFormClosing(e);
        }
    }

    // Embedded script storage - populated by build script
    public static class EmbeddedScripts
    {
        // Placeholder - build script replaces this with actual content
        public const string RootToolScript = @"EMBEDDED_ROOT_SCRIPT_PLACEHOLDER";
        public const string DebloatScript = @"EMBEDDED_DEBLOAT_SCRIPT_PLACEHOLDER";
    }

    static class Program
    {
        [STAThread]
        static void Main()
        {
            if (!IsAdministrator())
            {
                try
                {
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = Assembly.GetExecutingAssembly().Location,
                        UseShellExecute = true,
                        Verb = "runas"
                    };
                    Process.Start(psi);
                    return;
                }
                catch
                {
                    MessageBox.Show(
                        "This application requires Administrator privileges.\n\nPlease run as Administrator.",
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
