"""Fetch the commentary's speech program and voice again, and check every file against its SHA-256.

The game speaks the commentary with a ready-made computer voice (NOT the commentator's own; see
Documentation/reports/broadcast/commentary_voice.md): Piper, a small offline speech program, and
one of its British English voices. They are not in git (about 85 MB). This script puts them in a
folder laid out the way the game looks for them:

    <folder>/piper/piper.exe (+ its DLLs and espeak-ng-data)     the speech program
    <folder>/voices/<voice>.onnx, <voice>.onnx.json, <voice>.MODEL_CARD   the voice
    <folder>/downloads/                                           the files as downloaded

WHERE THE GAME EXPECTS THEM: in a play folder, the folder "tts" next to the game's executable
(<play folder>/tts/); in the development tree, the folder named by --tts_dir=<folder> on the game's
command line (after "--") or by the environment variable MMZB_TTS_DIR. On Max's PC they are in
C:/Users/Max de Dikke/source/pwa_broadcast/tts (fetched 27 November 2026).

    python -I tools/tts/fetch_tts.py <folder>          fetch what is missing, check every sum
    python -I tools/tts/fetch_tts.py <folder> --check  only check what is there

Nothing is run from the downloads; the zip is unpacked with Python's own zipfile.

The program: Piper 2023.11.14-2, the last standalone Windows build of rhasspy/piper (MIT licence;
it carries espeak-ng, GPL-3.0, for turning words into sounds, and onnxruntime, MIT). Newer Piper
(1.5 and up, OHF-Voice/piper1-gpl) is a Python package without a Windows program, and its newly
trained voices need it, so the voice is pinned to the Hugging Face commit before its retraining.
The voice: en_GB-northern_english_male-medium, a British man (OpenSLR 83, CC BY-SA 4.0), fine-tuned
from Piper's U.S. "lessac" voice, whose recordings are licensed for research only (Blizzard 2013
Lessac licence): fine for the team's play tests, NOT for a public release (see the report).
"""
import argparse
import hashlib
import os
import shutil
import sys
import urllib.request
import zipfile

PIPER_ZIP_URL = "https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_windows_amd64.zip"
PIPER_ZIP_SHA256 = "f3c58906402b24f3a96d92145f58acba6d86c9b5db896d207f78dc80811efcea"

VOICE = "en_GB-northern_english_male-medium"
VOICE_COMMIT = "e9c8a39444359388adaa94255becb37a5a2b8e51"  # rhasspy/piper-voices, 20 November 2026
VOICE_BASE = ("https://huggingface.co/rhasspy/piper-voices/resolve/%s/en/en_GB/northern_english_male/medium/"
              % VOICE_COMMIT)
VOICE_FILES = {
    VOICE + ".onnx": "57a219ae8e638873db7d18893304be5069c42868f392bb95c3ff17f0690d0689",
    VOICE + ".onnx.json": "69557ed3d974463453e9b0c09dd99a7ed0e52b8b87b64b357dbeeb2540a97d47",
    "MODEL_CARD": "75661c3a50c0ba82b32b3a438e54103d8dfe5bbe8fbb864ac687a040e79948bb",
}


def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def fetch(url, path, sha256, check_only):
    """The file at `path`, downloaded if missing; True when its sum is right."""
    if not os.path.exists(path):
        if check_only:
            print("MISSING  %s" % path)
            return False
        print("download %s" % url)
        part = path + ".part"
        with urllib.request.urlopen(url, timeout=120) as answer, open(part, "wb") as f:
            shutil.copyfileobj(answer, f)
        os.replace(part, path)
    got = sha256_of(path)
    ok = got == sha256
    print("%s %s  %s" % ("OK      " if ok else "WRONG   ", got, os.path.basename(path)))
    return ok


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("folder")
    parser.add_argument("--check", action="store_true", help="only check the files that are there")
    args = parser.parse_args()
    folder = os.path.abspath(args.folder)
    downloads = os.path.join(folder, "downloads")
    voices = os.path.join(folder, "voices")
    os.makedirs(downloads, exist_ok=True)
    os.makedirs(voices, exist_ok=True)

    ok = fetch(PIPER_ZIP_URL, os.path.join(downloads, "piper_windows_amd64.zip"), PIPER_ZIP_SHA256, args.check)
    for name, sha256 in VOICE_FILES.items():
        ok = fetch(VOICE_BASE + name, os.path.join(downloads, name), sha256, args.check) and ok
    if not ok:
        print("A file is missing or its sum is wrong: nothing unpacked.")
        sys.exit(1)

    if not os.path.exists(os.path.join(folder, "piper", "piper.exe")) and not args.check:
        with zipfile.ZipFile(os.path.join(downloads, "piper_windows_amd64.zip")) as archive:
            for member in archive.namelist():
                target = os.path.abspath(os.path.join(folder, member))
                if not target.startswith(folder + os.sep):
                    sys.exit("The zip holds a path outside the folder: %s" % member)
            archive.extractall(folder)
        print("unpacked piper/ into %s" % folder)
    for name in VOICE_FILES:
        target = os.path.join(voices, VOICE + ".MODEL_CARD" if name == "MODEL_CARD" else name)
        if not os.path.exists(target) and not args.check:
            shutil.copyfile(os.path.join(downloads, name), target)
    for name, sha256 in VOICE_FILES.items():
        target = os.path.join(voices, VOICE + ".MODEL_CARD" if name == "MODEL_CARD" else name)
        if not os.path.exists(target) or sha256_of(target) != sha256:
            print("WRONG    %s" % target)
            ok = False
    exe = os.path.join(folder, "piper", "piper.exe")
    if not os.path.exists(exe):
        print("MISSING  %s" % exe)
        ok = False
    print("The speech program is ready in %s" % folder if ok else "Not ready.")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
