class_name RemoveDartsScreen
extends Control

## Ecran "Remove your darts" avec decompte, affiche entre deux tours pour
## laisser le temps de retirer les fleches de la cible. start() l'affiche et
## lance le decompte ; finished est emis a la fin, l'ecran se masque alors.
## Il bloque les interactions avec l'ecran en dessous tant qu'il est visible.

signal finished

@onready var countdown_label: Label = $Center/Content/CountdownLabel

var _remaining := 0.0

func _ready() -> void:
	visible = false
	set_process(false)

func start(duration: float) -> void:
	_remaining = duration
	_update_label()
	visible = true
	set_process(true)

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		set_process(false)
		visible = false
		finished.emit()
		return
	_update_label()

func _update_label() -> void:
	countdown_label.text = str(ceili(_remaining))
