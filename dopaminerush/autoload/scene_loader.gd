extends CanvasLayer

# Autoload registrado como "SceneLoader".
# Se encarga de cambiar de escena con un fundido, para que las transiciones
# no sean cortes bruscos.
#
# Uso desde cualquier script:
#   SceneLoader.cambiar_escena("res://escenas/04_parque/parque.tscn")
#   SceneLoader.cambiar_escena("res://escenas/05_creditos/creditos.tscn", Color.WHITE, 2.0)
#
# Tambien se puede usar el fundido solo, sin cambiar de escena:
#   await SceneLoader.fundir_a(Color.BLACK, 1.0)

const DURACION_DEFAULT: float = 0.5

var _panel: ColorRect


func _ready() -> void:
	# layer alto = se dibuja por encima de todo lo demas
	layer = 128
	# que el fundido siga funcionando aunque el juego este pausado
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = ColorRect.new()
	_panel.color = Color(0, 0, 0, 0)   # negro pero totalmente transparente
	# que no bloquee los clicks de la interfaz que esta abajo
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# El panel cuelga de un CanvasLayer, que no es un Control, asi que las
	# anclas no tienen contra que anclarse. Le damos el tamaño a mano.
	_ajustar_tamano()
	get_viewport().size_changed.connect(_ajustar_tamano)


func _ajustar_tamano() -> void:
	_panel.position = Vector2.ZERO
	_panel.size = get_viewport().get_visible_rect().size


# Funde a un color, cambia de escena, y funde de vuelta.
func cambiar_escena(ruta: String, color := Color.BLACK, duracion := DURACION_DEFAULT) -> void:
	await fundir_a(color, duracion)
	get_tree().change_scene_to_file(ruta)
	# esperamos un frame para que la escena nueva termine de cargar
	await get_tree().process_frame
	await fundir_desde(duracion)


# Oscurece la pantalla hasta tapar todo.
func fundir_a(color := Color.BLACK, duracion := DURACION_DEFAULT) -> void:
	_panel.color = Color(color.r, color.g, color.b, _panel.color.a)
	var tween := create_tween()
	tween.tween_property(_panel, "color:a", 1.0, duracion)
	await tween.finished


# Devuelve la vista: el panel se vuelve transparente.
func fundir_desde(duracion := DURACION_DEFAULT) -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "color:a", 0.0, duracion)
	await tween.finished


# Tapa la pantalla al instante, sin animacion (para el corte de luz del paso 39).
func tapar_ya(color := Color.BLACK) -> void:
	_panel.color = Color(color.r, color.g, color.b, 1.0)
