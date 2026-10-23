class_name PlayerEditPanel
extends VBoxContainer

## Vue d'edition du nom d'un joueur. open() la prepare avec le nom courant ;
## name_confirmed est emis avec le nouveau nom (OK ou Entree), cancelled
## si l'utilisateur annule. Un nom vide ne peut pas etre valide.
## Le bouton base de donnees (database_requested) ouvre la base des joueurs
## inscrits.

signal name_confirmed(new_name: String)
signal cancelled
signal database_requested

@onready var name_edit: LineEdit = $NameRow/NameEdit
@onready var database_button: Button = $NameRow/DatabaseButton
@onready var ok_button: Button = $Buttons/OkButton
@onready var cancel_button: Button = $Buttons/CancelButton

func _ready() -> void:
	name_edit.text_changed.connect(func(_text: String): _update_ok_button())
	name_edit.text_submitted.connect(func(_text: String): _confirm())
	ok_button.pressed.connect(_confirm)
	cancel_button.pressed.connect(func(): cancelled.emit())
	database_button.pressed.connect(func(): database_requested.emit())
	PressScale.attach(database_button)
	PressScale.attach(ok_button)
	PressScale.attach(cancel_button)

func open(current_name: String) -> void:
	name_edit.text = current_name
	_update_ok_button()
	name_edit.grab_focus()
	name_edit.select_all()

## Nom en cours de saisie (sans espaces en debut / fin).
func get_current_name() -> String:
	return name_edit.text.strip_edges()

## Reprend la saisie apres un passage par la base des joueurs.
func resume() -> void:
	name_edit.grab_focus()

func _confirm() -> void:
	var new_name := name_edit.text.strip_edges()
	if new_name.is_empty():
		return
	name_confirmed.emit(new_name)

func _update_ok_button() -> void:
	ok_button.disabled = name_edit.text.strip_edges().is_empty()
