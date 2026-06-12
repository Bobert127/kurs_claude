import os
import sys
import json
import pandas as pd
import tkinter as tk
from tkinter import filedialog, messagebox

# ścieżka config.json zawsze obok EXE (lub obok skryptu w trybie dev)
if getattr(sys, 'frozen', False):
    _BASE_DIR = os.path.dirname(sys.executable)
else:
    _BASE_DIR = os.path.dirname(os.path.abspath(__file__))
config_file = os.path.join(_BASE_DIR, "config.json")

def load_last_paths():
    if os.path.exists(config_file):
        with open(config_file, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"read_path": "", "save_path": ""}

def save_last_paths(read_path, save_path):
    paths = load_last_paths()
    paths["read_path"] = read_path
    paths["save_path"] = save_path
    with open(config_file, "w", encoding="utf-8") as f:
        json.dump(paths, f)

def load_json(file_path):
    # próba kilku kodowań — pliki eksportowane z Windows mogą być w cp1250
    for encoding in ("utf-8", "utf-8-sig", "cp1250", "latin-1"):
        try:
            with open(file_path, "r", encoding=encoding) as f:
                data = json.load(f)
            break
        except UnicodeDecodeError:
            continue
    else:
        raise ValueError("Nie można odczytać pliku — nieobsługiwane kodowanie.")

    if "results" not in data or not isinstance(data["results"], list):
        raise ValueError("Nie znaleziono sekcji 'results' w JSON.")
    if not data["results"]:
        raise ValueError("Sekcja 'results' jest pusta.")

    items = data["results"][0].get("items")
    if not items:
        raise ValueError("Sekcja 'items' jest pusta lub nie istnieje.")

    df = pd.DataFrame(items)

    # konwersja kolumn liczbowych (przecinek dziesiętny → float) bez dotykania tekstów
    for col in df.columns:
        if df[col].dtype == object:
            converted = df[col].str.replace(",", ".", regex=False)
            numeric = pd.to_numeric(converted, errors="coerce")
            if numeric.notna().sum() > 0:
                df[col] = numeric

    return df

def main():
    root = tk.Tk()
    root.withdraw()

    paths = load_last_paths()
    home = os.path.expanduser("~")

    file_path = filedialog.askopenfilename(
        initialdir=os.path.dirname(paths["read_path"]) if paths["read_path"] else home,
        title="Wybierz plik JSON",
        filetypes=[("Pliki JSON", "*.json")]
    )
    if not file_path:
        return  # użytkownik anulował — cicha rezygnacja

    try:
        df = load_json(file_path)
    except Exception as e:
        messagebox.showerror("Błąd wczytywania", str(e))
        return

    print("Wczytane kolumny:", list(df.columns))

    output_path = filedialog.asksaveasfilename(
        initialdir=paths["save_path"] if paths["save_path"] else home,
        title="Zapisz plik jako",
        defaultextension=".xlsx",
        filetypes=[("Pliki Excel", "*.xlsx")]
    )
    if not output_path:
        return  # użytkownik anulował — cicha rezygnacja

    try:
        df.to_excel(output_path, index=False, engine="openpyxl")
    except PermissionError:
        messagebox.showerror("Błąd zapisu", f"Nie można zapisać pliku:\n{output_path}\n\nSprawdź czy plik nie jest otwarty w Excelu.")
        return
    except Exception as e:
        messagebox.showerror("Błąd zapisu", str(e))
        return

    save_last_paths(file_path, os.path.dirname(output_path))
    messagebox.showinfo("Zakończono", f"Plik został zapisany jako:\n{output_path}")

if __name__ == "__main__":
    main()
