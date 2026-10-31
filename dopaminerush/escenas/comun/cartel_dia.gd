extends CanvasLayer

# El cartel del dia: "Lunes" y abajo "08:00", en la esquina de abajo a la
# izquierda, sobre el negro del despertar. Como un titulo de capitulo.
#
#   var cartel := CartelDia.new()        (preload de este script)
#   add_child(cartel)
#   cartel.mostrar("Lunes", "08:00")     entra solo, con su animacion
#   cartel.ocultar(2.0)                  se va mientras aparece la escena
#
# Va por encima del fundido del SceneLoader (capa 128): tiene que leerse
# sobre el negro, que es justamente cuando aparece.
#
# LA ENTRADA, en tres tiempos que se pisan un poco:
#   1. el dia se revela de izquierda a derecha con un borde difuso (como
#      tinta que aparece), mientras sube unos pixeles;
#   2. una linea finita se dibuja debajo;
#   3. la hora aparece y sus letras se van juntando hasta asentarse.

const FUENTE_DIA := preload("res://assets/fuentes/CormorantGaramond-Italic.ttf")
const FUENTE_HORA := preload("res://assets/fuentes/DMMono-Light.ttf")

# Medidas en la resolucion base del juego (1920x1080)
const MARGEN_IZQUIERDO := 112.0
const MARGEN_ABAJO := 104.0
const TAMANO_DIA := 104
const PESO_DIA := 420              # la fuente es variable: 300 fina, 700 negrita
const TAMANO_HORA := 30
const ALFA_HORA := 0.8
const LARGO_LINEA := 64.0
const SEPARACION := 16.0           # entre el dia, la linea y la hora

# Tiempos de la entrada
const REVELAR_DIA := 1.7
const SUBIDA := 14.0
const DEMORA_LINEA := 0.95
const DIBUJAR_LINEA := 0.8
const DEMORA_HORA := 1.15
const APARECER_HORA := 1.5
const ESPACIADO_HORA_INICIAL := 16
const ESPACIADO_HORA := 6

const SHADER_REVELAR := """
shader_type canvas_item;
// El texto se revela de izquierda a derecha con el borde difuso.
uniform float progreso = 0.0;
uniform float ancho = 400.0;
uniform float suavidad = 90.0;
varying float x_local;

void vertex() {
	x_local = VERTEX.x;
}

void fragment() {
	float frente = progreso * (ancho + suavidad);
	COLOR.a *= 1.0 - smoothstep(frente - suavidad, frente, x_local);
}
"""

var _bloque: Control
var _dia: Label
var _linea: ColorRect
var _hora: Label
var _material_dia: ShaderMaterial
var _variacion_hora: FontVariation
var _tween: Tween


func _ready() -> void:
	layer = 129
	process_mode = Node.PROCESS_MODE_ALWAYS

	_bloque = Control.new()
	_bloque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloque.modulate.a = 0.0
	add_child(_bloque)

	var variacion_dia := FontVariation.new()
	variacion_dia.base_font = FUENTE_DIA
	variacion_dia.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): PESO_DIA}
	_dia = _etiqueta(variacion_dia, TAMANO_DIA)
	_material_dia = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER_REVELAR
	_material_dia.shader = shader
	_dia.material = _material_dia
	_bloque.add_child(_dia)

	_linea = ColorRect.new()
	_linea.color = Color(1, 1, 1, 0.5)
	_linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloque.add_child(_linea)

	_variacion_hora = FontVariation.new()
	_variacion_hora.base_font = FUENTE_HORA
	_variacion_hora.spacing_glyph = ESPACIADO_HORA
	_hora = _etiqueta(_variacion_hora, TAMANO_HORA)
	_bloque.add_child(_hora)


func _etiqueta(fuente: Font, tamano: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_override("font", fuente)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	# Sombra suave: sobre el negro no se ve, pero cuando la habitacion
	# aparece por detras sostiene la lectura sobre fondos claros.
	etiqueta.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	etiqueta.add_theme_constant_override("shadow_offset_x", 0)
	etiqueta.add_theme_constant_override("shadow_offset_y", 2)
	etiqueta.add_theme_constant_override("shadow_outline_size", 8)
	return etiqueta


# Arma el cartel y lo hace entrar. No hace falta esperarlo.
func mostrar(dia: String, hora: String) -> void:
	_dia.text = dia
	_hora.text = hora
	_variacion_hora.spacing_glyph = ESPACIADO_HORA
	_acomodar()

	if _tween and _tween.is_valid():
		_tween.kill()
	_bloque.modulate.a = 1.0
	_material_dia.set_shader_parameter("progreso", 0.0)
	_linea.size.x = 0.0
	_hora.modulate.a = 0.0
	_variacion_hora.spacing_glyph = ESPACIADO_HORA_INICIAL
	var y_final := _bloque.position.y
	_bloque.position.y = y_final + SUBIDA

	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_revelar_dia, 0.0, 1.0, REVELAR_DIA) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_bloque, "position:y", y_final, REVELAR_DIA + 0.6) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_linea, "size:x", LARGO_LINEA, DIBUJAR_LINEA) \
		.set_delay(DEMORA_LINEA).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_hora, "modulate:a", ALFA_HORA, APARECER_HORA) \
		.set_delay(DEMORA_HORA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_espaciar_hora, float(ESPACIADO_HORA_INICIAL), float(ESPACIADO_HORA), APARECER_HORA) \
		.set_delay(DEMORA_HORA).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


# Se desvanece y se corre apenas, mientras la escena aparece detras.
func ocultar(duracion: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_bloque, "modulate:a", 0.0, duracion * 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_bloque, "position:x", _bloque.position.x - 10.0, duracion) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func esta_visible() -> bool:
	return _bloque.modulate.a > 0.01


func texto() -> String:
	return "%s %s" % [_dia.text, _hora.text]


# Todo se apila desde abajo: la hora pegada al margen, la linea arriba y
# el dia arriba de la linea.
func _acomodar() -> void:
	var pantalla := get_viewport().get_visible_rect().size
	var alto_dia := _dia.get_minimum_size().y
	var alto_hora := _hora.get_minimum_size().y
	var ancho_dia := _dia.get_minimum_size().x

	_bloque.position = Vector2(MARGEN_IZQUIERDO, pantalla.y - MARGEN_ABAJO)
	_hora.position = Vector2(2.0, -alto_hora)
	_linea.position = Vector2(4.0, _hora.position.y - SEPARACION)
	_linea.size = Vector2(LARGO_LINEA, 1.0)
	# La italica tiene aire debajo de la linea de base: se la acerca.
	_dia.position = Vector2(0.0, _linea.position.y - SEPARACION * 0.4 - alto_dia * 0.92)
	_material_dia.set_shader_parameter("ancho", ancho_dia + 30.0)


func _revelar_dia(valor: float) -> void:
	_material_dia.set_shader_parameter("progreso", valor)


func _espaciar_hora(valor: float) -> void:
	_variacion_hora.spacing_glyph = int(round(valor))
