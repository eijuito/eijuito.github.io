#!/usr/bin/env python3
"""
Crawler de Artefatos & Gerador de Manifesto SHA-256
Varre recursivamente o diretório 'repo/', identifica arquivos e gera 'repo/manifest.json'.
"""

import os
import json
import hashlib
from datetime import datetime, timezone

REPO_DIR = "repo"
MANIFEST_PATH = os.path.join(REPO_DIR, "manifest.json")
IGNORE_FILES = {"index.html", "manifest.json", ".gitkeep", "SHA256SUMS"}

def calculate_sha256(filepath, chunk_size=65536):
    """Calcula o hash SHA-256 de forma eficiente em blocos."""
    hasher = hashlib.sha256()
    try:
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(chunk_size), b""):
                hasher.update(chunk)
        return hasher.hexdigest()
    except Exception as e:
        print(f"[ERRO] Falha ao ler {filepath}: {e}")
        return None

def format_size(bytes_size):
    """Formata bytes em unidade legível (B, KB, MB, GB)."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_size < 1024.0:
            return f"{bytes_size:.2f} {unit}"
        bytes_size /= 1024.0
    return f"{bytes_size:.2f} TB"

def scan_repositories():
    if not os.path.exists(REPO_DIR):
        print(f"[AVISO] Pasta {REPO_DIR} não encontrada.")
        return []

    repos_data = []

    # Cada subpasta dentro de repo/ representa um repositório
    for item in sorted(os.listdir(REPO_DIR)):
        item_path = os.path.join(REPO_DIR, item)
        if not os.path.isdir(item_path):
            continue

        repo_name = item
        artifacts = []

        for root, _, files in os.walk(item_path):
            for file in sorted(files):
                if file in IGNORE_FILES or file.startswith("."):
                    continue

                abs_file_path = os.path.join(root, file)
                rel_to_repo = os.path.relpath(abs_file_path, REPO_DIR).replace(os.path.sep, "/")
                
                size_bytes = os.path.getsize(abs_file_path)
                sha256_hash = calculate_sha256(abs_file_path)
                mod_time = datetime.fromtimestamp(os.path.getmtime(abs_file_path), tz=timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

                artifacts.append({
                    "filename": file,
                    "relative_url": rel_to_repo,
                    "size_bytes": size_bytes,
                    "size_human": format_size(size_bytes),
                    "sha256": sha256_hash,
                    "last_modified": mod_time
                })

        repos_data.append({
            "name": repo_name,
            "has_custom_index": os.path.exists(os.path.join(item_path, "index.html")),
            "total_artifacts": len(artifacts),
            "artifacts": artifacts
        })

    manifest = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_repositories": len(repos_data),
        "repositories": repos_data
    }

    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    print(f"[OK] Manifesto gerado com sucesso em '{MANIFEST_PATH}' ({len(repos_data)} repositórios varridos).")

if __name__ == "__main__":
    scan_repositories()
