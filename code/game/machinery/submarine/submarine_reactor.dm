/obj/machinery/submarine_reactor
	name = "reactor section"
	desc = "Heavy lead-composite armor plate."
	icon_state = "engine"
	anchored = 1
	density = 1
	var/casing_fixed = 1

/obj/machinery/submarine_reactor/attack_hand(mob/user)
	user << "You start messing with the bolts..."
	if(do_after(user, 30, target = src))
		casing_fixed = !casing_fixed
		user << "You [casing_fixed ? "secured" : "removed"] the armor plate."
		update_icon()
	return 1

/obj/machinery/submarine_reactor/update_icon()
	if(casing_fixed)
		src.alpha = 255
	else
		src.alpha = 120

// --- СЕКЦИИ РЕАКТОРА ---

/obj/machinery/submarine_reactor/left_end
	name = "reactor left section"
	icon_state = "engine_left"

/obj/machinery/submarine_reactor/core_left
	name = "reactor core A"
	icon_state = "engine_center"
	var/active = 0
	var/core_temperature = 20
	var/rods_pos = 0
	var/water_level = 100
	var/steam_pressure = 0

	// Ссылки на соседние секции для логической связи
	var/obj/machinery/submarine_reactor/left_end/linked_left = null
	var/obj/machinery/submarine_reactor/right_end/linked_right = null
	var/obj/machinery/submarine_reactor/core_right/linked_core_R = null

/obj/machinery/submarine_reactor/core_left/Initialize()
	. = ..()
	START_PROCESSING(SSobj, src)

	// Поиск соседей поблизости (в радиусе 2 клеток)
	linked_left = locate(/obj/machinery/submarine_reactor/left_end) in range(2, src)
	linked_right = locate(/obj/machinery/submarine_reactor/right_end) in range(2, src)
	linked_core_R = locate(/obj/machinery/submarine_reactor/core_right) in range(2, src)

/obj/machinery/submarine_reactor/core_left/Destroy()
	STOP_PROCESSING(SSobj, src)
	. = ..()
	return .

/obj/machinery/submarine_reactor/core_left/Process()
	// Проверяем, снята ли броня хотя бы на одной из 4-х секций
	var/thermal_leak = 0
	if(!casing_fixed)
		thermal_leak = 1
	if(linked_left && !linked_left.casing_fixed)
		thermal_leak = 1
	if(linked_right && !linked_right.casing_fixed)
		thermal_leak = 1
	if(linked_core_R && !linked_core_R.casing_fixed)
		thermal_leak = 1

	if(active)
		// Если есть утечка тепла, реактор остывает быстрее, чем греется!
		if(thermal_leak)
			core_temperature = max(20, core_temperature - 2)
		else
			core_temperature += (rods_pos * 0.1)

		if(core_temperature > 100 && water_level > 0)
			var/evap = (core_temperature / 50)
			water_level -= (evap * 0.1)
			steam_pressure += evap
			core_temperature -= (evap * 0.5)
	else
		core_temperature = max(20, core_temperature - 0.5)

/obj/machinery/submarine_reactor/core_right
	name = "reactor core B"
	icon_state = "engine_center"

/obj/machinery/submarine_reactor/core_right/attack_hand(mob/user)
	user << "You start messing with the bolts..."
	if(do_after(user, 30, target = src))
		casing_fixed = !casing_fixed
		user << "You [casing_fixed ? "secured" : "removed"] the armor plate."
		update_icon()
	return 1

/obj/machinery/submarine_reactor/right_end
	name = "reactor right section"
	icon_state = "engine_right"

// --- CONSOLE (БЩУ) ---

/obj/machinery/computer/submarine_console
	name = "Reactor Control Console"
	desc = "Controls the control rods of the reactor."
	icon_state = "computer"
	var/obj/machinery/submarine_reactor/core_left/linked_core = null

/obj/machinery/computer/submarine_console/attack_hand(mob/user)
	if(!linked_core)
		linked_core = locate(/obj/machinery/submarine_reactor/core_left) in range(10, src)

	if(!linked_core)
		user << "<span class='warning'>ERROR: No connection to the core!</span>"
		return

	var/menu = "<html><head><title>MCR Submarine</title><meta http-equiv='refresh' content='2'></head><body>"
	menu += "<h2>NS-13 Reactor Status</h2>"
	menu += "Core Temperature: <b>[linked_core.core_temperature] C</b><br>"
	menu += "Control Rods: <b>[linked_core.rods_pos]%</b><br>"
	menu += "<hr>"
	menu += "<a href='?src=\ref[src];action=up'>&#91; RAISE RODS (+10%) &#93;</a><br>"
	menu += "<a href='?src=\ref[src];action=down'>&#91; LOWER RODS (-10%) &#93;</a>"
	menu += "</body></html>"

	user << browse(menu, "window=reactor_console;size=400x300")

/obj/machinery/computer/submarine_console/Topic(href, href_list)
	if(!linked_core) return

	if(href_list["action"] == "up")
		linked_core.rods_pos = min(100, linked_core.rods_pos + 10)
		if(!linked_core.active && linked_core.rods_pos > 0)
			linked_core.active = 1

	if(href_list["action"] == "down")
		linked_core.rods_pos = max(0, linked_core.rods_pos - 10)
		if(linked_core.rods_pos == 0)
			linked_core.active = 0

	attack_hand(usr)
