# shirSEARCH ⚡

> **Pure Stealth Whole-Page Question Solver & HUD** powered by Google Gemini 2.5 Flash Vision.  
> Available for **Windows** (Taskbar HUD) and **macOS** (Menu Bar HUD).

`shirSEARCH` is a lightweight, zero-dependency stealth problem-solving HUD. When triggered via global shortcut, it silently captures your entire display in high resolution, feeds the page into Gemini Vision to solve multiple-choice questions, and updates the correct option (**A**, **B**, **C**, or **D**) directly onto your **Windows Taskbar** or **macOS Menu Bar** without popping up any disruptive windows on your screen.

---

## 🔑 Custom API Key Support

Anyone using `shirSEARCH` can easily add or change their own Google Gemini API key:

### Method 1: GUI Menu
- **Windows**: Right-click the `shirSEARCH` icon in your Windows System Tray $\rightarrow$ **"🔑 Set Gemini API Key..."**.
- **macOS**: Click the `★ shirSEARCH` item in the top Menu Bar $\rightarrow$ **"🔑 Set Gemini API Key..."**.
- Paste your Gemini API key (starts with `AIzaSy...`) and click **Save Key**. It will be saved permanently.

### Method 2: Config File (`apikey.txt`)
Create a text file named `apikey.txt` in the same directory as the executable (or `~/.shirsearch/apikey.txt` on macOS) and paste your key inside.

> *Get a free Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey).*

---

## 🌟 Key Features

- **100% Stealth Mode (No Popups)**:
  - When you hit the shortcut, **no window appears on your screen**.
  - Operates completely in the background without stealing focus or interrupting your work.
- **Whole-Page Scanner**:
  - Full-resolution desktop capture (Retina / 4K / High-DPI aware).
- **AI-Powered Question Solving**:
  - Direct integration with Google Gemini Vision (`gemini-2.5-flash-lite`).
  - Automatically identifies questions, evaluates all options, and selects the correct choice.
- **HUD Integration**:
  - **Windows**: Displays on the Taskbar title and paints dynamic circular badge icons (**A**, **B**, **C**, **D**) onto the taskbar button and system tray.
  - **macOS**: Updates the top Menu Bar in real time with color emoji badges (`🟢 A`, `🔵 B`, `🟣 C`, `🟠 D`) and concise reasoning.
- **Anti-Screen-Recording Evasion (Windows)**:
  - Enforces `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)` to exclude the window from screen recorders (OBS, Zoom, Discord, Teams).
- **Zero Heavy Dependencies**:
  - Windows: Built natively with C# / .NET (~19 KB).
  - macOS: Built natively in Swift with Cocoa / AppKit (no external package manager needed).

---

## ⌨️ Shortcuts & Controls

| Platform | Shortcut | Description |
|---|---|---|
| **Windows** | <kbd>Ctrl</kbd> + <kbd>Win</kbd> + <kbd>Alt</kbd> | **Primary Global Trigger**: Silently captures screen & solves question |
| **Windows** | <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>S</kbd> | **Backup Hotkey** |
| **Windows** | <kbd>F9</kbd> | **Single-Key Fast Trigger** |
| **macOS** | <kbd>Cmd</kbd> + <kbd>Ctrl</kbd> + <kbd>Opt</kbd> | **Primary Global Trigger** on Mac |
| **macOS** | <kbd>Cmd</kbd> + <kbd>Opt</kbd> + <kbd>S</kbd> | **Backup Hotkey** |
| **macOS** | <kbd>F9</kbd> | **Single-Key Fast Trigger** |

---

## 🍎 macOS Quick Start

### Option 1: Native Swift Application (Recommended)
You can compile the native macOS Menu Bar app directly on any Mac with Xcode Command Line Tools installed:

```bash
# 1. Clone the repository
git clone https://github.com/ShirishSingh0/shirSEARCH.git
cd shirSEARCH

# 2. Run the build script
chmod +x build_mac.sh
./build_mac.sh

# 3. Launch the app
open shirSEARCH.app
```
*(Or compile directly with: `swiftc -O shirSEARCH.swift -o shirSEARCH -framework Cocoa -framework CoreGraphics`)*

### Option 2: Python Edition
If you prefer running via Python 3:

```bash
pip install rumps pynput requests
python3 shirSEARCH_mac.py
```

> **Note for macOS Users**: On first launch, macOS will prompt you to grant **Screen Recording** permission in *System Settings $\rightarrow$ Privacy & Security $\rightarrow$ Screen Recording* so the app can silently capture display questions.

---

## 🪟 Windows Quick Start

### Running Pre-compiled Executable
Double-click `shirSEARCH.exe`. It runs silently in the background and sits ready in your Windows System Tray and Taskbar.

### Compiling from Source
```cmd
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /target:winexe /optimize+ /platform:anycpu /out:shirSEARCH.exe shirSEARCH.cs
```
Or simply run `build.bat`.

---

## 📄 License
MIT License.

---

## 📄 License
MIT License.
