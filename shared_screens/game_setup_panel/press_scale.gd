class_name PressScale
extends Node

## Animation d'appui d'un bouton : il retrecit legerement depuis son centre
## tant qu'il est enfonce (button_down / button_up), comme le bouton Play de
## l'ecran de selection. Les textures du kit UI n'ont pas d'etat "pressed".
## Usage : PressScale.attach(button) (ajoute ce noeud comme enfant du bouton).

@export var press_scale: float = 0.9
@export var duration: float = 0.07

var _button: BaseButton
var _tween: Tween

static func attach(button: BaseButton) -> PressScale:
	var press := PressScale.new()
	button.add_child(press)
	return press

func _ready() -> void:
	_button = get_parent() as BaseButton
	if _button == null:
		push_warning("PressScale doit etre l'enfant d'un BaseButton")
		return
	_button.resized.connect(_center_pivot)
	_button.button_down.connect(_animate.bind(press_scale))
	_button.button_up.connect(_animate.bind(1.0))
	_center_pivot()

func _center_pivot() -> void:
	_button.pivot_offset = _button.size / 2.0

func _animate(target: float) -> void:
	if _tween:
		_tween.kill()
	_tween = _button.create_tween()
	_tween.tween_property(_button, "scale", Vector2.ONE * target, duration)
