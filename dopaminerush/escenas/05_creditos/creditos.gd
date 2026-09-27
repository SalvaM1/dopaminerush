extends Control

# Creditos. El contenido lo maneja el addon (credits-template), que vive
# en su propio nodo hijo. Este script solo se encarga de tres cosas:
#   - devolver el cursor (venimos del parque, donde estaba capturado)
#   - resetear el estado del juego para la proxima partida
#   - permitir volver al menu con Esc, pero no enseguida

const ESPERA_SALIDA: float = 10.0

@onready var aviso: Label = $AvisoSalir

var _puede_salir: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.reiniciar()

	aviso.modulate.a = 0.0

	# Los primeros segundos no se puede salir: que nadie se saltee
	# el final por apoyar una tecla sin querer.
	await get_tree().create_timer(ESPERA_SALIDA).timeout

	_puede_salir = true
	var tween := create_tween()
	tween.tween_property(aviso, "modulate:a", 1.0, 1.5)


func _input(event: InputEvent) -> void:
	if not _puede_salir:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_puede_salir = false
		SceneLoader.cambiar_escena("res://escenas/00_menu/menu.tscn")
