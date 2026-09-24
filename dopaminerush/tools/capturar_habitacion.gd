extends Node3D

const DIRECTORIO_SALIDA := "res://capturas/habitacion"

@onready var habitacion: Node3D = $Habitacion
@onready var camara: Camera3D = $CamaraCaptura

var tomas := [
	{
		"archivo": "01_general.png",
		"posicion": Vector3(0.7, 4.5, 8.4),
		"objetivo": Vector3(0.5, 2.1, -2.8),
	},
	{
		"archivo": "02_cama_despertador.png",
		"posicion": Vector3(0.8, 3.15, 1.2),
		"objetivo": Vector3(-3.8, 1.65, -3.25),
	},
	{
		"archivo": "03_escritorio.png",
		"posicion": Vector3(0.2, 3.1, 1.0),
		"objetivo": Vector3(3.45, 2.05, -2.9),
	},
	{
		"archivo": "04_televisor_puerta.png",
		"posicion": Vector3(2.2, 3.4, -3.5),
		"objetivo": Vector3(8.1, 2.75, 4.0),
	},
	{
		"archivo": "05_ventana_exterior.png",
		"posicion": Vector3(0.8, 3.2, -1.0),
		"objetivo": Vector3(-4.5, 3.35, -8.75),
	},
]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SceneLoader.visible = false

	var despertador := habitacion.get_node_or_null("Despertador/Sonido") as AudioStreamPlayer3D
	if despertador:
		despertador.stop()
	var cuerpo_jugador := habitacion.get_node_or_null("Jugador/MeshInstance3D") as MeshInstance3D
	if cuerpo_jugador:
		cuerpo_jugador.hide()
	var pantalla_apagada := habitacion.get_node_or_null("PantallaViewport/Apagada") as ColorRect
	var escritorio_virtual := habitacion.get_node_or_null("PantallaViewport/Escritorio") as CanvasLayer
	if pantalla_apagada:
		pantalla_apagada.hide()
	if escritorio_virtual:
		escritorio_virtual.show()

	var salida_absoluta := ProjectSettings.globalize_path(DIRECTORIO_SALIDA)
	DirAccess.make_dir_recursive_absolute(salida_absoluta)

	await get_tree().process_frame
	await get_tree().process_frame

	for toma in tomas:
		camara.global_position = toma["posicion"]
		camara.look_at(toma["objetivo"], Vector3.UP)
		camara.current = true
		await get_tree().process_frame
		await RenderingServer.frame_post_draw

		var imagen := get_viewport().get_texture().get_image()
		var ruta := DIRECTORIO_SALIDA.path_join(toma["archivo"])
		var error := imagen.save_png(ruta)
		if error != OK:
			push_error("No se pudo guardar la captura: " + ruta)

	print("CAPTURAS_HABITACION_OK")
	get_tree().quit()
