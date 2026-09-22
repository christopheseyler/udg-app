class_name PlayerWinsScreen
extends Control

## Ecran partage de fin de partie, affiche quand un joueur a gagne.
## Contenu provisoire (nom du gagnant + bouton de sortie) : a etoffer plus
## tard (score final, animations, ...). show_winner() l'affiche ;
## continue_pressed est emis quand le joueur le ferme.

signal continue_pressed

@onready var winner_label: Label = $Center/Content/WinnerLabel
@onready var continue_button: Button = $Center/Content/ContinueButton

func _ready() -> void:
	visible = false
	continue_button.pressed.connect(func(): continue_pressed.emit())

func show_winner(player_name: String) -> void:
	winner_label.text = "%s wins!" % player_name
	visible = true

func hide_screen() -> void:
	visible = false
