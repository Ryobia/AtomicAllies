extends Node

var owned_monsters: Array[MonsterData] = []

# For the MVP, we'll pre-load the 6 common monsters so the collection isn't empty.
# NOTE: You'll need to create these .tres files first!
var starter_monster_paths = [
	"res://data/monsters/Cinder.tres",
	"res://data/monsters/Sprout.tres",
	"res://data/monsters/Droplet.tres",
	"res://data/monsters/Spark.tres",
	"res://data/monsters/Mote.tres",
	"res://data/monsters/Pulse.tres"
]

func _ready():
	# Load the starter monsters into the collection
	for path in starter_monster_paths:
		if FileAccess.file_exists(path):
			var monster_resource = load(path)
			if monster_resource:
				owned_monsters.append(monster_resource)
		else:
			print("MISSING FILE: " + path)
			print("Make sure you created the folder 'data' and 'monsters' and saved the .tres files there!")