from pathlib import Path
from openai import OpenAI

client = OpenAI()

output = Path("player_01.wav")

with client.audio.speech.with_streaming_response.create(
    model="gpt-4o-mini-tts",
    voice="marin",
    input="First player!",
    instructions=(
        "Female British English voice. "
        "Sound like a professional modern darts game announcer. "
        "Clear, energetic and confident, but not exaggerated. "
        "Keep the announcement short and punchy. "
        "Slight emphasis on 'First'."
    ),
    response_format="wav",
) as response:
    response.stream_to_file(output)
    