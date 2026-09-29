class_name CricketScorePanel
extends PanelContainer

## Panneau de score du Cricket : une grille avec une ligne d'en-tete (valeur
## des 7 cibles) puis une ligne par joueur : icone d'etat (coupe du rang pour
## un joueur qui a gagne, bouclier pour un joueur protege en Protect the
## Weaks), nom, score et ses marques sur chaque cible (voir Slot). Le joueur
## en cours est mis en surbrillance, les joueurs sortis du jeu (gagne ou
## elimine) sont grises, un joueur elimine porte le tampon "ELIMINATED".
## Jusqu'a 8 joueurs sans defilement : la taille des lignes s'adapte au
## nombre de joueurs (voir ROW_SIZES).
##
## set_players() construit la grille, set_values() met a jour les valeurs
## des cibles (animees quand elles changent : Wild, Crazy), set_row() met a
## jour un joueur, set_current_player() deplace la surbrillance et
## play_eliminated() fait frapper le tampon sur les joueurs elimines.

## slot_states.png : les 5 etats (voir Slot) de gauche a droite. Genere par
## IA, ce n'est pas une vraie grille : chaque symbole est decoupe autour de
## son centre mesure pixel par pixel dans l'image (halo compris), avec une
## zone de meme taille pour tous, afin qu'ils soient alignes et a la meme
## echelle une fois affiches.
const SLOT_ATLAS := preload("res://assets/games/cricket/slot_states.png")
const SLOT_CENTERS: Array[Vector2] = [
	Vector2(229, 353), Vector2(672.5, 350.5), Vector2(1088, 346.5), Vector2(1518.5, 348.5), Vector2(1946.5, 347.5),
]
const SLOT_REGION_SIZE := Vector2(434, 692)
const STAMP_TEXTURE := preload("res://assets/games/cricket/eliminated_stamp.png")
## Bouclier d'un joueur protege (Protect the Weaks).
const SHIELD_TEXTURE := preload("res://assets/games/cricket/shield.png")
const RANK_ICONS: Array[Texture2D] = [
	preload("res://assets/game_screen/ranking/icon_1.png"),
	preload("res://assets/game_screen/ranking/icon_2.png"),
	preload("res://assets/game_screen/ranking/icon_3.png"),
]

## Etat d'une case de marques : vide, 1 marque (trait oblique), 2 marques
## (croix), fermee (croix et cercle), fermee par tout le monde (rouge).
enum Slot { EMPTY, ONE, TWO, CLOSED, CLOSED_BY_ALL }

## Tailles selon le nombre de joueurs (le premier seuil atteint) : taille
## d'une case de marques et polices du nom, du score et des valeurs.
const ROW_SIZES := [
	{"players": 7, "slot": 60, "name": 44, "score": 52, "value": 52},
	{"players": 5, "slot": 72, "name": 50, "score": 58, "value": 58},
	{"players": 0, "slot": 80, "name": 54, "score": 64, "value": 62},
]
const SCORE_COLUMN_WIDTH := 170.0
const CELL_PADDING := Vector2(16, 8)
const SLOT_PADDING := Vector2(12, 8)
const HIGHLIGHT_COLOR := Color(0.95, 0.75, 0.2, 0.38)
const NORMAL_COLOR := Color(1, 1, 1, 0.05)
const HEADER_COLOR := Color(1, 1, 1, 0.0)
const VALUE_COLOR := Color(1.0, 0.82, 0.25)
## Joueur sorti du jeu (gagne ou elimine) : nom, score et marques grises.
const OUT_MODULATE := Color(0.55, 0.55, 0.55, 0.6)
## Bull verrouille (Locked Bull) : case attenuee.
const LOCKED_MODULATE := Color(1, 1, 1, 0.25)

## Animation d'une valeur qui change (voir set_values) : les chiffres
## defilent au hasard puis la valeur finale s'affiche en rebondissant.
const VALUE_ROLL_DURATION := 0.7
const VALUE_ROLL_STEP := 0.05
const VALUE_POP_SCALE := 1.5
const VALUE_POP_DURATION := 0.35
const VALUE_FLASH_COLOR := Color(1.8, 1.6, 1.0)

## Tampon "ELIMINATED" (voir play_eliminated) : il tombe de haut en
## grossissant a l'envers (de STAMP_START_SCALE a 1), frappe le nom (secousse
## de la ligne) et y reste. Il deborde un peu de la case du nom.
const STAMP_START_SCALE := 3.0
const STAMP_FALL_DURATION := 0.2
const STAMP_OVERFLOW := Vector2(12, 22)
const STAMP_SHAKE_AMPLITUDE := 10.0
const STAMP_SHAKE_DURATION := 0.35
const STAMP_DISPLAY_DURATION := STAMP_FALL_DURATION + STAMP_SHAKE_DURATION + 0.5

@onready var grid: GridContainer = $Margin/Grid

var _sizes: Dictionary = ROW_SIZES[0]
var _slot_textures: Array[AtlasTexture] = []
var _value_labels: Array[Label] = []
var _value_texts: Array[String] = []
var _value_tweens: Array[Tween] = []
var _value_pool: Array = []
var _row_styles: Array[Array] = []
var _name_labels: Array[Label] = []
var _score_labels: Array[Label] = []
var _slots: Array[Array] = []
var _rank_icons: Array[TextureRect] = []
var _rank_labels: Array[Label] = []
var _shields: Array[TextureRect] = []
var _stamps: Array[TextureRect] = []
var _stamp_tweens: Array[Tween] = []

func _ready() -> void:
	for center in SLOT_CENTERS:
		var cell := AtlasTexture.new()
		cell.atlas = SLOT_ATLAS
		cell.region = Rect2(center - SLOT_REGION_SIZE / 2.0, SLOT_REGION_SIZE)
		_slot_textures.append(cell)

## Construit la grille. value_pool : valeurs que peuvent prendre les cibles
## (defilement de l'animation des valeurs).
func set_players(names: Array[String], value_pool: Array) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for tween in _value_tweens + _stamp_tweens:
		if tween:
			tween.kill()
	_value_labels.clear()
	_value_texts.clear()
	_value_tweens.clear()
	_row_styles.clear()
	_name_labels.clear()
	_score_labels.clear()
	_slots.clear()
	_rank_icons.clear()
	_rank_labels.clear()
	_shields.clear()
	_stamps.clear()
	_stamp_tweens.clear()
	_value_pool = value_pool
	for sizes in ROW_SIZES:
		if names.size() >= sizes.players:
			_sizes = sizes
			break
	var slot_size: Vector2 = Vector2.ONE * _sizes.slot
	grid.columns = 3 + CricketRules.TARGET_COUNT

	# En-tete : colonnes d'etat, de nom et de score vides, puis les valeurs.
	var header_styles: Array[StyleBoxFlat] = []
	_add_cell(Control.new(), slot_size.x, CELL_PADDING, header_styles)
	_add_cell(Control.new(), 0.0, CELL_PADDING, header_styles).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_cell(Control.new(), SCORE_COLUMN_WIDTH, CELL_PADDING, header_styles)
	for i in CricketRules.TARGET_COUNT:
		var label := _make_label("", _sizes.value, HORIZONTAL_ALIGNMENT_CENTER)
		label.add_theme_color_override("font_color", VALUE_COLOR)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 10)
		var holder := _add_animated(label, slot_size.x, SLOT_PADDING, header_styles)
		holder.custom_minimum_size.y = _sizes.value * 1.2
		_value_labels.append(label)
		_value_texts.append("")
		_value_tweens.append(null)
	for style in header_styles:
		style.bg_color = HEADER_COLOR

	for player_name in names:
		var styles: Array[StyleBoxFlat] = []
		_add_status_cell(slot_size, styles)
		_add_name_cell(player_name, styles)
		var score_label := _make_label("0", _sizes.score, HORIZONTAL_ALIGNMENT_CENTER)
		_add_cell(score_label, SCORE_COLUMN_WIDTH, CELL_PADDING, styles)
		_score_labels.append(score_label)
		var slots: Array[TextureRect] = []
		for i in CricketRules.TARGET_COUNT:
			var slot := TextureRect.new()
			slot.custom_minimum_size = slot_size
			slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			slot.texture = _slot_textures[Slot.EMPTY]
			_add_cell(slot, slot_size.x, SLOT_PADDING, styles)
			slots.append(slot)
		_slots.append(slots)
		_row_styles.append(styles)

## Colonne d'etat : coupe du rang (icone pour les 3 premiers, "#x" sinon) ou
## bouclier, superposes dans la meme case.
func _add_status_cell(slot_size: Vector2, styles: Array[StyleBoxFlat]) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = slot_size
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(icon)
	var rank := _make_label("", int(_sizes.name * 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	rank.add_theme_color_override("font_color", VALUE_COLOR)
	rank.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(rank)
	var shield := TextureRect.new()
	shield.texture = SHIELD_TEXTURE
	shield.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shield.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(shield)
	_add_cell(holder, slot_size.x, CELL_PADDING, styles)
	_rank_icons.append(icon)
	_rank_labels.append(rank)
	_shields.append(shield)

## Case du nom, avec le tampon "ELIMINATED" par-dessus (masque par defaut),
## dessine au-dessus des cases voisines qu'il deborde.
func _add_name_cell(player_name: String, styles: Array[StyleBoxFlat]) -> void:
	var holder := Control.new()
	holder.custom_minimum_size.y = _sizes.slot
	var label := _make_label(player_name, _sizes.name, HORIZONTAL_ALIGNMENT_LEFT)
	label.clip_text = true
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(label)
	var stamp := TextureRect.new()
	stamp.texture = STAMP_TEXTURE
	stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stamp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.set_anchors_preset(Control.PRESET_FULL_RECT)
	stamp.offset_left = -STAMP_OVERFLOW.x
	stamp.offset_right = STAMP_OVERFLOW.x
	stamp.offset_top = -STAMP_OVERFLOW.y
	stamp.offset_bottom = STAMP_OVERFLOW.y
	stamp.z_index = 1
	stamp.visible = false
	stamp.resized.connect(func(): stamp.pivot_offset = stamp.size / 2.0)
	holder.add_child(stamp)
	var cell := _add_cell(holder, 0.0, CELL_PADDING, styles)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_labels.append(label)
	_stamps.append(stamp)
	_stamp_tweens.append(null)

## Valeurs des 7 cibles (25 = bull). animated : indices des cibles dont la
## valeur vient d'etre tiree (Wild en debut de partie, Crazy en debut de
## tour), qui defilent avant de s'afficher.
func set_values(values: Array, animated: Array = []) -> void:
	for i in _value_labels.size():
		var text := "Bull" if values[i] == DartHit.BULL else str(values[i])
		if animated.has(i):
			_roll_value(i, text)
		elif text != _value_texts[i]:
			_stop_value_tween(i)
			_value_labels[i].text = text
		_value_texts[i] = text

func _roll_value(index: int, text: String) -> void:
	_stop_value_tween(index)
	var label := _value_labels[index]
	var tween := create_tween()
	for _step in int(VALUE_ROLL_DURATION / VALUE_ROLL_STEP):
		tween.tween_callback(func(): label.text = str(_value_pool.pick_random()))
		tween.tween_interval(VALUE_ROLL_STEP)
	tween.tween_callback(func():
		label.text = text
		label.scale = Vector2.ONE * VALUE_POP_SCALE
		label.modulate = VALUE_FLASH_COLOR)
	tween.tween_property(label, "scale", Vector2.ONE, VALUE_POP_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate", Color.WHITE, VALUE_POP_DURATION)
	_value_tweens[index] = tween

func _stop_value_tween(index: int) -> void:
	if _value_tweens[index]:
		_value_tweens[index].kill()
		_value_tweens[index] = null
	_value_labels[index].scale = Vector2.ONE
	_value_labels[index].modulate = Color.WHITE

## Met a jour la ligne d'un joueur. slots : etat (Slot) de ses 7 cases ;
## bull_locked : bull verrouille (Locked Bull) ; rank : son rang s'il a
## gagne (0 sinon) ; eliminated : tampon affiche (sans animation, voir
## play_eliminated) ; shielded : protege (Protect the Weaks).
func set_row(index: int, score: int, slots: Array, bull_locked: bool, rank: int, eliminated: bool, shielded: bool) -> void:
	_score_labels[index].text = str(score)
	for i in slots.size():
		var slot: TextureRect = _slots[index][i]
		slot.texture = _slot_textures[slots[i]]
		slot.self_modulate = LOCKED_MODULATE if i == CricketRules.BULL_INDEX and bull_locked else Color.WHITE
	var out := rank > 0 or eliminated
	var row_modulate := OUT_MODULATE if out else Color.WHITE
	_name_labels[index].modulate = row_modulate
	_score_labels[index].modulate = row_modulate
	for slot: TextureRect in _slots[index]:
		slot.modulate = row_modulate

	_rank_icons[index].texture = RANK_ICONS[rank - 1] if rank >= 1 and rank <= RANK_ICONS.size() else null
	_rank_labels[index].text = "#%d" % rank if rank > RANK_ICONS.size() else ""
	_shields[index].visible = shielded and not out
	if not eliminated:
		_stop_stamp(index)
		_stamps[index].visible = false
	elif _stamp_tweens[index] == null:
		_stamps[index].visible = true

func set_current_player(index: int) -> void:
	for i in _row_styles.size():
		var color := HIGHLIGHT_COLOR if i == index else NORMAL_COLOR
		for style: StyleBoxFlat in _row_styles[i]:
			style.bg_color = color

## Fait frapper le tampon "ELIMINATED" sur le nom des joueurs indices :
## il tombe en retrecissant, la ligne tremble sous le choc, puis il reste.
func play_eliminated(indices: Array) -> void:
	for index in indices:
		_stop_stamp(index)
		var stamp := _stamps[index]
		var label := _name_labels[index]
		stamp.visible = true
		stamp.scale = Vector2.ONE * STAMP_START_SCALE
		stamp.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(stamp, "scale", Vector2.ONE, STAMP_FALL_DURATION) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(stamp, "modulate:a", 1.0, STAMP_FALL_DURATION * 0.5)
		tween.tween_method(func(strength: float):
			label.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * STAMP_SHAKE_AMPLITUDE * strength,
			1.0, 0.0, STAMP_SHAKE_DURATION)
		tween.tween_callback(func():
			label.position = Vector2.ZERO
			_stamp_tweens[index] = null)
		_stamp_tweens[index] = tween

func _stop_stamp(index: int) -> void:
	if _stamp_tweens[index]:
		_stamp_tweens[index].kill()
		_stamp_tweens[index] = null
	_stamps[index].scale = Vector2.ONE
	_stamps[index].modulate.a = 1.0
	_name_labels[index].position = Vector2.ZERO

func _make_label(text: String, font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Contenu anime (echelle) : place dans un controle simple plutot que
## directement dans la case, dont la mise en page remettrait l'echelle a 1.
func _add_animated(content: Control, min_width: float, padding: Vector2, styles: Array[StyleBoxFlat]) -> Control:
	var holder := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.resized.connect(func(): content.pivot_offset = content.size / 2.0)
	holder.add_child(content)
	_add_cell(holder, min_width, padding, styles)
	return holder

## Ajoute une cellule (fond + contenu) a la grille ; min_width > 0 fixe sa
## largeur.
func _add_cell(content: Control, min_width: float, padding: Vector2, styles: Array[StyleBoxFlat]) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = NORMAL_COLOR
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	styles.append(style)

	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", style)
	cell.custom_minimum_size.x = min_width + 2.0 * padding.x if min_width > 0.0 else 0.0
	grid.add_child(cell)
	cell.add_child(content)
	return cell
