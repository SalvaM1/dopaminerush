extends AppBase

# APP DE PRUEBA — provisoria.
# Se usa para cualquier app que todavia no este construida, asi se puede
# probar el escritorio completo antes de tener las 6 apps reales.
# Cuando una app real exista, se reemplaza en ESCENAS_APPS del escritorio.

@onready var boton: Button = $Boton
@onready var etiqueta: Label = $Etiqueta


func _ready() -> void:
	boton.pressed.connect(_al_apretar)
	etiqueta.text = "App de prueba\n(sin mecanica todavia)"


func _al_apretar() -> void:
	recompensar()
