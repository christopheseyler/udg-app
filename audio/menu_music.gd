extends Node

## Musique de fond des menus (autoload MenuMusic) : menu_music3 en boucle, a
## faible volume, de l'ecran de selection des jeux jusqu'au lancement d'une
## partie. play() la demarre en fondu (sans effet si elle joue deja), stop()
## l'arrete en fondu. L'ecran de selection la demarre a son ouverture, l'arrete
## au lancement d'une partie et la relance au retour de la partie.

const MUSIC := preload("res://assets/sounds/sfx/menu_music3.mp3")
## Volume de croisiere : musique de fond, sous les sons et les annonces
## vocales (le morceau est mixe fort, environ -9 dBFS RMS).
const VOLUME_DB := -22.0
const FADE_IN_DURATION := 2.5
const FADE_OUT_DURATION := 1.5

var _player: AudioStreamPlayer
var _tween: Tween

func _ready() -> void:
	# Copie : la boucle ne s'applique qu'a cette musique, pas a la ressource
	# importee (importee sans boucle, comme les autres mp3).
	var stream: AudioStreamMP3 = MUSIC.duplicate()
	stream.loop = true
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	add_child(_player)

func is_playing() -> bool:
	return _player.playing

## Demarre la musique depuis le debut en fondu, ou, si un stop() est en
## cours, remonte le volume depuis son niveau actuel.
func play() -> void:
	if _tween:
		_tween.kill()
	if not _player.playing:
		_player.volume_linear = 0.0
		_player.play()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_linear", db_to_linear(VOLUME_DB), FADE_IN_DURATION)

## Baisse la musique en fondu puis l'arrete.
func stop() -> void:
	if not _player.playing:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_linear", 0.0, FADE_OUT_DURATION)
	_tween.tween_callback(_player.stop)
