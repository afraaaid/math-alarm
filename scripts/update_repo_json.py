#!/usr/bin/env python3
"""
Aggiorna la versione dentro Info.plist prima della creazione dell'IPA
e genera repo.json compatibile con FlareStore / AltStore / SideStore / Feather.
"""

import datetime
import json
import os
import plistlib
import sys


def patch_plist(plist_path: str, version_str: str, build_num: str) -> None:
    with open(plist_path, "rb") as f:
        pl = plistlib.load(f)
    pl["CFBundleShortVersionString"] = version_str
    pl["CFBundleVersion"] = build_num
    with open(plist_path, "wb") as f:
        plistlib.dump(pl, f, sort_keys=True)
    print(f"Info.plist aggiornato: CFBundleShortVersionString={version_str}, CFBundleVersion={build_num}")


def update_repo_json(
    repo_json_path: str,
    ipa_path: str,
    repo_slug: str,
    version_str: str,
    build_num: str,
    tag_name: str,
    commit_msg: str,
) -> None:
    ipa_size = os.path.getsize(ipa_path)
    now_iso = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    download_url = f"https://github.com/{repo_slug}/releases/download/{tag_name}/Sveglia.ipa"
    icon_url = f"https://raw.githubusercontent.com/{repo_slug}/main/Sveglia/Resources/Icons/AppIcon-1024.png"

    clean_note = (commit_msg or f"Build automatica #{build_num}").strip()
    if not clean_note:
        clean_note = f"Build automatica #{build_num}"

    new_version_entry = {
        "version": version_str,
        "buildVersion": build_num,
        "date": now_iso,
        "localizedDescription": clean_note,
        "downloadURL": download_url,
        "size": ipa_size,
        "minOSVersion": "15.0",
    }

    existing_versions = []
    if os.path.exists(repo_json_path):
        try:
            with open(repo_json_path, "r", encoding="utf-8") as f:
                old_data = json.load(f)
            old_apps = old_data.get("apps", [])
            if old_apps and isinstance(old_apps[0].get("versions"), list):
                existing_versions = [
                    v for v in old_apps[0]["versions"]
                    if v.get("version") != version_str and v.get("version") != "1.0.0"
                ]
        except Exception:
            existing_versions = []

    all_versions = [new_version_entry] + existing_versions[:14]

    repo_data = {
        "name": "Sveglia Math Alarm",
        "identifier": "com.sveglia.mathalarm.repo",
        "subtitle": "Sveglia matematica anti-chiusura per iOS (0% consumo notturno)",
        "description": "Repository ufficiale per installare e aggiornare automaticamente Sveglia Math Alarm Pro su iOS tramite FlareStore, SideStore, AltStore o Feather.",
        "iconURL": icon_url,
        "website": f"https://github.com/{repo_slug}",
        "tintColor": "#FF732E",
        "featuredApps": [
            "com.sveglia.mathalarm"
        ],
        "apps": [
            {
                "name": "Sveglia",
                "bundleIdentifier": "com.sveglia.mathalarm",
                "developerName": repo_slug.split("/")[0] if "/" in repo_slug else "afraaaid",
                "subtitle": "Sveglia matematica impossibile da chiudere",
                "localizedDescription": "Sveglia nativa iOS OLED Dark con 0% consumo batteria notturno (Catena Hydra Time-Sensitive), blocco volume fisico al 100%, sirena in background e spegnimento consentito solo risolvendo i calcoli matematici.",
                "iconURL": icon_url,
                "tintColor": "#FF732E",
                "category": "utilities",
                "version": version_str,
                "buildVersion": build_num,
                "versionDate": now_iso,
                "versionDescription": clean_note,
                "downloadURL": download_url,
                "size": ipa_size,
                "versions": all_versions,
                "appPermissions": {
                    "entitlements": [],
                    "privacy": {
                        "NSAlarmKitUsageDescription": "Sveglia utilizza AlarmKit e notifiche Time-Sensitive per suonare anche in Silenzioso con 0% consumo batteria notturno."
                    }
                }
            }
        ],
        "news": []
    }

    with open(repo_json_path, "w", encoding="utf-8") as f:
        json.dump(repo_data, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"repo.json aggiornato: versione={version_str}, size={ipa_size}, url={download_url}")


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "--patch-plist":
        patch_plist(sys.argv[2], sys.argv[3], sys.argv[4])
    elif mode == "--update-repo":
        update_repo_json(
            repo_json_path=sys.argv[2],
            ipa_path=sys.argv[3],
            repo_slug=sys.argv[4],
            version_str=sys.argv[5],
            build_num=sys.argv[6],
            tag_name=sys.argv[7],
            commit_msg=sys.argv[8] if len(sys.argv) > 8 else "",
        )
    else:
        print("Uso: update_repo_json.py --patch-plist <plist> <version> <build>")
        print("  o: update_repo_json.py --update-repo <repo.json> <ipa> <slug> <version> <build> <tag> <msg>")
        sys.exit(1)


if __name__ == "__main__":
    main()
