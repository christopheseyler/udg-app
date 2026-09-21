class_name GameDefinition
extends RefCounted

## Definition d'un jeu, exposee a l'ecran de selection. Chaque jeu vit dans
## games/<nom_du_jeu>/ et etend cette classe en renseignant ses champs dans
## _init(). "max_players", "options" et "uses_players_order" sont facultatifs
## (voir game_options.gd pour le format des options ; un jeu sans option
## desactive le bouton Options ; "uses_players_order" indique si le demarrage
## passe par l'ecran d'ordre de passage, vrai par defaut).

const DEFAULT_MAX_PLAYERS := 4

var id: String
var name: String
var image: String
var max_players: int = DEFAULT_MAX_PLAYERS
var options: Array = []
var uses_players_order := true
