extends Control

# Menu principal. Deliberadamente minimo: titulo y dos botones.
# Sin opciones, sin configuracion.

@onready var boton_comenzar: Button = $BotonComenzar
@onready var boton_salir: Button = $BotonSalir


func _ready() -> void:
	# Por si venimos de una partida anterior: el cursor tiene que verse
	# y el estado del juego tiene que arrancar limpio.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.reiniciar()

	boton_comenzar.pressed.connect(_comenzar)
	boton_salir.pressed.connect(_salir)


func _comenzar() -> void:
	boton_comenzar.disabled = true
	boton_salir.disabled = true
	await SceneLoader.fundir_a(Color.BLACK, 1.0)
	get_tree().change_scene_to_file("res://escenas/01_habitacion/habitacion.tscn")


func _salir() -> void:
	get_tree().quit()
