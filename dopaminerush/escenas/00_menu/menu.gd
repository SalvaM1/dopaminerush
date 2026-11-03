extends Control

# ============================================================
#  Menu principal
# ============================================================
#
# De fondo, la habitacion vista por una camara que paneá despacio (o el
# parque, si el juego ya se termino alguna vez): ver fondo_menu.gd.
#
# Adelante, una columna a la izquierda, sobre el tercio izquierdo de la
# pantalla: el titulo, y abajo Empezar / Sonido / Salir. Un degrade oscuro
# desde la izquierda la hace legible sobre cualquier parte del paneo, y
# deja la escena limpia en los dos tercios de la derecha.
#
# Misma familia tipografica que los carteles de los dias: la serif italica
# para lo que se lee como titulo, la monoespaciada para lo que se toca.
#
# La pestaña SONIDO reemplaza al titulo y los botones: un control por grupo
# de buses (ver Ajustes.GRUPOS). El ambiente del fondo sigue sonando, asi
# se escucha lo que se cambia. Se recuerda mientras el juego esta abierto.

const CartelDia := preload("res://escenas/comun/cartel_dia.gd")
const FondoMenu := preload("res://escenas/00_menu/fondo_menu.gd")
const FUENTE_TITULO := preload("res://assets/fuentes/CormorantGaramond-Italic.ttf")
const FUENTE_MONO := preload("res://assets/fuentes/DMMono-Light.ttf")
const ICONO_AURICULARES := preload("res://assets/ui/auriculares.svg")
const RUTA_CLICK := "res://assets/audio/ui/softclick.wav"
const ESCENA_JUEGO := "res://escenas/01_habitacion/habitacion.tscn"

# ---- MEDIDAS (en la resolucion base, 1920x1080) ----
const COLUMNA_X := 300.0           # la columna, sobre el tercio izquierdo
const TITULO_Y := 236.0
const TAMANO_TITULO := 176
const PESO_TITULO := 380
const SANGRIA_RUSH := 92.0         # "Rush" corrido: la palabra cae, no se apila
const BOTONES_Y := 712.0
const ENTRE_BOTONES := 64.0
const TAMANO_BOTON := 23
const MARGEN_AVISO := Vector2(96, 84)
const BLANCO := Color(0.96, 0.96, 0.97)

# ---- TIEMPOS DE LA ENTRADA ----
const APARECER_FONDO := 2.6
const ESCALON_BOTONES := 0.12

enum Pantalla { ENTRANDO, PRINCIPAL, SONIDO, SALIENDO }

var _pantalla := Pantalla.ENTRANDO
var _fondo: Node3D
var _negro: ColorRect
var _bloque_principal: Control
var _bloque_sonido: Control
var _aviso: Control
var _palabras: Array[Label] = []
var _materiales_titulo: Array[ShaderMaterial] = []
var _sobrelinea: Label
var _linea: ColorRect
var _opciones: Array[Control] = []
var _opciones_sonido: Array[Control] = []
var _click: AudioStreamPlayer
var _ultimo_tic: float = 0.0


func _ready() -> void:
	# Por si venimos de una partida anterior: el cursor tiene que verse
	# y el estado del juego tiene que arrancar limpio.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.reiniciar()
	# Partida nueva de verdad: los tutoriales vuelven a salir. El dia nuevo
	# tambien llama a reiniciar(), pero ese NO los repite.
	GameManager.tutoriales_vistos.clear()
	Ajustes.aplicar_audio()

	_fondo = FondoMenu.new()
	_fondo.lugar = "parque" if Ajustes.juego_completado() else "habitacion"
	add_child(_fondo)

	_click = AudioStreamPlayer.new()
	_click.bus = "UI"
	if ResourceLoader.exists(RUTA_CLICK):
		_click.stream = load(RUTA_CLICK)
	add_child(_click)

	_armar_velos()
	_armar_principal()
	_armar_sonido()
	_armar_aviso()

	_negro = ColorRect.new()
	_negro.color = Color.BLACK
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_negro)

	_entrar()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _pantalla == Pantalla.SONIDO:
		_cerrar_sonido()
		get_viewport().set_input_as_handled()
		return
	# Con teclado: la primera flecha entra a los botones
	if (event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up")) \
			and get_viewport().gui_get_focus_owner() == null:
		var lista := _opciones if _pantalla == Pantalla.PRINCIPAL else _opciones_sonido
		if _pantalla in [Pantalla.PRINCIPAL, Pantalla.SONIDO] and not lista.is_empty():
			lista[0].get_meta("foco").grab_focus()
			get_viewport().set_input_as_handled()


# ============================================================
#  Armado
# ============================================================

# El degrade desde la izquierda (donde va el texto) y una viñeta suave.
func _armar_velos() -> void:
	var lateral := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.32, 0.66, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.72), Color(0, 0, 0, 0.46), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 512
	t.height = 4
	lateral.texture = t
	lateral.stretch_mode = TextureRect.STRETCH_SCALE
	lateral.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lateral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lateral.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(lateral)

	var vineta := TextureRect.new()
	var gv := Gradient.new()
	gv.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gv.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.06), Color(0, 0, 0, 0.42)])
	var tv := GradientTexture2D.new()
	tv.gradient = gv
	tv.fill = GradientTexture2D.FILL_RADIAL
	tv.fill_from = Vector2(0.5, 0.5)
	tv.fill_to = Vector2(1.08, 1.08)
	tv.width = 256
	tv.height = 256
	vineta.texture = tv
	vineta.stretch_mode = TextureRect.STRETCH_SCALE
	vineta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vineta.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vineta)


func _armar_principal() -> void:
	_bloque_principal = Control.new()
	_bloque_principal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bloque_principal)

	_sobrelinea = _texto_mono("CREATIVIDAD  ·  GRUPO 9", 17, 7, 0.75)
	_sobrelinea.position = Vector2(COLUMNA_X + 6.0, TITULO_Y - 6.0)
	_sobrelinea.modulate.a = 0.0
	_bloque_principal.add_child(_sobrelinea)

	var fuente := FontVariation.new()
	fuente.base_font = FUENTE_TITULO
	fuente.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): PESO_TITULO}
	var y := TITULO_Y + 4.0
	for i in 2:
		var palabra := Label.new()
		palabra.text = ["Dopamine", "Rush"][i]
		palabra.add_theme_font_override("font", fuente)
		palabra.add_theme_font_size_override("font_size", TAMANO_TITULO)
		palabra.add_theme_color_override("font_color", BLANCO)
		palabra.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
		palabra.add_theme_constant_override("shadow_offset_y", 3)
		palabra.add_theme_constant_override("shadow_outline_size", 14)
		palabra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		palabra.position = Vector2(COLUMNA_X + (SANGRIA_RUSH if i == 1 else 0.0), y)
		var material := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = CartelDia.SHADER_REVELAR
		material.shader = shader
		material.set_shader_parameter("progreso", 0.0)
		material.set_shader_parameter("suavidad", 140.0)
		palabra.material = material
		_bloque_principal.add_child(palabra)
		_palabras.append(palabra)
		_materiales_titulo.append(material)
		y += TAMANO_TITULO * 0.96
	for i in 2:
		_materiales_titulo[i].set_shader_parameter("ancho", _palabras[i].get_minimum_size().x + 40.0)

	_linea = ColorRect.new()
	_linea.color = Color(1, 1, 1, 0.5)
	_linea.position = Vector2(COLUMNA_X + 8.0, BOTONES_Y - 46.0)
	_linea.size = Vector2(0.0, 1.0)
	_linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloque_principal.add_child(_linea)

	var acciones := [["EMPEZAR", _empezar], ["SONIDO", _abrir_sonido], ["SALIR", _salir]]
	for i in acciones.size():
		var opcion := _opcion(acciones[i][0], acciones[i][1])
		opcion.position = Vector2(COLUMNA_X, BOTONES_Y + i * ENTRE_BOTONES)
		opcion.modulate.a = 0.0
		_bloque_principal.add_child(opcion)
		_opciones.append(opcion)
	_encadenar_foco(_opciones)


func _armar_sonido() -> void:
	_bloque_sonido = Control.new()
	_bloque_sonido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloque_sonido.visible = false
	_bloque_sonido.modulate.a = 0.0
	add_child(_bloque_sonido)

	var fuente := FontVariation.new()
	fuente.base_font = FUENTE_TITULO
	fuente.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): PESO_TITULO}
	var titulo := Label.new()
	titulo.text = "Sonido"
	titulo.add_theme_font_override("font", fuente)
	titulo.add_theme_font_size_override("font_size", 104)
	titulo.add_theme_color_override("font_color", BLANCO)
	titulo.position = Vector2(COLUMNA_X, TITULO_Y + 10.0)
	_bloque_sonido.add_child(titulo)

	var sub := _texto_mono("VOLUMEN DE CADA PARTE DEL JUEGO", 15, 5, 0.5)
	sub.position = Vector2(COLUMNA_X + 6.0, TITULO_Y + 150.0)
	_bloque_sonido.add_child(sub)

	var y := TITULO_Y + 228.0
	for g in Ajustes.GRUPOS:
		var fila := _fila_volumen(g["id"], g["nombre"])
		fila.position = Vector2(COLUMNA_X, y)
		_bloque_sonido.add_child(fila)
		_opciones_sonido.append(fila)
		y += 58.0

	var volver := _opcion("VOLVER", _cerrar_sonido)
	volver.position = Vector2(COLUMNA_X, y + 40.0)
	_bloque_sonido.add_child(volver)
	_opciones_sonido.append(volver)
	_encadenar_foco(_opciones_sonido)


# Abajo a la derecha: los auriculares y la recomendacion.
func _armar_aviso() -> void:
	_aviso = Control.new()
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.modulate.a = 0.0
	add_child(_aviso)

	var texto := _texto_mono("SE RECOMIENDA JUGAR\nCON AURICULARES", 15, 4, 0.78)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	texto.add_theme_constant_override("line_spacing", 4)
	var tam := texto.get_minimum_size()
	var pantalla := Vector2(1920, 1080)
	texto.position = pantalla - MARGEN_AVISO - tam
	_aviso.add_child(texto)

	var icono := TextureRect.new()
	icono.texture = ICONO_AURICULARES
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.size = Vector2(46, 46)
	icono.modulate = Color(1, 1, 1, 0.85)
	icono.position = Vector2(texto.position.x - 46.0 - 20.0, texto.position.y + (tam.y - 46.0) * 0.5)
	_aviso.add_child(icono)


# ============================================================
#  Piezas
# ============================================================

func _texto_mono(texto: String, tamano: int, espaciado: int, alfa: float) -> Label:
	var fuente := FontVariation.new()
	fuente.base_font = FUENTE_MONO
	fuente.spacing_glyph = espaciado
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_override("font", fuente)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", Color(BLANCO, alfa))
	etiqueta.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	etiqueta.add_theme_constant_override("shadow_offset_y", 1)
	etiqueta.add_theme_constant_override("shadow_outline_size", 6)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


# Una opcion del menu: texto en mayusculas que, con el mouse encima o con
# foco, se ilumina, se corre a la derecha y le aparece una rayita adelante.
func _opcion(texto: String, accion: Callable) -> Control:
	var caja := Control.new()
	caja.custom_minimum_size = Vector2(420, 44)
	caja.size = caja.custom_minimum_size
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var raya := ColorRect.new()
	raya.color = BLANCO
	raya.position = Vector2(0, 21)
	raya.size = Vector2(0, 1.5)
	raya.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(raya)

	var fuente := FontVariation.new()
	fuente.base_font = FUENTE_MONO
	fuente.spacing_glyph = 8
	var boton := Button.new()
	boton.text = texto
	boton.flat = true
	boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	boton.add_theme_font_override("font", fuente)
	boton.add_theme_font_size_override("font_size", TAMANO_BOTON)
	for estado in ["font_color", "font_disabled_color"]:
		boton.add_theme_color_override(estado, Color(BLANCO, 0.62))
	for estado in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		boton.add_theme_color_override(estado, BLANCO)
	for estilo in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		boton.add_theme_stylebox_override(estilo, StyleBoxEmpty.new())
	boton.position = Vector2(0, 0)
	boton.size = Vector2(420, 44)
	boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	caja.add_child(boton)

	var resaltar := func(si: bool) -> void:
		var t := caja.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(boton, "position:x", 40.0 if si else 0.0, 0.28)
		t.tween_property(raya, "size:x", 26.0 if si else 0.0, 0.28)
	boton.mouse_entered.connect(func():
		boton.grab_focus())
	boton.focus_entered.connect(func():
		resaltar.call(true)
		_tic(-14.0))
	boton.focus_exited.connect(func(): resaltar.call(false))
	boton.mouse_exited.connect(func():
		if boton.has_focus():
			boton.release_focus())
	boton.pressed.connect(func():
		_tic(-4.0)
		accion.call())
	caja.set_meta("foco", boton)
	return caja


# Una fila de volumen: NOMBRE ———●——— 80
func _fila_volumen(id: String, nombre: String) -> Control:
	var fila := Control.new()
	fila.custom_minimum_size = Vector2(900, 44)
	fila.size = fila.custom_minimum_size
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var etiqueta := _texto_mono(nombre.to_upper(), 16, 5, 0.72)
	etiqueta.position = Vector2(0, 10)
	fila.add_child(etiqueta)

	var valor := _texto_mono("", 16, 3, 0.9)
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	valor.position = Vector2(780, 10)
	valor.size = Vector2(64, 24)
	fila.add_child(valor)

	var barra := HSlider.new()
	barra.min_value = 0
	barra.max_value = 100
	barra.step = 1
	barra.position = Vector2(330, 10)
	barra.size = Vector2(420, 24)
	barra.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_estilar_barra(barra)
	barra.value = round(Ajustes.volumen(id) * 100.0)
	valor.text = str(int(barra.value))
	barra.value_changed.connect(func(v: float):
		valor.text = str(int(v))
		Ajustes.poner_volumen(id, v / 100.0)
		_tic(-10.0, true))
	barra.focus_entered.connect(func(): etiqueta.add_theme_color_override("font_color", BLANCO))
	barra.focus_exited.connect(func(): etiqueta.add_theme_color_override("font_color", Color(BLANCO, 0.72)))
	barra.mouse_entered.connect(func(): barra.grab_focus())
	fila.add_child(barra)
	fila.set_meta("foco", barra)
	return fila


func _estilar_barra(barra: HSlider) -> void:
	var riel := StyleBoxFlat.new()
	riel.bg_color = Color(1, 1, 1, 0.16)
	riel.content_margin_top = 1
	riel.content_margin_bottom = 1
	var lleno := riel.duplicate()
	lleno.bg_color = Color(1, 1, 1, 0.78)
	var lleno_foco := riel.duplicate()
	lleno_foco.bg_color = BLANCO
	barra.add_theme_stylebox_override("slider", riel)
	barra.add_theme_stylebox_override("grabber_area", lleno)
	barra.add_theme_stylebox_override("grabber_area_highlight", lleno_foco)
	barra.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	barra.add_theme_icon_override("grabber", _circulo(14, 0.92))
	barra.add_theme_icon_override("grabber_highlight", _circulo(18, 1.0))
	barra.add_theme_icon_override("grabber_disabled", _circulo(14, 0.4))


# Un circulo blanco con el borde suavizado, para la perilla de la barra.
func _circulo(lado: int, alfa: float) -> ImageTexture:
	var imagen := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var centro := Vector2(lado, lado) * 0.5
	var radio := lado * 0.5 - 1.0
	for y in lado:
		for x in lado:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(centro)
			imagen.set_pixel(x, y, Color(1, 1, 1, alfa * clampf(radio - d + 0.5, 0.0, 1.0)))
	return ImageTexture.create_from_image(imagen)


func _encadenar_foco(lista: Array[Control]) -> void:
	for i in lista.size():
		var actual: Control = lista[i].get_meta("foco")
		var anterior: Control = lista[(i - 1 + lista.size()) % lista.size()].get_meta("foco")
		var siguiente: Control = lista[(i + 1) % lista.size()].get_meta("foco")
		actual.focus_neighbor_top = actual.get_path_to(anterior)
		actual.focus_neighbor_bottom = actual.get_path_to(siguiente)
		actual.focus_previous = actual.focus_neighbor_top
		actual.focus_next = actual.focus_neighbor_bottom


# Un click suave. Moviendo una barra suena seguido pero no metralleta.
func _tic(volumen: float, de_barra: bool = false) -> void:
	if _click.stream == null or _pantalla == Pantalla.ENTRANDO:
		return
	var ahora := Time.get_ticks_msec() / 1000.0
	if de_barra and ahora - _ultimo_tic < 0.07:
		return
	_ultimo_tic = ahora
	_click.volume_db = volumen
	_click.pitch_scale = randf_range(0.96, 1.04) + (0.25 if de_barra else 0.0)
	_click.play()


# ============================================================
#  Transiciones
# ============================================================

func _entrar() -> void:
	_fondo.fundir_ambiente(true, 3.5)
	var t := create_tween().set_parallel(true)
	t.tween_property(_negro, "color:a", 0.0, APARECER_FONDO).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_sobrelinea, "modulate:a", 1.0, 1.2).set_delay(0.9)
	for i in 2:
		var mat := _materiales_titulo[i]
		t.tween_method(func(v: float): mat.set_shader_parameter("progreso", v), 0.0, 1.0, 1.7) \
			.set_delay(1.0 + i * 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_linea, "size:x", 64.0, 0.9).set_delay(2.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in _opciones.size():
		var o := _opciones[i]
		var x := o.position.x
		o.position.x = x - 14.0
		t.tween_property(o, "modulate:a", 1.0, 0.7).set_delay(2.35 + i * ESCALON_BOTONES)
		t.tween_property(o, "position:x", x, 0.9).set_delay(2.35 + i * ESCALON_BOTONES) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_aviso, "modulate:a", 1.0, 1.4).set_delay(3.0)
	await get_tree().create_timer(2.35).timeout
	if _pantalla == Pantalla.ENTRANDO:
		_pantalla = Pantalla.PRINCIPAL


func _abrir_sonido() -> void:
	if _pantalla != Pantalla.PRINCIPAL:
		return
	_pantalla = Pantalla.SONIDO
	_cambiar_bloque(_bloque_principal, _bloque_sonido)


func _cerrar_sonido() -> void:
	if _pantalla != Pantalla.SONIDO:
		return
	_pantalla = Pantalla.PRINCIPAL
	_cambiar_bloque(_bloque_sonido, _bloque_principal)


# El que se va se corre a la izquierda y se apaga; el que llega entra
# desde la derecha. Los dos a la vez, cortito.
func _cambiar_bloque(sale: Control, entra: Control) -> void:
	var foco := get_viewport().gui_get_focus_owner()
	if foco:
		foco.release_focus()
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(sale, "modulate:a", 0.0, 0.25)
	t.tween_property(sale, "position:x", -28.0, 0.3)
	entra.visible = true
	entra.position.x = 28.0
	t.tween_property(entra, "modulate:a", 1.0, 0.4).set_delay(0.12)
	t.tween_property(entra, "position:x", 0.0, 0.5).set_delay(0.12)
	await t.finished
	sale.visible = false


func _empezar() -> void:
	if _pantalla != Pantalla.PRINCIPAL:
		return
	_pantalla = Pantalla.SALIENDO
	_bloquear()
	var t := create_tween().set_parallel(true)
	t.tween_property(_bloque_principal, "modulate:a", 0.0, 0.6)
	t.tween_property(_aviso, "modulate:a", 0.0, 0.6)
	_fondo.fundir_ambiente(false, 1.4)
	await t.finished
	await SceneLoader.fundir_y_cambiar(ESCENA_JUEGO, Color.BLACK, 1.2)


func _salir() -> void:
	if _pantalla != Pantalla.PRINCIPAL:
		return
	_pantalla = Pantalla.SALIENDO
	_bloquear()
	_fondo.fundir_ambiente(false, 0.6)
	var t := create_tween()
	t.tween_property(_negro, "color:a", 1.0, 0.6)
	await t.finished
	get_tree().quit()


func _bloquear() -> void:
	for o in _opciones:
		o.get_meta("foco").disabled = true
