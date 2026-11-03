extends SceneTree

# Godot --headless --path . --script res://tools/tests/mezcla_test.gd
#
# La mezcla de los ultimos 30 s: que TODO suene a la vez y la musica se
# entienda. Se separa cada fuente por estereo (donde esta su ventana) y
# por frecuencias, en vez de bajar lo demas. Prueba que el layout de buses
# cargue como esta pensado y que cada reproductor salga por el suyo.
var _fallos: int = 0

# Sonoridad medida de cada fuente despues de igualar los videos (LUFS).
# Sirve para comprobar el orden de la mezcla: musica arriba, despues los
# videos, la tele de fondo.
const LUFS_MUSICA := -13.8
const LUFS_TIKTOK := -16.0
const LUFS_SLOP := -17.3
const LUFS_TELE := -8.8
const VOLUMEN_TELE := -8.0   # el del reproductor 3D en netflox.tscn


func _initialize() -> void:
	call_deferred("_probar")


func _comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos += 1
		push_error("[Mezcla TEST] " + mensaje)


func _bus(nombre: String) -> int:
	return AudioServer.get_bus_index(nombre)


func _efecto(bus: String, clase: String) -> AudioEffect:
	var i := _bus(bus)
	for k in range(AudioServer.get_bus_effect_count(i)):
		var e := AudioServer.get_bus_effect(i, k)
		if e.is_class(clase):
			return e
	return null


func _probar() -> void:
	# ---- los buses cargan ----
	# project.godot pide la configuracion por UID; si la cache de Godot lo
	# pierde, el AudioManager la carga por su ruta. Sin esto el juego arranca
	# con el Master solo y no andan ni la mezcla ni los volumenes del menu.
	await process_frame
	_comprobar(AudioServer.bus_count == 9, "Estan los 9 buses (%d)" % AudioServer.bus_count)

	# ---- los buses y a donde mandan ----
	for nombre in ["Master", "Musica", "Apps", "Ambiente", "UI", "Video", "Loopify", "Slop", "Tele"]:
		_comprobar(_bus(nombre) >= 0, "Existe el bus " + nombre)
	var envios := {"Video": &"Master", "Slop": &"Master", "Tele": &"Master", "Apps": &"Master", "Loopify": &"Musica"}
	for b in envios:
		_comprobar(AudioServer.get_bus_send(_bus(b)) == envios[b], "%s manda a %s" % [b, envios[b]])

	# ---- el 2x de TikTok depende de que el corrector sea el efecto 0 ----
	_comprobar(AudioServer.get_bus_effect(_bus("Video"), 0) is AudioEffectPitchShift,
		"El corrector de tono sigue siendo el efecto 0 del bus Video")

	# ---- el Master: compresor ANTES del limitador ----
	_comprobar(AudioServer.get_bus_effect(_bus("Master"), 0) is AudioEffectCompressor, "El Master comprime primero")
	_comprobar(AudioServer.get_bus_effect(_bus("Master"), 1) is AudioEffectHardLimiter, "Y despues limita")

	# ---- el estereo: cada fuente del lado de su ventana ----
	var pan := func(b: String) -> float:
		var p := _efecto(b, "AudioEffectPanner") as AudioEffectPanner
		return p.pan if p else 0.0
	_comprobar(pan.call("Video") < -0.2, "TikTok suena a la izquierda (su ventana esta a la izquierda)")
	_comprobar(pan.call("Slop") < 0.0 and pan.call("Slop") > pan.call("Video"), "Subway Slop, un poco a la izquierda")
	_comprobar(pan.call("Apps") > 0.2, "El casino y Preguntados, a la derecha")
	_comprobar(_efecto("Loopify", "AudioEffectPanner") == null, "La musica, al centro")

	# ---- las frecuencias ----
	for b in ["Loopify", "Video", "Slop", "Apps", "Tele"]:
		_comprobar(_efecto(b, "AudioEffectEQ6") != null, "El bus %s tiene su ecualizador" % b)
	var eq_musica := _efecto("Loopify", "AudioEffectEQ6") as AudioEffectEQ6
	var eq_tiktok := _efecto("Video", "AudioEffectEQ6") as AudioEffectEQ6
	if eq_musica and eq_tiktok:
		_comprobar(eq_musica.get_band_gain_db(1) > eq_tiktok.get_band_gain_db(1) + 5.0,
			"Los graves son de la musica, no de TikTok")
		_comprobar(eq_tiktok.get_band_gain_db(4) > eq_musica.get_band_gain_db(4) + 3.0,
			"Los medios-agudos (las voces) son de los videos")
	_comprobar(_efecto("Loopify", "AudioEffectLowPassFilter") != null, "El filtro del 'aburrido' sigue en Loopify")

	# ---- lo que NO se toca ----
	_comprobar(AudioServer.get_bus_effect_count(_bus("Ambiente")) == 0, "Ambiente sin efectos: los pasos y el parque suenan igual")
	_comprobar(is_equal_approx(AudioServer.get_bus_volume_db(_bus("Ambiente")), -4.0), "Ambiente con su volumen de siempre")
	_comprobar(is_equal_approx(AudioServer.get_bus_volume_db(_bus("Apps")), -3.0), "Apps con su volumen de siempre (la palanca suena igual)")

	# ---- el orden de la mezcla ----
	var nivel := func(lufs: float, buses: Array, extra: float = 0.0) -> float:
		var n := lufs + extra
		for b in buses:
			n += AudioServer.get_bus_volume_db(_bus(b))
		return n
	var musica: float = nivel.call(LUFS_MUSICA, ["Loopify", "Musica"])
	var tiktok: float = nivel.call(LUFS_TIKTOK, ["Video"])
	var slop: float = nivel.call(LUFS_SLOP, ["Slop"])
	var tele: float = nivel.call(LUFS_TELE, ["Tele"], VOLUMEN_TELE)
	print("[Mezcla TEST] musica %.1f  tiktok %.1f  slop %.1f  tele %.1f" % [musica, tiktok, slop, tele])
	_comprobar(musica > tiktok and tiktok > slop and slop > tele, "Orden: musica, TikTok, Subway, tele")
	_comprobar(musica - tiktok < 5.0, "La musica arriba, pero no tapa: menos de 5 dB sobre TikTok")
	_comprobar(musica - tele < 9.0, "Hasta la tele se escucha: menos de 9 dB debajo de la musica")

	# ---- nada se agacha ----
	var am = root.get_node("AudioManager")
	_comprobar(is_equal_approx(am.AGACHE_DB, 0.0), "Sin agache: todo suena a la vez")

	# ---- cada reproductor sale por su bus ----
	var subway = load("res://escenas/03_apps/app_03_subway/app_subway.tscn").instantiate()
	var reproductor = subway.find_child("Reproductor", true, false)
	_comprobar(reproductor != null and reproductor.bus == &"Slop", "El video de Subway sale por Slop")
	subway.free()
	var tv = load("res://escenas/01_habitacion/netflox/netflox.tscn").instantiate()
	_comprobar(tv.get_node("SonidoPelicula").bus == &"Tele", "La tele sale por Tele, no por Ambiente")
	tv.free()
	var ofertas = load("res://escenas/03_apps/app_05_ofertas/app_ofertas.tscn").instantiate()
	for n in ofertas.get_node("Sonidos").get_children():
		_comprobar(n.bus == &"Apps", "Mercado Libre suena por Apps, como las demas apps (%s)" % n.name)
	ofertas.free()
	var tiktok_app = load("res://escenas/03_apps/app_01_scroll/app_scroll.tscn").instantiate()
	var video = tiktok_app.find_children("*", "VideoStreamPlayer", true, false)
	_comprobar(video.size() > 0 and video[0].bus == &"Video", "El video de TikTok sale por Video")
	tiktok_app.free()

	print("[Mezcla TEST] completado; fallos=", _fallos)
	quit(_fallos)
