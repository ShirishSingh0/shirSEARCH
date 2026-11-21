#!/usr/bin/env python3
"""
shirSEARCH for macOS (Python Edition) ⚡
Pure Stealth Whole-Screen AI Question Solver & Menu Bar HUD

Requirements:
    pip install rumps pynput requests
"""

import os
import sys
import time
import json
import base64
import re
import subprocess
import threading
import requests

try:
    import rumps
    from pynput import keyboard
except ImportError:
    print("[ERROR] Missing required libraries. Please run:")
    print("pip install rumps pynput requests")
    sys.exit(1)

APP_NAME = "shirSEARCH"
DEFAULT_MODEL = "gemini-2.5-flash-lite"
PROMPT = (
    "Analyze this screen capture immediately. Find the main multiple-choice or true/false question. "
    "Answer with ONLY a single line in this exact format: [ANSWER: X] Reasoning. "
    "Where X is A, B, C, or D (or True/False). Keep explanation strictly under 15 words. Be accurate and fast."
)

class ShirSearchMacApp(rumps.App):
    def __init__(self):
        super(ShirSearchMacApp, self).__init__("★ shirSEARCH", quit_button=None)
        self.api_key = self.load_api_key()
        self.is_processing = False
        self.last_trigger_time = 0

        # Build menu
        self.menu = [
            rumps.MenuItem("⚡ Scan Whole Screen (Cmd+Ctrl+Opt / F9)", callback=self.menu_trigger_scan),
            None,
            rumps.MenuItem("🔑 Set Gemini API Key...", callback=self.prompt_api_key),
            rumps.MenuItem("🔄 Reset Status", callback=self.reset_status),
            None,
            rumps.MenuItem("Quit shirSEARCH", callback=self.quit_app)
        ]

        # Start background hotkey listener
        self.start_hotkey_listener()

    def get_key_file_paths(self):
        local_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "apikey.txt")
        user_path = os.path.expanduser("~/.shirsearch/apikey.txt")
        return local_path, user_path

    def load_api_key(self):
        local_path, user_path = self.get_key_file_paths()
        for path in (local_path, user_path):
            if os.path.isfile(path):
                try:
                    with open(path, "r", encoding="utf-8") as f:
                        k = f.read().strip()
                        if k:
                            return k
                except Exception:
                    pass
        return ""

    def save_api_key(self, key):
        self.api_key = key
        local_path, user_path = self.get_key_file_paths()
        os.makedirs(os.path.dirname(user_path), exist_ok=True)
        try:
            with open(user_path, "w", encoding="utf-8") as f:
                f.write(key)
        except Exception:
            pass
        try:
            with open(local_path, "w", encoding="utf-8") as f:
                f.write(key)
        except Exception:
            pass

    def prompt_api_key(self, _):
        resp = rumps.Window(
            message="Enter your Google Gemini API Key (starts with AIzaSy...):",
            title="shirSEARCH - Set Gemini API Key",
            default_text=self.api_key,
            ok="Save Key",
            cancel="Cancel",
            dimensions=(360, 24)
        ).run()
        if resp.clicked:
            new_key = resp.text.strip()
            if new_key:
                self.save_api_key(new_key)
                self.title = "★ [Key Saved]"

    def reset_status(self, _):
        self.title = "★ shirSEARCH"

    def quit_app(self, _):
        rumps.quit_application()

    def menu_trigger_scan(self, _):
        threading.Thread(target=self.trigger_scan_and_solve, daemon=True).start()

    def start_hotkey_listener(self):
        def for_canonical(f):
            return lambda k: f(listener.canonical(k))

        current_keys = set()

        def on_press(key):
            try:
                # Direct F9 single-key trigger
                if key == keyboard.Key.f9:
                    self.on_hotkey_triggered("F9")
                    return

                current_keys.add(key)

                # Check Cmd + Ctrl + Opt
                has_cmd = (keyboard.Key.cmd in current_keys or keyboard.Key.cmd_l in current_keys or keyboard.Key.cmd_r in current_keys)
                has_ctrl = (keyboard.Key.ctrl in current_keys or keyboard.Key.ctrl_l in current_keys or keyboard.Key.ctrl_r in current_keys)
                has_alt = (keyboard.Key.alt in current_keys or keyboard.Key.alt_l in current_keys or keyboard.Key.alt_r in current_keys)

                if has_cmd and has_ctrl and has_alt:
                    self.on_hotkey_triggered("Cmd+Ctrl+Opt")

            except Exception:
                pass

        def on_release(key):
            try:
                current_keys.discard(key)
            except Exception:
                pass

        listener = keyboard.Listener(on_press=on_press, on_release=on_release)
        listener.daemon = True
        listener.start()

    def on_hotkey_triggered(self, hotkey_name):
        now = time.time()
        if now - self.last_trigger_time > 1.5 and not self.is_processing:
            self.last_trigger_time = now
            threading.Thread(target=self.trigger_scan_and_solve, daemon=True).start()

    def trigger_scan_and_solve(self):
        if self.is_processing:
            return

        if not self.api_key:
            self.title = "⚠️ [Set API Key]"
            return

        self.is_processing = True
        self.title = "⚡ Scanning..."

        temp_img = "/tmp/shirsearch_capture.jpg"
        try:
            if os.path.exists(temp_img):
                os.remove(temp_img)

            # Native macOS silent high-res capture
            subprocess.run(["/usr/sbin/screencapture", "-x", "-C", "-t", "jpg", temp_img], check=True)

            with open(temp_img, "rb") as f:
                b64_data = base64.b64encode(f.read()).decode("utf-8")

            if os.path.exists(temp_img):
                os.remove(temp_img)

            url = f"https://generativelanguage.googleapis.com/v1beta/models/{DEFAULT_MODEL}:generateContent?key={self.api_key}"
            payload = {
                "contents": [
                    {
                        "parts": [
                            {"text": PROMPT},
                            {"inline_data": {"mime_type": "image/jpeg", "data": b64_data}}
                        ]
                    }
                ],
                "generationConfig": {"temperature": 0.1, "maxOutputTokens": 60}
            }

            resp = requests.post(url, json=payload, timeout=15)
            if resp.status_code != 200:
                self.title = f"❌ [API Error {resp.status_code}]"
                return

            data = resp.json()
            answer_text = data["candidates"][0]["content"]["parts"][0]["text"].strip()

            # Parse answer
            match = re.search(r"\[ANSWER:\s*([A-Za-z0-9]+)\]", answer_text, re.IGNORECASE)
            letter = match.group(1).upper() if match else "?"
            clean_reason = re.sub(r"\[ANSWER:\s*([A-Za-z0-9]+)\]", "", answer_text, flags=re.IGNORECASE).strip()

            badges = {"A": "🟢 A", "B": "🔵 B", "C": "🟣 C", "D": "🟠 D"}
            badge = badges.get(letter, f"★ [{letter}]")

            summary = clean_reason.replace("\n", " ")[:30]
            self.title = f"{badge}  {summary}"

        except Exception as ex:
            self.title = "❌ [Error]"
        finally:
            self.is_processing = False

if __name__ == "__main__":
    app = ShirSearchMacApp()
    app.run()
