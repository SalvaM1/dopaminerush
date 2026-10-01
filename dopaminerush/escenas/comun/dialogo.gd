extends CanvasLayer

# ============================================================
#  Dialogo — el pensamiento del personaje sobre un objeto
# ============================================================
#
# Sistema reutilizable, al estilo de los Resident Evil viejos: mirás algo,
# apretás E, y el personaje PIENSA algo sobre eso. No es narracion ni
# tutorial: es la voz interna de alguien que esta evitando hacer otra cosa.
#
# POR QUE IMPORTA QUE LAS LETRAS SALGAN DE A UNA: un cartel que aparece
# entero se lee como interfaz. Un texto que se escribe se lee como alguien
# pensando, y le da al jugador el ritmo de la frase — donde respira, donde
# duda. Por eso las comas y los puntos tienen pausas propias: sin eso el
# tipeo es una maquina, con eso es una persona.
#
# USO desde cualquier escena:
#     dialogo.mostrar("La mochila de la facultad.")
#     await dialogo.cerrado
#
# El jugador queda quieto mientras hay texto en pantalla. No se congela
# nada del juego porque esto solo pasa ANTES de sentarse a la computadora,
# cuando el drenaje todavia no arranco: explorar la habitacion es gratis,
# y tiene que serlo.

signal cerrado()

# ---- RITMO DEL TIPEO ----
const VELOCIDAD: float = 45.0        # caracteres por segundo
const PAUSA_COMA: float = 0.12       # lo que respira en , ; :
const PAUSA_PUNTO: float = 0.28      # y en . ! ?
const CADA_CUANTO_SUENA: int = 2     # un tic cada N letras

# Ventana muerta despues de abrir. Sin esto, la misma E que abrio el
# cartel lo adelantaria en el mismo frame.
const BLOQUEO_INICIAL: float = 0.18

const SONIDO_TIC := "res://assets/audio/ui/softclick.wav"

# LA FUENTE. El proyecto todavia no tiene ninguna, asi que esto usa la
# que venga de Godot y la reemplaza sola apenas aparezca un archivo en
# assets/fuentes/ con alguno de estos nombres. Dejar un .ttf ahi es todo
# lo que hace falta: no hay que tocar ni esta escena ni este script.
const FUENTES := [
	"res://assets/fuentes/ui.ttf",
	"res://assets/fuentes/ui.otf",
	"res://assets/fuentes/dialogo.ttf",
	"res://assets/fuentes/dialogo.otf",
]

enum Fase { CERRADO, ESCRIBIENDO, ESPERANDO, SALIENDO }

@onready var caja: Panel = $Caja
@onready var texto: Label = $Caja/Texto
@onready var avance: HBoxContainer = $Caja/Avance
@onready var tic: AudioStreamPlayer = $Tic

var _fase: int = Fase.CERRADO
var _completo: String = ""
var _acumulado: float = 0.0
var _pausa: float = 0.0
var _bloqueo: float = 0.0
var _tween_flecha: Tween = null

# Quien pidio el dialogo, para devolverle el control al cerrar.
var _jugador: Node = null


func _ready() -> void:
	caja.modulate.a = 0.0
	caja.visible = false
	avance.visible = false

	if tic.stream == null and ResourceLoader.exists(SONIDO_TIC):
		tic.stream = load(SONIDO_TIC)

	_cargar_fuente()


# Si alguien deja una fuente en assets/fuentes/, la usa. Si no, sigue con
# la de Godot y no se rompe nada.
func _cargar_fuente() -> void:
	for ruta in FUENTES:
		if ResourceLoader.exists(ruta):
			var f = load(ruta)
			if f is Font:
				texto.add_theme_font_override("font", f)
			return


func esta_abierto() -> bool:
	return _fase != Fase.CERRADO


# Muestra un pensamiento. Si le pasas el jugador, le saca el control
# mientras dura y se lo devuelve al cerrar.
func mostrar(pensamiento: String, jugador: Node = null) -> void:
	if _fase != Fase.CERRADO:
		return

	_jugador = jugador
	if _jugador:
		_jugador.puede_mover = false
		_jugador.puede_interactuar = false

	_completo = pensamiento
	texto.text = pensamiento
	texto.visible_characters = 0

	_fase = Fase.ESCRIBIENDO
	_acumulado = 0.0
	_pausa = 0.0
	_bloqueo = BLOQUEO_INICIAL

	avance.visible = false
	caja.visible = true

	# Entra subiendo apenas. Nada de rebotes: no es un premio, es un
	# pensamiento.
	caja.position.y = 26.0
	var t := create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(caja, "modulate:a", 1.0, 0.18)
	t.tween_property(caja, "position:y", 0.0, 0.2)


func _process(delta: float) -> void:
	if _fase == Fase.CERRADO or _fase == Fase.SALIENDO:
		return

	if _bloqueo > 0.0:
		_bloqueo -= delta

	_revisar_tecla()

	if _fase == Fase.ESCRIBIENDO:
		_escribir(delta)


func _revisar_tecla() -> void:
	if _bloqueo > 0.0:
		return
	if not Input.is_action_just_pressed("interactuar"):
		return

	# Primera E: termina de escribir. Segunda: cierra. Es lo que espera
	# cualquiera que haya jugado algo con texto, y evita que el jugador
	# impaciente tenga que esperar la animacion.
	if _fase == Fase.ESCRIBIENDO:
		_terminar_de_escribir()
	else:
		_cerrar()


func _escribir(delta: float) -> void:
	if _pausa > 0.0:
		_pausa -= delta
		return

	_acumulado += delta * VELOCIDAD

	while _acumulado >= 1.0:
		if texto.visible_characters >= _completo.length():
			_terminar_de_escribir()
			return

		_acumulado -= 1.0
		texto.visible_characters += 1

		var c := _completo[texto.visible_characters - 1]
		if texto.visible_characters % CADA_CUANTO_SUENA == 0 and c != " ":
			Juice.sonar(tic, 0.0, 0.12)

		# La puntuacion respira. Es el detalle que separa un tipeo que
		# parece alguien pensando de uno que parece una impresora.
		if c in ",;:":
			_pausa = PAUSA_COMA
			return
		if c in ".!?":
			_pausa = PAUSA_PUNTO
			return


func _terminar_de_escribir() -> void:
	texto.visible_characters = -1      # -1 = todos
	_fase = Fase.ESPERANDO
	_pausa = 0.0

	avance.visible = true
	avance.modulate.a = 0.0

	if _tween_flecha and _tween_flecha.is_valid():
		_tween_flecha.kill()
	_tween_flecha = create_tween().set_loops()
	_tween_flecha.set_trans(Tween.TRANS_SINE)
	_tween_flecha.tween_property(avance, "modulate:a", 1.0, 0.45)
	_tween_flecha.tween_property(avance, "modulate:a", 0.25, 0.45)


func _cerrar() -> void:
	_fase = Fase.SALIENDO

	if _tween_flecha and _tween_flecha.is_valid():
		_tween_flecha.kill()
	avance.visible = false

	var t := create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(caja, "modulate:a", 0.0, 0.14)
	t.tween_property(caja, "position:y", 18.0, 0.16)
	await t.finished

	caja.visible = false
	caja.position.y = 0.0
	_fase = Fase.CERRADO

	if _jugador:
		_jugador.puede_mover = true
		_jugador.puede_interactuar = true
		_jugador = null

	cerrado.emit()
