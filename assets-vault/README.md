# assets-vault

Ressources gardées dans le dépôt mais non utilisées par le jeu : sons
d'effets, voix des autres annonceurs, phrases du pack `party_announcer_1022`
pas encore annoncées, mp3 d'origine avant découpage, anciennes voix `.wav`
(avec leur générateur `generate_voice.py` et `phrases.json`).

Le fichier `.gdignore` exclut ce dossier de Godot : rien n'y est importé ni
exporté, il ne gonfle donc pas l'image du jeu.

L'arborescence reproduit celle de `assets/` : pour utiliser une ressource,
la remettre à son chemin d'origine, par exemple
`assets-vault/sounds/voices/party_announcer_1022/zap.mp3` vers
`assets/sounds/voices/party_announcer_1022/zap.mp3` (Godot l'importe au
prochain lancement de l'éditeur).
