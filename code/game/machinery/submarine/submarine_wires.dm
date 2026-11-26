/// Провода пульта турбины (ревизия 33).
/// Панель открывается отвёрткой, провода режутся кусачками, импульсы подаёт мультитул. Цвета проводов случайные на раунд и общие у всех пультов.
/// Три провода: кардридер (доступ для обхода защиты), цепь защиты (оборвать = защита не работает) и лампа табло (оборвать = плитка про обход молчит).
/datum/wires/submarine_turbine_console
	holder_type = /obj/machinery/computer/submarine_turbine_console
	wire_count = 3
	descriptions = list(
		new /datum/wire_description(NST_WIRE_ACCESS, "This wire runs to the ID reader.", "ID", SKILL_EXPERIENCED),
		new /datum/wire_description(NST_WIRE_PROTECT, "This wire leads to the turbine protection relay.", "Protection", SKILL_EXPERIENCED),
		new /datum/wire_description(NST_WIRE_LAMP, "This wire leads to the annunciator lamp.", "Lamp", SKILL_EXPERIENCED)
	)

/datum/wires/submarine_turbine_console/CanUse(mob/living/L)
	var/obj/machinery/computer/submarine_turbine_console/C = holder
	return C.panel_open

/datum/wires/submarine_turbine_console/GetInteractWindow(mob/user)
	. += ..()
	. += "<BR>The green light is [IsIndexCut(NST_WIRE_ACCESS) ? "off" : "on"].<BR>"
	. += "The red light is [IsIndexCut(NST_WIRE_PROTECT) ? "off" : "on"].<BR>"
	. += "The amber light is [IsIndexCut(NST_WIRE_LAMP) ? "off" : "on"].<BR>"

/datum/wires/submarine_turbine_console/UpdateCut(index, mended)
	var/obj/machinery/computer/submarine_turbine_console/C = holder
	var/obj/machinery/power/submarine_turbine_generator/G = C.get_unit()
	switch(index)
		if(NST_WIRE_ACCESS)
			C.access_wire_cut = !mended
		if(NST_WIRE_PROTECT)
			if(G)
				G.protection_cut = !mended
		if(NST_WIRE_LAMP)
			if(G)
				G.bypass_lamp_cut = !mended

/datum/wires/submarine_turbine_console/UpdatePulsed(index)
	var/obj/machinery/computer/submarine_turbine_console/C = holder
	switch(index)
		if(NST_WIRE_ACCESS)
			C.access_open_until = world.time + 30 SECONDS
		if(NST_WIRE_PROTECT)
			var/obj/machinery/power/submarine_turbine_generator/G = C.get_unit()
			if(G)
				G.trip_stop_valve("PROTECTION RELAY")

/// Провода сервисной панели стола турбины (ревизия 37). Панель открывается отвёрткой, провода режутся кусачками, импульсы подаёт мультитул.
/// Цвета проводов случайные на раунд. Три провода: кардридер ключа обхода защиты, цепь аварийного останова и индикация (лампы и дисплей).
/datum/wires/submarine_turbine_desk
	holder_type = /obj/structure/turbine_part/panel
	wire_count = 3
	descriptions = list(
		new /datum/wire_description(NST_WIRE_DESK_ID, "This wire runs to the ID reader of the bypass key.", "ID", SKILL_EXPERIENCED),
		new /datum/wire_description(NST_WIRE_DESK_STOP, "This wire leads to the emergency stop circuit.", "Stop", SKILL_EXPERIENCED),
		new /datum/wire_description(NST_WIRE_DESK_LAMP, "This wire leads to the lamps and the display.", "Indication", SKILL_EXPERIENCED)
	)

/datum/wires/submarine_turbine_desk/CanUse(mob/living/L)
	var/obj/structure/turbine_part/panel/P = holder
	return P.panel_open

/datum/wires/submarine_turbine_desk/GetInteractWindow(mob/user)
	. += ..()
	. += "<BR>The green light is [IsIndexCut(NST_WIRE_DESK_ID) ? "off" : "on"].<BR>"
	. += "The red light is [IsIndexCut(NST_WIRE_DESK_STOP) ? "off" : "on"].<BR>"
	. += "The amber light is [IsIndexCut(NST_WIRE_DESK_LAMP) ? "off" : "on"].<BR>"

/datum/wires/submarine_turbine_desk/UpdateCut(index, mended)
	var/obj/structure/turbine_part/panel/P = holder
	switch(index)
		if(NST_WIRE_DESK_ID)
			P.access_wire_cut = !mended
		if(NST_WIRE_DESK_STOP)
			P.stop_cut = !mended
		if(NST_WIRE_DESK_LAMP)
			P.lamp_cut = !mended

/datum/wires/submarine_turbine_desk/UpdatePulsed(index)
	var/obj/structure/turbine_part/panel/P = holder
	switch(index)
		if(NST_WIRE_DESK_ID)
			P.access_open_until = world.time + 30 SECONDS
		if(NST_WIRE_DESK_STOP)
			var/obj/machinery/power/submarine_turbine_generator/G = P.find_unit()
			if(G)
				G.trip_stop_valve("DESK RELAY")
		if(NST_WIRE_DESK_LAMP)
			P.lamp_test_until = world.time + 5 SECONDS
