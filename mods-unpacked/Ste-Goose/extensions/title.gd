extends "res://src/title/title.gd"

func _ready():
	super()
	Players.timedMode = false
	Players.inMultiplayer = false
	Players.playerCount = 1

	Players.details = [{
		char = Players.Char.MELEE,
		color = Color.CYAN,
		bgColor = Color.TRANSPARENT,
		colorState = 1,
		skin = "" #"skinCrown"
	}]

	Global.title.startGame()
