// NS-13, палуба 3: карта-шаблон (ревизия 21). Один уровень. Остальные палубы, верфь и штатные роли добавляются позже.
/datum/map/ns13
	name = "NS-13"
	full_name = "NS-13 Deck 3 (template)"
	path = "ns13"

	lobby_screens = list('maps/example/lobby.png')
	lobby_tracks = list(/singleton/audio/track/ns13_deep_sonar_hiss)

	station_levels = list(1)
	contact_levels = list(1)
	player_levels = list(1)

	allowed_spawns = list("Arrivals Shuttle")

	shuttle_docked_message = "The shuttle has docked."
	shuttle_leaving_dock = "The shuttle has departed from home dock."
	shuttle_called_message = "A scheduled transfer shuttle has been sent."
	shuttle_recall_message = "The shuttle has been recalled"
	emergency_shuttle_docked_message = "The emergency escape shuttle has docked."
	emergency_shuttle_leaving_dock = "The emergency escape shuttle has departed from %dock_name%."
	emergency_shuttle_called_message = "An emergency escape shuttle has been sent."
	emergency_shuttle_recall_message = "The emergency shuttle has been recalled"

	// Unit test exemptions
	apc_test_exempt_areas = list(
		/area/space = NO_SCRUBBER|NO_VENT|NO_APC
	)
