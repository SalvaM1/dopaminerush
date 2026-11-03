extends Node3D

# El fondo del menu: la habitacion (o el parque, si ya se termino el juego)
# vista por una camara que paneá despacio, sin nadie adentro.
#
# Se usa la escena REAL, pero sin sus scripts: se los saca a todos antes
# de que entre al arbol, asi no arranca nada del juego (ni el despertador,
# ni el mouse capturado, ni los carteles). Tambien se sacan el jugador, el
# perro, las interfaces y los sonidos; el menu pone su propio ambiente.
#
# EL PANEO no da la vuelta: ida y vuelta, con un seno, entre dos limites
# que nunca miran una pared. En las puntas frena solo, como una grua. La
# camara ademas se corre un poco de costado, desfasada del giro: eso da
# paralaje (lo cercano se mueve mas que lo lejano) y es lo que hace que se
# sienta una toma y no una foto girando.

const TOMAS := {
	"habitacion": {
		"escena": "res://escenas/01_habitacion/habitacion.tscn",
		# Arriba, contra la ventana (del lado del marco derecho), mirando la
		# pieza en diagonal hacia la puerta. Del otro lado de la ventana
		# esta la cama, y su cabecera taparia media toma.
		"posicion": Vector3(-2.4, 3.55, -8.2),
		"mira": Vector3(5.2, 1.2, 2.6),
		"amplitud": 15.0,       # grados para cada lado
		"periodo": 64.0,        # segundos de una ida y vuelta
		"corrimiento": Vector3(0.45, 0.0, -0.3),
		"fov": 56.0,
		"hora": 9.5 * 60.0,     # luz de mañana por la ventana
		"plafon": true,
		# Casi silencio: solo el zumbido de la pieza, muy bajito
		"ambiente": [
			["res://assets/audio/ambiente/zumbido.ogg", -30.0],
		],
	},
	"parque": {
		"escena": "res://escenas/04_parque/parque.tscn",
		# Del otro lado del lago, mirando hacia el sol: el agua adelante, los
		# arboles a contraluz y la bruma dorada del atardecer.
		"posicion": Vector3(37.0, 3.9, -15.0),
		"mira": Vector3(14.0, 1.2, -2.0),
		"amplitud": 16.0,
		"periodo": 70.0,
		"corrimiento": Vector3(0.0, 0.0, 0.8),
		"fov": 58.0,
		"hora": -1.0,
		"ambiente": [
			["res://assets/audio/ambiente/pajaros.ogg", -14.0],
			["res://assets/audio/ambiente/viento.ogg", -26.0],
			["res://assets/audio/ambiente/agua.ogg", -24.0],
		],
	},
}

# Lo que se saca de la escena, por nombre (ademas de toda interfaz y todo
# sonido, que se sacan por tipo).
const SACAR := ["Jugador", "Perrito", "PantallaViewport", "Dialogo", "Sonidos", "UI"]

@export_enum("habitacion", "parque") var lugar: String = "habitacion"

var camara: Camera3D
var _toma: Dictionary
var _base: Transform3D
var _tiempo: float = 0.0
var _ambiente: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_toma = TOMAS[lugar].duplicate()
	var escena: Node3D = load(_toma["escena"]).instantiate()
	_desarmar(escena)
	add_child(escena)
	if lugar == "habitacion":
		_vestir_habitacion(escena)

	camara = Camera3D.new()
	camara.fov = _toma["fov"]
	add_child(camara)
	camara.current = true
	_base = Transform3D.IDENTITY.looking_at(_toma["mira"] - _toma["posicion"], Vector3.UP)
	_base.origin = _toma["posicion"]
	# Arranca a mitad de camino y yendo: la primera imagen ya se mueve.
	_tiempo = _toma["periodo"] * 0.08
	_mover_camara()

	for capa in _toma["ambiente"]:
		_sumar_ambiente(capa[0], capa[1])


func _process(delta: float) -> void:
	_tiempo += delta
	_mover_camara()


func _mover_camara() -> void:
	var fase := TAU * _tiempo / float(_toma["periodo"])
	var giro := deg_to_rad(_toma["amplitud"]) * sin(fase)
	# Un cabeceo minimo, a otro ritmo, para que no sea un giro de maquina
	var cabeceo := deg_to_rad(1.2) * sin(fase * 0.5 + 1.3)
	var corrimiento: Vector3 = _toma["corrimiento"]
	camara.global_transform = Transform3D(
		Basis(Vector3.UP, giro) * _base.basis * Basis(Vector3.RIGHT, cabeceo),
		_base.origin + corrimiento * cos(fase))


# Sube el ambiente de a poco (lo llama el menu al aparecer) o lo apaga.
func fundir_ambiente(entrada: bool, duracion: float) -> void:
	for r in _ambiente:
		var destino: float = r.get_meta("volumen") if entrada else -60.0
		var t := create_tween()
		t.tween_property(r, "volume_db", destino, duracion)


# ============================================================
#  Armado
# ============================================================

func _desarmar(raiz: Node) -> void:
	var todos: Array[Node] = [raiz]
	todos.append_array(raiz.find_children("*", "", true, false))
	var basura: Array[Node] = []
	for n in todos:
		# La luz del dia se arma con el script del ciclo: ese se queda.
		if n.name != "CicloDia":
			n.set_script(null)
		if n == raiz:
			continue
		if n.name in SACAR or n is CanvasLayer or n is AudioStreamPlayer \
				or n is AudioStreamPlayer3D or n is VideoStreamPlayer:
			basura.append(n)
	for n in basura:
		if is_instance_valid(n) and n.get_parent():
			n.get_parent().remove_child(n)
			n.free()


# Lo que el script de la habitacion hacia al arrancar y se necesita para
# que se vea igual que en el juego.
func _vestir_habitacion(h: Node3D) -> void:
	# El frente plano del mueble se esconde: el cajon de verdad esta adelante
	for ruta in ["HabitacionVisual/MesaDeLuz/FrenteCajon", "HabitacionVisual/MesaDeLuz/Tirador",
			"Interactuables/Cajon/Libreta"]:
		var n := h.get_node_or_null(ruta) as Node3D
		if n:
			n.visible = false

	# El monitor y la tele, apagados: un vidrio oscuro que apenas refleja
	var vidrio := StandardMaterial3D.new()
	vidrio.albedo_color = Color(0.02, 0.025, 0.035)
	vidrio.roughness = 0.12
	vidrio.metallic_specular = 0.8
	var pantalla := h.get_node_or_null("Monitor/Pantalla") as MeshInstance3D
	if pantalla:
		pantalla.material_override = vidrio
	var tele := h.get_node_or_null("HabitacionVisual/Televisor/Cuerpo/Pantalla") as CSGBox3D
	if tele:
		tele.material = vidrio

	# La luz de la hora elegida, por la ventana
	var ciclo := h.get_node_or_null("CicloDia")
	if ciclo and ciclo.has_method("preparar"):
		ciclo.preparar(h)
		ciclo.poner_hora(_toma["hora"])
	var plafon := h.get_node_or_null("HabitacionVisual/Iluminacion/LuzGeneralFria") as Light3D
	if plafon and not _toma.get("plafon", true):
		plafon.light_energy = 0.0


func _sumar_ambiente(ruta: String, volumen: float) -> void:
	if not ResourceLoader.exists(ruta):
		return
	var sonido = load(ruta)
	if sonido is AudioStreamOggVorbis or sonido is AudioStreamMP3:
		sonido.loop = true
	var r := AudioStreamPlayer.new()
	r.stream = sonido
	r.bus = "Ambiente"
	r.volume_db = -60.0
	r.set_meta("volumen", volumen)
	add_child(r)
	r.play()
	_ambiente.append(r)
