extends Node

# Autoload registrado como "AudioManager".
# Maneja las capas de sonido que se van acumulando a medida que se abren apps.
#
# POR AHORA ES UN ESQUELETO: las funciones existen pero no hacen nada.
# Sirve para que las apps puedan llamarlas sin romperse.
# Se implementa de verdad en el Bloque 5 (pasos 27 a 29).

# Diccionario: nombre de la app -> su reproductor de audio
var _capas: Dictionary = {}


# La llama una app cuando se abre. Enciende su capa de sonido.
func iniciar_capa(nombre: String) -> void:
	print("[AudioManager] iniciar_capa: ", nombre)
	# TODO paso 28: crear/reproducir el AudioStreamPlayer de esta app


# La llama una app cuando se cierra. Apaga su capa de sonido.
func detener_capa(nombre: String) -> void:
	print("[AudioManager] detener_capa: ", nombre)
	# TODO paso 28: detener el AudioStreamPlayer de esta app


# Corta TODO el audio de golpe. Se usa en el corte de luz (paso 39).
func silenciar_todo() -> void:
	print("[AudioManager] silenciar_todo")
	# TODO paso 39: detener todas las capas al instante
