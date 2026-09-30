# La cle OPENAI_API_KEY doit etre definie dans l'environnement (ne jamais la commiter).
if (-not $env:OPENAI_API_KEY) { Write-Error "OPENAI_API_KEY is not set"; exit 1 }
python generate_voice.py
