extends AppBase

# ============================================================
#  Preguntados — la app de la racha (version pulida)
# ============================================================
#
# Es la unica app que te hace PERDER algo. Las demas son tentacion:
# perseguis una recompensa. Esta es obligacion: evitas una perdida.
#
# SOBRE EL EXCESO DE JUICE: en esta app la desproporcion ES el chiste.
# Duolingo real es agresivamente satisfactorio a proposito, y esa
# maquinaria es justo lo que el juego retrata. En las otras apps el
# feedback tiene que ser proporcional; aca cuanto mas desmedido, mejor.
#
# FLUJO:
#   1. Cartel de bienvenida la primera vez. Boton OK.
#   2. La pregunta entra desde arriba y las opciones escalonadas.
#   3. Hay TIEMPO_PREGUNTA segundos. El temporizador escala en urgencia.
#   4. Al clickear: pausa de anticipacion, y recien ahi el resultado.
#        - bien -> verde, racha +1, dopamina x multiplicador
#        - mal o sin responder -> rojo, la racha se ROMPE
#   5. Espera y vuelve a empezar.

# ---- BALANCEO (provisorio, se ajusta en la fase G) ----
const TIEMPO_PREGUNTA: float = 15.0
const ESPERA_ENTRE: float = 5.0
const DURACION_RESULTADO: float = 2.0

const RACHA_MAX: int = 10
const MULT_POR_ACIERTO: float = 0.1
const RACHA_HITO: int = 5          # cada cuantos aciertos hay fanfarria

# Fallar NO resta dopamina: el castigo es perder la racha y el
# multiplicador. Restar encima se sentia injusto.
const PENALIZACION: float = 0.0

# ---- JUICE ----
const PAUSA_ANTICIPACION: float = 0.15   # el silencio antes del reveal
const DEMORA_ENTRE_OPCIONES: float = 0.05
const UMBRAL_ALERTA: float = 5.0
const UMBRAL_CRITICO: float = 3.0

const RUTA_PREGUNTAS := "res://escenas/03_apps/app_04_racha/preguntas.json"

# Los sonidos se cargan por codigo porque asignarlos desde el Inspector
# daba problemas. Si mas adelante se asignan en la escena, estas rutas
# no pisan nada: solo se cargan si el reproductor esta vacio.
const SONIDOS := {
	"acierto":    "res://assets/audio/ui/correct.wav",
	"error":      "res://assets/audio/ui/fail.wav",
	"racha_rota": "res://assets/audio/ui/powerdown.wav",
	"hito":       "res://assets/audio/ui/levelup.wav",
	"pregunta":   "res://assets/audio/ui/popup.wav",
	"hover":      "res://assets/audio/ui/softclick.wav",
	"click":      "res://assets/audio/ui/softclick.wav",
	"tic":        "res://assets/audio/ui/TICTAC.wav",
}

const VERDE := Color(0.25, 0.78, 0.4, 1.0)
const ROJO := Color(0.88, 0.28, 0.28, 1.0)
const NEUTRO := Color(1, 1, 1, 1)
const APAGADO := Color(0.45, 0.47, 0.5, 0.65)
const NARANJA := Color(1.0, 0.65, 0.2, 1.0)

# ---- NODOS ----
@onready var barra_superior: Panel = $BarraSuperior
@onready var barra_racha: ProgressBar = $BarraSuperior/BarraRacha
@onready var etiqueta_mult: Label = $BarraSuperior/Multiplicador
@onready var etiqueta_dias: Label = $BarraSuperior/Dias
@onready var fuego: GPUParticles2D = $BarraSuperior/Fuego

@onready var pregunta_label: Label = $Pregunta
@onready var opciones: GridContainer = $Opciones
@onready var tiempo_barra: ProgressBar = $TiempoBarra
@onready var tiempo_texto: Label = $TiempoTexto

@onready var resultado: Label = $Resultado
@onready var espera: Label = $Espera
@onready var alerta: Panel = $Alerta

@onready var bienvenida: Panel = $Bienvenida
@onready var boton_ok: Button = $Bienvenida/BotonOk

@onready var chispas: GPUParticles2D = $Chispas
@onready var confeti: GPUParticles2D = $Confeti

# Sonidos: todos opcionales. Si el nodo no existe o no tiene archivo
# cargado, la app funciona igual en silencio.
@onready var snd_pregunta: AudioStreamPlayer = get_node_or_null("Sonidos/Pregunta")
@onready var snd_acierto: AudioStreamPlayer = get_node_or_null("Sonidos/Acierto")
@onready var snd_error: AudioStreamPlayer = get_node_or_null("Sonidos/Error")
@onready var snd_racha_rota: AudioStreamPlayer = get_node_or_null("Sonidos/RachaRota")
@onready var snd_hito: AudioStreamPlayer = get_node_or_null("Sonidos/Hito")
@onready var snd_hover: AudioStreamPlayer = get_node_or_null("Sonidos/Hover")
@onready var snd_click: AudioStreamPlayer = get_node_or_null("Sonidos/Click")
@onready var snd_tic: AudioStreamPlayer = get_node_or_null("Sonidos/Tic")

# ---- ESTADO ----
enum Fase { BIENVENIDA, ESPERANDO, PREGUNTANDO, REVELANDO, RESULTADO }

var _fase: int = Fase.BIENVENIDA
var _preguntas: Array = []
var _orden: Array = []
var _cursor: int = 0
var _actual: Dictionary = {}

var _reloj: float = 0.0
var _racha: int = 0
var _ultimo_segundo: int = -1
var _estilo_alerta: StyleBoxFlat = null
var _tween_alerta: Tween = null

const ELOGIOS_BAJO := ["Bien", "Correcto", "Dale", "Ahí va"]
const ELOGIOS_MEDIO := ["¡Muy bien!", "¡Seguí así!", "¡Excelente!", "¡Genio!"]
const ELOGIOS_ALTO := ["¡SOS IMPARABLE 🔥", "¡NADIE TE PARA!", "¡LEYENDA!", "¡INCREÍBLE!"]


func _ready() -> void:
	_cargar_preguntas()
	_barajar()

	# El borde de alerta necesita su propio estilo para poder cambiarle
	# el color en tiempo real sin afectar a nadie mas.
	var estilo := alerta.get_theme_stylebox("panel")
	if estilo is StyleBoxFlat:
		_estilo_alerta = estilo.duplicate()
		alerta.add_theme_stylebox_override("panel", _estilo_alerta)

	_cargar_sonidos()

	Juice.configurar_rafaga(chispas, VERDE, 14, 200.0)
	Juice.configurar_rafaga(confeti, Color(1.0, 0.85, 0.3), 32, 260.0)
	Juice.configurar_fuego(fuego, 24)

	boton_ok.pressed.connect(_empezar)

	for i in range(opciones.get_child_count()):
		var b := opciones.get_child(i) as Button
		if b == null:
			continue
		b.pressed.connect(_responder.bind(i))
		b.mouse_entered.connect(_al_entrar_mouse.bind(b))
		b.mouse_exited.connect(_al_salir_mouse.bind(b))
		b.button_down.connect(_al_apretar.bind(b))

	alerta.modulate.a = 0.0
	resultado.hide()
	espera.hide()
	_mostrar_pregunta_ui(false)
	bienvenida.show()

	_actualizar_racha_ui(false)

	await get_tree().process_frame
	if not esta_activa:
		iniciar()


func _process(delta: float) -> void:
	if not esta_activa:
		return

	match _fase:
		Fase.PREGUNTANDO:
			_reloj -= delta
			_actualizar_temporizador()
			if _reloj <= 0.0:
				_fallar(-1)

		Fase.ESPERANDO:
			_reloj -= delta
			espera.text = "Siguiente pregunta en: %.0f" % ceil(max(0.0, _reloj))
			if _reloj <= 0.0:
				_nueva_pregunta()

		Fase.RESULTADO:
			_reloj -= delta
			if _reloj <= 0.0:
				_ir_a_espera()


# ============================================================
#  Carga de preguntas
# ============================================================

func _cargar_preguntas() -> void:
	var datos = null

	var recurso = load(RUTA_PREGUNTAS)
	if recurso is JSON:
		datos = recurso.data
	elif FileAccess.file_exists(RUTA_PREGUNTAS):
		var f := FileAccess.open(RUTA_PREGUNTAS, FileAccess.READ)
		datos = JSON.parse_string(f.get_as_text())
		f.close()

	if datos is Dictionary and datos.has("preguntas"):
		_preguntas = datos["preguntas"]

	if _preguntas.is_empty():
		push_warning("[Preguntados] no se pudieron cargar las preguntas de " + RUTA_PREGUNTAS)
		_preguntas = [{
			"texto": "Pregunta de ejemplo",
			"opciones": ["Opción 1", "Opción 2"],
			"correcta": 0,
		}]


# Le pone el archivo a cada reproductor que este vacio.
func _cargar_sonidos() -> void:
	var mapa := {
		"acierto": snd_acierto,
		"error": snd_error,
		"racha_rota": snd_racha_rota,
		"hito": snd_hito,
		"pregunta": snd_pregunta,
		"hover": snd_hover,
		"click": snd_click,
		"tic": snd_tic,
	}

	for clave in mapa:
		var reproductor: AudioStreamPlayer = mapa[clave]
		if reproductor == null or reproductor.stream != null:
			continue

		var ruta: String = SONIDOS[clave]
		if ResourceLoader.exists(ruta):
			reproductor.stream = load(ruta)
		else:
			print("[Preguntados] falta el sonido: ", ruta)


func _barajar() -> void:
	_orden = range(_preguntas.size())
	_orden.shuffle()
	_cursor = 0


# ============================================================
#  Ciclo de preguntas
# ============================================================

func _empezar() -> void:
	Juice.sonar(snd_click)
	bienvenida.hide()
	_nueva_pregunta()


func _nueva_pregunta() -> void:
	if _cursor >= _orden.size():
		_barajar()

	_actual = _preguntas[_orden[_cursor]]
	_cursor += 1

	pregunta_label.text = str(_actual.get("texto", "?"))

	var lista: Array = _actual.get("opciones", [])
	for i in range(opciones.get_child_count()):
		var b := opciones.get_child(i) as Button
		if b == null:
			continue
		if i < lista.size():
			b.text = str(lista[i])
			b.show()
			b.disabled = false
			b.modulate = NEUTRO
			b.scale = Vector2.ONE
			b.rotation = 0.0
		else:
			b.hide()

	_fase = Fase.PREGUNTANDO
	_reloj = TIEMPO_PREGUNTA
	_ultimo_segundo = -1

	espera.hide()
	resultado.hide()
	_mostrar_pregunta_ui(true)
	_actualizar_temporizador()

	# La pregunta entra desde arriba, y las opciones escalonadas.
	# Cuatro cosas que aparecen de a una se sienten muchisimo mejor
	# que cuatro que aparecen juntas.
	Juice.entrar(pregunta_label, 22.0, 0.25)
	var visibles := 0
	for i in range(opciones.get_child_count()):
		var b := opciones.get_child(i) as Button
		if b and b.visible:
			Juice.entrar(b, 16.0, 0.22, 0.08 + visibles * DEMORA_ENTRE_OPCIONES)
			visibles += 1

	_encender_alerta(true)
	Juice.sonar(snd_pregunta)


func _responder(indice: int) -> void:
	if _fase != Fase.PREGUNTANDO:
		return

	_fase = Fase.REVELANDO
	Juice.sonar(snd_click)

	var boton := opciones.get_child(indice) as Button
	if boton:
		Juice.escalar_a(boton, 0.96, 0.06)

	# LA PAUSA DE ANTICIPACION. Va contra la intuicion, pero es lo que
	# convierte el resultado en un evento y no en un cambio de estado.
	await get_tree().create_timer(PAUSA_ANTICIPACION).timeout

	var correcta: int = int(_actual.get("correcta", 0))
	if indice == correcta:
		_acertar(indice)
	else:
		_fallar(indice)


# ============================================================
#  Acertar
# ============================================================

func _acertar(indice: int) -> void:
	_apagar_las_otras(indice)

	var boton := opciones.get_child(indice) as Button
	if boton:
		Juice.flash(boton)
		Juice.tintar(boton, VERDE, 0.1)
		Juice.pop(boton, 0.14)
		_lanzar_particulas(chispas, boton)

	var racha_previa := _racha
	_racha = min(_racha + 1, RACHA_MAX)

	# El tono sube un semitono por cada acierto: la serie se vuelve
	# una melodia ascendente.
	Juice.sonar(snd_acierto, float(_racha))

	var ganado := dopamina_por_interaccion * multiplicador_racha()
	recompensar(multiplicador_racha())

	Juice.numero_flotante(
		self, "+%d" % int(ganado), VERDE,
		Vector2(size.x * 0.5, size.y * 0.42),
		28 + _racha * 2
	)

	_actualizar_racha_ui(true, racha_previa)

	# Hito: cada RACHA_HITO aciertos, fanfarria y confeti
	if _racha % RACHA_HITO == 0 and _racha > 0:
		Juice.sonar(snd_hito)
		Juice.pop(barra_superior, 0.06, 0.4)
		_lanzar_particulas(confeti, barra_racha)

	resultado.text = _elogio()
	resultado.modulate = VERDE
	Juice.shake(self, 2.0, 0.08)
	_terminar_pregunta()


# La validacion crece de forma desproporcionada con la racha.
# Que te feliciten asi por acertar una pavada es el chiste.
func _elogio() -> String:
	if _racha >= 8:
		return ELOGIOS_ALTO[randi() % ELOGIOS_ALTO.size()]
	if _racha >= 4:
		return ELOGIOS_MEDIO[randi() % ELOGIOS_MEDIO.size()]
	return ELOGIOS_BAJO[randi() % ELOGIOS_BAJO.size()]


# ============================================================
#  Fallar
# ============================================================

func _fallar(indice: int) -> void:
	var correcta: int = int(_actual.get("correcta", 0))
	_apagar_las_otras(indice if indice >= 0 else correcta)

	if indice >= 0:
		var b := opciones.get_child(indice) as Button
		if b:
			Juice.tintar(b, ROJO, 0.1)
			Juice.tambalear(b, 5.0, 0.35)

	var racha_previa := _racha
	if racha_previa > 0:
		# Romper una racha larga tiene su propio sonido y su propio peso
		Juice.sonar(snd_racha_rota)
		resultado.text = "Perdiste tu racha de %d días" % racha_previa
		Juice.shake(barra_superior, 9.0, 0.45)
		Juice.shake(self, 5.0, 0.3)
	else:
		Juice.sonar(snd_error)
		resultado.text = "Se te pasó" if indice < 0 else "Incorrecto"

	_racha = 0
	_actualizar_racha_ui(true, racha_previa)

	resultado.modulate = ROJO
	Juice.flash(barra_superior, Color(2.0, 0.6, 0.6), 0.2)

	if PENALIZACION > 0.0:
		GameManager.sumar_dopamina(-PENALIZACION, id_app)

	_terminar_pregunta()

	# Medio segundo despues, se ilumina cual era la correcta
	if correcta != indice:
		await get_tree().create_timer(0.5).timeout
		var bc := opciones.get_child(correcta) as Button
		if is_instance_valid(bc):
			Juice.tintar(bc, VERDE, 0.25)
			Juice.pop(bc, 0.08)


func _terminar_pregunta() -> void:
	_fase = Fase.RESULTADO
	_reloj = DURACION_RESULTADO

	for hijo in opciones.get_children():
		if hijo is Button:
			hijo.disabled = true

	resultado.show()
	Juice.pop(resultado, 0.22, 0.45)
	_encender_alerta(false)


func _ir_a_espera() -> void:
	_fase = Fase.ESPERANDO
	_reloj = ESPERA_ENTRE
	resultado.hide()
	_mostrar_pregunta_ui(false)
	espera.show()

	# Que respire, para que no parezca congelado
	Juice.centrar_pivote(espera)
	var t := create_tween().set_loops()
	t.tween_property(espera, "scale", Vector2.ONE * 1.02, 0.8)
	t.tween_property(espera, "scale", Vector2.ONE, 0.8)


# Los que no se eligieron se apagan: dirige la mirada al que importa.
func _apagar_las_otras(elegida: int) -> void:
	for i in range(opciones.get_child_count()):
		var b := opciones.get_child(i) as Button
		if b and b.visible and i != elegida:
			Juice.tintar(b, APAGADO, 0.2)


# ============================================================
#  Botones: hover y press
# ============================================================

func _al_entrar_mouse(boton: Button) -> void:
	if _fase != Fase.PREGUNTANDO:
		return
	Juice.escalar_a(boton, 1.03)
	Juice.sonar(snd_hover, 0.0, 0.06)


func _al_salir_mouse(boton: Button) -> void:
	if _fase != Fase.PREGUNTANDO:
		return
	Juice.escalar_a(boton, 1.0)


func _al_apretar(boton: Button) -> void:
	if _fase != Fase.PREGUNTANDO:
		return
	Juice.escalar_a(boton, 0.96, 0.05)


# ============================================================
#  Racha
# ============================================================

func multiplicador_racha() -> float:
	return 1.0 + _racha * MULT_POR_ACIERTO


func _actualizar_racha_ui(animado: bool, racha_previa: int = 0) -> void:
	barra_racha.max_value = RACHA_MAX

	if animado:
		if _racha == 0 and racha_previa > 0:
			# Al romperse, se vacia DE GOLPE. El contraste con el
			# llenado suave es justamente el efecto.
			barra_racha.value = 0
			Juice.contar(etiqueta_dias, racha_previa, 0, 0.4, "%d días de racha")
		else:
			var t := create_tween()
			t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(barra_racha, "value", float(_racha), 0.35)
			Juice.contar(etiqueta_dias, racha_previa, _racha, 0.35, "%d días de racha")

		Juice.contar(
			etiqueta_mult,
			1.0 + racha_previa * MULT_POR_ACIERTO,
			multiplicador_racha(),
			0.4,
			"%.1fx"
		)
	else:
		barra_racha.value = _racha
		etiqueta_dias.text = "%d días de racha" % _racha
		etiqueta_mult.text = "%.1fx" % multiplicador_racha()

	_actualizar_estado_racha()


func _actualizar_estado_racha() -> void:
	var proporcion: float = float(_racha) / RACHA_MAX

	if _racha >= RACHA_MAX:
		# Al tope: se prende fuego
		barra_racha.modulate = Color(1.0, 0.55, 0.15)
		etiqueta_mult.modulate = Color(1.0, 0.7, 0.25)
		etiqueta_mult.text = "🔥 %.1fx" % multiplicador_racha()
		fuego.emitting = true
		_latir(barra_racha, 1.03, 0.7)
		_latir(etiqueta_mult, 1.06, 0.55)
	else:
		fuego.emitting = false
		barra_racha.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.75, 0.3), proporcion)
		etiqueta_mult.modulate = NEUTRO
		_parar_latido(barra_racha)
		_parar_latido(etiqueta_mult)


func _latir(nodo: Control, escala: float, periodo: float) -> void:
	if nodo.has_meta("latiendo"):
		return
	nodo.set_meta("latiendo", true)
	Juice.centrar_pivote(nodo)

	var t := create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE)
	t.tween_property(nodo, "scale", Vector2.ONE * escala, periodo * 0.5)
	t.tween_property(nodo, "scale", Vector2.ONE, periodo * 0.5)
	nodo.set_meta("tween_latido", t)


func _parar_latido(nodo: Control) -> void:
	if not nodo.has_meta("latiendo"):
		return
	nodo.remove_meta("latiendo")
	var t = nodo.get_meta("tween_latido", null)
	if t is Tween and t.is_valid():
		t.kill()
	nodo.scale = Vector2.ONE


# ============================================================
#  Temporizador
# ============================================================

func _actualizar_temporizador() -> void:
	var restante: float = max(0.0, _reloj)
	tiempo_barra.value = (restante / TIEMPO_PREGUNTA) * 100.0
	tiempo_texto.text = "%.1f s" % restante

	if restante <= UMBRAL_CRITICO:
		tiempo_barra.modulate = ROJO
		tiempo_texto.modulate = ROJO
		_color_alerta(ROJO, 0.22)
	elif restante <= UMBRAL_ALERTA:
		tiempo_barra.modulate = Color(1.0, 0.5, 0.25)
		tiempo_texto.modulate = Color(1.0, 0.5, 0.25)
		_color_alerta(Color(1.0, 0.45, 0.2), 0.32)
	else:
		tiempo_barra.modulate = NEUTRO
		tiempo_texto.modulate = NARANJA

	# Tic-tac y pop del numero en cada segundo entero de la zona de alerta
	var seg := int(ceil(restante))
	if seg != _ultimo_segundo:
		_ultimo_segundo = seg
		if restante <= UMBRAL_ALERTA and restante > 0.0:
			Juice.sonar(snd_tic, 0.0 if restante > UMBRAL_CRITICO else 5.0)
			Juice.pop(tiempo_texto, 0.25 if restante <= UMBRAL_CRITICO else 0.15, 0.25)


# ============================================================
#  Interfaz
# ============================================================

func _mostrar_pregunta_ui(visible_: bool) -> void:
	pregunta_label.visible = visible_
	opciones.visible = visible_
	tiempo_barra.visible = visible_
	tiempo_texto.visible = visible_


func _lanzar_particulas(particulas: GPUParticles2D, sobre: Control) -> void:
	if particulas == null or sobre == null:
		return
	particulas.position = sobre.global_position - global_position + sobre.size * 0.5
	particulas.restart()
	particulas.emitting = true


# El borde pulsa mientras hay una pregunta activa. Con seis ventanas
# abiertas, esta app tiene que competir por la mirada periferica o el
# tiempo se vence sin que el jugador se entere.
func _encender_alerta(encendida: bool) -> void:
	if not encendida:
		if _tween_alerta and _tween_alerta.is_valid():
			_tween_alerta.kill()
		alerta.remove_meta("periodo")
		alerta.modulate.a = 0.0
		return

	_color_alerta(NARANJA, 0.45)


func _color_alerta(color: Color, periodo: float) -> void:
	if _estilo_alerta:
		_estilo_alerta.border_color = color

	# Solo reiniciamos el pulso si cambio el ritmo
	if alerta.has_meta("periodo") and abs(float(alerta.get_meta("periodo")) - periodo) < 0.01:
		return
	alerta.set_meta("periodo", periodo)

	if _tween_alerta and _tween_alerta.is_valid():
		_tween_alerta.kill()

	_tween_alerta = create_tween().set_loops()
	_tween_alerta.tween_property(alerta, "modulate:a", 0.9, periodo)
	_tween_alerta.tween_property(alerta, "modulate:a", 0.15, periodo)
