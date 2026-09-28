class_name DebtBadge
extends PanelContainer

## Petite gommette ronde affichant le nombre de fleches perdues par un joueur
## (mode "Give-me your darts" du X01), ex. "-2". set_debt(0) la masque.
## Une premiere apparition (masquee -> visible) se fait en fondu avec un
## zoom depuis le centre (leger effet de rebond) ; une mise a jour alors
## qu'elle est deja visible ne refait qu'un petit zoom (pas de fondu), et
## seulement si le nombre change.

const POP_DURATION := 0.28
const PULSE_DURATION := 0.22
const PULSE_SCALE := 1.35

@onready var value_label: Label = $Value

## Dette actuellement affichee ; 0 tant que la gommette n'a jamais ete
## montree, ce qui declenche l'apparition en fondu au premier appel.
var _shown_debt := 0
var _tween: Tween

func _ready() -> void:
	pivot_offset = size / 2.0
	scale = Vector2.ZERO
	modulate.a = 0.0
	visible = false

## Appele a chaque rafraichissement de la ligne du joueur (a chaque jet,
## pour tous les joueurs) : n'anime la gommette que si la dette change.
func set_debt(debt: int) -> void:
	if maxi(debt, 0) == _shown_debt:
		return
	if debt <= 0:
		_hide_badge()
		_shown_debt = 0
		return

	value_label.text = "-%d" % debt
	if _shown_debt <= 0:
		_pop_in()
	else:
		_pulse()
	_shown_debt = debt

## Premiere apparition : fondu + zoom depuis le centre, avec un leger
## rebond (depasse legerement 1.0 avant de se stabiliser).
func _pop_in() -> void:
	visible = true
	if _tween:
		_tween.kill()
	modulate.a = 0.0
	scale = Vector2.ZERO
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, POP_DURATION)
	_tween.tween_property(self, "scale", Vector2.ONE, POP_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Mise a jour alors que la gommette est deja visible : juste un petit
## zoom-dezoom pour attirer l'oeil sur le nouveau nombre, sans fondu.
func _pulse() -> void:
	if _tween:
		_tween.kill()
	scale = Vector2.ONE
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * PULSE_SCALE, PULSE_DURATION * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, PULSE_DURATION * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _hide_badge() -> void:
	if _tween:
		_tween.kill()
	visible = false
