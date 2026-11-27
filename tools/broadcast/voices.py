"""Tell the main commentator's sentences from the other voices (guests, interviews).

Every sentence gets a voice fingerprint (a WeSpeaker model run by sherpa-onnx, on this
PC). The main voice is found by itself: he speaks most, so the middle of all fingerprints
is pulled towards him; the middle is then taken again over the closest 60 % only, three
times. Each sentence gets its likeness to that main voice (1 = the same voice, 0 = not
alike). Sentences shorter than 1.5 s are too short for a fingerprint of their own and
take the answer of the sentence next to them in time.

    python -E -P tools/broadcast/voices.py <media folder> [...] [--main=<main_voice.npy>]
        --main: use this main voice (made from another stream) and don't find it again;
                without it the main voice found here is saved as <folder>/main_voice.npy

Reads sentences.jsonl, writes voices.npy (one fingerprint per sentence) and adds
"voice_like" (0 to 1) to every line of sentences.jsonl. Which likeness counts as "him" is
decided afterwards from the spread of the numbers (see bank.py), not here.
"""
import argparse
import json
import os

import numpy as np
import sherpa_onnx

import transcribe

HOME = os.path.expanduser("~")
MODEL = os.path.join(HOME, "source", "pwa_broadcast", "models", "wespeaker_en_voxceleb_resnet34_LM.onnx")
SHORT_S = 1.5
PAD_S = 0.15


def unit(v):
    return v / (np.linalg.norm(v, axis=-1, keepdims=True) + 1e-9)


def fingerprints(folder, threads):
    media = transcribe.find_media(folder)
    with open(os.path.join(folder, "sentences.jsonl"), encoding="utf-8") as f:
        rows = [json.loads(l) for l in f]
    audio = transcribe.read_audio(media)
    ex = sherpa_onnx.SpeakerEmbeddingExtractor(
        sherpa_onnx.SpeakerEmbeddingExtractorConfig(model=MODEL, num_threads=threads))
    embs = np.zeros((len(rows), ex.dim), dtype=np.float32)
    has = np.zeros(len(rows), dtype=bool)
    for i, r in enumerate(rows):
        if r["seconds"] < SHORT_S:
            continue
        a = max(0, int((r["start"] - PAD_S) * transcribe.RATE))
        b = min(len(audio), int((r["end"] + PAD_S) * transcribe.RATE))
        st = ex.create_stream()
        st.accept_waveform(transcribe.RATE, audio[a:b])
        st.input_finished()
        if ex.is_ready(st):
            embs[i] = np.asarray(ex.compute(st), dtype=np.float32)
            has[i] = True
    return rows, unit(embs), has


def main_voice(embs, has):
    use = embs[has]
    mid = unit(use.mean(axis=0))
    for _ in range(3):
        like = use @ mid
        mid = unit(use[like >= np.percentile(like, 40)].mean(axis=0))
    return mid


def run(folder, main_path, threads):
    rows, embs, has = fingerprints(folder, threads)
    if main_path:
        mid = np.load(main_path)
    else:
        mid = main_voice(embs, has)
        np.save(os.path.join(folder, "main_voice.npy"), mid)
    like = embs @ mid
    # Short sentences take the nearest fingerprinted sentence's answer (within 4 s).
    idx = np.where(has)[0]
    for i, r in enumerate(rows):
        if has[i]:
            r["voice_like"], r["voice_own"] = round(float(like[i]), 3), True
            continue
        best, gap = None, 4.0
        for j in (idx[idx < i][-1:].tolist() + idx[idx > i][:1].tolist()):
            g = (r["start"] - rows[j]["end"]) if j < i else (rows[j]["start"] - r["end"])
            if g < gap:
                best, gap = j, g
        r["voice_like"] = round(float(like[best]), 3) if best is not None else -1.0
        r["voice_own"] = False
    np.save(os.path.join(folder, "voices.npy"), embs)
    with open(os.path.join(folder, "sentences.jsonl"), "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    own = np.array([r["voice_like"] for r in rows if r["voice_own"]])
    hist, _ = np.histogram(own, bins=10, range=(0.0, 1.0))
    print("%s: %d sentences, %d with a fingerprint; likeness 0.0-1.0 in tenths: %s"
          % (os.path.basename(folder), len(rows), int(has.sum()), " ".join(str(h) for h in hist)), flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folders", nargs="+")
    ap.add_argument("--main", default="")
    ap.add_argument("--threads", type=int, default=2)
    a = ap.parse_args()
    for folder in a.folders:
        run(folder.rstrip("/\\"), a.main, a.threads)


if __name__ == "__main__":
    main()
