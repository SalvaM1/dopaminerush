extends AppBase

# ============================================================
#  Mercado Libre — la app del apuro y el tramite
# ============================================================
#
# QUE APORTA: ventana de tiempo y tramite. Es la unica app que te APURA,
# y la unica que te saca de la pantalla para poder seguir usandola.
#
# EL CICLO:
#   ESPERANDO  no hay nada. Entre 20 y 30 s, al azar.
#   OFERTA     aparece un producto con 8 segundos de contador. Si se
#              vence, se perdio.
#   CODIGO     al comprar, EL CONTADOR PARA. Llega un codigo de 3 digitos
#              al celular 3D: hay que girar la camara, leerlo, volver y
#              tipearlo en el teclado de la pantalla.
#   COMPRADO   la dopamina entra ACA, al confirmar el codigo. No antes.
#
# POR QUE EL CONTADOR PARA AL COMPRAR: el apuro era para DECIDIR, no para
# completar el tramite. Una vez que te engancho el impulso ya sos un
# cliente en proceso de pago. Y si el codigo tuviera reloj, una sola
# distraccion haria perder todo el esfuerzo: se sentiria injusto en vez
# de tenso.
#
# POR QUE EL CODIGO SE TIPEA CON EL MOUSE Y NO CON EL TECLADO: el recurso
# escaso de este juego es el mouse — las seis apps lo pelean. Si el codigo
# se escribiera con el teclado, el jugador podria tipear con una mano y
# seguir usando las otras apps con la otra, y el tramite saldria gratis.
# Son cuatro clicks que NO estas gastando en ninguna otra ventana: ese es
# el costo, y es el punto de la app.
#
# EL DRENAJE NO SE CONGELA EN NINGUN MOMENTO, a diferencia del vape.
# Estas perdiendo tiempo en una gestion administrativa mientras todo lo
# demas se cae. Esa frustracion es deliberada.

# ---- BALANCEO (provisorio, se ajusta en la fase G) ----
const ESPERA_MIN: float = 15.0            # entre oferta y oferta
const ESPERA_MAX: float = 30.0

# La PRIMERA oferta llega casi enseguida. Si el jugador abre la app y se
# encuentra con -No hay ofertas disponibles- durante medio minuto, la
# cierra antes de entender para que sirve. Una vez que ya vio el ciclo
# completo, la espera larga si tiene sentido: ahi la espera es la tension.
const ESPERA_PRIMERA: float = 4.0
const DURACION_OFERTA: float = 8.0        # para decidir, no para tramitar
const DURACION_VENCIDA: float = 2.0
const DURACION_COMPRADO: float = 2.6

const LARGO_CODIGO: int = 3

const RUTA_PRODUCTOS := "res://escenas/03_apps/app_05_ofertas/productos.json"
const CARPETA_IMAGENES := "res://assets/ui/productos/"

const SONIDOS := {
	"oferta":  "res://assets/audio/ui/popup.wav",
	# El sonido de compra de Mercado Libre va aca cuando lo consigan.
	"comprar": "res://assets/audio/apps/mercadolibre.wav",
	"tecla":   "res://assets/audio/ui/softclick.wav",
	"error":   "res://assets/audio/ui/fail.wav",
	"exito":   "res://assets/audio/ui/levelup.wav",
}

# ---- PALETA DE MERCADO LIBRE ----
const AMARILLO := Color(1.0, 0.902, 0.0)
const AZUL := Color(0.204, 0.514, 0.98)
const VERDE := Color(0.0, 0.651, 0.314)
const TEXTO := Color(0.2, 0.2, 0.2)
const GRIS := Color(0.4, 0.4, 0.4)
const ROJO := Color(0.85, 0.22, 0.18)

# Productos de emergencia por si falta el JSON.
const PRODUCTOS_DE_EMERGENCIA := [
	{
		"nombre": "Tostadora que imprime tu cara en el pan",
		"precio": 183041, "descuento": 47, "cuotas": 6,
		"vendedor": "Garage Home", "estrellas": 4.9, "vendidos": 50, "emoji": "🍞",
	},
]

# ---- NODOS ----
@onready var gasto_label: Label = $Header/Gasto

@onready var panel_espera: Control = $PanelEspera
@onready var espera_texto: Label = $PanelEspera/Texto

@onready var panel_oferta: Control = $PanelOferta
@onready var tarjeta: Panel = $PanelOferta/Tarjeta
@onready var imagen: TextureRect = $PanelOferta/Tarjeta/Imagen
@onready var imagen_emoji: Label = $PanelOferta/Tarjeta/Imagen/Emoji
@onready var titulo: Label = $PanelOferta/Tarjeta/Titulo
@onready var vendedor: Label = $PanelOferta/Tarjeta/Vendedor
@onready var precio_viejo: RichTextLabel = $PanelOferta/Tarjeta/PrecioViejo
@onready var precio: Label = $PanelOferta/Tarjeta/Precio
@onready var badge_off: Label = $PanelOferta/Tarjeta/BadgeOff
@onready var cuotas: Label = $PanelOferta/Tarjeta/Cuotas
@onready var urgencia: Label = $PanelOferta/Tarjeta/Urgencia
@onready var barra_tiempo: ProgressBar = $PanelOferta/BarraTiempo
@onready var boton_comprar: Button = $PanelOferta/BotonComprar

@onready var panel_codigo: Control = $PanelCodigo
@onready var digitos: HBoxContainer = $PanelCodigo/Digitos
@onready var teclado: GridContainer = $PanelCodigo/Teclado
@onready var boton_confirmar: Button = $PanelCodigo/BotonConfirmar

@onready var panel_final: Control = $PanelFinal
@onready var final_titulo: Label = $PanelFinal/Titulo
@onready var final_texto: Label = $PanelFinal/Texto

@onready var banner: Panel = $Banner
@onready var banner_texto: Label = $Banner/Texto
@onready var banner_sub: Label = $Banner/Sub

# Sonidos: todos opcionales. Si falta el archivo, la app anda en silencio.
@onready var snd_oferta: AudioStreamPlayer = get_node_or_null("Sonidos/Oferta")
@onready var snd_comprar: AudioStreamPlayer = get_node_or_null("Sonidos/Comprar")
@onready var snd_tecla: AudioStreamPlayer = get_node_or_null("Sonidos/Tecla")
@onready var snd_error: AudioStreamPlayer = get_node_or_null("Sonidos/Error")
@onready var snd_exito: AudioStreamPlayer = get_node_or_null("Sonidos/Exito")

# ---- ESTADO ----
enum Fase { ESPERANDO, OFERTA, CODIGO, VENCIDA, COMPRADO }

var _fase: int = Fase.ESPERANDO
var _reloj: float = 0.0
var _productos: Array = []
var _actual: Dictionary = {}

var _codigo: String = ""          # el que llego al celular
var _tipeado: String = ""         # lo que lleva ingresado el jugador
var _cajas: Array = []            # los 3 recuadros de digito

var _gastado: int = 0
var _pulso: float = 0.0
var _primera: bool = true


func _ready() -> void:
	_cargar_productos()
	_cargar_sonidos()

	_armar_digitos()
	_armar_teclado()

	boton_comprar.pressed.connect(_comprar)
	boton_confirmar.pressed.connect(_confirmar)

	banner.hide()
	_actualizar_gasto(false)
	_ir_a_espera()

	await get_tree().process_frame
	if not esta_activa:
		iniciar()


func _process(delta: float) -> void:
	if not esta_activa:
		return

	match _fase:
		Fase.ESPERANDO:
			_reloj -= delta
			_latir_espera(delta)
			if _reloj <= 0.0:
				_nueva_oferta()

		Fase.OFERTA:
			# El unico reloj que corre. Es para DECIDIR.
			_reloj -= delta
			_actualizar_contador()
			if _reloj <= 0.0:
				_vencer()

		Fase.VENCIDA, Fase.COMPRADO:
			_reloj -= delta
			if _reloj <= 0.0:
				_ir_a_espera()

		# En Fase.CODIGO no corre NINGUN reloj: el apuro ya cumplio su
		# funcion. Lo unico que sigue corriendo es el drenaje del juego.


# Si el jugador cierra la ventana en pleno tramite, el telefono tiene que
# apagarse igual: si no, queda encendido con un codigo que ya no sirve.
func detener() -> void:
	if _fase == Fase.CODIGO:
		GameManager.codigo_resuelto.emit()
	super()


# ============================================================
#  El ciclo
# ============================================================

func _ir_a_espera() -> void:
	_fase = Fase.ESPERANDO
	_reloj = ESPERA_PRIMERA if _primera else randf_range(ESPERA_MIN, ESPERA_MAX)
	_primera = false
	_mostrar_panel(panel_espera)
	espera_texto.text = "No hay ofertas disponibles"


func _nueva_oferta() -> void:
	_actual = _productos[randi() % _productos.size()]
	_fase = Fase.OFERTA
	_reloj = DURACION_OFERTA

	_llenar_tarjeta()
	_mostrar_panel(panel_oferta)
	_actualizar_contador()

	Juice.sonar(snd_oferta)
	_mostrar_banner()


# El cartelon de "OFERTA RELAMPAGO" que tapa la ventana un segundo.
# Es lo que hace que la oferta se note aunque estes mirando otra app:
# con seis ventanas abiertas, algo que solo cambia de contenido pasa
# completamente desapercibido.
func _mostrar_banner() -> void:
	banner_texto.text = "OFERTA RELÁMPAGO"
	banner_sub.text = "HASTA %d%% OFF" % int(_actual.get("descuento", 50))
	banner.show()
	banner.modulate.a = 1.0

	Juice.centrar_pivote(banner)
	banner.scale = Vector2(0.86, 0.86)

	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(banner, "scale", Vector2.ONE, 0.28)
	t.tween_interval(0.5)
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(banner, "modulate:a", 0.0, 0.3)
	t.tween_callback(banner.hide)

	Juice.pop(tarjeta, 0.05, 0.3)


func _vencer() -> void:
	_fase = Fase.VENCIDA
	_reloj = DURACION_VENCIDA
	_mostrar_panel(panel_final)
	final_titulo.text = "Oferta vencida"
	final_titulo.add_theme_color_override("font_color", GRIS)
	final_texto.text = "Se agotó el tiempo. Otra vez será."
	Juice.sonar(snd_error)


# ============================================================
#  El tramite
# ============================================================

func _comprar() -> void:
	if _fase != Fase.OFERTA:
		return

	_fase = Fase.CODIGO
	_tipeado = ""
	_pintar_digitos()

	# El codigo es al azar en cada compra: no se puede memorizar.
	_codigo = ""
	for i in range(LARGO_CODIGO):
		_codigo += str(randi() % 10)

	_mostrar_panel(panel_codigo)
	Juice.sonar(snd_comprar)

	# El celular de la habitacion se entera por el GameManager. La app no
	# sabe que existe un telefono, ni el telefono sabe que existe esta app.
	GameManager.codigo_pedido.emit(_codigo)


func _tecla(digito: int) -> void:
	if _fase != Fase.CODIGO or _tipeado.length() >= LARGO_CODIGO:
		return
	_tipeado += str(digito)
	_pintar_digitos()
	Juice.sonar(snd_tecla)


func _borrar() -> void:
	if _fase != Fase.CODIGO or _tipeado.is_empty():
		return
	_tipeado = _tipeado.substr(0, _tipeado.length() - 1)
	_pintar_digitos()
	Juice.sonar(snd_tecla, -3.0)


func _confirmar() -> void:
	if _fase != Fase.CODIGO:
		return

	if _tipeado.length() < LARGO_CODIGO:
		Juice.shake(digitos, 6.0, 0.25)
		Juice.sonar(snd_error)
		return

	if _tipeado != _codigo:
		# Equivocarse no cuesta la compra: cuesta TIEMPO, que en este
		# juego ya es el castigo mas caro que hay.
		Juice.shake(digitos, 9.0, 0.35)
		Juice.sonar(snd_error)
		_tipeado = ""
		_pintar_digitos()
		return

	_completar_compra()


func _completar_compra() -> void:
	_fase = Fase.COMPRADO
	_reloj = DURACION_COMPRADO

	# LA DOPAMINA ENTRA ACA, recien al confirmar. No al ver la oferta ni
	# al apretar comprar: al terminar el tramite entero.
	recompensar()

	_gastado += int(_actual.get("precio", 0))
	_actualizar_gasto(true)

	GameManager.codigo_resuelto.emit()

	_mostrar_panel(panel_final)
	final_titulo.text = "¡Listo!"
	final_titulo.add_theme_color_override("font_color", VERDE)
	final_texto.text = "Tu compra está en camino."

	Juice.sonar(snd_exito)
	Juice.numero_flotante(
		self, "+%d" % int(dopamina_por_interaccion), VERDE,
		Vector2(size.x * 0.5, size.y * 0.45), 34
	)


# ============================================================
#  La tarjeta del producto
# ============================================================

func _llenar_tarjeta() -> void:
	var p := _actual
	var precio_actual: int = int(p.get("precio", 0))
	var desc: int = int(p.get("descuento", 0))

	titulo.text = str(p.get("nombre", ""))
	vendedor.text = "%s  ★ %.1f  |  +%s vendidos" % [
		str(p.get("vendedor", "")),
		float(p.get("estrellas", 4.5)),
		_con_puntos(int(p.get("vendidos", 0))),
	]

	# El precio viejo se calcula desde el descuento, asi no hay que
	# cargar dos numeros coherentes a mano en el JSON.
	var viejo := precio_actual
	if desc > 0 and desc < 100:
		viejo = int(round(precio_actual / (1.0 - desc / 100.0)))
	precio_viejo.text = "[s]%s[/s]" % _formato_precio(viejo)

	precio.text = _formato_precio(precio_actual)
	badge_off.text = "%d%% OFF" % desc
	badge_off.visible = desc > 0

	var n: int = int(p.get("cuotas", 6))
	cuotas.text = "%d cuotas de %s" % [n, _formato_precio(int(precio_actual / float(n)))]

	_cargar_imagen(p)


func _cargar_imagen(p: Dictionary) -> void:
	imagen.texture = null
	imagen_emoji.text = str(p.get("emoji", "📦"))
	imagen_emoji.show()

	var archivo := str(p.get("imagen", ""))
	if archivo == "":
		return

	var ruta := archivo if archivo.begins_with("res://") else CARPETA_IMAGENES + archivo
	if ResourceLoader.exists(ruta):
		imagen.texture = load(ruta)
		imagen_emoji.hide()


# "17 personas viendo esto" y "quedan 2 unidades" son patrones oscuros
# reales. Los numeros cambian en cada oferta para que parezcan medidos.
func _actualizar_contador() -> void:
	var restante: float = max(0.0, _reloj)
	barra_tiempo.value = (restante / DURACION_OFERTA) * 100.0

	if restante <= 3.0:
		barra_tiempo.modulate = ROJO
		urgencia.add_theme_color_override("font_color", ROJO)
	else:
		barra_tiempo.modulate = Color.WHITE
		urgencia.add_theme_color_override("font_color", GRIS)

	urgencia.text = "¡Quedan %d unidades!  ·  Termina en %d s" % [
		int(_actual.get("_stock", 2)),
		int(ceil(restante)),
	]


# El contador de lo gastado NO HACE NADA: no desbloquea ni penaliza.
# Solo sube. Es culpa pura, y por eso esta siempre a la vista.
func _actualizar_gasto(animado: bool) -> void:
	gasto_label.text = "Gastaste hoy: " + _formato_precio(_gastado)
	if animado:
		Juice.pop(gasto_label, 0.18, 0.4)


# La espera respira, para que no parezca que la app se colgo.
func _latir_espera(delta: float) -> void:
	_pulso += delta * 2.2
	espera_texto.modulate.a = 0.55 + sin(_pulso) * 0.2


# ============================================================
#  El teclado en pantalla
# ============================================================

func _armar_digitos() -> void:
	_cajas.clear()
	for hijo in digitos.get_children():
		digitos.remove_child(hijo)
		hijo.queue_free()

	for i in range(LARGO_CODIGO):
		var caja := Panel.new()
		caja.custom_minimum_size = Vector2(54, 56)
		caja.add_theme_stylebox_override("panel", _estilo_caja(false))
		caja.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var l := Label.new()
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", TEXTO)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.add_child(l)

		digitos.add_child(caja)
		_cajas.append(l)

	_pintar_digitos()


# Grilla de telefono: 1-9, despues vacio / 0 / borrar.
func _armar_teclado() -> void:
	for hijo in teclado.get_children():
		teclado.remove_child(hijo)
		hijo.queue_free()

	for n in range(1, 10):
		teclado.add_child(_boton_tecla(str(n), _tecla.bind(n)))

	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(86, 36)
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	teclado.add_child(hueco)

	teclado.add_child(_boton_tecla("0", _tecla.bind(0)))
	teclado.add_child(_boton_tecla("⌫", _borrar))


func _boton_tecla(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(86, 36)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", TEXTO)
	b.add_theme_color_override("font_hover_color", TEXTO)
	b.add_theme_color_override("font_pressed_color", TEXTO)
	b.add_theme_stylebox_override("normal", _estilo_tecla(Color(0.96, 0.96, 0.96)))
	b.add_theme_stylebox_override("hover", _estilo_tecla(Color(0.90, 0.92, 0.96)))
	b.add_theme_stylebox_override("pressed", _estilo_tecla(Color(0.84, 0.87, 0.93)))
	b.pressed.connect(accion)
	return b


func _pintar_digitos() -> void:
	for i in range(_cajas.size()):
		var l: Label = _cajas[i]
		var lleno: bool = i < _tipeado.length()
		l.text = _tipeado[i] if lleno else ""

		var caja := l.get_parent() as Panel
		if caja:
			# El recuadro que toca ahora se marca en azul: sin esto, con
			# tres cajas vacias no se sabe donde va a caer el proximo.
			var activo: bool = (i == _tipeado.length())
			caja.add_theme_stylebox_override("panel", _estilo_caja(activo))
			if lleno:
				Juice.pop(caja, 0.12, 0.2)


func _estilo_caja(activo: bool) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = Color(1, 1, 1)
	e.border_color = AZUL if activo else Color(0.78, 0.78, 0.78)
	e.set_border_width_all(2 if activo else 1)
	e.set_corner_radius_all(6)
	return e


func _estilo_tecla(fondo: Color) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = fondo
	e.border_color = Color(0.84, 0.84, 0.84)
	e.set_border_width_all(1)
	e.set_corner_radius_all(6)
	return e


# ============================================================
#  Interfaz
# ============================================================

func _mostrar_panel(cual: Control) -> void:
	for p in [panel_espera, panel_oferta, panel_codigo, panel_final]:
		p.visible = (p == cual)


# "$ 183.041", con el punto de miles que usa Mercado Libre.
func _formato_precio(n: int) -> String:
	return "$ " + _con_puntos(n)


func _con_puntos(n: int) -> String:
	var s := str(abs(n))
	var salida := ""
	var cuenta := 0
	for i in range(s.length() - 1, -1, -1):
		salida = s[i] + salida
		cuenta += 1
		if cuenta % 3 == 0 and i > 0:
			salida = "." + salida
	return ("-" if n < 0 else "") + salida


# ============================================================
#  Carga de contenido
# ============================================================

func _cargar_productos() -> void:
	var datos = null

	var recurso = load(RUTA_PRODUCTOS)
	if recurso is JSON:
		datos = recurso.data
	elif FileAccess.file_exists(RUTA_PRODUCTOS):
		var f := FileAccess.open(RUTA_PRODUCTOS, FileAccess.READ)
		datos = JSON.parse_string(f.get_as_text())
		f.close()

	if datos is Dictionary and datos.has("productos"):
		_productos = datos["productos"]

	if _productos.is_empty():
		push_warning("[MercadoLibre] no se pudieron cargar los productos de " + RUTA_PRODUCTOS)
		_productos = PRODUCTOS_DE_EMERGENCIA

	# El stock falso se sortea una vez por producto, asi no cambia de
	# numero mientras lo estas mirando.
	for p in _productos:
		p["_stock"] = randi() % 3 + 1


func _cargar_sonidos() -> void:
	var mapa := {
		"oferta": snd_oferta,
		"comprar": snd_comprar,
		"tecla": snd_tecla,
		"error": snd_error,
		"exito": snd_exito,
	}

	for clave in mapa:
		var reproductor: AudioStreamPlayer = mapa[clave]
		if reproductor == null or reproductor.stream != null:
			continue

		var ruta: String = SONIDOS[clave]
		if ResourceLoader.exists(ruta):
			reproductor.stream = load(ruta)
		else:
			print("[MercadoLibre] falta el sonido: ", ruta)
