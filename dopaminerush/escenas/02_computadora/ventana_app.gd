extends Panel

# Marco de ventana reutilizable, estilo sistema operativo.
# Sirve para CUALQUIER app: la app solo aporta su contenido, no su ventana.
# El tamaño lo define cada app (ver paso 22), no esta escena.
#
# Uso desde el escritorio:
#   var v = VENTANA.instantiate()
#   contenedor.add_child(v)
#   v.abrir(escena_de_la_app)

signal cerrada(app)

@onready var titulo: Label = $Layout/BarraTitulo/Titulo
@onready var boton_cerrar: Button = $Layout/BarraTitulo/BotonCerrar
@onready var contenido: Control = $Layout/Contenido

# En el paso 22, cuando exista AppBase, esto pasa a ser: var app: AppBase = null
var app = null

# Para arrastrar la ventana
var _arrastrando: bool = false
var _offset_arrastre: Vector2


func _ready() -> void:
	boton_cerrar.pressed.connect(cerrar)
	$Layout/BarraTitulo.gui_input.connect(_input_barra_titulo)


# Recibe la ESCENA de una app (un PackedScene) y la mete adentro.
func abrir(escena_app: PackedScene) -> void:
	app = escena_app.instantiate()
	contenido.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	titulo.text = app.nombre_app
	size = app.tamano_ventana
	app.iniciar()
	


func cerrar() -> void:
	if app:
		app.detener()
		cerrada.emit(app)
	queue_free()


# --- Arrastrar la ventana desde la barra de título ---
func _input_barra_titulo(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_arrastrando = event.pressed
		if _arrastrando:
			_offset_arrastre = get_global_mouse_position() - global_position
			# traer la ventana al frente
			get_parent().move_child(self, -1)


func _process(_delta: float) -> void:
	if _arrastrando:
		global_position = get_global_mouse_position() - _offset_arrastre
