/*
	NS-13: парогенератор и главный циркуляционный насос (ревизия 14, начало второго контура).
	Подробности и проверка: README.md в этой же папке, GDD §5.2 (схема двух контуров).

	КАК ЭТО РАБОТАЕТ
	- Если на карте стоит хотя бы один парогенератор с той же меткой reactor_id, ядро работает в РЕЖИМЕ ДВУХ КОНТУРОВ:
	  оно больше не кипит, а греет первичный теплоноситель (вода под постоянным давлением), и тепло уходит в парогенераторы.
	  Без парогенераторов ядро работает по-старому (кипит само), старые карты продолжают работать.
	- Парогенератор (/obj/machinery/submarine_steam_generator) это вторичная сторона: у него своя вода (уровень в процентах),
	  он кипятит её теплом первичного контура, и пар уходит в настоящие паровые трубы Бэя через СВОЙ паровой порт
	  (/obj/machinery/atmospherics/unary/tank/submarine_reactor_steam_port, он находится рядом с парогенератором в радиусе
	  NSR_SG_LINK_RANGE и достаётся ближайшему). Дальше пар идёт в турбину, конденсатор и питательный насос, как и раньше.
	  Питательная вода входит через питательный вход ядра (общий коллектор на оба парогенератора) и делится поровну по свободному месту.
	- Первичный контур пока без труб: ядро, главный насос и парогенераторы связаны только меткой reactor_id (физические трубы
	  первичного контура придут отдельной ревизией, GDD §5.2).
	- Главный циркуляционный насос (/obj/machinery/submarine_primary_pump) гонит первичную воду. Расход от его оборотов; без насоса
	  (или когда он остановлен или выбегает) остаётся естественная циркуляция NSR_NATURAL_CIRC.
	- Давление первичного контура ведёт компенсатор (submarine_pressurizer.dm), без него оно постоянное NSR_PRIMARY_PRESSURE.
- Паровой клапан (ревизия 16): закрытый клапан отрезает парогенератор от труб, пар копится внутри и давление растёт (разрыв при NSR_PRESSURE_BURST).
- Трубки (ревизия 17): повреждение от перепада давлений и оголения, течь первичной воды во вторичный контур, заражение, глушение сваркой.
*/

// ----------------------------------------------------------------------------
// ПАРОГЕНЕРАТОР
// ----------------------------------------------------------------------------

/obj/machinery/submarine_steam_generator
	name = "steam generator"
	desc = "A tall boiler. Hot water from the reactor circuit runs through its tubes and boils clean water on the other side: that steam goes to the turbine."
	// Временный спрайт: стоковый бак, окрашенный в серо-голубой. Заменить своим.
	icon = 'icons/atmos/tank.dmi'
	icon_state = "air"
	color = "#9fb4c4"
	density = TRUE
	anchored = TRUE
	use_power = POWER_USE_OFF
	construct_state = null
	uncreated_component_parts = null
	can_use_tools = FALSE
	stat_immune = MACHINE_STAT_NOPOWER | MACHINE_STAT_NOSCREEN | MACHINE_STAT_NOINPUT

	/// Метка реактора, к которому подключён парогенератор. Должна совпадать с reactor_id ядра.
	var/reactor_id = "main"
	var/obj/machinery/submarine_reactor_core/core
	/// Вода вторичного контура, 0-100%.
	var/coolant_level = 100
	/// Давление пара на выходе, бар. Считается из настоящего газа.
	var/steam_pressure = 0
	/// Выработка пара за последний тик, моль/с.
	var/steam_flow = 0
	/// Тепло, которое парогенератор забрал у первичного контура за последний тик, ед. в секунду.
	var/heat_transfer = 0
	/// Парогенератор разорван давлением (взрыв). Необратимо.
	var/ruptured = FALSE
	/// Паровой порт на трубах. Если есть, пар и давление берутся оттуда.
	var/obj/machinery/atmospherics/unary/tank/submarine_reactor_steam_port/steam_port
	/// Собственный газ запечатанного парогенератора: если порта нет, или если закрыт паровой клапан (тогда в нём копится пар и растёт давление).
	var/datum/gas_mixture/vessel_air
	/// Паровой клапан закрыт (ревизия 16): парогенератор отрезан от паровых труб, пар копится внутри. Закрывают и открывают с пульта реактора или рукой у самого парогенератора.
	var/steam_valve_closed = FALSE
	/// Повреждение трубок, 0-100% (ревизия 17). Растёт от слишком большого перепада давлений между контурами и от оголения трубок при перегреве. Необратимо.
	var/tube_damage = 0
	/// Трубки текут: первичная вода идёт во вторичный контур, пока давление первичного контура выше давления пара.
	var/tube_leak = FALSE
	/// Доля заглушённых трубок, %. Теплоотдача парогенератора падает на столько же, течь становится слабее.
	var/tubes_plugged = 0
	/// Утечка первичной воды за последний тик, % запаса первичного контура в секунду (для пульта).
	var/leak_rate = 0
	/// Заражение вторичной стороны, 0-100: копится, пока трубки текут, и убывает медленно. Заражённый парогенератор фонит.
	var/contamination = 0

/obj/machinery/submarine_steam_generator/Initialize()
	. = ..()
	GLOB.submarine_steam_gens += src
	vessel_air = new /datum/gas_mixture(NSR_VESSEL_VOLUME, T0C + NSR_AMBIENT_TEMP)
	queue_icon_update()
	return INITIALIZE_HINT_LATELOAD

/obj/machinery/submarine_steam_generator/LateInitialize(mapload, ...)
	find_steam_port()

/obj/machinery/submarine_steam_generator/Destroy()
	GLOB.submarine_steam_gens -= src
	if(core)
		core.steam_gens -= src
		core = null
	if(steam_port)
		steam_port.sg = null
		steam_port = null
	vessel_air = null
	return ..()

/// Ищет ближайший свободный паровой порт с той же меткой реактора. Если порт уже занят другим парогенератором, который к нему ближе, берёт следующий.
/obj/machinery/submarine_steam_generator/proc/find_steam_port()
	if(steam_port)
		steam_port.sg = null
	steam_port = null
	var/best_dist = 999
	var/obj/machinery/atmospherics/unary/tank/submarine_reactor_steam_port/best
	for(var/obj/machinery/atmospherics/unary/tank/submarine_reactor_steam_port/P in range(NSR_SG_LINK_RANGE, src))
		if(P.reactor_id != reactor_id || P.core)
			continue
		var/dist = get_dist(P, src)
		if(P.sg && P.sg != src && !QDELETED(P.sg) && get_dist(P, P.sg) <= dist)
			continue
		if(dist < best_dist)
			best = P
			best_dist = dist
	if(best)
		if(best.sg && best.sg != src)
			best.sg.steam_port = null
		best.sg = src
		steam_port = best
	return !!steam_port

/// Газ, в котором живёт пар парогенератора: газ порта на трубах или собственный газ запечатанного парогенератора (нет порта или закрыт паровой клапан).
/obj/machinery/submarine_steam_generator/proc/get_steam_air()
	RETURN_TYPE(/datum/gas_mixture)
	if(!steam_valve_closed && steam_port && !QDELETED(steam_port) && steam_port.air_contents)
		return steam_port.air_contents
	return vessel_air

/// Закрывает или открывает паровой клапан. При закрытии парогенератор запирает у себя столько пара, сколько было в его газовом объёме (давление то же, что в линии),
/// и дальше пар копится внутри: давление растёт, пока не откроют клапан или не разорвёт парогенератор. При открытии накопленный пар разом уходит в трубы:
/// если давление внутри намного выше давления в линии, трубы получают скачок давления. Возвращает TRUE, если состояние изменилось.
/obj/machinery/submarine_steam_generator/proc/set_steam_valve(closed)
	if(ruptured || closed == steam_valve_closed)
		return FALSE
	var/datum/gas_mixture/line = (steam_port && !QDELETED(steam_port)) ? steam_port.air_contents : null
	if(closed)
		if(line)
			vessel_air.copy_from(line)
			vessel_air.volume = line.volume
		steam_valve_closed = TRUE
		playsound(src, NS_SND_WRENCH, 50, TRUE)
		return TRUE
	steam_valve_closed = FALSE
	if(line && vessel_air.total_moles > 0)
		line.merge(vessel_air.remove_ratio(1))
		if(steam_port.network)
			steam_port.network.update = 1
	playsound(src, NS_SND_HATCH_OPEN, 40, TRUE)
	return TRUE

/// Питательная вода входит в парогенератор (в молях). Возвращает, сколько моль влезло.
/obj/machinery/submarine_steam_generator/proc/add_water(moles)
	if(ruptured)
		return 0
	var/room = (100 - coolant_level) * NSR_SG_MOLES_PER_PERCENT
	var/added = clamp(moles, 0, room)
	coolant_level = min(100, coolant_level + added / NSR_SG_MOLES_PER_PERCENT)
	return added

/// Один шаг теплообмена за dt секунд. primary_temp: температура первичной воды, C. flow: расход первичной воды, доля от полного (0-1).
/// Возвращает, сколько тепла забрано у первичного контура. Кипит вторичная вода, пар уходит в порт. Если уровень воды ниже
/// NSR_SG_COVER_LEVEL, трубки оголяются и теплоотдача падает пропорционально, при нулевом уровне её нет.
/obj/machinery/submarine_steam_generator/proc/transfer_heat(primary_temp, flow, dt)
	steam_flow = 0
	heat_transfer = 0
	var/datum/gas_mixture/air = get_steam_air()
	steam_pressure = air.return_pressure() / NSR_KPA_PER_BAR
	if(ruptured)
		return 0
	var/boil_point = NSR_BOIL_TEMP + steam_pressure * NSR_BOIL_TEMP_PER_BAR
	if(primary_temp <= boil_point || coolant_level <= 0)
		return 0
	var/cover = clamp(coolant_level / NSR_SG_COVER_LEVEL, 0, 1)
	var/heat = (primary_temp - boil_point) * NSR_SG_CONDUCT * flow * cover * (1 - tubes_plugged / 100)
	// Не больше, чем способна отдать оставшаяся вода за этот шаг.
	var/boil_moles = min(heat * NSR_MOLES_PER_HEAT * dt, coolant_level * NSR_SG_MOLES_PER_PERCENT)
	heat = boil_moles / (NSR_MOLES_PER_HEAT * dt)
	coolant_level = max(0, coolant_level - boil_moles / NSR_SG_MOLES_PER_PERCENT)
	// Пар уходит в порт (или в собственный газ) с температурой кипения.
	air.adjust_gas_temp(GAS_STEAM, boil_moles, boil_point + T0C)
	if(!steam_valve_closed && steam_port && steam_port.network)
		steam_port.network.update = 1
	steam_flow = boil_moles / dt
	heat_transfer = heat
	steam_pressure = air.return_pressure() / NSR_KPA_PER_BAR
	return heat

/// Состояние трубок за dt секунд (ревизия 17). primary_pressure: давление первичного контура, бар; primary_temp: температура первичной воды, C.
/// Трубки портятся, если перепад давлений между контурами выше NSR_TUBE_DP_SAFE, и если они оголены и горячее NSR_TUBE_DRY_TEMP (сухой парогенератор).
/// Когда повреждение дошло до 100%, трубки текут: первичная вода идёт во вторичный контур пропорционально перепаду давлений. Возвращает, сколько процентов
/// запаса первичной воды утекло за шаг (ядро вычитает это из запаса). Закрытый клапан не спасает: пар в парогенераторе копится, давление растёт,
/// перепад давлений падает, течь слабеет, зато парогенератор рвётся при NSR_PRESSURE_BURST.
/obj/machinery/submarine_steam_generator/proc/update_tubes(primary_pressure, primary_temp, dt)
	leak_rate = 0
	if(ruptured)
		return 0
	var/delta_p = primary_pressure - steam_pressure
	if(!tube_leak)
		var/damage = 0
		if(delta_p > NSR_TUBE_DP_SAFE)
			damage += NSR_TUBE_DP_RATE * (delta_p - NSR_TUBE_DP_SAFE) / 10
		if(coolant_level < NSR_TUBE_DRY_LEVEL && primary_temp > NSR_TUBE_DRY_TEMP)
			damage += NSR_TUBE_DRY_RATE * (primary_temp - NSR_TUBE_DRY_TEMP) / 100 * (1 - coolant_level / NSR_TUBE_DRY_LEVEL)
		if(damage > 0)
			tube_damage = min(100, tube_damage + damage * dt)
			if(tube_damage >= 100)
				start_tube_leak()
	var/leaked = 0
	if(tube_leak && delta_p > 0)
		leak_rate = NSR_TUBE_LEAK_DRAIN * delta_p / NSR_PRIMARY_PRESSURE * (1 - tubes_plugged / 100)
		leaked = leak_rate * dt
		// Вода первичного контура прибавляется к воде парогенератора; если он полон, излишек вскипает в пар (парогенератор «захлёбывается»).
		var/added = leaked * NSR_PRIMARY_KG_PER_PERCENT / NSR_SG_KG_PER_PERCENT
		var/room = 100 - coolant_level
		coolant_level = min(100, coolant_level + added)
		if(added > room)
			var/datum/gas_mixture/air = get_steam_air()
			var/boil_point = NSR_BOIL_TEMP + steam_pressure * NSR_BOIL_TEMP_PER_BAR
			air.adjust_gas_temp(GAS_STEAM, (added - room) * NSR_SG_MOLES_PER_PERCENT, boil_point + T0C)
			if(!steam_valve_closed && steam_port && steam_port.network)
				steam_port.network.update = 1
	contamination = clamp(contamination + leaked * NSR_CONTAM_PER_LEAK - NSR_CONTAM_DECAY * dt, 0, 100)
	return leaked

/// Одна из трубок лопнула: начинается течь первичной воды во вторичный контур.
/obj/machinery/submarine_steam_generator/proc/start_tube_leak()
	if(tube_leak)
		return
	tube_leak = TRUE
	visible_message(SPAN_DANGER("Something bursts inside \the [src] with a muffled bang, and its gauge starts to climb!"))
	playsound(src, NS_SND_RELIEF, 60, TRUE)

/// Заражённый парогенератор фонит (первичная вода радиоактивна). Зовёт ядро.
/obj/machinery/submarine_steam_generator/proc/emit_contamination()
	if(contamination < 1)
		return
	SSradiation.radiate(src, NSR_RADS_TUBE_LEAK * contamination / 100)

/// Состояние трубок для пульта.
/obj/machinery/submarine_steam_generator/proc/get_tube_text()
	if(tube_leak)
		return "LEAKING"
	if(tube_damage >= NSR_TUBE_WARN)
		return "DAMAGED"
	return "OK"

/// Рука у парогенератора: местный паровой клапан (то же, что кнопка на пульте реактора).
/obj/machinery/submarine_steam_generator/physical_attack_hand(mob/user)
	if(ruptured)
		to_chat(user, SPAN_WARNING("\The [src] has burst, there is no valve left to turn."))
		return TRUE
	set_steam_valve(!steam_valve_closed)
	visible_message(SPAN_NOTICE("\The [user] [steam_valve_closed ? "closes" : "opens"] the steam valve of \the [src]."))
	return TRUE

/// Сварка: глушение текущих трубок. Возможно, пока реактор холодный и оба контура без давления. Заглушённые трубки не греют и не текут, остальные уже слабые.
/obj/machinery/submarine_steam_generator/use_tool(obj/item/tool, mob/living/user, list/click_params)
	if(!isWelder(tool))
		return ..()
	if(ruptured)
		to_chat(user, SPAN_WARNING("\The [src] has burst, there is nothing to weld here."))
		return TRUE
	if(!tube_leak)
		to_chat(user, SPAN_NOTICE("The tubes of \the [src] do not leak, there is nothing to plug."))
		return TRUE
	if(tubes_plugged >= NSR_TUBE_PLUG_MAX)
		to_chat(user, SPAN_WARNING("Too many tubes of \the [src] are plugged already: it would not heat the steam any more. It needs a new tube bundle."))
		return TRUE
	if(!can_plug_tubes())
		to_chat(user, SPAN_WARNING("The tubes are too hot or under pressure to plug. Cool the reactor below [NSR_LEAK_REPAIR_TEMP] C and let both circuits drop below [NSR_LEAK_REPAIR_PRESSURE] bar first."))
		return TRUE
	var/obj/item/weldingtool/welder = tool
	if(!welder.remove_fuel(5, user))
		return TRUE
	user.visible_message(SPAN_NOTICE("\The [user] starts plugging the leaking tubes of \the [src]."))
	playsound(src, NS_SND_WELD, 50, TRUE)
	if(!do_after(user, NSR_TUBE_PLUG_TIME, src) || !tube_leak || !can_plug_tubes())
		return TRUE
	tube_leak = FALSE
	tubes_plugged = min(NSR_TUBE_PLUG_MAX, tubes_plugged + NSR_TUBE_PLUG_STEP)
	tube_damage = NSR_TUBE_PLUG_DAMAGE
	user.visible_message(SPAN_NOTICE("\The [user] plugs the leaking tubes of \the [src]."))
	playsound(src, NS_SND_BUILT, 50, TRUE)
	return TRUE

/// Можно ли сейчас глушить трубки: реактор холодный, давление в обоих контурах низкое.
/obj/machinery/submarine_steam_generator/proc/can_plug_tubes()
	if(steam_pressure > NSR_LEAK_REPAIR_PRESSURE)
		return FALSE
	if(core && !QDELETED(core))
		if(core.core_temperature > NSR_LEAK_REPAIR_TEMP || core.primary_pressure > NSR_LEAK_REPAIR_PRESSURE)
			return FALSE
	return TRUE

/// Энергия взрыва парогенератора, МДж: расширение пара в паровом объёме (по давлению) плюс вскипание вторичной воды, разом потерявшей давление (ревизия 16).
/obj/machinery/submarine_steam_generator/proc/blast_energy()
	var/gas = NSR_BLAST_BAR_M3 * max(0, steam_pressure - 1) * NSR_SG_GAS_M3
	var/boil_point = NSR_BOIL_TEMP + steam_pressure * NSR_BOIL_TEMP_PER_BAR
	var/flash = NSR_BLAST_FLASH_YIELD * NSR_SG_KG_PER_PERCENT * coolant_level * NSR_WATER_MJ_PER_KG_C * max(0, boil_point - NSR_BOIL_TEMP)
	return gas + flash

/// Взрыв от давления пара. Рвёт парогенератор и всё вокруг; радиус по энергии (blast_energy), на давлении разрыва это NSR_SG_RUPTURE_RANGE. Необратимо.
/// Первичный контур от этого пока не страдает (течь трубок парогенератора и заражение вторички будут отдельной ревизией).
/obj/machinery/submarine_steam_generator/proc/rupture()
	if(ruptured)
		return
	var/blast_range = nsr_blast_range(blast_energy(), NSR_SG_ENERGY_REF, NSR_SG_RUPTURE_RANGE)
	ruptured = TRUE
	steam_flow = 0
	heat_transfer = 0
	queue_icon_update()
	visible_message(SPAN_DANGER("\The [src] ruptures violently!"))
	var/datum/gas_mixture/released = get_steam_air().remove_ratio(1)
	var/turf/here = get_turf(src)
	if(here && released)
		here.assume_air(released)
	steam_pressure = 0
	if(here)
		explosion(here, blast_range)

/// Состояние для пульта.
/obj/machinery/submarine_steam_generator/proc/get_state_text()
	if(ruptured)
		return "RUPTURED"
	if(!steam_port)
		return "NO STEAM PORT"
	if(coolant_level <= 0)
		return "DRY"
	if(steam_valve_closed)
		return "VALVE CLOSED"
	if(coolant_level < NSR_SG_COVER_LEVEL)
		return "LOW WATER"
	if(heat_transfer > 0.5)
		return "BOILING"
	return "IDLE"

/obj/machinery/submarine_steam_generator/on_update_icon()
	color = ruptured ? "#554433" : initial(color)

/obj/machinery/submarine_steam_generator/examine(mob/user, distance)
	. = ..()
	if(ruptured)
		to_chat(user, SPAN_DANGER("It has burst. Steam is no longer made here."))
	else if(distance <= 3)
		to_chat(user, "Its gauge shows [round(coolant_level)]% water on the steam side and [round(steam_pressure, 0.1)] bar of steam. Its steam valve is [steam_valve_closed ? "CLOSED" : "open"]. Click it with an empty hand to turn the valve.")
		if(tube_leak)
			to_chat(user, SPAN_WARNING("A tube inside it leaks: the water on the steam side is rising and it feels warm."))
		if(tubes_plugged > 0)
			to_chat(user, "[tubes_plugged]% of its tubes are plugged.")

// ----------------------------------------------------------------------------
// ГЛАВНЫЙ ЦИРКУЛЯЦИОННЫЙ НАСОС ПЕРВИЧНОГО КОНТУРА
// ----------------------------------------------------------------------------

/// Главный циркуляционный насос. Гонит первичную воду через ядро и парогенераторы: чем выше обороты, тем больше теплоотдача.
/// Ему нужно электропитание от щитка (как питательному насосу). Разгоняется за 20 секунд и выбегает около 40 секунд (тяжёлый ротор).
/// Остановленный насос не отключает теплоотвод совсем: остаётся естественная циркуляция (NSR_NATURAL_CIRC), она тянет остаточное тепло и малую мощность.
/// Пока без труб, связан с реактором меткой reactor_id (физические трубы первичного контура придут отдельной ревизией).
/obj/machinery/submarine_primary_pump
	name = "main coolant pump"
	desc = "A heavy pump that drives the reactor water around the primary circuit. It needs electric power. If it stops, the water still creeps by natural circulation, but much too slowly for full power."
	// Временный спрайт: стоковый насос, окрашенный в красно-коричневый. Заменить своим.
	icon = 'icons/atmos/pump.dmi'
	icon_state = "off"
	color = "#b0502d"
	density = TRUE
	anchored = TRUE
	use_power = POWER_USE_OFF

	/// Метка реактора. Должна совпадать с reactor_id ядра.
	var/reactor_id = "main"
	var/obj/machinery/submarine_reactor_core/core
	/// Заданная скорость (уставка), 0-100%. По умолчанию полная: главный насос в нормальной работе не останавливают.
	var/speed = 100
	/// Фактическая скорость, 0-100%: идёт к уставке с разгоном и торможением, без питания выбегает.
	var/spin = 0
	/// Петля звука работы (стоковый sound_player).
	var/datum/sound_token/sound_token
	/// Износ, 0-100% (ревизия 17): растёт от кавитации (пар в ядре), горячей воды и сухого хода. При 100% ротор заклинивает.
	var/wear = 0
	/// Ротор заклинило. Насос встаёт, не запускается, пока не заменят подшипники (гаечный ключ на остановленном холодном насосе).
	var/seized = FALSE

/obj/machinery/submarine_primary_pump/Initialize()
	. = ..()
	GLOB.submarine_primary_pumps += src
	return INITIALIZE_HINT_LATELOAD

/obj/machinery/submarine_primary_pump/LateInitialize(mapload, ...)
	for(var/obj/machinery/submarine_reactor_core/R in GLOB.submarine_reactors)
		if(R.reactor_id == reactor_id)
			R.find_primary_pump()

/obj/machinery/submarine_primary_pump/Destroy()
	QDEL_NULL(sound_token)
	GLOB.submarine_primary_pumps -= src
	if(core)
		core.primary_pump = null
	core = null
	return ..()

/// Обороты для пульта, об/мин.
/obj/machinery/submarine_primary_pump/proc/get_rpm()
	return round(spin / 100 * NSR_PRIMARY_PUMP_RPM_MAX)

/// Что делает ротор: для пульта.
/obj/machinery/submarine_primary_pump/proc/get_state_text()
	if(seized)
		return "SEIZED"
	if(spin <= 0)
		return inoperable() ? "NO POWER" : "STOPPED"
	if(inoperable())
		return "COASTING DOWN"
	if(spin < speed - 0.5)
		return "SPINNING UP"
	if(spin > speed + 0.5)
		return "SPINNING DOWN"
	return "AT SPEED"

/// Гул насоса: петля звука с громкостью по оборотам. Выключается, когда насос встал.
/obj/machinery/submarine_primary_pump/proc/update_sound()
	if(spin < 3)
		if(sound_token)
			QDEL_NULL(sound_token)
		return
	var/volume = 8 + 18 * spin / 100
	if(!sound_token)
		sound_token = GLOB.sound_player.PlayLoopingSound(src, "nsr_primary_\ref[src]", NS_SND_PUMP_LOOP, volume = volume, range = 7, falloff = 3, prefer_mute = TRUE)
	else
		sound_token.SetVolume(volume)

/obj/machinery/submarine_primary_pump/Process(wait)
	// Родительский Process() не зовём: у /obj/machinery он возвращает PROCESS_KILL и остановил бы обработку.
	var/dt = 2
	if(wait > 0)
		dt = clamp(wait / 10, 0.5, 5)
	if(seized)
		spin = max(0, spin - NSR_PPUMP_SEIZE_DECEL * dt)
		update_sound()
		return
	update_wear(dt)
	var/powered = !inoperable()
	var/goal = powered ? speed : 0
	if(spin < goal)
		spin = min(goal, spin + NSR_PRIMARY_PUMP_SPINUP * dt)
	else if(spin > goal)
		spin = max(goal, spin - NSR_PRIMARY_PUMP_SPINDOWN * dt)
	if(spin < 0.5 && goal <= 0)
		spin = 0
	if(powered && spin > 0)
		use_power_oneoff(NSR_PRIMARY_PUMP_POWER * spin / 100)
	update_sound()

/// Износ за dt секунд: пар в ядре (кавитация), горячая первичная вода (уплотнения), сухой ход (мало воды). Зависит от оборотов: стоящий насос не изнашивается.
/obj/machinery/submarine_primary_pump/proc/update_wear(dt)
	if(spin < 20 || !core || QDELETED(core))
		return
	var/wear_rate = 0
	if(core.cooling_eff < 0.9)
		wear_rate += NSR_PPUMP_CAV_RATE * (1 - core.cooling_eff)
	if(core.core_temperature > NSR_PPUMP_HOT_TEMP)
		wear_rate += NSR_PPUMP_HOT_RATE * (core.core_temperature - NSR_PPUMP_HOT_TEMP) / 100
	if(core.two_circuit && core.primary_inventory < NSR_INV_COVER)
		wear_rate += NSR_PPUMP_DRY_RATE * (1 - core.primary_inventory / NSR_INV_COVER)
	if(wear_rate <= 0)
		return
	wear = min(100, wear + wear_rate * (spin / 100) * dt)
	if(wear >= 100)
		seize()

/// Ротор заклинило: насос встаёт, остаётся только естественная циркуляция. Заводить заново нельзя, пока не заменят подшипники.
/obj/machinery/submarine_primary_pump/proc/seize()
	if(seized)
		return
	seized = TRUE
	speed = 0
	visible_message(SPAN_DANGER("\The [src] shrieks, shudders and seizes up!"))
	playsound(src, NS_SND_TRIP, 80, TRUE)

/// Замена подшипников гаечным ключом: насос стоит (ротор встал), первичная вода холоднее NSR_PPUMP_REPAIR_TEMP. Износ сбрасывается, заклинивание снимается.
/obj/machinery/submarine_primary_pump/use_tool(obj/item/tool, mob/living/user, list/click_params)
	if(!isWrench(tool))
		return ..()
	if(wear <= 0 && !seized)
		to_chat(user, SPAN_NOTICE("The bearings of \the [src] are fine."))
		return TRUE
	if(spin > 0 || (core && !QDELETED(core) && core.core_temperature > NSR_PPUMP_REPAIR_TEMP))
		to_chat(user, SPAN_WARNING("The rotor still turns or the water is too hot to take the pump apart. Stop it and let the reactor cool below [NSR_PPUMP_REPAIR_TEMP] C."))
		return TRUE
	user.visible_message(SPAN_NOTICE("\The [user] starts replacing the bearings of \the [src]."))
	playsound(src, NS_SND_WRENCH, 50, TRUE)
	if(!do_after(user, NSR_PPUMP_REPAIR_TIME, src) || spin > 0)
		return TRUE
	wear = 0
	seized = FALSE
	user.visible_message(SPAN_NOTICE("\The [user] replaces the bearings of \the [src]."))
	playsound(src, NS_SND_BUILT, 50, TRUE)
	return TRUE

/obj/machinery/submarine_primary_pump/examine(mob/user, distance)
	. = ..()
	if(distance <= 3)
		to_chat(user, "It is [lowertext(get_state_text())], [get_rpm()] rpm.")
		if(seized)
			to_chat(user, SPAN_DANGER("The rotor is jammed. The bearings need replacing (wrench, pump stopped and cold)."))
		else if(wear >= NSR_PPUMP_WEAR_WARN)
			to_chat(user, SPAN_WARNING("It grinds and vibrates: the bearings are worn."))
