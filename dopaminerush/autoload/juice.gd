extends Node

# ============================================================
#  Juice  (autoload)
# ============================================================
#
# Funciones de feedback que usan TODAS las apps. Se escriben una vez
# aca y despues se llaman en una linea desde cualquier lado.
#
# Sin esto, cada persona del equipo resuelve el "pop de un boton" a su
# manera y terminamos con seis estilos distintos y seis bugs distintos.
#
# REGLA DE ORO: el feedback tiene que ser PROPORCIONAL al peso de la
# accion. Una accion chica, una reaccion chica. Juice en todo se vuelve
# ruido y entierra los momentos que si importan.
# (La excepcion es Preguntados, donde la desproporcion es el chiste.)

# Un tween por nodo y por tipo de efecto: si dos tweens animan la misma
# propiedad al mismo tiempo, el resultado es erratico.
var _tweens: Dictionary = {}

var _textura_particula: ImageTexture = null


# ============================================================
#  Escala
# ============================================================

# Crece de golpe y vuelve con rebote elastico. El sobrepaso es lo que
# lo vende: sin el, es solo un cambio de tamaño.
func pop(nodo: Control, fuerza: float = 0.12, duracion: float = 0.35) -> void:
	if nodo == null or not is_instance_valid(nodo):
		return
	centrar_pivote(nodo)

	var t := _nuevo_tween(nodo, "escala")
	nodo.scale = Vector2.ONE * (1.0 + fuerza)
	t.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(nodo, "scale", Vector2.ONE, duracion)


# Aplasta en Y y estira en X, despues vuelve. Lee como peso o impacto.
func squash(nodo: Control, fuerza: float = 0.14, duracion: float = 0.28) -> void:
	if nodo == null or not is_instance_valid(nodo):
		return
	centrar_pivote(nodo)

	var t := _nuevo_tween(nodo, "escala")
	nodo.scale = Vector2(1.0 + fuerza, 1.0 - fuerza)
	t.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(nodo, "scale", Vector2.ONE, duracion)


# Lleva la escala a un valor y la deja ahi (para hover).
func escalar_a(nodo: Control, escala: float, duracion: float = 0.12) -> void:
	if nodo == null or not is_instance_valid(nodo):
		return
	centrar_pivote(nodo)

	var t := _nuevo_tween(nodo, "escala")
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(nodo, "scale", Vector2.ONE * escala, duracion)


# Un Control escala desde su esquina superior izquierda si no se le
# corre el pivote. Sin esto, todo se estira hacia abajo a la derecha.
func centrar_pivote(nodo: Control) -> void:
	if nodo and is_instance_valid(nodo):
		nodo.pivot_offset = nodo.size * 0.5


# ============================================================
#  Color
# ============================================================

# Un frame de color plano y vuelve. Lee al instante como "eso conecto".
func flash(nodo: CanvasItem, color: Color = Color(2.2, 2.2, 2.2), duracion: float = 0.14) -> void:
	if nodo == null or not is_instance_valid(nodo):
		return
	var destino: Color = nodo.modulate
	var t := _nuevo_tween(nodo, "color")
	nodo.modulate = color
	t.tween_property(nodo, "modulate", destino, duracion)


# Va a un color y se queda (para marcar estados).
func tintar(nodo: CanvasItem, color: Color, duracion: float = 0.18) -> void:
	if nodo == null or not is_instance_valid(nodo):
		return
	var t := _nuevo_tween(nodo, "color")
	t.tween_property(nodo, "modulate", color, duracion)


# ============================================================
#  Movimiento
# ============================================================

# Temblor que decae. OJO: mueve la posicion, asi que NO sirve para
# nodos dentro de un contenedor (el contenedor les pisa la posicion).
# Para esos, usar tambalear().
func shake(nodo: Control, intensidad: float = 6.0, duracion: float = 0.3) -> void:
	if nodo == null or not is_instance_valid(nodo):
		return

	var base: Vector2 = nodo.position
	var t := _nuevo_tween(nodo, "shake")
	var pasos := int(duracion / 0.035)

	for i in range(pasos):
		var caida: float = 1.0 - (float(i) / pasos)
		var desvio := Vector2(
			randf_range(-intensidad, intensidad) * caida,
			randf_range(-intensidad, intensidad) * caida * 0.5
		)
		t.tween_property(nodo, "position", base + desvio, 0.035)

	t.tween_property(nodo, "position", base, 0.04)


# Temblor por rotacion. Sirve tambien dentro de contenedores.
func tambalear(nodo: Control, grados: float = 4.0, duracion: float = 0.35) -> void:
	if nodo == null or not is_instance_valid(nodo):
		return
	centrar_pivote(nodo)

	var t := _nuevo_tween(nodo, "rot")
	var pasos := 5
	for i in range(pasos):
		var caida: float = 1.0 - (float(i) / pasos)
		var signo: float = 1.0 if i % 2 == 0 else -1.0
		t.tween_property(nodo, "rotation", deg_to_rad(grados * caida * signo), duracion / pasos)
	t.tween_property(nodo, "rotation", 0.0, 0.06)


# Entrada con fade + escala.
# NO toca la posicion a proposito: si el nodo esta dentro de un
# contenedor (Grid, VBox, HBox), el contenedor le pisa la posicion en
# cada reacomodo y la animacion queda a medias o el nodo desaparece.
# La escala y el alpha son seguros en cualquier contexto.
func entrar(nodo: Control, _desplazamiento: float = 0.0, duracion: float = 0.25, demora: float = 0.0) -> void:
	if nodo == null or not is_instance_valid(nodo):
		return

	centrar_pivote(nodo)
	nodo.modulate.a = 0.0
	nodo.scale = Vector2(0.92, 0.92)

	var t := _nuevo_tween(nodo, "entrada")
	if demora > 0.0:
		t.tween_interval(demora)
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(nodo, "scale", Vector2.ONE, duracion)
	t.parallel().tween_property(nodo, "modulate:a", 1.0, duracion * 0.7)


# ============================================================
#  Numeros
# ============================================================

# Un numero que rueda en vez de saltar.
func contar(label: Label, desde: float, hasta: float, duracion: float = 0.4, formato: String = "%d") -> void:
	if label == null or not is_instance_valid(label):
		return
	var t := _nuevo_tween(label, "contar")
	t.tween_method(
		func(v: float) -> void:
			if is_instance_valid(label):
				label.text = formato % v,
		desde, hasta, duracion
	)


# El "+18" que sube y se desvanece. Se crea y se borra solo.
func numero_flotante(padre: Control, texto: String, color: Color = Color.WHITE,
		posicion: Vector2 = Vector2.ZERO, tamano: int = 32) -> void:
	if padre == null or not is_instance_valid(padre):
		return

	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 100
	padre.add_child(label)

	await padre.get_tree().process_frame
	if not is_instance_valid(label):
		return

	label.position = posicion - label.size * 0.5
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * 0.6

	var t := label.create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "position:y", label.position.y - 55.0, 0.8)
	t.tween_property(label, "modulate:a", 0.0, 0.8)
	t.tween_property(label, "scale", Vector2.ONE, 0.25)
	await t.finished

	if is_instance_valid(label):
		label.queue_free()


# ============================================================
#  Particulas
# ============================================================

# Un puntito suave, generado por codigo: asi no hace falta ningun
# archivo de imagen y todas las apps usan el mismo.
func textura_particula() -> Texture2D:
	if _textura_particula != null:
		return _textura_particula

	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var d: float = Vector2(x - 7.5, y - 7.5).length() / 8.0
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))

	_textura_particula = ImageTexture.create_from_image(img)
	return _textura_particula


# Configura un GPUParticles2D como una rafaga corta.
func configurar_rafaga(particulas: GPUParticles2D, color: Color,
		cantidad: int = 12, velocidad: float = 180.0) -> void:
	if particulas == null or not is_instance_valid(particulas):
		return

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = velocidad * 0.5
	mat.initial_velocity_max = velocidad
	mat.gravity = Vector3(0, 320, 0)
	mat.scale_min = 0.35
	mat.scale_max = 0.9
	mat.damping_min = 40.0
	mat.damping_max = 90.0

	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	mat.color_ramp = gt

	particulas.process_material = mat
	particulas.texture = textura_particula()
	particulas.amount = cantidad
	particulas.lifetime = 0.8
	particulas.one_shot = true
	particulas.explosiveness = 0.95
	particulas.emitting = false


# Configura un GPUParticles2D como fuego continuo.
func configurar_fuego(particulas: GPUParticles2D, cantidad: int = 26) -> void:
	if particulas == null or not is_instance_valid(particulas):
		return

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 14.0
	mat.initial_velocity_min = 38.0
	mat.initial_velocity_max = 78.0
	mat.gravity = Vector3(0, -34, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.8
	mat.damping_min = 10.0
	mat.damping_max = 25.0

	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.92, 0.4, 0.95))
	g.add_point(0.35, Color(1.0, 0.55, 0.12, 0.8))
	g.set_color(1, Color(0.7, 0.16, 0.05, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	mat.color_ramp = gt

	particulas.process_material = mat
	particulas.texture = textura_particula()
	particulas.amount = cantidad
	particulas.lifetime = 1.0
	particulas.one_shot = false
	particulas.explosiveness = 0.0
	particulas.emitting = false


# ============================================================
#  Audio
# ============================================================

# Reproduce un sonido con el tono cambiado. El truco principal de todo
# esto: si el tono sube con la racha, una serie de aciertos se convierte
# en una melodia ascendente. Es lo que hacen Duolingo y medio mercado
# de apps, y genera una sensacion de progresion que ningun efecto
# visual iguala.
func sonar(reproductor: Node, semitonos: float = 0.0, variacion: float = 0.03) -> void:
	if reproductor == null or not is_instance_valid(reproductor):
		return
	if reproductor.stream == null:
		return

	reproductor.pitch_scale = pow(2.0, semitonos / 12.0) * randf_range(1.0 - variacion, 1.0 + variacion)
	reproductor.play()


# ============================================================
#  Interno
# ============================================================

# Devuelve un tween nuevo para ese nodo y ese tipo de efecto, matando
# el anterior si seguia corriendo.
func _nuevo_tween(nodo: Node, clave: String) -> Tween:
	var id := "%d_%s" % [nodo.get_instance_id(), clave]

	if _tweens.has(id):
		var viejo = _tweens[id]
		if viejo is Tween and viejo.is_valid():
			viejo.kill()

	var t := nodo.create_tween()
	_tweens[id] = t
	return t
