extends Node

## Base de donnees des joueurs inscrits (autoload PlayerDatabase). Chaque
## joueur est une fiche : identifiant, nom, photo optionnelle et
## statistiques (dictionnaire libre, rempli par les jeux plus tard).
## Les fiches sont enregistrees dans user://players/players.json, les photos
## dans user://players/photos/<id>.png (copiees et reduites a l'import).

signal changed

const DIR := "user://players"
const PHOTO_DIR := "user://players/photos"
const DB_PATH := "user://players/players.json"
## Cote maximal (en pixels) des photos conservees.
const PHOTO_MAX_SIZE := 512

var _players: Array[Dictionary] = []
var _photo_cache: Dictionary = {}

func _ready() -> void:
	_load()

## Fiches triees par nom (copies : les modifier ne change pas la base).
func get_players() -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	for player in _players:
		players.append(player.duplicate(true))
	players.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
	return players

func get_player(id: String) -> Dictionary:
	var index := _index_of(id)
	return _players[index].duplicate(true) if index >= 0 else {}

func has_name(player_name: String, except_id := "") -> bool:
	for player in _players:
		if player.id != except_id and player.name.nocasecmp_to(player_name) == 0:
			return true
	return false

## Inscrit un nouveau joueur et renvoie son identifiant.
func add_player(player_name: String) -> String:
	var id := "%d_%04d" % [int(Time.get_unix_time_from_system() * 1000.0), randi() % 10000]
	_players.append({"id": id, "name": player_name, "photo": "", "stats": {}})
	_save()
	return id

func rename_player(id: String, player_name: String) -> void:
	var index := _index_of(id)
	if index < 0:
		return
	_players[index].name = player_name
	_save()

func remove_player(id: String) -> void:
	var index := _index_of(id)
	if index < 0:
		return
	var photo: String = _players[index].photo
	if not photo.is_empty():
		DirAccess.remove_absolute(photo)
	_photo_cache.erase(id)
	_players.remove_at(index)
	_save()

## Importe l'image `source_path` comme photo du joueur. Renvoie false si
## l'image ne peut pas etre lue.
func set_photo(id: String, source_path: String) -> bool:
	var index := _index_of(id)
	if index < 0:
		return false
	var image := Image.load_from_file(source_path)
	if image == null or image.is_empty():
		return false
	var longest := maxi(image.get_width(), image.get_height())
	if longest > PHOTO_MAX_SIZE:
		var ratio := float(PHOTO_MAX_SIZE) / longest
		image.resize(roundi(image.get_width() * ratio), roundi(image.get_height() * ratio),
				Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(PHOTO_DIR)
	var path := "%s/%s.png" % [PHOTO_DIR, id]
	if image.save_png(path) != OK:
		return false
	_players[index].photo = path
	_photo_cache[id] = ImageTexture.create_from_image(image)
	_save()
	return true

## Photo du joueur, ou null s'il n'en a pas.
func get_photo(id: String) -> Texture2D:
	if _photo_cache.has(id):
		return _photo_cache[id]
	var index := _index_of(id)
	if index < 0 or _players[index].photo.is_empty():
		return null
	var image := Image.load_from_file(_players[index].photo)
	if image == null or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(image)
	_photo_cache[id] = texture
	return texture

func _index_of(id: String) -> int:
	for i in _players.size():
		if _players[i].id == id:
			return i
	return -1

func _load() -> void:
	_players.clear()
	if not FileAccess.file_exists(DB_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(DB_PATH))
	if not data is Dictionary or not data.get("players") is Array:
		push_warning("PlayerDatabase : %s illisible" % DB_PATH)
		return
	for entry in data.players:
		if entry is Dictionary and entry.has("id") and entry.has("name"):
			_players.append({
				"id": str(entry.id),
				"name": str(entry.name),
				"photo": str(entry.get("photo", "")),
				"stats": entry.get("stats", {}) if entry.get("stats") is Dictionary else {},
			})

func _save() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(DB_PATH, FileAccess.WRITE)
	if file == null:
		push_error("PlayerDatabase : ecriture de %s impossible" % DB_PATH)
		return
	file.store_string(JSON.stringify({"version": 1, "players": _players}, "\t"))
	file.close()
	changed.emit()
