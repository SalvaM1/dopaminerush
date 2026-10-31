extends Panel

# ============================================================
#  La notificacion de "app instalada"
# ============================================================
#
# Antes era un cartel rojo en el medio de la pantalla. Ahora es lo que es
# de verdad: el sistema operativo avisandote que se instalo algo que vos
# no pediste. Entra por la derecha, arriba de la bandeja, como cualquier
# notificacion de Windows.
#
# Suena UNA vez, al aparecer: una por app, unas seis en toda la partida.
#
# NO SE PUEDE CERRAR. Es una oferta pendiente: si se fuera sola, el
# GameManager se quedaria esperando una respuesta que nunca llega y no se
# ofreceria ninguna app mas.
#
# Siempre se dibuja ARRIBA de todo (z_index), como las notificaciones de
# verdad. Antes, si el jugador se tropezaba justo cuando salia la oferta
# (pasa seguido: sale cuando la barra esta baja), la pantalla del tropiezo
# la tapaba.

signal aceptada()

# El tamano va aca y no se lee de size: la instancia en el escritorio
# todavia tiene guardado como override el tamano del cartel rojo viejo.
const ANCHO: float = 470.0
const ALTO: float = 170.0

const MARGEN_DERECHO: float = 18.0
const ALTO_BARRA_TAREAS: float = 64.0
const SEPARACION_BARRA: float = 16.0

# El sonido. Se busca en este orden y se usa el primero que exista. El
# ultimo es un respaldo que ya esta en el proyecto, para que no quede muda
# mientras no haya uno propio.
const SONIDOS := [
	"res://assets/audio/ui/notificacion.ogg",
	"res://assets/audio/ui/notificacion.wav",
	"res://assets/audio/ui/notificacion.mp3",
	"res://assets/audio/ui/popup.wav",
]

# Un "icono" por app: un cuadrado de color con la inicial. Las apps no
# tienen icono propio, y los simbolos que usa el dock no existen en la
# fuente del proyecto (se ven como cuadraditos).
const ICONOS := {
	"scroll":  [Color(0.93, 0.18, 0.45), "T", Color.WHITE],
	"slots":   [Color(0.95, 0.66, 0.12), "F", Color(0.2, 0.12, 0.02)],
	"racha":   [Color(0.22, 0.7, 0.45), "P", Color.WHITE],
	"subway":  [Color(0.98, 0.48, 0.13), "S", Color.WHITE],
	"ofertas": [Color(1.0, 0.9, 0.2), "M", Color(0.12, 0.17, 0.45)],
	"musica":  [Color(0.2, 0.78, 0.4), "L", Color.WHITE],
}

@onready var icono: Panel = $Icono
@onready var letra: Label = $Icono/Letra
@onready var encabezado: Label = $Encabezado
@onready var titulo: Label = $Titulo
@onready var texto: Label = $Texto
@onready var boton: Button = $BotonAceptar
@onready var sonido: AudioStreamPlayer = $Sonido

var _x_final: float = 0.0
var _cerrando: bool = false
var _tween: Tween = null
var _estilo_icono: StyleBoxFlat = null


func _ready() -> void:
	# El layout se fija aca y no en la escena del escritorio: la instancia
	# vieja tenia la posicion del cartel rojo guardada como override.
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_right = -MARGEN_DERECHO
	offset_left = offset_right - ANCHO
	offset_bottom = -(ALTO_BARRA_TAREAS + SEPARACION_BARRA)
	offset_top = offset_bottom - ALTO
	z_index = 40
	_x_final = position.x

	var base := icono.get_theme_stylebox("panel")
	if base is StyleBoxFlat:
		_estilo_icono = base.duplicate()
		icono.add_theme_stylebox_override("panel", _estilo_icono)

	for ruta in SONIDOS:
		if ResourceLoader.exists(ruta):
			sonido.stream = load(ruta)
			break

	hide()


# La llama el escritorio cuando el GameManager ofrece una app.
func mostrar(id_app: String, nombre: String, gancho: String, cuerpo: String, accion: String) -> void:
	var datos: Array = ICONOS.get(id_app, [Color(0.4, 0.45, 0.55), nombre.left(1), Color.WHITE])
	if _estilo_icono:
		_estilo_icono.bg_color = datos[0]
	letra.text = datos[1]
	letra.add_theme_color_override("font_color", datos[2])

	encabezado.text = "Se terminó de instalar  ·  ahora"
	titulo.text = nombre
	texto.text = _juntar(gancho, cuerpo)
	boton.text = accion
	boton.disabled = false

	_cerrando = false
	if _tween and _tween.is_valid():
		_tween.kill()

	# Entra deslizandose desde afuera de la pantalla. El destino se calcula
	# aca y no una sola vez: el tween mueve position, o sea los offsets.
	_x_final = get_parent_area_size().x - MARGEN_DERECHO - ANCHO
	show()
	modulate.a = 1.0
	position.x = _x_final + ANCHO + MARGEN_DERECHO + 30.0
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:x", _x_final, 0.5)

	Juice.sonar(sonido, 0.0, 0.0)


# Se va deslizandose. El boton se apaga en el acto: dos clicks rapidos no
# tienen que aceptar dos veces.
func cerrar() -> void:
	if not visible or _cerrando:
		return
	_cerrando = true
	boton.disabled = true
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "position:x", _x_final + ANCHO + MARGEN_DERECHO + 30.0, 0.28)
	_tween.tween_callback(hide)


# "¿Aburrido?" + "Family Savings — tu primer giro es gratis." Si el gancho
# no termina en signo, se le agrega un punto para que no se peguen.
func _juntar(gancho: String, cuerpo: String) -> String:
	gancho = gancho.strip_edges()
	cuerpo = cuerpo.strip_edges()
	if gancho == "":
		return cuerpo
	if cuerpo == "":
		return gancho
	if not gancho.right(1) in ["?", "!", ".", "…"]:
		gancho += "."
	return gancho + " " + cuerpo
