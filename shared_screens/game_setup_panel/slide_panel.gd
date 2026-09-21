class_name SlidePanel
extends PanelContainer

## Base des panneaux ancres en bas de l'ecran : show_panel() les fait glisser
## depuis le bas de l'ecran (avec un fondu) jusqu'a leur position de repos
## definie dans la scene, hide_panel() les fait ressortir par le bas.

@export var slide_duration: float = 0.4

var is_open := false

var _tween: Tween
var _rest_offset_top := 0.0
var _rest_captured := false

func show_panel() -> void:
	_capture_rest()
	if _tween:
		_tween.kill()
	visible = true
	is_open = true
	position.y = get_parent_area_size().y
	modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position:y", _rest_y(), slide_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, slide_duration)

func hide_panel() -> void:
	if not visible:
		return
	_capture_rest()
	if _tween:
		_tween.kill()
	is_open = false
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position:y", get_parent_area_size().y, slide_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, slide_duration)
	_tween.chain().tween_callback(func(): visible = false)

func _capture_rest() -> void:
	if not _rest_captured:
		_rest_offset_top = offset_top
		_rest_captured = true

func _rest_y() -> float:
	return get_parent_area_size().y * anchor_top + _rest_offset_top
