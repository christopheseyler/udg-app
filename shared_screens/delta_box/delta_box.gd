class_name DeltaBox
extends PanelContainer

## Encadre "delta" pose a droite du nom d'un joueur dans un panneau de score :
## les points que le joueur en cours doit marquer pour arriver exactement au
## score de ce joueur (zap au 321 Zap, egalite "Give-me your darts" au X01),
## precedes du symbole delta (ex. "Δ40"). set_delta() l'affiche ou le masque ;
## quand le delta est jouable avec les fleches restantes (voir
## is_reachable), l'encadre est plus clair, borde de blanc, entoure d'un halo
## dore et pulse.

const BG_COLOR := Color(1.0, 0.78, 0.16)
const BORDER_COLOR := Color(0.45, 0.28, 0.02)
const TEXT_COLOR := Color(0.12, 0.08, 0.0)
const BRIGHT_BG_COLOR := Color(1.0, 0.92, 0.45)
const BRIGHT_BORDER_COLOR := Color(1.0, 1.0, 1.0)
const GLOW_COLOR := Color(1.0, 0.85, 0.2, 0.75)
const GLOW_SIZE := 14
## Pulsation lumineuse (self_modulate > 1 : n'eclaircit que le fond, pas le
## texte, qui est un enfant).
const PULSE_COLOR := Color(1.45, 1.35, 1.1)
const PULSE_DURATION := 0.45

static var _normal_style := _make_style(false)
static var _bright_style := _make_style(true)
## _reachable_sums[k] : totaux atteignables avec exactement k fleches,
## etendu a la demande (voir is_reachable).
static var _reachable_sums: Array[Dictionary] = [{0: true}]
static var _dart_scores: Array[int] = _all_dart_scores()

var _label: Label
var _bright := false
var _tween: Tween

func _init(font_size: int = 32) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	add_theme_stylebox_override("panel", _normal_style)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)

## Ancre l'encadre au bord droit de son parent (un Control simple qui
## enveloppe la cellule du nom), centre verticalement, a margin du bord ; il
## grandit vers la gauche.
func anchor_right_center(margin: float) -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -margin
	offset_right = -margin
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BOTH

## delta <= 0 masque l'encadre. bright : delta jouable avec les fleches
## restantes. N'anime que si l'etat brillant change.
func set_delta(delta: int, bright: bool) -> void:
	visible = delta > 0
	if delta > 0:
		_label.text = "Δ%d" % delta
	bright = bright and delta > 0
	if bright == _bright:
		return
	_bright = bright
	add_theme_stylebox_override("panel", _bright_style if bright else _normal_style)
	if _tween:
		_tween.kill()
		_tween = null
	self_modulate = Color.WHITE
	if bright:
		_tween = create_tween().set_loops()
		_tween.tween_property(self, "self_modulate", PULSE_COLOR, PULSE_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(self, "self_modulate", Color.WHITE, PULSE_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Vrai si delta peut etre marque exactement avec 1 a darts fleches (toutes
## les valeurs de jet possibles : 1 a 20 en simple, double ou triple, 25 et
## 50). Ne tient pas compte des regles du jeu (bust, rebond...) entre deux
## fleches.
static func is_reachable(delta: int, darts: int) -> bool:
	if delta <= 0:
		return false
	while _reachable_sums.size() <= darts:
		var next := {}
		for total in _reachable_sums[-1]:
			for score in _dart_scores:
				next[total + score] = true
		_reachable_sums.append(next)
	for k in range(1, darts + 1):
		if _reachable_sums[k].has(delta):
			return true
	return false

static func _all_dart_scores() -> Array[int]:
	var scores: Array[int] = [DartHit.BULL, 2 * DartHit.BULL]
	for segment in range(1, 21):
		for multiplier in range(1, 4):
			scores.append(segment * multiplier)
	return scores

static func _make_style(bright: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BRIGHT_BG_COLOR if bright else BG_COLOR
	style.border_color = BRIGHT_BORDER_COLOR if bright else BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	if bright:
		style.shadow_color = GLOW_COLOR
		style.shadow_size = GLOW_SIZE
	return style
