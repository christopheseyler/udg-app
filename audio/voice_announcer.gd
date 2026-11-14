class_name VoiceAnnouncer
extends Node

## Annonces vocales des jeux (cree par GameScreen) : joue les phrases d'un
## pack de voix, VOICES_DIR/<pack>/<cle>.mp3 (un dossier par annonceur, une
## phrase par fichier : player_01 a player_08, remove_darts, last_round,
## missed, game_shot = "We have a winner", bust, zap...).
##
## Une seule voix a la fois. Une annonce interruptible (ex. "Player two",
## "Remove your darts") est coupee par l'annonce suivante ; les autres vont
## jusqu'au bout et les suivantes attendent leur tour (ex. "Missed" sur la
## derniere fleche, puis "Remove your darts"). Une annonce interruptible
## encore en attente est abandonnee des qu'une autre est demandee : elle
## n'est plus d'actualite.

const VOICES_DIR := "res://assets/sounds/voices/"

## Pack de voix utilise (nom de son dossier dans VOICES_DIR).
var pack := "party_announcer_1022"

var _player: AudioStreamPlayer
var _current_interruptible := true
## Annonces en attente, dans l'ordre : {"key", "stream", "interruptible"}.
var _queue: Array[Dictionary] = []
## Phrases deja chargees (null : absente du pack).
var _streams: Dictionary[String, AudioStream] = {}

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_play_next)

## Annonce la phrase key du pack (sans effet s'il ne l'a pas). Une phrase
## deja en attente n'est pas ajoutee une seconde fois (jets rates en rafale).
func say(key: String, interruptible := false) -> void:
	var stream := _stream(key)
	if stream == null:
		return
	_queue.assign(_queue.filter(func(entry: Dictionary) -> bool: return not entry.interruptible))
	if _player.playing and (not _current_interruptible or not _queue.is_empty()):
		if not _queue.any(func(entry: Dictionary) -> bool: return entry.key == key):
			_queue.append({"key": key, "stream": stream, "interruptible": interruptible})
		return
	_start(stream, interruptible)

func _start(stream: AudioStream, interruptible: bool) -> void:
	_current_interruptible = interruptible
	_player.stream = stream
	_player.play()

func _play_next() -> void:
	if _queue.is_empty():
		return
	var entry: Dictionary = _queue.pop_front()
	_start(entry.stream, entry.interruptible)

func _stream(key: String) -> AudioStream:
	if not _streams.has(key):
		var path := VOICES_DIR + pack + "/" + key + ".mp3"
		_streams[key] = load(path) if ResourceLoader.exists(path) else null
	return _streams[key]
