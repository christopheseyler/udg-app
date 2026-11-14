class_name RulesPanel
extends SlidePanel

## Panneau des regles du jeu choisi, ouvert par le bouton Rules du panneau de
## configuration (comme Players et Options). Les regles sont le texte
## markdown-like de GameDefinition.rules, affiche par un MarkdownView (voir
## sa syntaxe), avec defilement si elles depassent la hauteur du panneau.

@onready var rules_view: MarkdownView = $Layout/Margin/RulesView

func set_rules(markdown: String) -> void:
	rules_view.set_markdown(markdown)
