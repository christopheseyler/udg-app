class_name PlayerProfilePanel
extends VBoxContainer

## Profil d'un joueur de la base (PlayerDatabase) : photo, nom et
## statistiques. open() affiche un joueur inscrit, open_new() prepare
## l'inscription d'un nouveau joueur (enregistre seulement a Save / Select).
## Le nom s'affiche en lecture ; le bouton crayon a cote le passe en saisie
## (name_edit_started / name_edit_finished : l'ecran parent affiche / masque
## le clavier). Un nouveau joueur s'ouvre directement en saisie du nom.
## Le bouton Photo choisit une image sur le disque (cle USB, ...).
## Save enregistre et revient a la liste (saved), Select enregistre et
## donne ce joueur a la place en cours d'edition (selected), Back abandonne
## les modifications (back_pressed).
## Le nom ne peut etre ni vide ni deja pris par un autre joueur inscrit.

signal back_pressed
signal saved
signal selected(player_name: String)
signal name_edit_started
signal name_edit_finished

const PHOTO_PLACEHOLDER := preload("res://assets/ui/setup/icon_person.svg")
const PENCIL := preload("res://assets/ui/setup/icon_pencil.png")
const PHOTO_FILTERS: Array[String] = ["*.png, *.jpg, *.jpeg, *.webp ; Images"]

@onready var photo_rect: TextureRect = $Content/PhotoColumn/Photo
@onready var photo_button: Button = $Content/PhotoColumn/PhotoButton
@onready var name_label: Label = $Content/Info/NameRow/NameLabel
@onready var name_edit: LineEdit = $Content/Info/NameRow/NameEdit
@onready var edit_name_button: Button = $Content/Info/NameRow/EditNameButton
@onready var hint_label: Label = $Content/Info/HintLabel
@onready var stats_label: Label = $Content/Info/StatsLabel
@onready var back_button: Button = $Buttons/BackButton
@onready var save_button: Button = $Buttons/SaveButton
@onready var select_button: Button = $Buttons/SelectButton

## Identifiant du joueur affiche ("" pour un nouveau joueur).
var _id := ""
## Image choisie, importee a l'enregistrement.
var _pending_photo := ""
var _file_dialog: FileDialog

## Vignette de la photo du joueur `id` (ou silhouette s'il n'en a pas).
static func photo_thumbnail(id: String, size: int) -> TextureRect:
	var rect := TextureRect.new()
	var photo := PlayerDatabase.get_photo(id)
	rect.texture = photo if photo else PHOTO_PLACEHOLDER
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _ready() -> void:
	edit_name_button.add_child(_centered_icon(PENCIL, 56))
	name_edit.text_changed.connect(func(_text: String): _update_buttons())
	name_edit.text_submitted.connect(func(_text: String): _finish_name_edit())
	edit_name_button.pressed.connect(func():
		if name_edit.visible:
			_finish_name_edit()
		else:
			_start_name_edit())
	photo_button.pressed.connect(_choose_photo)
	back_button.pressed.connect(func(): back_pressed.emit())
	save_button.pressed.connect(func(): _save_and(saved.emit))
	select_button.pressed.connect(func(): _save_and(func(): selected.emit(name_edit.text.strip_edges())))
	for button in [edit_name_button, photo_button, back_button, save_button, select_button]:
		PressScale.attach(button)

func open(id: String) -> void:
	var player := PlayerDatabase.get_player(id)
	_id = id
	_pending_photo = ""
	name_edit.text = player.get("name", "")
	var photo := PlayerDatabase.get_photo(id)
	photo_rect.texture = photo if photo else PHOTO_PLACEHOLDER
	stats_label.text = _stats_text(player.get("stats", {}))
	_show_name_label()
	_update_buttons()

func open_new(suggested_name: String) -> void:
	_id = ""
	_pending_photo = ""
	name_edit.text = suggested_name
	photo_rect.texture = PHOTO_PLACEHOLDER
	stats_label.text = _stats_text({})
	_update_buttons()
	_start_name_edit()

## Icone du kit centree dans un bouton (la texture deborde de UiKit.PAD).
func _centered_icon(texture: Texture2D, visual_size: int) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(UiKit.image(texture, visual_size))
	return center

func _start_name_edit() -> void:
	name_label.visible = false
	name_edit.visible = true
	name_edit.grab_focus()
	name_edit.select_all()
	name_edit_started.emit()

func _finish_name_edit() -> void:
	if not name_edit.visible:
		return
	if not _name_error(name_edit.text.strip_edges()).is_empty():
		return
	_show_name_label()
	name_edit_finished.emit()

func _show_name_label() -> void:
	name_label.text = name_edit.text.strip_edges()
	name_edit.visible = false
	name_label.visible = true

func _stats_text(stats: Dictionary) -> String:
	if stats.is_empty():
		return "No statistics yet."
	var lines: PackedStringArray = []
	for key in stats:
		lines.append("%s: %s" % [str(key).capitalize(), str(stats[key])])
	return "\n".join(lines)

func _name_error(player_name: String) -> String:
	if player_name.is_empty():
		return "Enter a name."
	if PlayerDatabase.has_name(player_name, _id):
		return "This name is already registered."
	return ""

func _update_buttons() -> void:
	var error := _name_error(name_edit.text.strip_edges())
	hint_label.text = error
	save_button.disabled = not error.is_empty()
	select_button.disabled = not error.is_empty()

func _save_and(then: Callable) -> void:
	var player_name := name_edit.text.strip_edges()
	if not _name_error(player_name).is_empty():
		return
	_finish_name_edit()
	if _id.is_empty():
		_id = PlayerDatabase.add_player(player_name)
	else:
		PlayerDatabase.rename_player(_id, player_name)
	if not _pending_photo.is_empty():
		PlayerDatabase.set_photo(_id, _pending_photo)
		_pending_photo = ""
	then.call()

func _choose_photo() -> void:
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.filters = PackedStringArray(PHOTO_FILTERS)
		_file_dialog.title = "Choose a photo"
		_file_dialog.file_selected.connect(_on_photo_selected)
		add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.7)

func _on_photo_selected(path: String) -> void:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		hint_label.text = "This image cannot be read."
		return
	_pending_photo = path
	photo_rect.texture = ImageTexture.create_from_image(image)
