using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Media;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

namespace shirSEARCH
{
    public class Program
    {
        [STAThread]
        public static void Main(string[] args)
        {
            try
            {
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new MainWindow());
            }
            catch (Exception ex)
            {
                try
                {
                    File.AppendAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "shirSEARCH.log"), "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "] Crash: " + ex.ToString() + Environment.NewLine);
                }
                catch { }
            }
        }
    }

    public class MainWindow : Form
    {
        // --- Windows API P/Invokes ---
        [DllImport("user32.dll")]
        public static extern short GetAsyncKeyState(int vKey);

        [DllImport("user32.dll")]
        public static extern IntPtr GetDesktopWindow();

        [DllImport("user32.dll")]
        public static extern IntPtr GetDC(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

        [DllImport("gdi32.dll")]
        public static extern IntPtr CreateCompatibleDC(IntPtr hdc);

        [DllImport("gdi32.dll")]
        public static extern IntPtr CreateCompatibleBitmap(IntPtr hdc, int nWidth, int nHeight);

        [DllImport("gdi32.dll")]
        public static extern IntPtr SelectObject(IntPtr hdc, IntPtr hgdiobj);

        [DllImport("gdi32.dll")]
        public static extern bool DeleteDC(IntPtr hdc);

        [DllImport("gdi32.dll")]
        public static extern bool DeleteObject(IntPtr hObject);

        [DllImport("gdi32.dll")]
        public static extern bool BitBlt(IntPtr hObject, int nXDest, int nYDest, int nWidth, int nHeight, IntPtr hObjectSource, int nXSrc, int nYSrc, int dwRop);

        [DllImport("user32.dll")]
        public static extern bool SetProcessDPIAware();

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetWindowDisplayAffinity(IntPtr hWnd, uint dwAffinity);

        // --- Constants ---
        private const int SRCCOPY = 0x00CC0020;
        private const int CAPTUREBLT = 0x40000000;
        private const uint WDA_EXCLUDEFROMCAPTURE = 0x00000011; // Stealth recording exclusion

        // Configuration
        private const string DEFAULT_GEMINI_API_KEY = "";
        private const string GEMINI_MODEL = "gemini-2.5-flash-lite";
        private string currentApiKey;

        // Global Key Polling Thread
        private Thread pollerThread;
        private volatile bool isPollerRunning = true;
        private long lastTriggerTicks = 0;
        private bool isProcessing = false;

        // UI / Tray
        private NotifyIcon trayIcon;

        public MainWindow()
        {
            SetProcessDPIAware();
            LoadApiKey();
            InitializeStealthTaskbarForm();
            SetupTray();
            StartGlobalKeyPoller();
            LogToFile("shirSEARCH started in Stealth Taskbar Mode. Ready for triggers.");
        }

        private string GetConfigFilePath()
        {
            return Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "apikey.txt");
        }

        private void LoadApiKey()
        {
            try
            {
                string path = GetConfigFilePath();
                if (File.Exists(path))
                {
                    string saved = File.ReadAllText(path).Trim();
                    if (!string.IsNullOrEmpty(saved))
                    {
                        currentApiKey = saved;
                        LogToFile("Loaded custom API key from apikey.txt");
                        return;
                    }
                }
            }
            catch {}
            currentApiKey = DEFAULT_GEMINI_API_KEY;
        }

        private void SaveApiKey(string key)
        {
            try
            {
                currentApiKey = key;
                File.WriteAllText(GetConfigFilePath(), key);
                LogToFile("Saved new API key to apikey.txt");
            }
            catch (Exception ex)
            {
                LogToFile("Failed to save API key: " + ex.Message);
            }
        }

        private void ShowApiKeyDialog()
        {
            using (Form prompt = new Form())
            {
                prompt.Width = 480;
                prompt.Height = 200;
                prompt.FormBorderStyle = FormBorderStyle.FixedDialog;
                prompt.Text = "shirSEARCH - Set Gemini API Key";
                prompt.StartPosition = FormStartPosition.CenterScreen;
                prompt.BackColor = Color.FromArgb(11, 19, 43);
                prompt.ForeColor = Color.White;
                prompt.MaximizeBox = false;
                prompt.MinimizeBox = false;

                Label textLabel = new Label()
                {
                    Left = 20,
                    Top = 18,
                    Width = 420,
                    Text = "Enter your Google Gemini API Key (starts with AIzaSy...):",
                    ForeColor = Color.FromArgb(45, 212, 191),
                    Font = new Font("Segoe UI", 9.5f, FontStyle.Bold)
                };

                TextBox textBox = new TextBox()
                {
                    Left = 20,
                    Top = 50,
                    Width = 420,
                    Text = currentApiKey,
                    BackColor = Color.FromArgb(23, 37, 84),
                    ForeColor = Color.White,
                    BorderStyle = BorderStyle.FixedSingle,
                    Font = new Font("Segoe UI", 10f)
                };

                Button saveBtn = new Button()
                {
                    Text = "Save Key",
                    Left = 240,
                    Width = 95,
                    Top = 96,
                    DialogResult = DialogResult.OK,
                    BackColor = Color.FromArgb(16, 185, 129),
                    ForeColor = Color.White,
                    FlatStyle = FlatStyle.Flat,
                    Font = new Font("Segoe UI", 9f, FontStyle.Bold),
                    Cursor = Cursors.Hand
                };
                saveBtn.FlatAppearance.BorderSize = 0;

                Button cancelBtn = new Button()
                {
                    Text = "Cancel",
                    Left = 345,
                    Width = 95,
                    Top = 96,
                    DialogResult = DialogResult.Cancel,
                    BackColor = Color.FromArgb(31, 41, 55),
                    ForeColor = Color.White,
                    FlatStyle = FlatStyle.Flat,
                    Font = new Font("Segoe UI", 9f),
                    Cursor = Cursors.Hand
                };
                cancelBtn.FlatAppearance.BorderSize = 0;

                saveBtn.Click += delegate { prompt.Close(); };
                cancelBtn.Click += delegate { prompt.Close(); };

                prompt.Controls.Add(textLabel);
                prompt.Controls.Add(textBox);
                prompt.Controls.Add(saveBtn);
                prompt.Controls.Add(cancelBtn);
                prompt.AcceptButton = saveBtn;
                prompt.CancelButton = cancelBtn;

                if (prompt.ShowDialog() == DialogResult.OK)
                {
                    string newKey = textBox.Text.Trim();
                    if (!string.IsNullOrEmpty(newKey))
                    {
                        SaveApiKey(newKey);
                        if (trayIcon != null)
                        {
                            trayIcon.BalloonTipTitle = "shirSEARCH";
                            trayIcon.BalloonTipText = "API Key saved successfully!";
                            trayIcon.ShowBalloonTip(3000);
                        }
                    }
                }
            }
        }

        private void InitializeStealthTaskbarForm()
        {
            // Show in taskbar, but keep window surface invisible off-screen
            this.ShowInTaskbar = true;
            this.FormBorderStyle = FormBorderStyle.FixedToolWindow;
            this.StartPosition = FormStartPosition.Manual;
            this.Location = new Point(-32000, -32000); // Placed completely off-screen
            this.Size = new Size(100, 100);
            this.Opacity = 0.0; // Completely transparent
            this.Text = "★ shirSEARCH [Ready: Ctrl+Win+Alt]";

            // Anti-recording stealth flag
            SetWindowDisplayAffinity(this.Handle, WDA_EXCLUDEFROMCAPTURE);

            UpdateBadgeIcon("?");
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            isPollerRunning = false;
            if (pollerThread != null && pollerThread.IsAlive)
            {
                pollerThread.Abort();
            }

            if (trayIcon != null)
            {
                trayIcon.Visible = false;
                trayIcon.Dispose();
            }
            base.OnFormClosing(e);
        }

        // --- Background Key Poller: Detects Ctrl + Win + Alt (and Ctrl+Alt+S / F9) Globally ---
        private void StartGlobalKeyPoller()
        {
            pollerThread = new Thread(new ThreadStart(KeyPollerLoop));
            pollerThread.IsBackground = true;
            pollerThread.Priority = ThreadPriority.AboveNormal;
            pollerThread.Start();
        }

        private void KeyPollerLoop()
        {
            while (isPollerRunning)
            {
                try
                {
                    bool ctrl = (GetAsyncKeyState(0x11) & 0x8000) != 0; // VK_CONTROL
                    bool alt  = (GetAsyncKeyState(0x12) & 0x8000) != 0; // VK_MENU (Alt)
                    bool lwin = (GetAsyncKeyState(0x5B) & 0x8000) != 0; // VK_LWIN
                    bool rwin = (GetAsyncKeyState(0x5C) & 0x8000) != 0; // VK_RWIN
                    bool win  = lwin || rwin;

                    bool sKey = (GetAsyncKeyState(0x53) & 0x8000) != 0; // S key
                    bool f9   = (GetAsyncKeyState(0x78) & 0x8000) != 0; // F9 key

                    // Trigger 1: Ctrl + Win + Alt
                    bool triggerCombo1 = ctrl && alt && win;
                    // Trigger 2: Ctrl + Alt + S
                    bool triggerCombo2 = ctrl && alt && sKey;
                    // Trigger 3: F9
                    bool triggerCombo3 = f9;

                    if (triggerCombo1 || triggerCombo2 || triggerCombo3)
                    {
                        long now = DateTime.UtcNow.Ticks;
                        // Debounce 1.5 seconds
                        if (now - lastTriggerTicks > 15000000 && !isProcessing)
                        {
                            lastTriggerTicks = now;
                            string trigType = triggerCombo1 ? "Ctrl+Win+Alt" : (triggerCombo2 ? "Ctrl+Alt+S" : "F9");
                            LogToFile("Triggered via " + trigType);
                            this.BeginInvoke(new Action(TriggerScanAndSolveSilently));
                        }
                    }
                }
                catch {}

                Thread.Sleep(25); // Check 40 times per second
            }
        }

        // --- Whole-Screen Capture Using GDI BitBlt & CAPTUREBLT ---
        private Bitmap CaptureWholeScreen()
        {
            Rectangle bounds = Screen.PrimaryScreen.Bounds;
            int w = bounds.Width;
            int h = bounds.Height;

            IntPtr hDesk = GetDesktopWindow();
            IntPtr hdcSrc = GetDC(hDesk);
            IntPtr hdcDest = CreateCompatibleDC(hdcSrc);
            IntPtr hBmp = CreateCompatibleBitmap(hdcSrc, w, h);
            IntPtr hOld = SelectObject(hdcDest, hBmp);

            BitBlt(hdcDest, 0, 0, w, h, hdcSrc, bounds.X, bounds.Y, SRCCOPY | CAPTUREBLT);

            Bitmap capturedImage = Image.FromHbitmap(hBmp);

            SelectObject(hdcDest, hOld);
            DeleteObject(hBmp);
            DeleteDC(hdcDest);
            ReleaseDC(hDesk, hdcSrc);

            return capturedImage;
        }

        // --- Silent Whole-Page Screen Scan & Gemini Solver Flow ---
        public void TriggerScanAndSolveSilently()
        {
            if (isProcessing) return;
            isProcessing = true;

            try
            {
                SystemSounds.Asterisk.Play();
            }
            catch {}

            // Update Taskbar title immediately to indicate scanning
            this.Text = "◌ [SCANNING PAGE WITH GEMINI...]";
            UpdateBadgeIcon("…");

            if (trayIcon != null)
            {
                trayIcon.Text = "shirSEARCH: Scanning whole page...";
            }

            LogToFile("Starting whole-page scan in background (pure stealth)...");

            // Dispatch background thread for Gemini Vision
            ThreadPool.QueueUserWorkItem(delegate
            {
                try
                {
                    // 1. Capture whole screen silently
                    Bitmap screenBmp = CaptureWholeScreen();
                    byte[] imageBytes;
                    using (MemoryStream ms = new MemoryStream())
                    {
                        screenBmp.Save(ms, ImageFormat.Jpeg);
                        imageBytes = ms.ToArray();
                    }
                    screenBmp.Dispose();

                    LogToFile("Full screen captured: " + imageBytes.Length + " bytes. Querying Gemini...");

                    string base64Image = Convert.ToBase64String(imageBytes);

                    // 2. Call Gemini Vision API
                    string geminiResult = CallGeminiVision(base64Image);
                    LogToFile("Gemini response: " + geminiResult.Substring(0, Math.Min(120, geminiResult.Length)));

                    this.BeginInvoke(new Action<string>(ProcessGeminiResultSilently), geminiResult);
                }
                catch (Exception ex)
                {
                    LogToFile("Error during scan/solve: " + ex.ToString());
                    this.BeginInvoke(new Action(delegate
                    {
                        isProcessing = false;
                        this.Text = "✖ [ERROR] Check shirSEARCH.log";
                        UpdateBadgeIcon("X");
                        if (trayIcon != null)
                        {
                            trayIcon.Text = "shirSEARCH Error. Right-click tray to set API key.";
                        }
                    }));
                }
            });
        }

        private string CallGeminiVision(string base64Image)
        {
            ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072 | SecurityProtocolType.Tls12;
            string keyToUse = string.IsNullOrEmpty(currentApiKey) ? DEFAULT_GEMINI_API_KEY : currentApiKey;
            string url = "https://generativelanguage.googleapis.com/v1beta/models/" + GEMINI_MODEL + ":generateContent?key=" + keyToUse;

            HttpWebRequest req = (HttpWebRequest)WebRequest.Create(url);
            req.Method = "POST";
            req.ContentType = "application/json";
            req.Timeout = 30000;

            string promptText = "You are an automated expert question and exam solver.\n" +
                               "Look at this screenshot of the computer screen.\n" +
                               "1. Scan the whole page to find any question or test problem.\n" +
                               "2. Read the question and all options (A, B, C, D or 1, 2, 3, 4, 5).\n" +
                               "3. Solve it and choose the correct option.\n" +
                               "4. Your VERY FIRST LINE must be EXACTLY:\n" +
                               "ANSWER: [Letter]\n" +
                               "For example: ANSWER: A or ANSWER: B or ANSWER: C or ANSWER: D\n" +
                               "5. On the next lines, output:\n" +
                               "QUESTION: [Question text found]\n" +
                               "REASON: [1-2 sentences explaining why this option is correct].";

            string jsonBody = "{\"contents\":[{\"parts\":[" +
                              "{\"text\":\"" + EscapeJson(promptText) + "\"}," +
                              "{\"inline_data\":{\"mime_type\":\"image/jpeg\",\"data\":\"" + base64Image + "\"}}" +
                              "]}]}";

            byte[] bodyBytes = Encoding.UTF8.GetBytes(jsonBody);
            req.ContentLength = bodyBytes.Length;

            using (Stream os = req.GetRequestStream())
            {
                os.Write(bodyBytes, 0, bodyBytes.Length);
            }

            try
            {
                using (HttpWebResponse resp = (HttpWebResponse)req.GetResponse())
                using (StreamReader sr = new StreamReader(resp.GetResponseStream(), Encoding.UTF8))
                {
                    string jsonResp = sr.ReadToEnd();

                    Match m = Regex.Match(jsonResp, "\"text\":\\s*\"(.*?)\"(,\\s*\"|\\]|\\})", RegexOptions.Singleline);
                    if (m.Success)
                    {
                        return UnescapeJson(m.Groups[1].Value);
                    }
                    return jsonResp;
                }
            }
            catch (WebException webEx)
            {
                string errDetails = "";
                if (webEx.Response != null)
                {
                    using (Stream s = webEx.Response.GetResponseStream())
                    using (StreamReader sr = new StreamReader(s))
                    {
                        errDetails = sr.ReadToEnd();
                    }
                }
                throw new Exception("Gemini WebException: " + (string.IsNullOrEmpty(errDetails) ? webEx.Message : errDetails));
            }
        }

        private void ProcessGeminiResultSilently(string rawText)
        {
            isProcessing = false;
            string letter = "A";
            string explanation = rawText;

            // Extract letter A, B, C, or D
            Match letterMatch = Regex.Match(rawText, @"ANSWER:\s*\[?([A-Da-d1-5])\]?", RegexOptions.IgnoreCase);
            if (letterMatch.Success)
            {
                string val = letterMatch.Groups[1].Value.ToUpper();
                if (val == "1") letter = "A";
                else if (val == "2") letter = "B";
                else if (val == "3") letter = "C";
                else if (val == "4") letter = "D";
                else letter = val;
            }
            else
            {
                Match fallback = Regex.Match(rawText, @"\b([A-D])\b");
                if (fallback.Success)
                {
                    letter = fallback.Groups[1].Value.ToUpper();
                }
            }

            explanation = Regex.Replace(rawText, @"^ANSWER:\s*.*?\n", "", RegexOptions.IgnoreCase).Trim();

            // Clean 1-line reason for taskbar
            string cleanReason = explanation.Replace("\r", " ").Replace("\n", " ").Trim();
            if (cleanReason.Length > 45) cleanReason = cleanReason.Substring(0, 42) + "...";

            // 1. UPDATE WINDOWS TASKBAR TITLE (Shows up directly on taskbar button!)
            this.Text = "★ [ANSWER: " + letter + "]  " + cleanReason;

            // 2. UPDATE TASKBAR & TRAY BADGE ICON
            UpdateBadgeIcon(letter);

            // 3. Update Tray Tooltip
            if (trayIcon != null)
            {
                trayIcon.Text = "shirSEARCH: [" + letter + "] - " + cleanReason;
                trayIcon.BalloonTipTitle = "shirSEARCH: Answer " + letter;
                trayIcon.BalloonTipText = explanation.Length > 90 ? explanation.Substring(0, 87) + "..." : explanation;
                trayIcon.ShowBalloonTip(3000);
            }

            try
            {
                SystemSounds.Exclamation.Play();
            }
            catch {}

            LogToFile("Solution successfully updated on Taskbar: " + letter);
        }

        private Color GetColorForLetter(string letter)
        {
            switch (letter.ToUpper())
            {
                case "A": return Color.FromArgb(16, 185, 129); // Emerald Green
                case "B": return Color.FromArgb(14, 165, 233); // Sky Blue
                case "C": return Color.FromArgb(168, 85, 247); // Purple
                case "D": return Color.FromArgb(249, 115, 22); // Orange
                default: return Color.FromArgb(45, 212, 191);
            }
        }

        private void UpdateBadgeIcon(string letter)
        {
            try
            {
                using (Bitmap bmp = new Bitmap(32, 32))
                {
                    using (Graphics g = Graphics.FromImage(bmp))
                    {
                        g.SmoothingMode = SmoothingMode.AntiAlias;
                        g.Clear(Color.Transparent);

                        Color bg = GetColorForLetter(letter);
                        using (Brush b = new SolidBrush(bg))
                        {
                            g.FillEllipse(b, 1, 1, 30, 30);
                        }

                        using (Pen p = new Pen(Color.White, 1.5f))
                        {
                            g.DrawEllipse(p, 2, 2, 28, 28);
                        }

                        using (Brush tb = new SolidBrush(Color.White))
                        {
                            using (Font f = new Font("Arial", 16f, FontStyle.Bold, GraphicsUnit.Pixel))
                            {
                                StringFormat sf = new StringFormat();
                                sf.Alignment = StringAlignment.Center;
                                sf.LineAlignment = StringAlignment.Center;
                                g.DrawString(letter, f, tb, new RectangleF(0, 0, 32, 32), sf);
                            }
                        }
                    }

                    Icon icon = Icon.FromHandle(bmp.GetHicon());
                    this.Icon = icon;
                    if (trayIcon != null)
                    {
                        trayIcon.Icon = icon;
                    }
                }
            }
            catch {}
        }

        private void LogToFile(string msg)
        {
            try
            {
                string logPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "shirSEARCH.log");
                File.AppendAllText(logPath, "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "] " + msg + Environment.NewLine);
            }
            catch {}
        }

        private static string EscapeJson(string s)
        {
            if (string.IsNullOrEmpty(s)) return "";
            return s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "").Replace("\n", "\\n");
        }

        private static string UnescapeJson(string s)
        {
            if (string.IsNullOrEmpty(s)) return "";
            return s.Replace("\\n", "\n").Replace("\\r", "").Replace("\\\"", "\"").Replace("\\\\", "\\");
        }

        private void SetupTray()
        {
            try
            {
                trayIcon = new NotifyIcon();
                trayIcon.Icon = this.Icon ?? SystemIcons.Application;
                trayIcon.Text = "shirSEARCH (Ctrl+Win+Alt)";
                trayIcon.Visible = true;

                ContextMenu menu = new ContextMenu();
                menu.MenuItems.Add("Scan Whole Page (Ctrl+Win+Alt / F9)", delegate { TriggerScanAndSolveSilently(); });
                menu.MenuItems.Add("-");
                menu.MenuItems.Add("🔑 Set Gemini API Key...", delegate { ShowApiKeyDialog(); });
                menu.MenuItems.Add("-");
                menu.MenuItems.Add("Exit", delegate { Application.Exit(); });
                trayIcon.ContextMenu = menu;

                trayIcon.DoubleClick += delegate { TriggerScanAndSolveSilently(); };
            }
            catch (Exception ex)
            {
                LogToFile("Error in SetupTray: " + ex.Message);
            }
        }
    }
}
