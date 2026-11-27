"""Offline per-user setup wizard, also used as the installed uninstaller."""

from __future__ import annotations

import argparse
import ctypes
import json
import os
from pathlib import Path
import queue
import shutil
import subprocess
import sys
import tempfile
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from modkit import __version__
from modkit.install import install_game, uninstall_game
from modkit.patcher import APP_NAME, InstallError


TEXT = {
    "en": {
        "title": "Setup — OrionMultiplayerEnhanced",
        "welcome": "Install OrionMultiplayerEnhanced",
        "intro": "Modified edition of Orion Sandbox Enhanced",
        "notice": "Includes our changes to worlds, characters, maps, interface, and multiplayer. Setup installs the modified edition in a separate folder and creates a launch shortcut.",
        "before": "Before you begin",
        "included": "The complete working modified edition is included in setup.",
        "saves": "Back up your game saves before playing this preview.",
        "preview": "Unofficial community modification. Original game rights remain with their owners.",
        "paths": "Choose installation folder",
        "paths_subtitle": "Choose where to install OrionMultiplayerEnhanced",
        "destination": "Install OrionMultiplayerEnhanced in",
        "browse": "Browse…", "desktop": "Create a desktop shortcut",
        "back": "Back", "next": "Next", "install": "Install",
        "cancel": "Cancel", "close": "Close", "language": "Language",
        "installing": "Installing", "installing_subtitle": "Please wait while setup prepares the mod",
        "done": "Installation complete", "done_subtitle": "OrionMultiplayerEnhanced is installed",
        "complete": "Use the new desktop or Start menu shortcut to play. You can remove the mod from Windows Apps settings.",
        "launch": "Launch OrionMultiplayerEnhanced", "error": "Installation could not be completed",
        "wait": "Please wait for installation to finish.",
        "uninstall": "Uninstall OrionMultiplayerEnhanced?",
        "uninstall_notice": "Remove the files installed by this mod? Saves and additional or modified files will be preserved.",
        "removed": "Uninstall complete. Your saves were preserved.",
        "remaining": "Additional or modified files were preserved in the installation folder.",
        "destination_hint": "Setup will create this folder and install the game in it.",
        "destination_required": "Choose a folder for OrionMultiplayerEnhanced.",
        "space": "Setup needs about 500 MB of free disk space, including temporary files.",
        "verifying": "Verifying the bundled game files…",
        "extracting": "Installing the modified game…",
        "copying": "Installing game files and documentation…",
        "shortcuts": "Creating shortcuts…",
        "installed_in": "Installed in",
    },
    "ru": {
        "title": "Установка — OrionMultiplayerEnhanced",
        "welcome": "Установка OrionMultiplayerEnhanced",
        "intro": "Модифицированная версия Orion Sandbox Enhanced",
        "notice": "Все наши изменения миров, персонажей, карты, интерфейса и сетевой игры. Мастер установит модифицированную версию в отдельную папку и создаст ярлык для запуска.",
        "before": "Перед началом",
        "included": "Рабочая модифицированная версия полностью включена в установщик.",
        "saves": "Сделайте резервную копию сохранений перед игрой.",
        "preview": "Неофициальная модификация сообщества. Права на оригинал принадлежат его авторам.",
        "paths": "Выбор папки установки",
        "paths_subtitle": "Выберите, куда установить OrionMultiplayerEnhanced",
        "destination": "Папка OrionMultiplayerEnhanced",
        "browse": "Обзор…", "desktop": "Создать ярлык на рабочем столе",
        "back": "Назад", "next": "Далее", "install": "Установить",
        "cancel": "Отмена", "close": "Закрыть", "language": "Язык",
        "installing": "Установка", "installing_subtitle": "Подождите, пока мастер подготовит мод",
        "done": "Установка завершена", "done_subtitle": "OrionMultiplayerEnhanced установлен",
        "complete": "Запускайте мод через новый ярлык на рабочем столе или в меню «Пуск». Удалить его можно в списке приложений Windows.",
        "launch": "Запустить OrionMultiplayerEnhanced", "error": "Не удалось завершить установку",
        "wait": "Дождитесь завершения установки.",
        "uninstall": "Удалить OrionMultiplayerEnhanced?",
        "uninstall_notice": "Удалить установленные файлы мода? Сохранения, дополнительные и изменённые файлы останутся.",
        "removed": "Удаление завершено. Сохранения не затронуты.",
        "remaining": "Дополнительные или изменённые файлы оставлены в папке установки.",
        "destination_hint": "Мастер создаст эту папку и установит в неё игру.",
        "destination_required": "Выберите папку для OrionMultiplayerEnhanced.",
        "space": "Для установки требуется около 500 МБ, включая временные файлы.",
        "verifying": "Проверка игровых файлов установщика…",
        "extracting": "Установка модифицированной игры…",
        "copying": "Копирование игровых файлов и документации…",
        "shortcuts": "Создание ярлыков…",
        "installed_in": "Папка установки",
    },
}


def resources() -> Path:
    return Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parents[1]))


def wait_for_parent(pid: int) -> None:
    if os.name != "nt" or not pid:
        return
    kernel = ctypes.windll.kernel32
    kernel.OpenProcess.restype = ctypes.c_void_p
    handle = kernel.OpenProcess(0x00100000, False, pid)
    if handle:
        kernel.WaitForSingleObject.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
        kernel.CloseHandle.argtypes = [ctypes.c_void_p]
        result = kernel.WaitForSingleObject(handle, 15000)
        kernel.CloseHandle(handle)
        if result == 0x102:
            raise InstallError("The previous uninstaller is still running.")


class Wizard:
    """A conventional Windows setup layout with native controls."""

    BG = "#fafafa"
    INK = "#202020"
    SECONDARY = "#5b5b5b"

    def __init__(self, root, args):
        self.root, self.args = root, args
        self.lang = tk.StringVar(value=args.lang)
        self.language_name = tk.StringVar(value="Русский" if args.lang == "ru" else "English")
        default_target = Path(os.environ.get("LOCALAPPDATA", Path.home())) / "Programs" / APP_NAME
        self.destination = tk.StringVar(value=str(args.destination) if args.destination else str(default_target))
        self.desktop = tk.BooleanVar(value=True)
        self.launch = tk.BooleanVar(value=False)
        self.step, self.busy = 0, False
        self.events = queue.Queue()
        root.title(self.t("title"))
        root.geometry("720x500")
        root.resizable(False, False)
        root.configure(bg=self.BG)
        icon = resources() / "assets/mod.ico"
        if icon.exists():
            root.iconbitmap(str(icon))
        style = ttk.Style(root)
        # Use the real platform theme rather than painting a themed sidebar.
        native = "vista" if "vista" in style.theme_names() else "default"
        style.theme_use(native)
        style.configure("TButton", font=("Segoe UI", 10), padding=(12, 4))
        style.configure("TEntry", font=("Segoe UI", 10), padding=(4, 4))
        style.configure("TCombobox", font=("Segoe UI", 9), padding=2)
        style.configure("Page.TCheckbutton", font=("Segoe UI", 10), background=self.BG)
        style.configure("Page.TLabel", font=("Segoe UI", 10), background=self.BG, foreground=self.INK)

        self.footer = tk.Frame(root, bg="#f2f2f2", padx=24, pady=12)
        self.footer.pack(side="bottom", fill="x")
        ttk.Separator(root, orient="horizontal").pack(side="bottom", fill="x")
        self.cancel_button = ttk.Button(self.footer, width=9, command=self.close)
        self.cancel_button.pack(side="right", padx=(8, 0))
        self.next_button = ttk.Button(self.footer, width=10, command=self.advance, default="active")
        self.next_button.pack(side="right", padx=(8, 0))
        self.back_button = ttk.Button(self.footer, width=9, command=self.back)
        self.back_button.pack(side="right", padx=(8, 0))
        self.language_picker = ttk.Combobox(
            self.footer, textvariable=self.language_name,
            values=("Русский", "English"), state="readonly", width=10,
        )
        self.language_picker.pack(side="left")
        self.language_picker.bind("<<ComboboxSelected>>", self.change_language)

        self.header = tk.Frame(root, bg=self.BG, padx=32, pady=20)
        self.header.pack(side="top", fill="x")
        face = resources() / "assets/orion-face.png"
        self.face = tk.PhotoImage(file=str(face)) if face.exists() else None
        if self.face:
            self.face = self.face.zoom(3).subsample(4)
            tk.Label(self.header, image=self.face, bg=self.BG).pack(side="right", padx=(24, 0))
        heading = tk.Frame(self.header, bg=self.BG)
        heading.pack(side="left", fill="both", expand=True)
        self.heading = tk.Label(
            heading, text="", bg=self.BG, fg=self.INK, font=("Segoe UI", 14),
            anchor="w", justify="left", wraplength=550,
        )
        self.heading.pack(fill="x", pady=(2, 4))
        self.subheading = tk.Label(
            heading, text="", bg=self.BG, fg=self.SECONDARY,
            font=("Segoe UI", 10), anchor="w", justify="left", wraplength=550,
        )
        self.subheading.pack(fill="x")
        self.body = tk.Frame(root, bg=self.BG, padx=32, pady=12)
        self.body.pack(fill="both", expand=True)

        root.protocol("WM_DELETE_WINDOW", self.close)
        root.bind("<Return>", self.enter)
        root.bind("<Escape>", lambda _: self.close())
        self.render()
        root.after(100, self.poll)
        root.update_idletasks()
        width, height = root.winfo_width(), root.winfo_height()
        root.geometry(f"+{max(0, (root.winfo_screenwidth() - width) // 2)}+{max(0, (root.winfo_screenheight() - height) // 2)}")

    def t(self, key):
        return TEXT[self.lang.get()][key]

    def label(self, text, *, small=False, strong=False, bottom=8, parent=None):
        widget = tk.Label(
            parent or self.body, text=text, bg=self.BG,
            fg=self.SECONDARY if small else self.INK,
            font=("Segoe UI", 9 if small else 10, "bold" if strong else "normal"),
            justify="left", anchor="w", wraplength=656,
        )
        widget.pack(fill="x", pady=(0, bottom))
        return widget

    def change_language(self, _=None):
        if not self.busy:
            self.lang.set("ru" if self.language_name.get() == "Русский" else "en")
            self.render()

    def render(self):
        for widget in self.body.winfo_children():
            widget.destroy()
        self.root.title(self.t("title"))
        self.back_button.configure(text=self.t("back"), state="normal" if self.step == 1 else "disabled")
        self.next_button.configure(text=self.t("next"), state="normal")
        self.cancel_button.configure(text=self.t("cancel"), state="normal")
        self.language_picker.configure(state="disabled" if self.busy else "readonly")
        if self.step != 3:
            if not self.cancel_button.winfo_manager():
                self.cancel_button.pack(side="right", padx=(8, 0))
        if self.step == 0:
            self.heading.configure(text=self.t("welcome"))
            self.subheading.configure(text=self.t("intro"))
            self.label(self.t("notice"), bottom=24)
            self.label(self.t("before"), strong=True, bottom=8)
            self.label(self.t("included"), bottom=8)
            self.label(self.t("saves"), bottom=24)
            self.label(self.t("preview"), small=True, bottom=4)
            self.label(__version__, small=True, bottom=0)
            self.focus_order([self.language_picker, self.next_button, self.cancel_button])
        elif self.step == 1:
            self.heading.configure(text=self.t("paths"))
            self.subheading.configure(text=self.t("paths_subtitle"))
            self.label(self.t("destination"), bottom=8)
            destination_widgets = self.path_row(self.destination, True)
            self.label(self.t("destination_hint"), small=True, bottom=20)
            check = ttk.Checkbutton(self.body, text=self.t("desktop"), variable=self.desktop, style="Page.TCheckbutton")
            check.pack(anchor="w", pady=(0, 16))
            self.label(self.t("space"), small=True, bottom=0)
            self.next_button.configure(text=self.t("install"))
            self.focus_order([*destination_widgets, check, self.back_button, self.next_button, self.cancel_button])
        elif self.step == 2:
            self.heading.configure(text=self.t("installing"))
            self.subheading.configure(text=self.t("installing_subtitle"))
            self.status = self.label(self.t("verifying"), bottom=12)
            self.bar = ttk.Progressbar(self.body, maximum=100, mode="determinate")
            self.bar.pack(fill="x", pady=(0, 20))
            self.label(self.destination.get(), small=True, bottom=0)
            self.next_button.configure(state="disabled")
            self.cancel_button.configure(state="disabled")
        else:
            self.heading.configure(text=self.t("done"))
            self.subheading.configure(text=self.t("done_subtitle"))
            self.label(self.t("complete"), bottom=24)
            self.label(self.t("installed_in"), small=True, bottom=8)
            field = ttk.Entry(self.body)
            field.insert(0, self.destination.get())
            field.configure(state="readonly")
            field.pack(fill="x", pady=(0, 24))
            check = ttk.Checkbutton(self.body, text=self.t("launch"), variable=self.launch, style="Page.TCheckbutton")
            check.pack(anchor="w")
            self.cancel_button.pack_forget()
            self.next_button.configure(text=self.t("close"))
            self.focus_order([field, check, self.next_button])
        if self.step != 2:
            self.root.after_idle(self.next_button.focus_set)

    def focus_order(self, widgets):
        for index, widget in enumerate(widgets):
            def forward(_, item=widgets[(index + 1) % len(widgets)]):
                item.focus_set()
                return "break"
            def backward(_, item=widgets[(index - 1) % len(widgets)]):
                item.focus_set()
                return "break"
            widget.bind("<Tab>", forward)
            widget.bind("<Shift-Tab>", backward)

    def path_row(self, variable, target):
        frame = tk.Frame(self.body, bg=self.BG)
        frame.pack(fill="x", pady=(0, 4))
        entry = ttk.Entry(frame, textvariable=variable)
        entry.pack(side="left", fill="x", expand=True)

        def choose():
            value = filedialog.askdirectory(parent=self.root, initialdir=variable.get() or str(Path.home()))
            if value:
                path = Path(value)
                variable.set(str(path / APP_NAME if target and path.name != APP_NAME else path))

        browse = ttk.Button(frame, text=self.t("browse"), width=9, command=choose)
        browse.pack(side="left", padx=(8, 0))
        return entry, browse

    def enter(self, _):
        if self.busy:
            return "break"
        focused = self.root.focus_get()
        if isinstance(focused, ttk.Button):
            focused.invoke()
        else:
            self.advance()
        return "break"

    def advance(self):
        if self.step == 0:
            self.step = 1
            self.render()
        elif self.step == 1:
            if not self.destination.get().strip():
                messagebox.showerror(self.t("error"), self.t("destination_required"), parent=self.root)
                return
            params = Path(self.destination.get()), self.desktop.get()
            self.step, self.busy = 2, True
            self.render()
            threading.Thread(target=self.worker, args=params, daemon=True).start()
        elif self.step == 3:
            self.close()

    def back(self):
        if self.step == 1:
            self.step = 0
            self.render()

    def worker(self, destination, desktop):
        try:
            install_game(
                destination, resources(),
                Path(sys.executable) if getattr(sys, "frozen", False) else None,
                desktop, progress=lambda p, m: self.events.put(("progress", p, m)),
            )
            self.events.put(("done",))
        except Exception as exc:
            self.events.put(("error", str(exc)))

    def poll(self):
        translated = {
            "Verifying the bundled game...": "verifying",
            "Extracting the bundled game...": "extracting",
            "Installing documentation and uninstaller...": "copying",
            "Creating shortcuts...": "shortcuts",
        }
        try:
            while True:
                event = self.events.get_nowait()
                if event[0] == "progress":
                    self.bar["value"] = event[1]
                    key = translated.get(event[2])
                    self.status.configure(text=self.t(key) if key else event[2])
                elif event[0] == "done":
                    self.busy, self.step = False, 3
                    self.render()
                else:
                    self.busy, self.step = False, 1
                    self.render()
                    messagebox.showerror(self.t("error"), event[1], parent=self.root)
        except queue.Empty:
            pass
        self.root.after(100, self.poll)

    def close(self):
        if self.busy:
            return
        if self.step == 3 and self.launch.get():
            target = Path(self.destination.get())
            subprocess.Popen([str(target / (APP_NAME + ".exe"))], cwd=str(target))
        self.root.destroy()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--destination", type=Path)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--no-shortcuts", action="store_true")
    parser.add_argument("--uninstall", action="store_true")
    parser.add_argument("--perform-uninstall", type=Path)
    parser.add_argument("--wait-pid", type=int, default=0)
    parser.add_argument("--log", type=Path)
    parser.add_argument("--lang", choices=("ru", "en"), default="ru")
    args = parser.parse_args()
    result, status = {}, 0
    try:
        if args.perform_uninstall:
            wait_for_parent(args.wait_pid)
            result = uninstall_game(args.perform_uninstall)
            if not args.headless:
                root = tk.Tk()
                root.withdraw()
                text = TEXT[args.lang]["removed"]
                if result["remaining_folder"]:
                    text += "\n\n" + TEXT[args.lang]["remaining"]
                messagebox.showinfo(APP_NAME, text)
                root.destroy()
        elif args.uninstall:
            root = tk.Tk()
            root.withdraw()
            if messagebox.askyesno(TEXT[args.lang]["uninstall"], TEXT[args.lang]["uninstall_notice"]):
                target = Path(sys.executable).parent
                temporary = Path(tempfile.mkdtemp(prefix="ome-uninstall-")) / "Uninstall.exe"
                shutil.copy2(sys.executable, temporary)
                subprocess.Popen([str(temporary), "--perform-uninstall", str(target), "--wait-pid", str(os.getpid()), "--lang", args.lang])
            root.destroy()
        elif args.headless:
            if not args.destination:
                raise InstallError("--headless requires --destination")
            result = install_game(args.destination, resources(),
                                  Path(sys.executable) if getattr(sys, "frozen", False) else None,
                                  shortcuts=not args.no_shortcuts)
        else:
            root = tk.Tk()
            Wizard(root, args)
            root.mainloop()
    except Exception as exc:
        result, status = {"error": str(exc)}, 1
        if not args.headless:
            messagebox.showerror(APP_NAME, str(exc))
    if args.log:
        args.log.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if sys.stdout is not None and args.headless:
        print(json.dumps(result, indent=2))
    return status


if __name__ == "__main__":
    if os.name == "nt":
        ctypes.windll.user32.SetProcessDPIAware()
    raise SystemExit(main())
