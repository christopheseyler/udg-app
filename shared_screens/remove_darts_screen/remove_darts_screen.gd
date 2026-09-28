class_name RemoveDartsScreen
extends Control

## Ecran "Remove your darts" avec decompte, affiche entre deux tours pour
## laisser le temps de retirer les fleches de la cible. start() l'affiche et
## lance le decompte ; finished est emis a la fin (ou des l'appel a skip(),
## voir le bouton Next de GameScreen qui reste accessible au-dessus de cet
## ecran), l'ecran se masque alors.
## Il bloque les interactions avec l'ecran en dessous tant qu'il est visible.

signal finished

## A chaque seconde : le nouveau chiffre arrive de plus grand en se posant
## (TICK_IN_*), l'ancien s'envole en grossissant et s'efface (TICK_OUT_*).
## Le reste de l'ecran (titre, image) reste fixe.
const TICK_IN_SCALE := 2.2
const TICK_IN_DURATION := 0.3
const TICK_OUT_SCALE := 1.8
const TICK_OUT_DURATION := 0.35
## Couleur du dernier chiffre (1), pour marquer la fin imminente.
const LAST_TICK_COLOR := Color(1.0, 0.45, 0.3)

@onready var countdown_holder: Control = $Center/Content/Row/CountdownHolder
@onready var countdown_label: Label = $Center/Content/Row/CountdownHolder/CountdownLabel

var _remaining := 0.0
var _shown_value := 0
var _tick_tween: Tween

func _ready() -> void:
	visible = false
	set_process(false)

func start(duration: float) -> void:
	_remaining = duration
	_shown_value = ceili(_remaining)
	countdown_label.text = str(_shown_value)
	visible = true
	set_process(true)
	_play_tick(false)

## Passe le decompte (bouton Next de l'ecran de jeu).
func skip() -> void:
	_finish()

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		_finish()
		return
	var value := ceili(_remaining)
	if value != _shown_value:
		_shown_value = value
		_play_tick(true)

func _finish() -> void:
	if not visible:
		return
	set_process(false)
	_stop_tweens()
	visible = false
	finished.emit()

## Affiche _shown_value : le chiffre arrive en se posant ; avec
## with_previous, l'ancien chiffre (copie du label) s'envole en meme temps.
func _play_tick(with_previous: bool) -> void:
	if with_previous:
		_spawn_leaving_digit()
	countdown_label.text = str(_shown_value)
	# Pivot depuis la taille fixe du conteneur (voir la scene) : a la premiere
	# apparition, la mise en page de l'ecran jusque-la masque n'est pas encore
	# faite.
	countdown_label.pivot_offset = countdown_holder.custom_minimum_size / 2.0
	countdown_label.scale = Vector2.ONE * TICK_IN_SCALE
	countdown_label.modulate = Color(LAST_TICK_COLOR if _shown_value <= 1 else Color.WHITE, 0.0)

	if _tick_tween:
		_tick_tween.kill()
	_tick_tween = create_tween().set_parallel()
	_tick_tween.tween_property(countdown_label, "scale", Vector2.ONE, TICK_IN_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tick_tween.tween_property(countdown_label, "modulate:a", 1.0, TICK_IN_DURATION / 2.0) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _spawn_leaving_digit() -> void:
	var leaving: Label = countdown_label.duplicate()
	countdown_holder.add_child(leaving)
	leaving.pivot_offset = countdown_holder.custom_minimum_size / 2.0
	leaving.scale = countdown_label.scale
	leaving.modulate = countdown_label.modulate
	var tween := leaving.create_tween().set_parallel()
	tween.tween_property(leaving, "scale", Vector2.ONE * TICK_OUT_SCALE, TICK_OUT_DURATION) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(leaving, "modulate:a", 0.0, TICK_OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(leaving.queue_free)

func _stop_tweens() -> void:
	if _tick_tween:
		_tick_tween.kill()
	for child in countdown_holder.get_children():
		if child != countdown_label:
			child.queue_free()
