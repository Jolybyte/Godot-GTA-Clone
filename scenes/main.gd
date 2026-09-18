extends Node3D
## Корень: создаёт и связывает все модули в правильном порядке.

func _ready() -> void:
	var asset_loader = preload("res://modules/asset_loader.gd").new()
	asset_loader.name = "AssetLoader"
	add_child(asset_loader)

	var city = preload("res://modules/city_builder.gd").new()
	city.name = "CityBuilder"
	add_child(city)
	Game.city = city

	var day_night = preload("res://modules/day_night.gd").new()
	day_night.name = "DayNight"
	add_child(day_night)

	var player = preload("res://modules/player_controller.gd").new()
	player.name = "PlayerController"
	add_child(player)

	var combat = preload("res://modules/combat.gd").new()
	combat.name = "Combat"
	add_child(combat)

	var weapons = preload("res://modules/weapon_system.gd").new()
	weapons.name = "WeaponSystem"
	add_child(weapons)

	var vehicles = preload("res://modules/vehicle_manager.gd").new()
	vehicles.name = "VehicleManager"
	add_child(vehicles)

	var peds = preload("res://modules/ped_manager.gd").new()
	peds.name = "PedManager"
	add_child(peds)

	var police = preload("res://modules/police_manager.gd").new()
	police.name = "PoliceManager"
	add_child(police)

	var missions = preload("res://modules/mission_manager.gd").new()
	missions.name = "MissionManager"
	add_child(missions)

	var hud = preload("res://modules/hud_manager.gd").new()
	hud.name = "HUDManager"
	add_child(hud)
	
	var audio = preload("res://modules/audio_manager.gd").new()
	audio.name = "AudioManager"
	add_child(audio)
	Game.audio = audio

	Game.combat = combat
	Game.police = police
	Game.missions = missions
	Game.weapons = weapons
	Game.vehicles = vehicles
	Game.peds_m = peds
