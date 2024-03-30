extends "res://src/main/main.gd"


func _ready():
	super()
	Utils.spawn(preload("res://mods-unpacked/Ste-Goose/goose.tscn"), Game.randomSpawnLocation(300, 300), game_area)
