class_name GameDefinition
extends RefCounted

## Definition d'un jeu, exposee a l'ecran de selection. Chaque jeu vit dans
## games/<nom_du_jeu>/ et etend cette classe en renseignant ses champs dans
## _init(). "min_players", "max_players", "options", "uses_players_order" et
## "reverse_players_order" sont facultatifs (voir game_options.gd pour le
## format des options ; un jeu sans option desactive le bouton Options ;
## "uses_players_order" indique si le demarrage passe par l'ecran d'ordre de
## passage, vrai par defaut ; "reverse_players_order" inverse cet ordre : le
## joueur le plus proche du centre joue en dernier).

const DEFAULT_MAX_PLAYERS := 4

var id: String
var name: String
var image: String
var min_players: int = 1
var max_players: int = DEFAULT_MAX_PLAYERS
var options: Array = []
var uses_players_order := true
var reverse_players_order := false
## Ecran de jeu (herite de GameScreen). Null tant que le jeu n'en a pas.
var screen_scene: PackedScene
