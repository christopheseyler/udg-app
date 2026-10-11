"""Genere les annonces vocales (.wav) listees dans phrases.json via OpenAI TTS.

La cle est lue depuis OPENAI_API_KEY, ou a defaut CLAUDE_OPENAI_API_KEY.

Usage :
    python generate_voice.py                  # genere les fichiers manquants
    python generate_voice.py bust game_shot   # seulement ces cles
    python generate_voice.py --force          # regenere meme si le .wav existe
    python generate_voice.py --list           # affiche les phrases sans rien generer
"""
import argparse
import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PHRASES_FILE = HERE / "phrases.json"


def build_instructions(base: str, phrase: dict) -> str:
    instructions = phrase.get("instructions", base)
    if "emphasis" in phrase:
        instructions += f" Slight emphasis on '{phrase['emphasis']}'."
    return instructions


def fix_wav_header(path: Path) -> None:
    """Le flux TTS ecrit des tailles RIFF/data a 0xFFFFFFFF : on les remplace par les vraies."""
    data = bytearray(path.read_bytes())
    pos = 12
    while pos + 8 <= len(data):
        chunk_id = bytes(data[pos:pos + 4])
        size = int.from_bytes(data[pos + 4:pos + 8], "little")
        if chunk_id == b"data":
            data[pos + 4:pos + 8] = (len(data) - pos - 8).to_bytes(4, "little")
            break
        pos += 8 + size + (size & 1)
    data[4:8] = (len(data) - 8).to_bytes(4, "little")
    path.write_bytes(data)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("keys", nargs="*", help="cles de phrases.json a generer (toutes par defaut)")
    parser.add_argument("--force", action="store_true", help="ecrase les .wav existants")
    parser.add_argument("--list", action="store_true", help="liste les phrases et quitte")
    args = parser.parse_args()

    config = json.loads(PHRASES_FILE.read_text(encoding="utf-8"))
    phrases: dict = config["phrases"]

    unknown = [k for k in args.keys if k not in phrases]
    if unknown:
        print(f"Cles inconnues : {', '.join(unknown)}", file=sys.stderr)
        return 1
    selected = {k: phrases[k] for k in (args.keys or phrases)}

    if args.list:
        for key, phrase in selected.items():
            state = "ok" if (HERE / f"{key}.wav").exists() else "--"
            print(f"[{state}] {key:<14} {phrase['text']}")
        return 0

    api_key = os.environ.get("OPENAI_API_KEY") or os.environ.get("CLAUDE_OPENAI_API_KEY")
    if not api_key:
        print("OPENAI_API_KEY (ou CLAUDE_OPENAI_API_KEY) n'est pas definie", file=sys.stderr)
        return 1

    from openai import OpenAI  # import tardif : --list fonctionne sans le paquet
    client = OpenAI(api_key=api_key)

    for key, phrase in selected.items():
        output = HERE / f"{key}.wav"
        if output.exists() and not args.force:
            print(f"skip  {output.name} (existe deja, --force pour regenerer)")
            continue
        print(f"gen   {output.name} <- {phrase['text']!r}")
        with client.audio.speech.with_streaming_response.create(
            model=phrase.get("model", config["model"]),
            voice=phrase.get("voice", config["voice"]),
            input=phrase["text"],
            instructions=build_instructions(config["instructions"], phrase),
            response_format="wav",
        ) as response:
            response.stream_to_file(output)
        fix_wav_header(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
