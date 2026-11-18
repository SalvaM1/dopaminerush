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

# EL ORDEN DE LOS VIDEOS. Como en la app real, no se repite ninguno hasta
# haber visto todos: se arma una lista mezclada al azar y se recorre en
# orden. Cuando se termina, se vuelve a mezclar y arranca otra vuelta. El
# azar cambia cada vez que se abre el juego.
#
# El PRIMER video del juego sale de estos tres (cual de ellos, al azar):
# son los que mejor enganchan. Despues, todo al azar.
const PRIMEROS := ["clip_03.ogv", "clip_06.ogv", "clip_08.ogv"]

# La lista vive en el SCRIPT, no en la ventana: cerrar la app destruye la
# ventana, y reabrirla no tiene que reiniciar la lista ni volver a sacar
# uno de los primeros. Sigue donde quedo.
static var _lista: Array[String] = []
static var _ultimo_video: String = ""
static var _primera_vez: bool = true

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

# ---- EL 2x, QUE SE NOTE ----
# Sin dialogos: todo pasa adentro de la app, como en la de verdad.
#   1. Al desbloquearse, un cartel grande en el medio del video ("2x",
#      DESBLOQUEADO) que entra con rebote y sonido, y despues cae hacia abajo.
#   2. Ahi queda una pastilla latiendo, "MANTENE APRETADO » 2x", hasta que
#      el jugador lo usa por primera vez.
#   3. Mientras se usa: la pastilla rosa "2x »" arriba y la barra rosa.
# Desbloqueado y usado se anotan en GameManager (como los tutoriales):
# cerrar y reabrir la app no vuelve a anunciarlo, y una partida nueva si.
const ACENTO := Color(1.0, 0.17, 0.33)       # el rosa de la app
const ACENTO_2 := Color(0.15, 0.96, 0.93)    # el celeste
const USO_PARA_ENTENDER: float = 0.6         # segundos a 2x para dar por aprendido
const RUTA_SONIDO_X2 := "res://assets/audio/ui/levelup.wav"
const CLAVE_X2 := "x2_desbloqueado"
const CLAVE_X2_USADO := "x2_usado"

var _banner_x2: Control = null
var _x2_grande: Control = null
var _pista_x2: Label = null
var _latido_pista: Tween = null
var _tiempo_rapido: float = 0.0
var _rapido_antes: bool = false
var _snd_x2: AudioStreamPlayer = null
var _relleno_normal: StyleBox = null
var _relleno_rapido: StyleBoxFlat = null

var _videos: Array[String] = []
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

	_x2_desbloqueado = forzar_2x_desbloqueado or not GameManager.tutorial_pendiente(CLAVE_X2)
	_armar_x2()
	if _x2_desbloqueado and GameManager.tutorial_pendiente(CLAVE_X2_USADO):
		_mostrar_pista_x2()

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

	# Usarlo un ratito es haberlo entendido: se va la pista.
	if velocidad > 1.0 and _pista_x2 and _pista_x2.visible:
		_tiempo_rapido += delta
		if _tiempo_rapido >= USO_PARA_ENTENDER:
			GameManager.marcar_tutorial(CLAVE_X2_USADO)
			_ocultar_pista_x2()


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


# El siguiente de la lista, arrancado desde cero.
func _poner_clip() -> void:
	if _videos.is_empty():
		return

	var elegido := _siguiente_video()
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


# Saca el proximo video de la lista; si se termino, arma otra vuelta.
func _siguiente_video() -> String:
	# Un video que ya no esta (se borro el archivo) se saltea
	while not _lista.is_empty() and not _videos.has(_lista[0]):
		_lista.pop_front()
	if _lista.is_empty():
		_mezclar_lista()
	return _lista.pop_front()


func _mezclar_lista() -> void:
	_lista = _videos.duplicate()
	_lista.shuffle()

	if _primera_vez:
		_primera_vez = false
		var candidatos: Array[String] = []
		for nombre in PRIMEROS:
			if _videos.has(CARPETA_VIDEOS + nombre):
				candidatos.append(CARPETA_VIDEOS + nombre)
		if not candidatos.is_empty():
			var primero: String = candidatos[randi() % candidatos.size()]
			_lista.erase(primero)
			_lista.push_front(primero)
			return

	# La vuelta nueva no arranca con el mismo con el que termino la anterior
	if _lista.size() > 1 and _lista[0] == _ultimo_video:
		_lista.append(_lista.pop_front())


# Vuelve la lista a cero, como al abrir el juego (para los tests).
static func reiniciar_lista() -> void:
	_lista.clear()
	_ultimo_video = ""
	_primera_vez = true


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
		GameManager.marcar_tutorial(CLAVE_X2)
		_anunciar_x2()


func _actualizar_velocidad() -> void:
	var rapido: bool = _manteniendo and _x2_desbloqueado and _progreso < 1.0

	etiqueta_velocidad.visible = rapido
	if rapido and not _rapido_antes:
		etiqueta_velocidad.scale = Vector2(0.7, 0.7)
		var pop := create_tween()
		pop.tween_property(etiqueta_velocidad, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_rapido_antes = rapido
	if _relleno_rapido:
		barra.add_theme_stylebox_override("fill", _relleno_rapido if rapido else _relleno_normal)

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


# ============================================================
#  El 2x: el cartel, la pista y la pastilla
# ============================================================

func _armar_x2() -> void:
	var telefono: Control = $Telefono
	var fuente := ThemeDB.fallback_font

	# Mientras se usa: pastilla rosa arriba, al centro
	etiqueta_velocidad.text = "2x  \u00bb"
	etiqueta_velocidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta_velocidad.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta_velocidad.add_theme_color_override("font_color", Color.WHITE)
	etiqueta_velocidad.add_theme_font_size_override("font_size", 22)
	etiqueta_velocidad.add_theme_font_override("font", _negrita(fuente))
	etiqueta_velocidad.add_theme_stylebox_override("normal", _pildora(ACENTO, Color(0, 0, 0, 0), 0))
	etiqueta_velocidad.set_anchors_preset(Control.PRESET_CENTER_TOP)
	etiqueta_velocidad.offset_left = -52
	etiqueta_velocidad.offset_right = 52
	etiqueta_velocidad.offset_top = 54
	etiqueta_velocidad.offset_bottom = 90
	etiqueta_velocidad.pivot_offset = Vector2(52, 18)

	# La barra se pinta del mismo rosa mientras va rapido
	_relleno_normal = barra.get_theme_stylebox("fill")
	_relleno_rapido = StyleBoxFlat.new()
	_relleno_rapido.bg_color = ACENTO

	# El cartel del desbloqueo
	_banner_x2 = Control.new()
	_banner_x2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_x2.set_anchors_preset(Control.PRESET_CENTER)
	_banner_x2.offset_left = -140
	_banner_x2.offset_right = 140
	_banner_x2.offset_top = -120
	_banner_x2.offset_bottom = 90
	_banner_x2.pivot_offset = Vector2(140, 105)
	_banner_x2.visible = false
	telefono.add_child(_banner_x2)

	var fondo := Panel.new()
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.add_theme_stylebox_override("panel", _pildora(Color(0, 0, 0, 0.74), ACENTO, 3, 28))
	_banner_x2.add_child(fondo)

	# "2x" con el efecto del logo: una copia rosa y una celeste corridas
	_x2_grande = Control.new()
	_x2_grande.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_x2_grande.position = Vector2(0, 8)
	_x2_grande.size = Vector2(280, 120)
	_x2_grande.pivot_offset = Vector2(140, 60)
	_banner_x2.add_child(_x2_grande)
	for capa in [[ACENTO_2, -4.0], [ACENTO, 4.0], [Color.WHITE, 0.0]]:
		var l := _etiqueta_x2("2x", 104, capa[0], fuente)
		l.position = Vector2(capa[1], 0)
		l.size = Vector2(280, 120)
		_x2_grande.add_child(l)

	var titulo := _etiqueta_x2("DESBLOQUEADO", 15, Color(1, 1, 1, 0.9), fuente, 5)
	titulo.position = Vector2(0, 124)
	titulo.size = Vector2(280, 24)
	_banner_x2.add_child(titulo)
	var como := _etiqueta_x2("Mantené apretado el video", 17, Color(1, 1, 1, 0.75), fuente)
	como.position = Vector2(0, 154)
	como.size = Vector2(280, 28)
	_banner_x2.add_child(como)

	# La pista que queda hasta usarlo
	_pista_x2 = Label.new()
	_pista_x2.text = "MANTENÉ APRETADO  \u00bb  2x"
	_pista_x2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pista_x2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pista_x2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pista_x2.add_theme_font_override("font", _negrita(fuente, 2))
	_pista_x2.add_theme_font_size_override("font_size", 15)
	_pista_x2.add_theme_color_override("font_color", Color.WHITE)
	_pista_x2.add_theme_stylebox_override("normal", _pildora(Color(0, 0, 0, 0.62), ACENTO, 2))
	_pista_x2.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_pista_x2.offset_left = -130
	_pista_x2.offset_right = 130
	_pista_x2.offset_top = -124
	_pista_x2.offset_bottom = -88
	_pista_x2.pivot_offset = Vector2(130, 18)
	_pista_x2.visible = false
	telefono.add_child(_pista_x2)

	_snd_x2 = AudioStreamPlayer.new()
	_snd_x2.bus = "Apps"
	_snd_x2.volume_db = -5.0
	if ResourceLoader.exists(RUTA_SONIDO_X2):
		_snd_x2.stream = load(RUTA_SONIDO_X2)
	add_child(_snd_x2)


func _anunciar_x2() -> void:
	if _banner_x2 == null:
		return
	if _snd_x2.stream:
		_snd_x2.play()
	_destello(Color(1.35, 1.15, 1.3))
	var y_base := _banner_x2.position.y
	_banner_x2.visible = true
	_banner_x2.modulate.a = 0.0
	_banner_x2.scale = Vector2(0.5, 0.5)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_banner_x2, "modulate:a", 1.0, 0.18)
	t.tween_property(_banner_x2, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.set_parallel(false)
	# El "2x" late dos veces
	for i in 2:
		t.tween_property(_x2_grande, "scale", Vector2(1.14, 1.14), 0.16).set_trans(Tween.TRANS_SINE)
		t.tween_property(_x2_grande, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)
	t.tween_interval(1.7)
	# Y cae hacia donde queda la pista
	t.set_parallel(true)
	t.tween_property(_banner_x2, "position:y", y_base + 250.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(_banner_x2, "scale", Vector2(0.35, 0.35), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(_banner_x2, "modulate:a", 0.0, 0.45)
	t.set_parallel(false)
	t.tween_callback(func():
		_banner_x2.visible = false
		_banner_x2.position.y = y_base
		if GameManager.tutorial_pendiente(CLAVE_X2_USADO):
			_mostrar_pista_x2())


func _mostrar_pista_x2() -> void:
	if _pista_x2 == null or _pista_x2.visible:
		return
	_tiempo_rapido = 0.0
	_pista_x2.visible = true
	_pista_x2.modulate.a = 0.0
	_pista_x2.scale = Vector2(0.8, 0.8)
	var entra := create_tween().set_parallel(true)
	entra.tween_property(_pista_x2, "modulate:a", 1.0, 0.3)
	entra.tween_property(_pista_x2, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _latido_pista and _latido_pista.is_valid():
		_latido_pista.kill()
	_latido_pista = create_tween().set_loops()
	_latido_pista.tween_interval(0.4)
	_latido_pista.tween_property(_pista_x2, "scale", Vector2(1.07, 1.07), 0.32).set_trans(Tween.TRANS_SINE)
	_latido_pista.tween_property(_pista_x2, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_SINE)


func _ocultar_pista_x2() -> void:
	if _latido_pista and _latido_pista.is_valid():
		_latido_pista.kill()
	var t := create_tween().set_parallel(true)
	t.tween_property(_pista_x2, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_pista_x2, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(func(): _pista_x2.visible = false)


func _etiqueta_x2(texto: String, tamano: int, color: Color, fuente: Font, espaciado: int = 0) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", _negrita(fuente, espaciado))
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	return l


func _negrita(fuente: Font, espaciado: int = 0) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = fuente
	v.variation_embolden = 0.9
	v.spacing_glyph = espaciado
	return v


func _pildora(fondo: Color, borde: Color, ancho_borde: int, radio: int = 18) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = fondo
	c.border_color = borde
	c.set_border_width_all(ancho_borde)
	c.set_corner_radius_all(radio)
	c.content_margin_left = 14
	c.content_margin_right = 14
	return c


func _mostrar_aviso(texto: String) -> void:
	aviso.text = texto
	aviso.modulate.a = 1.0
	aviso.show()

	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(aviso, "modulate:a", 0.0, 0.8)
	tween.tween_callback(aviso.hide)
