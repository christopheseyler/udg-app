class_name DartInput
extends Node

## Interface commune des sources de jets de fleche. Le jeu ne depend que de
## ce signal : la vraie carte d'interface (UART) et le simulateur en sont
## deux implementations interchangeables (voir DartInputManager.set_input()).
## Pour ajouter une source, etendre cette classe et emettre hit_detected a
## chaque fleche detectee ; comme c'est un Node, elle peut lire son port dans
## _process() ou un thread.

@warning_ignore("unused_signal")
signal hit_detected(hit: DartHit)
