class_name SimulatedDartInput
extends DartInput

## Source de jets simulee, a la place de la carte UART : les jets sont
## injectes par le code (simulate_hit) ou par le panneau DartSimulator.

func simulate_hit(hit: DartHit) -> void:
	hit_detected.emit(hit)
