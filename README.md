# shirSEARCH ⚡

> **Pure Stealth Whole-Page Question Solver & HUD** powered by Google Gemini 2.5 Flash Vision.

`shirSEARCH` is a lightweight, zero-dependency Windows desktop tool designed for instant, stealth problem-solving. When triggered via global shortcut, it silently captures your entire display in high resolution, feeds the page into Gemini Vision to solve multiple-choice questions, and updates the correct option (**A**, **B**, **C**, or **D**) directly onto your **Windows Taskbar** without popping up any disruptive windows on your screen.

---

## 🔑 Custom API Key Support

Anyone using `shirSEARCH` can easily add or change their own Google Gemini API key:

### Method 1: Right-Click System Tray (GUI)
1. Run `shirSEARCH.exe`.
2. Right-click the `shirSEARCH` icon in your Windows System Tray (near the clock).
3. Select **"🔑 Set Gemini API Key..."**.
4. Paste your Gemini API key (starts with `AIzaSy...`) and click **Save Key**. It will be saved permanently to `apikey.txt`.

### Method 2: Config File (`apikey.txt`)
Simply create a text file named `apikey.txt` in the same directory as `shirSEARCH.exe` and paste your key inside.

> *Get a free Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey).*

---

## 🌟 Key Features

- **100% Stealth Mode (No Popups)**:
  - When you hit the shortcut, **no window appears on your screen**.
  - Operates completely in the background without stealing focus or interrupting your work.
- **Whole-Page Scanner**:
  - DPI-aware full-resolution desktop capture (`2560x1600`+) using GDI BitBlt with `CAPTUREBLT` support for modern Windows DWM layered displays.
- **AI-Powered Question Solving**:
  - Direct integration with Google Gemini Vision (`gemini-2.5-flash-lite`).
  - Automatically identifies questions, evaluates all options, and selects the correct choice.
- **Taskbar & Tray Integration**:
  - **Taskbar Title**: Shows `★ [ANSWER: A]  Explanation...` (or B, C, D).
  - **Taskbar Button Badge Icon**: Dynamically paints a bold circular badge with the letter **A** (Emerald Green), **B** (Sky Blue), **C** (Purple), or **D** (Orange) directly onto your Windows Taskbar and System Tray.
  - **Tray Tooltip**: Hovering over the system tray icon displays the solved option and 1-line reasoning.
- **Anti-Screen-Recording Evasion**:
  - Enforces Windows API `SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE = 0x00000011)` so the app surface is completely excluded from screen recordings (OBS, Zoom, Discord, Teams, and browser proctoring tools).
- **Zero Dependencies**:
  - Built natively with Windows C# / .NET with ~19 KB binary footprint.

---

## ⌨️ Shortcuts & Controls

| Shortcut | Description |
|---|---|
| <kbd>Ctrl</kbd> + <kbd>Win</kbd> + <kbd>Alt</kbd> | **Primary Global Trigger**: Silently captures screen & solves question |
| <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>S</kbd> | **Backup Hotkey** |
| <kbd>F9</kbd> | **Single-Key Fast Trigger** |
| Double-click Tray Icon | Trigger manual scan |
| Right-click Tray Icon | **Set Gemini API Key**, manual scan, or exit |

---

## 🚀 Quick Start

### Running the Pre-compiled App
Double-click `shirSEARCH.exe`. It will start in the background and reside silently in your taskbar and system tray.

### Compiling from Source
You can compile `shirSEARCH` on any Windows 10/11 system using the built-in C# compiler without installing Visual Studio:

```cmd
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /target:winexe /optimize+ /platform:anycpu /out:shirSEARCH.exe shirSEARCH.cs
```
Or simply run `build.bat`.

---

## 📄 License
MIT License.
