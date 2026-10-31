extends AppBase

# ============================================================
#  Loopify — la ultima app
# ============================================================
#
# No da dopamina propia. Mientras suena un tema FRESCO, todo lo que dan
# las otras apps rinde x1.3 (GameManager.mult_dopamina_musica). Pero el
# tema dura poco: a los 7-8 segundos ya aburre, se apaga un poco, el
# multiplicador se va, y hay que saltar al siguiente. Es la satira del
# que no termina ningun tema.
#
# Es la ultima app y vive poco: la etapa final arranca 30 s despues de
# desbloquearla. Es la banda sonora del colapso, y por eso la mecanica es
# un solo boton. En el colapso el juego corta todo el audio de golpe: de
# la musica al silencio, y despues al parque.
#
# LOS TEMAS: cualquier .mp3, .ogg o .wav en assets/audio/loopify/. Lo que
# se muestra sale del nombre del archivo: "Artista - Tema.ogg". Si al lado
# hay una imagen con el MISMO nombre (.png, .jpg o .webp), es la tapa.
#
# Los que vienen con el juego son recortes de 30 s que ya arrancan en el
# estribillo, asi que se reproducen desde el principio. Un tema entero (mas
# de un minuto) arranca en un punto al azar de la mitad: las intros reales
# son largas, y 10 segundos de intro no son un tema.

@export_dir var carpeta_temas: String = "res://assets/audio/loopify"
@export var duracion_fresca: float = 10.0
@export var multiplicador: float = 1.3
@export_range(-40.0, 6.0) var volumen_temas: float = 0.0
# Cuando el tema aburre no baja casi de volumen (la musica se tiene que
# escuchar si o si): suena APAGADO, como desde abajo del agua. Es el
# filtro de graves del bus Loopify. Esto es lo poco que ademas baja.
@export var caida_aburrido: float = 3.0
const CORTE_ABIERTO: float = 20500.0   # el filtro no hace nada
const CORTE_ABURRIDO: float = 900.0    # solo pasan los graves
const BUS := "Loopify"

const SONIDO_CLICK := "res://assets/audio/ui/softclick.wav"

const VERDE := Color(0.114, 0.725, 0.329)
const ROJO := Color(0.93, 0.33, 0.36)
const GRIS := Color(0.66, 0.67, 0.71)
const FONDO := Color(0.071, 0.071, 0.078)
const BARRAS_ECUALIZADOR := 7

var _temas: Array[String] = []
var _actual: int = -1
var _fresco: float = 0.0
var _aburrido: bool = false
var _segundos_escuchados: float = 0.0

var _reproductor: AudioStreamPlayer
var _click: AudioStreamPlayer
var _tween_volumen: Tween
var _tween_latido: Tween
var _tween_filtro: Tween

var _tinte: Gradient
var _marco_portada: Panel
var _portada: Panel
var _tapa: TextureRect
var _colores_tapa := {}
var _estilo_portada: StyleBoxFlat
var _iniciales: Label
var _titulo: Label
var _artista: Label
var _estado: Label
var _escuchado: Label
var _barra: ProgressBar
var _estilo_barra: StyleBoxFlat
var _boton: Button
var _ecualizador: Array[ColorRect] = []
var _alturas_destino: Array[float] = []
var _reloj_ecualizador: float = 0.0


func _ready() -> void:
	_armar_interfaz()

	_reproductor = AudioStreamPlayer.new()
	_reproductor.bus = BUS
	_reproductor.finished.connect(_al_terminar_tema)
	add_child(_reproductor)

	_click = AudioStreamPlayer.new()
	_click.bus = "UI"
	if ResourceLoader.exists(SONIDO_CLICK):
		_click.stream = load(SONIDO_CLICK)
	add_child(_click)

	_temas = _buscar_temas(carpeta_temas)
	# Cuanto escuchaste hoy: arranca alto, porque eso es lo que es.
	_segundos_escuchados = randf_range(150.0, 260.0) * 60.0
	_actualizar_escuchado()

	if _temas.is_empty():
		_titulo.text = "Sin música"
		_artista.text = "Agregá temas en assets/audio/loopify/"
		_estado.text = ""
		_boton.disabled = true


func iniciar() -> void:
	super()
	if _temas.is_empty():
		return
	_siguiente(false)


func detener() -> void:
	super()
	GameManager.mult_dopamina_musica = 1.0
	if _reproductor:
		_reproductor.stop()
	_soltar_audio()


func _exit_tree() -> void:
	# Si la ventana se va sin pasar por detener (cambio de escena), que no
	# quede el multiplicador prendido, ni el resto agachado, ni el filtro
	# cerrado: los buses son de todo el juego y duran mas que esta app.
	if GameManager.mult_dopamina_musica != 1.0 and esta_activa:
		GameManager.mult_dopamina_musica = 1.0
	_soltar_audio()


func _soltar_audio() -> void:
	AudioManager.agachar(false)
	_poner_filtro(CORTE_ABIERTO, 0.0)


# Un recorte que termina sin que lo cambien: silencio. Sin musica no hay
# por que tener el resto agachado.
func _al_terminar_tema() -> void:
	AudioManager.agachar(false)


func _process(delta: float) -> void:
	if not esta_activa or _actual < 0:
		return

	if _reproductor.playing:
		_segundos_escuchados += delta
		_actualizar_escuchado()

	if not _aburrido:
		_fresco -= delta
		_barra.value = clampf(1.0 - _fresco / duracion_fresca, 0.0, 1.0)
		if _fresco <= 0.0:
			_aburrir()

	_animar_ecualizador(delta)


# ============================================================
#  Los temas
# ============================================================

func _siguiente(con_click: bool = true) -> void:
	if _temas.is_empty():
		return
	if con_click:
		Juice.sonar(_click, 0.0, 0.05)

	# Nunca el mismo dos veces seguidas: "siguiente" tiene que sentirse
	# como algo nuevo.
	var i := randi() % _temas.size()
	if _temas.size() > 1 and i == _actual:
		i = (i + 1) % _temas.size()
	_poner_tema(i)


func _poner_tema(indice: int) -> void:
	var stream = load(_temas[indice])
	if not (stream is AudioStream):
		return
	_actual = indice
	_aburrido = false
	_fresco = duracion_fresca

	# Arranca en algun lugar de la mitad del tema, donde ya esta andando.
	var largo: float = stream.get_length()
	var desde := 0.0
	if largo > 60.0:
		desde = randf_range(0.2, 0.55) * largo

	_reproductor.stop()
	_reproductor.stream = stream
	_reproductor.volume_db = -40.0
	_reproductor.play(desde)
	_llevar_volumen(volumen_temas, 0.35)
	_poner_filtro(CORTE_ABIERTO, 0.15)
	# Mientras suena Loopify, lo demas baja: el tema se escucha si o si.
	AudioManager.agachar(true)

	GameManager.mult_dopamina_musica = multiplicador
	_mostrar_tema(_temas[indice])


func _aburrir() -> void:
	_aburrido = true
	_barra.value = 1.0
	GameManager.mult_dopamina_musica = 1.0
	_llevar_volumen(volumen_temas - caida_aburrido, 0.8)
	_poner_filtro(CORTE_ABURRIDO, 0.8)

	_estado.text = "Ya te aburrió"
	_estado.add_theme_color_override("font_color", ROJO)
	_estilo_barra.bg_color = ROJO
	Juice.tintar(_portada, Color(0.55, 0.55, 0.58), 0.6)

	# El boton late hasta que lo apretes.
	if _tween_latido and _tween_latido.is_valid():
		_tween_latido.kill()
	Juice.centrar_pivote(_boton)
	_tween_latido = create_tween().set_loops()
	_tween_latido.set_trans(Tween.TRANS_SINE)
	_tween_latido.tween_property(_boton, "scale", Vector2.ONE * 1.12, 0.35)
	_tween_latido.tween_property(_boton, "scale", Vector2.ONE, 0.35)


# El filtro de graves del bus Loopify. Esta en default_bus_layout.tres.
func _filtro() -> AudioEffectLowPassFilter:
	var i := AudioServer.get_bus_index(BUS)
	if i < 0:
		return null
	for k in range(AudioServer.get_bus_effect_count(i)):
		var efecto := AudioServer.get_bus_effect(i, k)
		if efecto is AudioEffectLowPassFilter:
			return efecto
	return null


func _poner_filtro(corte: float, duracion: float) -> void:
	var filtro := _filtro()
	if filtro == null:
		return
	if _tween_filtro and _tween_filtro.is_valid():
		_tween_filtro.kill()
	if duracion <= 0.0 or not is_inside_tree():
		filtro.cutoff_hz = corte
		return
	_tween_filtro = create_tween()
	_tween_filtro.tween_property(filtro, "cutoff_hz", corte, duracion)


func _llevar_volumen(destino: float, duracion: float) -> void:
	if _tween_volumen and _tween_volumen.is_valid():
		_tween_volumen.kill()
	_tween_volumen = create_tween()
	_tween_volumen.tween_property(_reproductor, "volume_db", destino, duracion)


# "Artista - Tema.mp3" -> ["Artista", "Tema"]. Sin guion, todo es el tema.
func _partes(ruta: String) -> Array:
	var nombre := ruta.get_file().get_basename()
	if " - " in nombre:
		var p := nombre.split(" - ", true, 1)
		return [p[0].strip_edges(), p[1].strip_edges()]
	return ["", nombre.strip_edges()]


func _mostrar_tema(ruta: String) -> void:
	var partes := _partes(ruta)
	var artista: String = partes[0]
	var tema: String = partes[1]
	_titulo.text = tema
	_artista.text = artista if artista != "" else "Para vos"

	# Con tapa, se ve la tapa y su color tine la app. Sin tapa, un cuadrado
	# de color (siempre el mismo para el mismo tema) con las iniciales.
	var color: Color
	var tapa := _tapa_de(ruta)
	if tapa:
		_tapa.texture = tapa
		_tapa.show()
		_iniciales.hide()
		color = _color_de(ruta, tapa)
	else:
		_tapa.hide()
		_iniciales.show()
		var tono := float(absi(hash(tema)) % 360) / 360.0
		color = Color.from_hsv(tono, 0.62, 0.78)
		var letras := (artista.left(1) + tema.left(1)) if artista != "" else tema.left(2)
		_iniciales.text = letras.to_upper()
	_estilo_portada.bg_color = color
	_tinte.set_color(0, Color(color, 0.45))

	_estado.text = "x%.1f a todas tus apps" % multiplicador
	_estado.add_theme_color_override("font_color", VERDE)
	_estilo_barra.bg_color = VERDE
	_barra.value = 0.0

	if _tween_latido and _tween_latido.is_valid():
		_tween_latido.kill()
	_boton.scale = Vector2.ONE
	_portada.modulate = Color.WHITE
	Juice.pop(_marco_portada, 0.08, 0.35)
	Juice.entrar(_titulo, 10.0, 0.2)


# La imagen con el mismo nombre que el tema, si hay.
func _tapa_de(ruta: String) -> Texture2D:
	var base := ruta.get_basename()
	for ext in ["png", "jpg", "jpeg", "webp"]:
		if ResourceLoader.exists(base + "." + ext):
			var t = load(base + "." + ext)
			if t is Texture2D:
				return t
	return null


# El color promedio de la tapa, para tenir la app con el. Se calcula una
# sola vez por tema.
func _color_de(ruta: String, tapa: Texture2D) -> Color:
	if _colores_tapa.has(ruta):
		return _colores_tapa[ruta]
	var color := Color(0.3, 0.3, 0.34)
	var img := tapa.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		img.resize(8, 8, Image.INTERPOLATE_LANCZOS)
		var suma := Color(0, 0, 0, 0)
		for y in range(8):
			for x in range(8):
				suma += img.get_pixel(x, y)
		color = suma / 64.0
		color.a = 1.0
		# Un poco mas vivo: el promedio de una tapa suele dar un gris barroso.
		color = Color.from_hsv(color.h, minf(1.0, color.s * 1.3), maxf(0.45, color.v))
	_colores_tapa[ruta] = color
	return color


func _actualizar_escuchado() -> void:
	var minutos := int(_segundos_escuchados / 60.0)
	var texto := "Hoy escuchaste %d h %d min" % [minutos / 60, minutos % 60]
	if _escuchado.text != texto:
		_escuchado.text = texto


# Todos los temas de la carpeta. En el juego exportado los archivos
# aparecen como .import/.remap: se les saca el sufijo para encontrarlos.
func _buscar_temas(carpeta: String) -> Array[String]:
	var lista: Array[String] = []
	var dir := DirAccess.open(carpeta)
	if dir == null:
		print("[Loopify] no existe la carpeta de temas: ", carpeta)
		return lista
	var vistos := {}
	for archivo in dir.get_files():
		var nombre: String = archivo
		if nombre.ends_with(".import") or nombre.ends_with(".remap") or nombre.ends_with(".uid"):
			nombre = nombre.get_basename()
		if not nombre.get_extension().to_lower() in ["mp3", "ogg", "wav"]:
			continue
		if vistos.has(nombre):
			continue
		vistos[nombre] = true
		var ruta := carpeta.path_join(nombre)
		if ResourceLoader.exists(ruta):
			lista.append(ruta)
	lista.sort()
	print("[Loopify] %d temas" % lista.size())
	return lista


# ============================================================
#  Ecualizador
# ============================================================
# Barritas que saltan mientras el tema esta fresco. Cuando aburre, caen
# y se mueven apenas: la musica sigue, pero ya no pasa nada.

func _animar_ecualizador(delta: float) -> void:
	_reloj_ecualizador -= delta
	if _reloj_ecualizador <= 0.0:
		_reloj_ecualizador = 0.11
		for i in range(_ecualizador.size()):
			var alto := randf_range(0.25, 1.0) if not _aburrido else randf_range(0.08, 0.22)
			_alturas_destino[i] = alto * 36.0
	for i in range(_ecualizador.size()):
		var barra := _ecualizador[i]
		var h := lerpf(barra.size.y, _alturas_destino[i], minf(1.0, delta * 14.0))
		barra.size.y = h
		barra.position.y = 36.0 - h
		barra.color = VERDE if not _aburrido else Color(0.35, 0.36, 0.4)


# ============================================================
#  Interfaz
# ============================================================
# Todo se arma por codigo. Area de la app: 560 x 282 (la ventana es de
# 560 x 320 y la barra de titulo se come 38).

func _armar_interfaz() -> void:
	var fondo := Panel.new()
	var estilo_fondo := StyleBoxFlat.new()
	estilo_fondo.bg_color = FONDO
	fondo.add_theme_stylebox_override("panel", estilo_fondo)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	# El color del tema tiñe la parte de arriba, como en la app de verdad.
	_tinte = Gradient.new()
	_tinte.set_color(0, Color(VERDE, 0.35))
	_tinte.set_color(1, Color(FONDO, 0.0))
	var textura := GradientTexture2D.new()
	textura.gradient = _tinte
	textura.width = 8
	textura.height = 128
	textura.fill_to = Vector2(0, 1)
	var tinte := TextureRect.new()
	tinte.texture = textura
	tinte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tinte.set_anchors_preset(Control.PRESET_FULL_RECT)
	tinte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tinte)

	# --- la portada ---
	# Dos paneles: el de afuera tiene la sombra; el de adentro recorta la
	# tapa con sus esquinas redondeadas. Si la sombra fuera del mismo panel
	# que recorta, las esquinas de la tapa se escaparian por la sombra.
	_marco_portada = Panel.new()
	var estilo_sombra := StyleBoxFlat.new()
	estilo_sombra.bg_color = Color(0, 0, 0, 0)
	estilo_sombra.set_corner_radius_all(10)
	estilo_sombra.shadow_color = Color(0, 0, 0, 0.5)
	estilo_sombra.shadow_size = 14
	estilo_sombra.shadow_offset = Vector2(0, 6)
	_marco_portada.add_theme_stylebox_override("panel", estilo_sombra)
	_marco_portada.position = Vector2(22, 22)
	_marco_portada.size = Vector2(180, 180)
	_marco_portada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marco_portada)

	_portada = Panel.new()
	_estilo_portada = StyleBoxFlat.new()
	_estilo_portada.bg_color = Color(0.25, 0.25, 0.28)
	_estilo_portada.set_corner_radius_all(10)
	_portada.add_theme_stylebox_override("panel", _estilo_portada)
	_portada.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portada.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_portada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marco_portada.add_child(_portada)

	_tapa = TextureRect.new()
	_tapa.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tapa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tapa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_tapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tapa.hide()
	_portada.add_child(_tapa)

	_iniciales = _etiqueta("", 58, Color.WHITE)
	_iniciales.set_anchors_preset(Control.PRESET_FULL_RECT)
	_iniciales.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_iniciales.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_iniciales.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	_iniciales.add_theme_constant_override("shadow_offset_y", 3)
	_portada.add_child(_iniciales)

	_escuchado = _etiqueta("", 13, GRIS)
	_escuchado.position = Vector2(22, 214)
	_escuchado.size = Vector2(180, 20)
	_escuchado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_escuchado)

	# --- la columna de la derecha ---
	var x := 222.0
	var ancho := 316.0

	var encabezado := _etiqueta("SONANDO  ·  TU MEZCLA DIARIA", 12, GRIS)
	encabezado.position = Vector2(x, 24)
	encabezado.size = Vector2(ancho, 18)
	add_child(encabezado)

	_titulo = _etiqueta("", 26, Color.WHITE)
	_titulo.position = Vector2(x, 42)
	_titulo.size = Vector2(ancho, 38)
	_titulo.clip_text = true
	_titulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_titulo)

	_artista = _etiqueta("", 17, GRIS)
	_artista.position = Vector2(x, 80)
	_artista.size = Vector2(ancho, 24)
	_artista.clip_text = true
	_artista.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_artista)

	var eq := Control.new()
	eq.position = Vector2(x, 112)
	eq.size = Vector2(140, 36)
	eq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(eq)
	for i in range(BARRAS_ECUALIZADOR):
		var barra := ColorRect.new()
		barra.color = VERDE
		barra.position = Vector2(i * 17.0, 30.0)
		barra.size = Vector2(12, 6)
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		eq.add_child(barra)
		_ecualizador.append(barra)
		_alturas_destino.append(6.0)

	# La barra no es el progreso del tema: es cuanto falta para que aburra.
	_barra = ProgressBar.new()
	_barra.show_percentage = false
	_barra.max_value = 1.0
	_barra.position = Vector2(x, 160)
	_barra.size = Vector2(ancho, 6)
	var estilo_vacio := StyleBoxFlat.new()
	estilo_vacio.bg_color = Color(1, 1, 1, 0.12)
	estilo_vacio.set_corner_radius_all(3)
	_estilo_barra = StyleBoxFlat.new()
	_estilo_barra.bg_color = VERDE
	_estilo_barra.set_corner_radius_all(3)
	_barra.add_theme_stylebox_override("background", estilo_vacio)
	_barra.add_theme_stylebox_override("fill", _estilo_barra)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_barra)

	_estado = _etiqueta("", 15, VERDE)
	_estado.position = Vector2(x, 172)
	_estado.size = Vector2(ancho, 22)
	add_child(_estado)

	# --- el boton de siguiente ---
	_boton = Button.new()
	_boton.position = Vector2(x, 204)
	_boton.size = Vector2(56, 56)
	_boton.focus_mode = Control.FOCUS_NONE
	_boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for estado in ["normal", "hover", "pressed", "disabled"]:
		var e := StyleBoxFlat.new()
		e.bg_color = {"normal": VERDE, "hover": VERDE.lightened(0.15),
			"pressed": VERDE.darkened(0.15), "disabled": Color(0.3, 0.3, 0.33)}[estado]
		e.set_corner_radius_all(28)
		_boton.add_theme_stylebox_override(estado, e)
	_boton.pressed.connect(_siguiente)
	add_child(_boton)

	# El icono de "siguiente" se dibuja: la fuente no tiene esos simbolos.
	var icono := Polygon2D.new()
	icono.color = Color(0.04, 0.04, 0.05)
	icono.polygon = PackedVector2Array([Vector2(-9, -11), Vector2(6, 0), Vector2(-9, 11)])
	icono.position = Vector2(28, 28)
	_boton.add_child(icono)
	var palito := Polygon2D.new()
	palito.color = Color(0.04, 0.04, 0.05)
	palito.polygon = PackedVector2Array([Vector2(7, -11), Vector2(11, -11), Vector2(11, 11), Vector2(7, 11)])
	palito.position = Vector2(28, 28)
	_boton.add_child(palito)

	var siguiente := _etiqueta("Siguiente", 15, GRIS)
	siguiente.position = Vector2(x + 68, 222)
	siguiente.size = Vector2(120, 22)
	add_child(siguiente)


func _etiqueta(texto: String, tamano: int, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
