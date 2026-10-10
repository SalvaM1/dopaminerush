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

# ---- ANIMACIONES ----
# La ventana no aparece: ENTRA. Un cuadro que se materializa de golpe se
# lee como un cambio de estado; uno que crece un poco se lee como algo
# que se abrio. Son 0.2 segundos y cambian por completo la sensacion de
# que esto es un sistema operativo y no una pantalla de menu.
const ENTRADA: float = 0.2
const SALIDA: float = 0.13
const ESCALA_INICIAL: float = 0.93

const ALTO_BARRA: float = 38.0

@onready var barra_titulo: Panel = $Layout/BarraTitulo
@onready var titulo: Label = $Layout/BarraTitulo/Titulo
@onready var boton_cerrar: Button = $Layout/BarraTitulo/BotonCerrar
@onready var boton_minimizar: Button = $Layout/BarraTitulo/BotonMinimizar
@onready var contenido: Control = $Layout/Contenido

var app = null

# Para arrastrar la ventana
var _arrastrando: bool = false
var _offset_arrastre: Vector2
var _cerrando: bool = false
var _activa: bool = true


func _ready() -> void:
	boton_cerrar.pressed.connect(cerrar)
	barra_titulo.gui_input.connect(_input_barra_titulo)

	# El de minimizar no hace nada: esta para que la ventana se vea como
	# una ventana. Igual tiembla, asi el jugador sabe que lo apreto.
	boton_minimizar.pressed.connect(_al_minimizar)


# Recibe la ESCENA de una app (un PackedScene) y la mete adentro.
func abrir(escena_app: PackedScene) -> void:
	app = escena_app.instantiate()
	contenido.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	titulo.text = app.nombre_app
	size = app.tamano_ventana
	app.iniciar()

	_animar_entrada()


# Crece desde un poco mas chica y se desvanece hacia adentro. El pivote
# va al centro para que crezca desde el medio y no desde la esquina.
func _animar_entrada() -> void:
	pivot_offset = size * 0.5
	scale = Vector2.ONE * ESCALA_INICIAL
	modulate.a = 0.0

	var t := create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, ENTRADA)
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, ENTRADA * 0.7)


func cerrar() -> void:
	if _cerrando:
		return
	_cerrando = true

	if app:
		app.detener()
		cerrada.emit(app)

	# Se achica y se va. Avisamos ANTES de animar: el escritorio tiene
	# que poder dar la ventana por cerrada enseguida, aunque el dibujo
	# tarde una decima mas en desaparecer.
	pivot_offset = size * 0.5
	var t := create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "scale", Vector2.ONE * 0.94, SALIDA)
	t.tween_property(self, "modulate:a", 0.0, SALIDA)
	await t.finished

	queue_free()


# Marca la ventana como la que tiene el foco. En un escritorio con seis
# ventanas abiertas, saber cual esta adelante no es decoracion: es lo
# unico que te dice sobre cual vas a escribir.
func marcar_activa(activa: bool) -> void:
	if _activa == activa:
		return
	_activa = activa

	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.tween_property(barra_titulo, "modulate",
		Color.WHITE if activa else Color(0.62, 0.64, 0.7, 1.0), 0.16)


func _al_minimizar() -> void:
	# No minimiza nada. Solo tiembla, como cualquier boton que no hace
	# lo que promete.
	Juice.tambalear(self, 1.5, 0.25)


# --- Arrastrar la ventana desde la barra de título ---
func _input_barra_titulo(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_arrastrando = event.pressed
		if _arrastrando:
			_offset_arrastre = get_global_mouse_position() - global_position
			# traer la ventana al frente
			get_parent().move_child(self, -1)
			traida_al_frente.emit(self)


signal traida_al_frente(ventana)


func _process(_delta: float) -> void:
	if not _arrastrando:
		return

	# Se mantiene dentro de la pantalla: una ventana que se va de los
	# bordes y se lleva su barra de titulo no se puede volver a agarrar.
	var limite: Vector2 = get_viewport_rect().size
	var destino: Vector2 = get_global_mouse_position() - _offset_arrastre
	destino.x = clamp(destino.x, -size.x + 120.0, limite.x - 120.0)
	destino.y = clamp(destino.y, 0.0, limite.y - ALTO_BARRA)
	global_position = destino
