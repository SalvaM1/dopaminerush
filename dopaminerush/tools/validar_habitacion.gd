extends Node

const RUTA_PARQUE := "res://escenas/04_parque/parque.tscn"

@onready var habitacion: Node3D = $Habitacion

var _fallos: int = 0


func _ready() -> void:
	SceneLoader.visible = false
	GameManager.reiniciar()

	var rutas_obligatorias := [
		"Jugador",
		"Despertador",
		"Monitor",
		"Monitor/Pantalla",
		"Monitor/Pantalla/AreaPantalla",
		"Monitor/PuntoSentado",
		"PantallaViewport",
		"PantallaViewport/Escritorio",
		"Puerta",
		"UI/CartelLevantarse",
		"HabitacionVisual/Televisor/PuntoInteraccionFuturo",
	]

	for ruta in rutas_obligatorias:
		_verificar(habitacion.get_node_or_null(ruta) != null, "Falta el nodo: " + ruta)

	var jugador = habitacion.get_node("Jugador")
	var despertador = habitacion.get_node("Despertador")
	var monitor = habitacion.get_node("Monitor")
	var puerta = habitacion.get_node("Puerta")
	var viewport: SubViewport = habitacion.get_node("PantallaViewport")
	var escritorio: CanvasLayer = habitacion.get_node("PantallaViewport/Escritorio")

	despertador.interactuar()
	await get_tree().process_frame
	_verificar(jugador.puede_mover, "El despertador no habilitó el movimiento")
	_verificar(not despertador.activo, "El despertador siguió activo después de usarlo")

	monitor.interactuar()
	await get_tree().create_timer(1.7).timeout
	_verificar(GameManager.activo, "La sesión de computadora no se inició")
	_verificar(escritorio.visible, "El escritorio virtual no se mostró")
	_verificar(viewport.get_texture() != null, "El monitor perdió la textura del SubViewport")

	var centro_pantalla := get_viewport().get_visible_rect().size * 0.5
	var punto_viewport: Vector2 = habitacion.call("_punto_en_viewport", centro_pantalla)
	_verificar(punto_viewport != Vector2(-1, -1), "El centro del monitor no acepta input traducido")

	GameManager.etapa_final = true
	GameManager.dopamina = 0.01
	GameManager.activo = true
	await get_tree().process_frame
	await get_tree().create_timer(2.2).timeout
	_verificar(habitacion.get("_puede_levantarse"), "El colapso no habilitó levantarse")

	habitacion.call("_levantarse")
	await get_tree().create_timer(1.7).timeout
	_verificar(puerta.activo, "La puerta no se habilitó al levantarse")
	_verificar(jugador.puede_mover, "El jugador no recuperó el movimiento al levantarse")
	_verificar(load(RUTA_PARQUE) is PackedScene, "La escena del parque no se puede cargar")

	if _fallos == 0:
		print("VALIDACION_HABITACION_OK")
		get_tree().quit(0)
	else:
		push_error("La validación de la habitación terminó con %d fallos" % _fallos)
		get_tree().quit(1)


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	_fallos += 1
	push_error(mensaje)

