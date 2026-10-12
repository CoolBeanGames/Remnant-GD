class_name portal_room
extends Node3D

## Art, baked static collision and local lighting stay editable in each scene.
@export var environment: Environment
@export var left_foot_sounds: Array[AudioStream] = []
@export var right_foot_sounds: Array[AudioStream] = []
@export var suppress_player_light: bool = false
