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
# OJO: esto NO es la duracion del video, es el COOLDOWN. Los clips duran
# lo que duran y vuelven a empezar solos si se terminan antes de que
# deslices: son dos relojes distintos.
const DURACION_VIDEO: float = 8.0          # segundos a velocidad normal
const VELOCIDAD_RAPIDA: float = 2.0        # multiplicador al mantener apretado
const UMBRAL_2X: float = 60.0              # dopamina a la que se desbloquea el 2x
const DISTANCIA_SCROLL: float = 250      # pixeles a arrastrar para pasar

# RECOMPENSA VARIABLE: casi siempre entra dopamina_por_interaccion, y un
# 15% de las veces entra DOPAMINA_JACKPOT. Se guarda como numero absoluto
# y no como multiplicador para que cambiar la base no mueva el premio.
# Los tres numeros se mueven JUNTOS. El rendimiento de la app es
# dopamina / DURACION_VIDEO, asi que estirar el cooldown sin subir la
# dopamina la deja rindiendo menos y desequilibra el juego entero.
#   8 s y 16 de dopamina  -> 2.00/s, igual que 5 s y 10
#   jackpot = el doble de la base, como siempre
const PROB_JACKPOT: float = 0.15
const DOPAMINA_JACKPOT: float = 32.0

# ---- LOS VIDEOS ----
# Godot solo reproduce Ogg Theora (.ogv). Todos los .ogv que haya en esta
# carpeta entran al mazo solos: no hay que anotarlos en ningun lado, se
# agregan copiando el archivo.
#
# OJO CON LA BARRA: la barra NO es la duracion del video, es el COOLDOWN.
# El video dura lo que dure y vuelve a empezar solo si se termina antes
# de que deslices, igual que en la app real. Son dos relojes distintos y
# tienen que seguir siendolo: si la barra dependiera del video, un clip
# largo haria esperar medio minuto y uno corto regalaria la dopamina.
const CARPETA_VIDEOS := "res://assets/video/scroll/"

# EL TONO DEL 2x. speed_scale acelera el stream entero, asi que el audio
# tambien sube de tono y queda voz de ardilla. Para evitarlo, el video
# tiene su propio bus con un AudioEffectPitchShift: al acelerar se
# enciende con pitch_scale 0.5, que baja justo una octava y compensa
# exactamente el x2. El tempo se mantiene al doble; solo vuelve el tono.
#
# Es un efecto de FFT, asi que algo de artefacto mete. Si al escucharlo
# molesta mas de lo que suma, con poner CORREGIR_TONO en false se vuelve
# al comportamiento anterior.
const CORREGIR_TONO: bool = true
const BUS_VIDEO := "Video"

# Para probar la escena sola con F6. En el juego real dejar en false.
@export var forzar_2x_desbloqueado: bool = false

# ---- NODOS ----
@onready var video: ColorRect = $Telefono/Video
@onready var marco_video: Control = $Telefono/MarcoVideo
@onready var reproductor: VideoStreamPlayer = $Telefono/MarcoVideo/Reproductor
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

var _videos: Array[String] = []
var _ultimo_video: String = ""
var _tam_video_previo: Vector2 = Vector2.ZERO
var _tam_marco_previo: Vector2 = Vector2.ZERO


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

	_buscar_videos()
	_cargar_video()

	# Si la app se abre sola (F6) nadie llama a iniciar(), asi que la
	# arrancamos nosotros. Dentro del escritorio, la ventana ya la inicio
	# y este chequeo no hace nada.
	await get_tree().process_frame
	if not esta_activa:
		iniciar()


# Si hay videos, NO se arranca la capa de audio de la app: los clips ya
# traen su propio sonido y las dos cosas juntas serian un ruido. Con la
# carpeta vacia la capa suena como siempre.
func iniciar() -> void:
	esta_activa = true
	if _videos.is_empty():
		AudioManager.iniciar_capa(id_app)


func _process(delta: float) -> void:
	if not esta_activa:
		return

	# Barato: solo recalcula si cambio el tamano del marco o del video.
	if reproductor.is_playing():
		_ajustar_video()

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


func detener() -> void:
	reproductor.stop()
	_corregir_tono(false)   # si no, el bus queda con el tono bajado
	super()


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

	# El color de atras se sortea igual: es lo que se ve si todavia no
	# hay videos, y tambien lo que asoma en los bordes si el clip no
	# tiene exactamente la proporcion de la ventana.
	video.color = Color.from_hsv(randf(), 0.55, 0.85)

	_poner_clip()

	descripcion.text = "%s\n%s" % [
		USUARIOS[randi() % USUARIOS.size()],
		SONIDOS[randi() % SONIDOS.size()]
	]

	_randomizar_acciones()
	_actualizar_velocidad()


# Busca los .ogv de la carpeta. Se miran los .import y .remap tambien
# porque en el juego exportado los archivos no se llaman igual que en el
# proyecto: sin esto, los videos andarian al probar y desaparecerian en
# el ejecutable final.
func _buscar_videos() -> void:
	_videos.clear()

	var dir := DirAccess.open(CARPETA_VIDEOS)
	if dir == null:
		print("[TikBrainRot] no existe la carpeta ", CARPETA_VIDEOS)
		_sin_videos()
		return

	var vistos := {}
	for archivo in dir.get_files():
		var nombre := archivo
		if nombre.ends_with(".import") or nombre.ends_with(".remap") or nombre.ends_with(".uid"):
			nombre = nombre.get_basename()
		if not nombre.ends_with(".ogv"):
			continue
		if vistos.has(nombre):
			continue
		vistos[nombre] = true
		_videos.append(CARPETA_VIDEOS + nombre)

	_videos.sort()

	if _videos.is_empty():
		print("[TikBrainRot] no hay .ogv en ", CARPETA_VIDEOS, " -- se usan colores")
		_sin_videos()
	else:
		print("[TikBrainRot] %d videos cargados" % _videos.size())


func _sin_videos() -> void:
	reproductor.hide()


# Elige uno al azar sin repetir el anterior, y lo arranca desde cero.
func _poner_clip() -> void:
	if _videos.is_empty():
		return

	var elegido: String = _videos[randi() % _videos.size()]
	if _videos.size() > 1:
		while elegido == _ultimo_video:
			elegido = _videos[randi() % _videos.size()]
	_ultimo_video = elegido

	var stream = load(elegido)
	if stream == null:
		push_warning("[TikBrainRot] no se pudo cargar " + elegido)
		return

	reproductor.stream = stream
	reproductor.show()
	reproductor.speed_scale = 1.0
	reproductor.play()

	# El clip nuevo puede tener otra medida que el anterior.
	_tam_video_previo = Vector2.ZERO


# Enciende o apaga el corrector de tono del bus del video.
func _corregir_tono(rapido: bool) -> void:
	if not CORREGIR_TONO:
		return

	var bus := AudioServer.get_bus_index(BUS_VIDEO)
	if bus < 0:
		return   # alguien saco el bus del layout: mejor sin tono que sin audio

	AudioServer.set_bus_effect_enabled(bus, 0, rapido)


# El video se escala a mano para que NUNCA se deforme. Con expand y los
# anclajes al marco, Godot lo estira hasta llenar el rectangulo, y como
# la ventana no tiene exactamente la proporcion de un 9:16, las caras
# salian apenas achatadas.
#
# Lo que hace es lo mismo que la app real: agranda el video hasta tapar
# todo el marco y recorta lo que sobra, en vez de deformarlo. Como el
# marco tiene clip_contents, lo que se pasa no se ve.
func _ajustar_video() -> void:
	var textura := reproductor.get_video_texture()
	if textura == null:
		return

	var tam_video: Vector2 = textura.get_size()
	if tam_video.x <= 0.0 or tam_video.y <= 0.0:
		return

	var tam_marco: Vector2 = marco_video.size
	if tam_marco.x <= 0.0 or tam_marco.y <= 0.0:
		return

	# Nada cambio: no hay que recalcular.
	if tam_video == _tam_video_previo and tam_marco == _tam_marco_previo:
		return
	_tam_video_previo = tam_video
	_tam_marco_previo = tam_marco

	# max() = tapar todo recortando. Con min() seria al reves: se veria
	# el cuadro entero pero con bandas negras.
	var escala: float = max(tam_marco.x / tam_video.x, tam_marco.y / tam_video.y)
	var final: Vector2 = tam_video * escala

	reproductor.size = final
	reproductor.position = (tam_marco - final) * 0.5


func _dar_bonus() -> void:
	if randf() < PROB_JACKPOT and dopamina_por_interaccion > 0.0:
		recompensar(DOPAMINA_JACKPOT / dopamina_por_interaccion)
		_mostrar_indicador("+%d" % int(DOPAMINA_JACKPOT), Color.YELLOW)
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
	var rapido: bool = _manteniendo and _x2_desbloqueado and _progreso < 1.0

	etiqueta_velocidad.visible = rapido
	etiqueta_velocidad.text = "2x"

	# speed_scale mueve el stream entero, imagen Y sonido. Por eso al
	# acelerar la voz suena mas aguda, igual que cuando adelantas un
	# video de verdad -- que es exactamente el efecto que se busca.
	if reproductor.stream != null:
		reproductor.speed_scale = VELOCIDAD_RAPIDA if rapido else 1.0

	_corregir_tono(rapido)


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
	var sobre: Control = marco_video if reproductor.visible else video
	sobre.modulate = color
	_tween_destello = create_tween()
	_tween_destello.tween_property(sobre, "modulate", Color.WHITE, 0.18)


func _mostrar_aviso(texto: String) -> void:
	aviso.text = texto
	aviso.modulate.a = 1.0
	aviso.show()

	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(aviso, "modulate:a", 0.0, 0.8)
	tween.tween_callback(aviso.hide)
