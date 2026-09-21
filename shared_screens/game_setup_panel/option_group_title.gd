class_name OptionGroupTitle
extends VBoxContainer

## Titre d'un groupe d'options : le nom du groupe avec une ligne en dessous.
## Appeler setup() une fois l'element ajoute a l'arbre : {"name": String}

@onready var title_label: Label = $TitleLabel

func setup(option: Dictionary) -> void:
	title_label.text = option["name"]
