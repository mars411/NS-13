/obj/shuttle_landmark/lower_level
	name = "Lower Level Dock"
	landmark_tag = "nav_reactor_test_station"
	docking_controller = "lower_level_dock"

/obj/shuttle_landmark/upper_level
	name = "Upper Level Dock"
	landmark_tag = "nav_reactor_test_offsite"
	special_dock_targets = list("Example" = "reactor_test_shuttle_port")
	docking_controller = "upper_level_dock"

/datum/shuttle/autodock/ferry/reactor_test
	name = "Example"
	shuttle_area = /area/shuttle/escape
	dock_target = "reactor_test_shuttle_starboard"
	warmup_time = 10

	location = 0
	waypoint_station = "nav_reactor_test_station"
	waypoint_offsite = "nav_reactor_test_offsite"
