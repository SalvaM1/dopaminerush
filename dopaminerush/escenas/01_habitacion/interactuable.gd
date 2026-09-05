class_name Interactuable
extends StaticBody3D

# Script reutilizable: se pega a cualquier objeto del mundo con el que
# se pueda interactuar (despertador, silla, puerta, etc.)

# Texto que aparece en el cartel. Se edita desde el Inspector, no desde el código.
@export var texto_interaccion: String = "Interactuar"

# Los demás nodos se conectan a esta señal para saber que fue usado.
signal usado()


# El jugador llama a esta función cuando aprieta E mirando este objeto.
func interactuar() -> void:
	usado.emit()
