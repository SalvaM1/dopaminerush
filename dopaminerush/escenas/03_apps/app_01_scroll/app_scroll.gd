extends AppBase

# ============================================================
#  TikBrainRot — scroll infinito
# ============================================================
#
# FLUJO DE UN VIDEO:
#
#   1. Se carga un video (color nuevo, descripcion nueva, barra en 0).
#   2. La barra de progreso se llena en DURACION_VIDEO segundos.
#      Mientras se llena, gotea dopamina.
#   3. Manteniendo apretado el boton izquierdo, la barra se llena al
#      DOBLE de velocidad y el goteo tambien se duplica.
#      (Solo si el 2x ya esta desbloqueado: pasa cuando la dopamina
#       baja de UMBRAL_2X por primera vez en la partida.)
#   4. Cuando la barra llega al 100%, el goteo se corta.
#   5. Recien ahi se puede arrastrar de abajo hacia arriba para pasar
#      al siguiente. Ese gesto da un bonus de recompensa variable.
#   6. Si se intenta arrastrar antes, la pantalla da un destello y
#      no pasa nada.

# ---- BALANCEO ----
const DURACION_VIDEO: float = 5.0          # segundos a velocidad normal
const VELOCIDAD_RAPIDA: float = 2.0        # multiplicador al mantener apretado
const UMBRAL_2X: float = 60.0              # dopamina a la que se desbloquea el 2x
const DISTANCIA_SCROLL: float = 250      # pixeles a arrastrar para pasar
const PROB_JACKPOT: float = 0.15
const MULT_JACKPOT: float = 3.0

# Para probar la escena sola con F6. En el juego real dejar en false.
@export var forzar_2x_desbloqueado: bool = false

# ---- NODOS ----
@onready var video: ColorRect = $Telefono/Video
@onready var descripcion: Label = $Telefono/Descripcion
@onready var barra: ProgressBar = $Telefono/BarraProgreso
@onready var etiqueta_velocidad: Label = $Telefono/Velocidad
@onready var aviso: Label = $Telefono/Aviso
@onready var indicador: Label = $Telefono/Indicador
@onready var acciones: VBoxContainer = $Telefono/Acciones

# ---- ESTADO ----
var _progreso: float = 0.0        # 0.0 a 1.0
var _manteniendo: bool = false
var _acumulado: float = 0.0       # pixeles arrastrados hacia arriba
var _numero_video: int = 0
var _x2_desbloqueado: bool = false
var _tween_destello: Tween = null


func _ready() -> void:
	barra.show_percentage = false
	barra.min_value = 0.0
	barra.max_value = 100.0
	barra.value = 0.0

	etiqueta_velocidad.hide()
	aviso.hide()
	indicador.modulate.a = 0.0

	_x2_desbloqueado = forzar_2x_desbloqueado

	GameManager.dopamina_cambio.connect(_al_cambiar_dopamina)

	_cargar_video()

	# Si la app se abre sola (F6) nadie llama a iniciar(), asi que la
	# arrancamos nosotros. Dentro del escritorio, la ventana ya la inicio
	# y este chequeo no hace nada.
	await get_tree().process_frame
	if not esta_activa:
		iniciar()


func _process(delta: float) -> void:
	if not esta_activa:
		return

	# El video ya termino: no gotea nada hasta que se deslice.
	if _progreso >= 1.0:
		return

	var velocidad := 1.0
	if _manteniendo and _x2_desbloqueado:
		velocidad = VELOCIDAD_RAPIDA

	# Un solo numero mueve las dos cosas: el progreso y el goteo.
	_progreso = min(1.0, _progreso + (delta * velocidad) / DURACION_VIDEO)
	barra.value = _progreso * 100.0


	if _progreso >= 1.0:
		_actualizar_velocidad()


# ============================================================
#  Input
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_manteniendo = event.pressed
		_acumulado = 0.0
		_actualizar_velocidad()
		return

	if event is InputEventMouseMotion and _manteniendo:
		# relative.y negativo = el mouse va hacia ARRIBA
		if event.relative.y < 0:
			_acumulado += -event.relative.y
		else:
			_acumulado = 0.0   # cambio de direccion: se reinicia

		if _acumulado >= DISTANCIA_SCROLL:
			_acumulado = 0.0
			_intentar_pasar()


func _intentar_pasar() -> void:
	if _progreso < 1.0:
		_destello(Color(1.3, 1.3, 1.3))   # "todavia no"
		return

	_dar_bonus()
	_cargar_video()


# ============================================================
#  Videos
# ============================================================

func _cargar_video() -> void:
	_numero_video += 1
	_progreso = 0.0
	barra.value = 0.0

	# Color aleatorio como placeholder. En la fase F esto es un video real.
	video.color = Color.from_hsv(randf(), 0.55, 0.85)

	descripcion.text = "%s\n%s" % [
		USUARIOS[randi() % USUARIOS.size()],
		SONIDOS[randi() % SONIDOS.size()]
	]

	_randomizar_acciones()
	_actualizar_velocidad()


func _dar_bonus() -> void:
	if randf() < PROB_JACKPOT:
		recompensar(MULT_JACKPOT)
		_mostrar_indicador("+%d" % int(dopamina_por_interaccion * MULT_JACKPOT), Color.YELLOW)
	else:
		recompensar()
		_mostrar_indicador("+%d" % int(dopamina_por_interaccion), Color.WHITE)


const USUARIOS := ["@brainrot_daily", "@sigma_edits", "@fyp_content",
	"@viral4u", "@nocap_clips", "@slop_central", "@dopamine.mp4"]
const SONIDOS := ["sonido original", "audio viral", "remix acelerado",
	"phonk edit", "sped up + reverb", "sonido original"]


# Numeritos decorativos de likes / comentarios / compartidos.
func _randomizar_acciones() -> void:
	var textos := [
		"♥\n%.1fK" % randf_range(1.0, 900.0),
		"💬\n%d" % randi_range(12, 4800),
		"↗\n%.1fK" % randf_range(0.5, 90.0),
	]
	for i in range(acciones.get_child_count()):
		if i < textos.size():
			var etiqueta := acciones.get_child(i) as Label
			if etiqueta:
				etiqueta.text = textos[i]


# ============================================================
#  Desbloqueo del 2x
# ============================================================

func _al_cambiar_dopamina(valor: float, _maximo: float) -> void:
	if _x2_desbloqueado:
		return
	if valor <= UMBRAL_2X:
		_x2_desbloqueado = true
		_mostrar_aviso("Mantené apretado\npara ver a 2x")


func _actualizar_velocidad() -> void:
	etiqueta_velocidad.visible = _manteniendo and _x2_desbloqueado and _progreso < 1.0
	etiqueta_velocidad.text = "2x"


# ============================================================
#  Feedback visual (se pule en la fase H)
# ============================================================

func _mostrar_indicador(texto: String, color: Color) -> void:
	indicador.text = texto
	indicador.modulate = color
	indicador.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_property(indicador, "modulate:a", 0.0, 0.7)


# Destello sin mover nada de lugar: no puede acumular error de posicion.
func _destello(color: Color) -> void:
	if _tween_destello and _tween_destello.is_running():
		_tween_destello.kill()
	video.modulate = color
	_tween_destello = create_tween()
	_tween_destello.tween_property(video, "modulate", Color.WHITE, 0.18)


func _mostrar_aviso(texto: String) -> void:
	aviso.text = texto
	aviso.modulate.a = 1.0
	aviso.show()

	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(aviso, "modulate:a", 0.0, 0.8)
	tween.tween_callback(aviso.hide)
