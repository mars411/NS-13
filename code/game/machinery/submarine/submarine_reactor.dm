/*
	NS-13: реактор подлодки. Чистая реализация, этап 1 («ядро и состояния»).

	ЧТО ЗДЕСЬ ЕСТЬ
	- Ядро реактора (/obj/machinery/submarine_reactor_core): вся физика и состояния.
	- Секции корпуса (/obj/machinery/submarine_reactor_section/...): снимается броня гаечным ключом.
	- Консоль БЩУ (/obj/machinery/computer/submarine_reactor_console): стержни, клапаны, SCRAM.

	КАК РАССТАВЛЯТЬ НА КАРТЕ (StrongDMM)
	Четыре тайла в ряд: left_end, core, middle, right_end.
	Ядро находит секции в радиусе NSR_SECTION_LINK_RANGE тайлов (по умолчанию 3).
	Консоль находит ядро по reactor_id (по умолчанию "main" у обоих), расстояние не важно.
	Между консолью и залом реактора должно быть минимум две двери (требование ТЗ, это вопрос карты).

	ЗАГЛУШКИ ДО ЭТАПА 3 (трубы и газ «Водяной пар»)
	- Клапан питательной воды: добавляет воду в сосуд. Потом заменится подключением к трубам.
	- Клапан пара: стравливает пар. Потом заменится турбиной (steam_flow уже считается для неё).

	НЕ РЕАЛИЗОВАНО НАМЕРЕННО (TBD в GDD, не подменяю догадками)
	- Износ стержней СУЗ и их замена (скафандр, радиация при замене).
	- Подключение к АКБ-контуру: консоль пока не требует питания (stat_immune ниже).

	Все числа — ЧЕРНОВЫЕ. Они собраны в одном блоке ниже, меняйте только там.
*/

GLOBAL_LIST_EMPTY(submarine_reactors)

// ----------------------------------------------------------------------------
// ЧЕРНОВЫЕ ЧИСЛА [TBD]
// ----------------------------------------------------------------------------

// Тепловая модель
#define NSR_AMBIENT_TEMP          30     // C, температура отсека
#define NSR_BOIL_TEMP             100    // C, точка кипения при нулевом давлении пара
#define NSR_BOIL_TEMP_PER_BAR     0.5    // на сколько C растёт точка кипения с каждым баром давления
#define NSR_MAX_HEAT_RATE         100    // ед. тепла в секунду при стержнях 100%
#define NSR_CORE_HEAT_CAP         10     // ед. тепла на 1 C, «сухая» активная зона
#define NSR_COOLANT_HEAT_CAP      40     // добавка к теплоёмкости при полном сосуде воды
#define NSR_PASSIVE_LOSS          0.2    // ед. тепла/с на каждый C выше температуры отсека
#define NSR_BOIL_CONDUCT          5      // ед. тепла/с, которые забирает кипение, на каждый C выше точки кипения
#define NSR_COOLANT_PER_HEAT      0.01   // процентов воды, выкипающих на единицу тепла
#define NSR_STEAM_PER_HEAT        0.02   // бар пара на единицу тепла, ушедшего в кипение

// Заглушки труб
#define NSR_FEEDWATER_MAX         1      // процентов воды в секунду при клапане питательной воды 100%
#define NSR_STEAM_VENT_COEF       0.05   // доля давления в секунду, уходящая при клапане пара 100%

// Пороги тревог и катастроф
#define NSR_TEMP_WARN             150    // C
#define NSR_TEMP_CRIT             250    // C
#define NSR_MELTDOWN_TEMP         400    // C, расплав
#define NSR_PRESSURE_WARN         70     // бар
#define NSR_PRESSURE_CRIT         90     // бар
#define NSR_PRESSURE_BURST        110    // бар, взрыв сосуда
#define NSR_COOLANT_WARN          40     // процентов воды
#define NSR_COOLANT_CRIT          15     // процентов воды
#define NSR_SCRAM_RESET_TEMP      150    // C, ниже этого можно сбросить SCRAM

// Катастрофы и радиация
#define NSR_RUPTURE_RANGE         10     // параметр range для explosion(); у стандартной пропорции 1:2:4
#define NSR_RADS_RUNNING_MAX      6      // «лёгкая радиация при работе», стержни 100%
#define NSR_RADS_OPEN_CASING_MULT 4      // множитель, если снята броня хотя бы с одной секции
#define NSR_RADS_RUPTURE          30     // одиночный импульс при взрыве сосуда
#define NSR_RADS_MELTDOWN         40     // каждый тик после расплава

// Управление и прочее
#define NSR_ROD_STEP              10     // шаг стержней, процентов
#define NSR_VALVE_STEP            10     // шаг клапанов, процентов
#define NSR_SECTION_LINK_RANGE    3      // радиус поиска секций от ядра, тайлов
#define NSR_CASING_TIME           (3 SECONDS)
#define NSR_ALARM_REPEAT          (6 SECONDS)

// ----------------------------------------------------------------------------
// СЕКЦИЯ КОРПУСА
// ----------------------------------------------------------------------------

/obj/machinery/submarine_reactor_section
	name = "reactor section"
	desc = "A heavy lead-composite armoured section of the reactor vessel. The armour plate is held by bolts."
	// Временный спрайт: существующий в Бэе generator-образный. Заменить на свои.
	icon = 'icons/obj/machines/field_generator.dmi'
	icon_state = "Field_Gen"
	density = TRUE
	anchored = TRUE
	use_power = POWER_USE_OFF
	construct_state = null
	uncreated_component_parts = null
	can_use_tools = FALSE
	/// Ядро, к которому привязана секция. Заполняет само ядро при поиске секций.
	var/obj/machinery/submarine_reactor_core/core
	/// TRUE, если броневая плита снята.
	var/casing_open = FALSE

/obj/machinery/submarine_reactor_section/left_end
	name = "reactor left section"

/obj/machinery/submarine_reactor_section/middle
	name = "reactor middle section"

/obj/machinery/submarine_reactor_section/right_end
	name = "reactor right section"

/obj/machinery/submarine_reactor_section/Destroy()
	if(core && core.sections)
		core.sections -= src
	core = null
	return ..()

/obj/machinery/submarine_reactor_section/use_tool(obj/item/tool, mob/living/user, list/click_params)
	if(!isWrench(tool))
		return ..()
	visible_message(SPAN_NOTICE("\The [user] starts [casing_open ? "securing" : "unbolting"] the armour plate of \the [src]."))
	playsound(src, 'sound/items/Ratchet.ogg', 50, TRUE)
	if(!do_after(user, NSR_CASING_TIME, src))
		return TRUE
	casing_open = !casing_open
	visible_message(SPAN_NOTICE("\The [user] [casing_open ? "removes" : "secures"] the armour plate of \the [src]."))
	queue_icon_update()
	return TRUE

/obj/machinery/submarine_reactor_section/on_update_icon()
	// Временная индикация: со снятой бронёй секция полупрозрачна.
	alpha = casing_open ? 150 : 255

// ----------------------------------------------------------------------------
// ЯДРО РЕАКТОРА
// ----------------------------------------------------------------------------

/obj/machinery/submarine_reactor_core
	name = "reactor core"
	desc = "The heart of the submarine. Water boils around the fuel rods, and the steam goes to the turbine."
	// Временный спрайт, см. секцию выше.
	icon = 'icons/obj/machines/field_generator.dmi'
	icon_state = "Field_Gen"
	density = TRUE
	anchored = TRUE
	use_power = POWER_USE_OFF
	construct_state = null
	uncreated_component_parts = null
	can_use_tools = FALSE

	/// Метка реактора. Консоли с тем же reactor_id управляют этим реактором.
	var/reactor_id = "main"

	/// Температура активной зоны, C.
	var/core_temperature = NSR_AMBIENT_TEMP
	/// Давление пара в сосуде, бар.
	var/steam_pressure = 0
	/// Уровень воды в сосуде, 0-100%.
	var/coolant_level = 100
	/// Положение стержней, 0-100%. Чем выше, тем больше тепловая мощность.
	var/rods_pos = 0
	/// Клапан питательной воды, 0-100%. ЗАГЛУШКА до труб.
	var/feedwater_valve = 0
	/// Клапан пара, 0-100%. ЗАГЛУШКА до турбины.
	var/steam_valve = 0
	/// Расход пара наружу за последний тик, бар/с. Это то, что потом заберёт турбина.
	var/steam_flow = 0

	/// SCRAM: стержни сброшены в ноль и заблокированы до сброса.
	var/scrammed = FALSE
	/// Сосуд разорван давлением (взрыв). Необратимо.
	var/ruptured = FALSE
	/// Активная зона расплавилась. Необратимо.
	var/melted = FALSE

	/// 0 - норма, 1 - предупреждение, 2 - критично.
	var/alarm_level = 0
	var/next_alarm_time = 0

	/// Привязанные секции корпуса.
	var/list/sections

/obj/machinery/submarine_reactor_core/Initialize()
	. = ..()
	GLOB.submarine_reactors += src
	find_sections()
	queue_icon_update()

/obj/machinery/submarine_reactor_core/Destroy()
	GLOB.submarine_reactors -= src
	for(var/obj/machinery/submarine_reactor_section/S in sections)
		S.core = null
	sections = null
	return ..()

/// Ищет секции корпуса рядом и привязывает их к ядру. Возвращает число найденных.
/obj/machinery/submarine_reactor_core/proc/find_sections()
	sections = list()
	for(var/obj/machinery/submarine_reactor_section/S in range(NSR_SECTION_LINK_RANGE, src))
		S.core = src
		sections += S
	return length(sections)

/obj/machinery/submarine_reactor_core/proc/count_open_casings()
	. = 0
	for(var/obj/machinery/submarine_reactor_section/S in sections)
		if(S.casing_open)
			. += 1

/obj/machinery/submarine_reactor_core/proc/is_dead()
	return ruptured || melted

// --- Управление (вызывается консолью) ---

/obj/machinery/submarine_reactor_core/proc/adjust_rods(amount)
	if(is_dead() || scrammed)
		return FALSE
	rods_pos = clamp(rods_pos + amount, 0, 100)
	queue_icon_update()
	return TRUE

/obj/machinery/submarine_reactor_core/proc/adjust_feedwater(amount)
	if(is_dead())
		return FALSE
	feedwater_valve = clamp(feedwater_valve + amount, 0, 100)
	return TRUE

/obj/machinery/submarine_reactor_core/proc/adjust_steam_valve(amount)
	if(is_dead())
		return FALSE
	steam_valve = clamp(steam_valve + amount, 0, 100)
	return TRUE

/obj/machinery/submarine_reactor_core/proc/scram()
	if(is_dead())
		return FALSE
	scrammed = TRUE
	rods_pos = 0
	playsound(src, 'sound/machines/buzz-two.ogg', 60, FALSE)
	audible_message(SPAN_WARNING("\The [src] drops its control rods with a heavy clunk."))
	queue_icon_update()
	return TRUE

/// Сбрасывает SCRAM, если активная зона достаточно остыла. Возвращает TRUE при успехе.
/obj/machinery/submarine_reactor_core/proc/reset_scram()
	if(is_dead() || !scrammed)
		return FALSE
	if(core_temperature > NSR_SCRAM_RESET_TEMP)
		return FALSE
	scrammed = FALSE
	return TRUE

// --- Физика ---

/obj/machinery/submarine_reactor_core/Process(wait)
	if(melted)
		SSradiation.radiate(src, NSR_RADS_MELTDOWN)
		return
	if(ruptured)
		return

	var/dt = 2
	if(wait > 0)
		dt = clamp(wait / 10, 0.5, 5)

	simulate(dt)

	if(steam_pressure >= NSR_PRESSURE_BURST)
		rupture()
		return
	if(core_temperature >= NSR_MELTDOWN_TEMP)
		meltdown()
		return

	update_alarm()
	emit_radiation()

/// Один шаг физики. dt - длительность шага в секундах.
/obj/machinery/submarine_reactor_core/proc/simulate(dt)
	var/rods_frac = rods_pos / 100
	var/coolant_frac = coolant_level / 100

	var/heat_in = rods_frac * NSR_MAX_HEAT_RATE
	var/heat_cap = NSR_CORE_HEAT_CAP + coolant_frac * NSR_COOLANT_HEAT_CAP
	var/heat_loss = max(0, core_temperature - NSR_AMBIENT_TEMP) * NSR_PASSIVE_LOSS

	// Кипение: чем выше давление пара, тем выше точка кипения.
	var/boil_point = NSR_BOIL_TEMP + steam_pressure * NSR_BOIL_TEMP_PER_BAR
	var/boil_heat = 0
	if(core_temperature > boil_point && coolant_level > 0)
		boil_heat = (core_temperature - boil_point) * NSR_BOIL_CONDUCT
		// Не больше, чем способна отдать оставшаяся вода за этот шаг.
		boil_heat = min(boil_heat, coolant_level / (NSR_COOLANT_PER_HEAT * dt))
		coolant_level = max(0, coolant_level - boil_heat * NSR_COOLANT_PER_HEAT * dt)
		steam_pressure += boil_heat * NSR_STEAM_PER_HEAT * dt

	core_temperature += (heat_in - heat_loss - boil_heat) * dt / heat_cap
	core_temperature = max(core_temperature, NSR_AMBIENT_TEMP)

	// Питательная вода (заглушка).
	coolant_level = min(100, coolant_level + (feedwater_valve / 100) * NSR_FEEDWATER_MAX * dt)

	// Стравливание пара (заглушка турбины): чем выше давление, тем быстрее уходит.
	var/steam_out = steam_pressure * (steam_valve / 100) * NSR_STEAM_VENT_COEF * dt
	steam_pressure = max(0, steam_pressure - steam_out)
	steam_flow = steam_out / dt

/obj/machinery/submarine_reactor_core/proc/update_alarm()
	var/new_level = 0
	// Нехватка воды важна только когда реактор греется или греет.
	var/coolant_matters = (rods_pos > 0 || core_temperature > NSR_BOIL_TEMP)
	if(core_temperature >= NSR_TEMP_WARN || steam_pressure >= NSR_PRESSURE_WARN || (coolant_matters && coolant_level < NSR_COOLANT_WARN))
		new_level = 1
	if(core_temperature >= NSR_TEMP_CRIT || steam_pressure >= NSR_PRESSURE_CRIT || (coolant_matters && coolant_level < NSR_COOLANT_CRIT))
		new_level = 2

	if(new_level > alarm_level)
		playsound(src, 'sound/machines/buzz-two.ogg', 60, FALSE)
		audible_message(SPAN_WARNING("\The [src] emits a warning tone."))
	if(new_level >= 2 && world.time >= next_alarm_time)
		playsound(src, 'sound/machines/warning-buzzer.ogg', 70, FALSE)
		next_alarm_time = world.time + NSR_ALARM_REPEAT
	alarm_level = new_level

/obj/machinery/submarine_reactor_core/proc/emit_radiation()
	if(rods_pos <= 0)
		return
	var/rads = (rods_pos / 100) * NSR_RADS_RUNNING_MAX
	if(count_open_casings())
		rads *= NSR_RADS_OPEN_CASING_MULT
	SSradiation.radiate(src, rads)

// --- Катастрофы ---

/// Взрыв от давления. Рвёт сосуд и всё вокруг в радиусе, но батареи должны стоять дальше (вопрос карты).
/obj/machinery/submarine_reactor_core/proc/rupture()
	ruptured = TRUE
	rods_pos = 0
	steam_pressure = 0
	steam_flow = 0
	queue_icon_update()
	visible_message(SPAN_DANGER("\The [src] ruptures violently!"))
	SSradiation.radiate(src, NSR_RADS_RUPTURE)
	explosion(get_turf(src), NSR_RUPTURE_RANGE)

/// Расплав от потери воды. Взрыва нет, но зона остаётся радиоактивной навсегда.
/obj/machinery/submarine_reactor_core/proc/meltdown()
	melted = TRUE
	rods_pos = 0
	queue_icon_update()
	visible_message(SPAN_DANGER("\The [src] collapses into a glowing molten mass!"))
	playsound(src, 'sound/machines/warning-buzzer.ogg', 100, FALSE)

// --- Текст для консоли ---

/obj/machinery/submarine_reactor_core/proc/get_status_text()
	if(melted)
		return "CORE MELTDOWN"
	if(ruptured)
		return "VESSEL RUPTURED"
	if(alarm_level >= 2)
		return "CRITICAL"
	if(alarm_level >= 1)
		return "WARNING"
	if(scrammed)
		return "SCRAM"
	if(rods_pos <= 0 && core_temperature < NSR_BOIL_TEMP)
		return "OFFLINE"
	return "NOMINAL"

/// Класс CSS для цвета статуса: "" (зелёный), "w" (жёлтый), "c" (красный).
/obj/machinery/submarine_reactor_core/proc/get_status_class()
	if(is_dead() || alarm_level >= 2)
		return "c"
	if(alarm_level >= 1)
		return "w"
	return ""

/obj/machinery/submarine_reactor_core/on_update_icon()
	ClearOverlays()
	if(is_dead())
		color = "#554433"
		return
	color = null
	if(rods_pos > 0)
		AddOverlays("+on")

// ----------------------------------------------------------------------------
// КОНСОЛЬ БЩУ
// ----------------------------------------------------------------------------

/obj/machinery/computer/submarine_reactor_console
	name = "reactor control console"
	desc = "Controls the control rods, the feedwater and the steam valve of the reactor."
	machine_name = "reactor control console"
	machine_desc = "Used to operate the submarine reactor: control rods, feedwater valve, steam valve and emergency SCRAM."
	// ВРЕМЕННО: консоль работает без питания, чтобы реактор можно было запустить на карте без АКБ-контура.
	// Когда контур АКБ будет готов (GDD, задача 5), убрать эту строку, и консоль начнёт требовать питание.
	stat_immune = MACHINE_STAT_NOPOWER

	/// Метка реактора, которым управляет консоль. Должна совпадать с reactor_id ядра.
	var/reactor_id = "main"
	var/obj/machinery/submarine_reactor_core/reactor

/obj/machinery/computer/submarine_reactor_console/proc/get_reactor()
	if(reactor && !QDELETED(reactor))
		return reactor
	reactor = null
	for(var/obj/machinery/submarine_reactor_core/R in GLOB.submarine_reactors)
		if(R.reactor_id == reactor_id)
			reactor = R
			break
	return reactor

/// Обновляет открытые окна, пока кто-то пользуется консолью.
/obj/machinery/computer/submarine_reactor_console/Process()
	if(in_use)
		updateUsrDialog()

/obj/machinery/computer/submarine_reactor_console/interface_interact(mob/user)
	interact(user)
	return TRUE

/obj/machinery/computer/submarine_reactor_console/proc/make_link(label, action)
	return "<a href='byond://?src=\ref[src];action=[action]'>[label]</a>"

/obj/machinery/computer/submarine_reactor_console/proc/make_bar(value, max_value, width = 20)
	var/filled = round(clamp(value / max_value, 0, 1) * width)
	var/bar = "|"
	for(var/i in 1 to width)
		bar += ((i <= filled) ? "#" : ".")
	return bar + "|"

/obj/machinery/computer/submarine_reactor_console/interact(mob/user)
	user.set_machine(src)
	var/list/html = list()
	html += "<style>body{background:#000;color:#3f3;font-family:'Courier New',monospace;font-size:13px}"
	html += "a{color:#3f3;text-decoration:none}a:hover{background:#3f3;color:#000}"
	html += ".w{color:#fc0}.c{color:#f33}</style>"

	var/obj/machinery/submarine_reactor_core/R = get_reactor()
	if(!R)
		html += "<pre>NS-13 REACTOR CONTROL\n\nNO LINK TO REACTOR UNIT '[reactor_id]'\n</pre>"
		html += make_link("RESCAN LINKS", "rescan")
	else
		var/open_casings = R.count_open_casings()
		var/total_casings = length(R.sections)
		var/armour_text = "sealed ([total_casings] sections linked)"
		if(open_casings)
			armour_text = "[open_casings] of [total_casings] plates REMOVED"
		var/scram_text = "ready"
		if(R.scrammed)
			scram_text = "ENGAGED"
		html += "<pre>"
		html += "NS-13 REACTOR CONTROL // UNIT [uppertext(R.reactor_id)]\n"
		html += "STATUS       <span class='[R.get_status_class()]'>[R.get_status_text()]</span>\n"
		html += "-----------------------------------------------\n"
		html += "CORE TEMP    [round(R.core_temperature)] C\n"
		html += "             [make_bar(R.core_temperature, NSR_MELTDOWN_TEMP)]\n"
		html += "PRESSURE     [round(R.steam_pressure, 0.1)] bar\n"
		html += "             [make_bar(R.steam_pressure, NSR_PRESSURE_BURST)]\n"
		html += "COOLANT      [round(R.coolant_level, 0.1)] %\n"
		html += "             [make_bar(R.coolant_level, 100)]\n"
		html += "CONTROL RODS [R.rods_pos] %\n"
		html += "             [make_bar(R.rods_pos, 100)]\n"
		html += "FEEDWATER    [R.feedwater_valve] %\n"
		html += "STEAM VALVE  [R.steam_valve] %   (steam out: [round(R.steam_flow, 0.1)] bar/s)\n"
		html += "SCRAM        [scram_text]\n"
		html += "ARMOUR       [armour_text]\n"
		html += "</pre>"
		if(R.is_dead())
			html += "<p class='c'>REACTOR LOST. NO CONTROL POSSIBLE.</p>"
		else
			html += "RODS &nbsp;&nbsp;&nbsp;&nbsp;&nbsp; [make_link("+10", "rods_up")] [make_link("-10", "rods_down")]<br>"
			html += "FEEDWATER &nbsp; [make_link("+10", "feed_up")] [make_link("-10", "feed_down")]<br>"
			html += "STEAM &nbsp;&nbsp;&nbsp;&nbsp; [make_link("+10", "steam_up")] [make_link("-10", "steam_down")]<br>"
			html += "<br>[make_link("SCRAM", "scram")] &nbsp; [make_link("RESET SCRAM", "reset")]<br>"
		html += "<br>[make_link("RESCAN LINKS", "rescan")]"

	show_browser(user, jointext(html, null), "window=ns_reactor;size=520x560")
	onclose(user, "ns_reactor")

/obj/machinery/computer/submarine_reactor_console/OnTopic(mob/user, href_list, datum/topic_state/state)
	var/action = href_list["action"]

	if(action == "rescan")
		reactor = null
		var/obj/machinery/submarine_reactor_core/found = get_reactor()
		if(found)
			var/section_count = found.find_sections()
			to_chat(user, SPAN_NOTICE("Linked to reactor unit '[found.reactor_id]', [section_count] hull section(s) detected."))
		else
			to_chat(user, SPAN_WARNING("No reactor unit '[reactor_id]' found."))
		return TOPIC_REFRESH

	var/obj/machinery/submarine_reactor_core/R = get_reactor()
	if(!R)
		to_chat(user, SPAN_WARNING("No link to a reactor unit."))
		return TOPIC_HANDLED
	if(R.is_dead())
		to_chat(user, SPAN_DANGER("The reactor is beyond control."))
		return TOPIC_REFRESH

	switch(action)
		if("rods_up")
			if(R.scrammed)
				to_chat(user, SPAN_WARNING("The control rods are locked by SCRAM. Reset it first."))
			else
				R.adjust_rods(NSR_ROD_STEP)
		if("rods_down")
			R.adjust_rods(-NSR_ROD_STEP)
		if("feed_up")
			R.adjust_feedwater(NSR_VALVE_STEP)
		if("feed_down")
			R.adjust_feedwater(-NSR_VALVE_STEP)
		if("steam_up")
			R.adjust_steam_valve(NSR_VALVE_STEP)
		if("steam_down")
			R.adjust_steam_valve(-NSR_VALVE_STEP)
		if("scram")
			R.scram()
		if("reset")
			if(!R.scrammed)
				to_chat(user, SPAN_NOTICE("SCRAM is not engaged."))
			else if(!R.reset_scram())
				to_chat(user, SPAN_WARNING("Cannot reset SCRAM: the core must cool below [NSR_SCRAM_RESET_TEMP] C first."))
	return TOPIC_REFRESH
