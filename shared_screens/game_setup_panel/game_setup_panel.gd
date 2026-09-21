class_name GameSetupPanel
extends SlidePanel

## Panneau de configuration de partie, ancre en bas de l'ecran. Contient
## les boutons Back, Players, Options et Start, exposes via des signaux.

signal back_pressed
signal players_pressed
signal options_pressed
signal start_pressed

@onready var back_button: Button = $Margin/Buttons/BackButton
@onready var players_button: Button = $Margin/Buttons/PlayersButton
@onready var options_button: Button = $Margin/Buttons/OptionsButton
@onready var start_button: Button = $Margin/Buttons/StartButton

func _ready() -> void:
	back_button.pressed.connect(func(): back_pressed.emit())
	players_button.pressed.connect(func(): players_pressed.emit())
	options_button.pressed.connect(func(): options_pressed.emit())
	start_button.pressed.connect(func(): start_pressed.emit())

## Desactive le bouton Options pour un jeu qui n'a aucune option.
func set_options_enabled(enabled: bool) -> void:
	options_button.disabled = not enabled
