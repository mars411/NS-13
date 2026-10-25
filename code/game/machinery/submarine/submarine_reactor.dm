/*
	NS-13: реактор подлодки. Этап 1 («ядро и состояния»), пульт БЩУ на NanoUI.
	Подробное описание, настройка и проверка: README.md в этой же папке.

	ЧТО ЗДЕСЬ ЕСТЬ
	- Ядро реактора (/obj/machinery/submarine_reactor_core): вся физика и состояния. Оно же одна из четырёх секций корпуса.
	- Ещё три секции корпуса (/obj/machinery/submarine_reactor_section/...): left_end, middle, right_end.
	  У всех четырёх секций броня снимается гаечным ключом.
	- Пульт БЩУ (/obj/machinery/computer/submarine_reactor_console): окно NanoUI с кнопками,
	  шаблон лежит в nano/templates/submarine_reactor_panel.tmpl.
	  Путь типа «computer» историческая случайность: на карте объект уже стоит, и менять путь без правки карты нельзя.
	  Для игрока это пульт, а не компьютер.

	КАК РАССТАВЛЯТЬ НА КАРТЕ (StrongDMM)
	Четыре тайла в ряд: left_end, core, middle, right_end.
	Ядро находит секции в радиусе NSR_SECTION_LINK_RANGE тайлов (по умолчанию 3).
	Пульт находит ядро по reactor_id (по умолчанию "main" у обоих), расстояние не важно.
	Между пультом и залом реактора должно быть минимум две двери (требование ТЗ, это вопрос карты).

	ЗАГЛУШКИ ДО ЭТАПА 3 (трубы и существующий в Бэе газ пар, GAS_STEAM)
	- Клапан питательной воды: добавляет воду в сосуд. Потом заменится подключением к трубам.
	- Клапан пара: стравливает пар. Потом заменится турбиной (steam_flow уже считается для неё).

	ПАРОВОЙ ПОРТ (этап 3а)
	- Паровой порт (/obj/machinery/atmospherics/unary/tank/submarine_reactor_steam_port) садится на настоящие трубы.
	  Пока порт стоит рядом с ядром, давление пара в сосуде равно давлению в этих трубах, а пар из кипения уходит в трубы.
	- Без порта работает прежний режим: запечатанный сосуд с заглушкой клапана пара. Старая карта продолжает работать.

	НЕ РЕАЛИЗОВАНО НАМЕРЕННО (TBD в GDD, не подменяю догадками)
	- Износ стержней СУЗ и их замена (скафандр, радиация при замене).
	- Подключение к АКБ-контуру: пульт пока не требует питания (stat_immune ниже).

	Все числа ЧЕРНОВЫЕ. Они собраны в одном блоке ниже, меняйте только там.
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
#define NSR_MOLES_PER_HEAT        0.6    // моль пара на единицу тепла, ушедшего в кипение
#define NSR_MOLES_PER_PERCENT     60     // моль воды в 1% уровня воды. Вода кипит в пар моль в моль, ничего не пропадает

// Паровое пространство сосуда
#define NSR_VESSEL_VOLUME         1000   // л, объём пара в сосуде и в паровом порту
#define NSR_KPA_PER_BAR           100    // перевод давления газа Бэя (кПа) в бары

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

/// Общий порядок снятия и установки броневой плиты для всех четырёх секций корпуса (три секции и ядро).
/// Возвращает TRUE, если плиту после этого нужно переключить: вызывающий сам меняет свой casing_open.
/proc/nsr_wrench_casing(obj/machinery/hull, mob/living/user, is_open)
	hull.visible_message(SPAN_NOTICE("\The [user] starts [is_open ? "securing" : "unbolting"] the armour plate of \the [hull]."))
	playsound(hull, 'sound/items/Ratchet.ogg', 50, TRUE)
	if(!do_after(user, NSR_CASING_TIME, hull))
		return FALSE
	hull.visible_message(SPAN_NOTICE("\The [user] [is_open ? "secures" : "removes"] the armour plate of \the [hull]."))
	return TRUE

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
	if(nsr_wrench_casing(src, user, casing_open))
		casing_open = !casing_open
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
	/// Давление пара в сосуде, бар. Считается из настоящего газа каждый тик, руками не менять.
	var/steam_pressure = 0
	/// Уровень воды в сосуде, 0-100%.
	var/coolant_level = 100
	/// Положение стержней, 0-100%. Чем выше, тем больше тепловая мощность.
	var/rods_pos = 0
	/// Клапан питательной воды, 0-100%. ЗАГЛУШКА до труб.
	var/feedwater_valve = 0
	/// Клапан пара, 0-100%. ЗАГЛУШКА для режима без порта: стравливает пар в никуда. С портом не действует.
	var/steam_valve = 0
	/// Выработка пара за последний тик, моль/с.
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

	/// Привязанные секции корпуса (три штуки). Само ядро тоже секция, его плита учитывается отдельно.
	var/list/sections
	/// TRUE, если броневая плита самого ядра снята.
	var/casing_open = FALSE

	/// Паровой порт на трубах. Если есть, пар и давление берутся оттуда.
	var/obj/machinery/atmospherics/unary/tank/submarine_reactor_steam_port/steam_port
	/// Собственный пар сосуда для режима без порта (запечатанный сосуд).
	var/datum/gas_mixture/vessel_air

/obj/machinery/submarine_reactor_core/Initialize()
	. = ..()
	GLOB.submarine_reactors += src
	vessel_air = new /datum/gas_mixture(NSR_VESSEL_VOLUME, T0C + NSR_AMBIENT_TEMP)
	find_sections()
	find_steam_port()
	queue_icon_update()

/obj/machinery/submarine_reactor_core/Destroy()
	GLOB.submarine_reactors -= src
	for(var/obj/machinery/submarine_reactor_section/S in sections)
		S.core = null
	sections = null
	if(steam_port)
		steam_port.core = null
		steam_port = null
	vessel_air = null
	return ..()

/// Ищет паровой порт рядом (с той же меткой реактора) и привязывает его. Возвращает TRUE, если порт найден.
/obj/machinery/submarine_reactor_core/proc/find_steam_port()
	steam_port = null
	for(var/obj/machinery/atmospherics/unary/tank/submarine_reactor_steam_port/P in range(NSR_SECTION_LINK_RANGE, src))
		if(P.reactor_id != reactor_id)
			continue
		steam_port = P
		P.core = src
		break
	return !!steam_port

/// Газ, в котором живёт пар реактора: газ порта на трубах или собственный газ запечатанного сосуда.
/obj/machinery/submarine_reactor_core/proc/get_steam_air()
	if(steam_port && !QDELETED(steam_port) && steam_port.air_contents)
		return steam_port.air_contents
	return vessel_air

/// Ищет секции корпуса рядом и привязывает их к ядру. Возвращает число найденных.
/obj/machinery/submarine_reactor_core/proc/find_sections()
	sections = list()
	for(var/obj/machinery/submarine_reactor_section/S in range(NSR_SECTION_LINK_RANGE, src))
		S.core = src
		sections += S
	return length(sections)

/// Сколько броневых плит снято из четырёх (три секции и ядро).
/obj/machinery/submarine_reactor_core/proc/count_open_casings()
	. = casing_open ? 1 : 0
	for(var/obj/machinery/submarine_reactor_section/S in sections)
		if(S.casing_open)
			. += 1

/// Сколько всего секций корпуса: привязанные секции и само ядро. На правильной карте это 4.
/obj/machinery/submarine_reactor_core/proc/count_casings()
	return length(sections) + 1

/obj/machinery/submarine_reactor_core/use_tool(obj/item/tool, mob/living/user, list/click_params)
	if(!isWrench(tool))
		return ..()
	if(nsr_wrench_casing(src, user, casing_open))
		casing_open = !casing_open
		queue_icon_update()
	return TRUE

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
	var/datum/gas_mixture/steam_air = get_steam_air()
	var/pressure_bar = steam_air.return_pressure() / NSR_KPA_PER_BAR

	var/rods_frac = rods_pos / 100
	var/coolant_frac = coolant_level / 100

	var/heat_in = rods_frac * NSR_MAX_HEAT_RATE
	var/heat_cap = NSR_CORE_HEAT_CAP + coolant_frac * NSR_COOLANT_HEAT_CAP
	var/heat_loss = max(0, core_temperature - NSR_AMBIENT_TEMP) * NSR_PASSIVE_LOSS

	// Кипение: чем выше давление пара, тем выше точка кипения. Давление настоящее: из сосуда или из труб.
	var/boil_point = NSR_BOIL_TEMP + pressure_bar * NSR_BOIL_TEMP_PER_BAR
	var/boil_heat = 0
	steam_flow = 0
	if(core_temperature > boil_point && coolant_level > 0)
		boil_heat = (core_temperature - boil_point) * NSR_BOIL_CONDUCT
		// Не больше, чем способна отдать оставшаяся вода за этот шаг.
		var/boil_moles = min(boil_heat * NSR_MOLES_PER_HEAT * dt, coolant_level * NSR_MOLES_PER_PERCENT)
		boil_heat = boil_moles / (NSR_MOLES_PER_HEAT * dt)
		coolant_level = max(0, coolant_level - boil_moles / NSR_MOLES_PER_PERCENT)
		// Пар уходит в сосуд (или в трубы) с температурой кипения.
		steam_air.adjust_gas_temp(GAS_STEAM, boil_moles, boil_point + T0C)
		if(steam_port && steam_port.network)
			steam_port.network.update = 1
		steam_flow = boil_moles / dt

	core_temperature += (heat_in - heat_loss - boil_heat) * dt / heat_cap
	core_temperature = max(core_temperature, NSR_AMBIENT_TEMP)

	// Питательная вода (заглушка).
	coolant_level = min(100, coolant_level + (feedwater_valve / 100) * NSR_FEEDWATER_MAX * dt)

	// Режим без порта: клапан пара стравливает часть пара в никуда (заглушка).
	if(!steam_port)
		var/vent_ratio = (steam_valve / 100) * NSR_STEAM_VENT_COEF * dt
		if(vent_ratio > 0)
			steam_air.remove_ratio(vent_ratio)

	steam_pressure = steam_air.return_pressure() / NSR_KPA_PER_BAR

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
	// Весь пар сосуда вырывается в помещение.
	var/datum/gas_mixture/released = get_steam_air().remove_ratio(1)
	var/turf/here = get_turf(src)
	if(here && released)
		here.assume_air(released)
	SSradiation.radiate(src, NSR_RADS_RUPTURE)
	explosion(here, NSR_RUPTURE_RANGE)

/// Расплав от потери воды. Взрыва нет, но зона остаётся радиоактивной навсегда.
/obj/machinery/submarine_reactor_core/proc/meltdown()
	melted = TRUE
	rods_pos = 0
	queue_icon_update()
	visible_message(SPAN_DANGER("\The [src] collapses into a glowing molten mass!"))
	playsound(src, 'sound/machines/warning-buzzer.ogg', 100, FALSE)

// --- Текст для пульта ---

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

/// Класс цвета NanoUI для статуса: good (зелёный), average (жёлтый), bad (красный).
/obj/machinery/submarine_reactor_core/proc/get_status_class()
	if(is_dead() || alarm_level >= 2)
		return "bad"
	if(alarm_level >= 1)
		return "average"
	return "good"

/obj/machinery/submarine_reactor_core/on_update_icon()
	ClearOverlays()
	// Временная индикация: со снятой бронёй ядро полупрозрачно.
	alpha = casing_open ? 150 : 255
	if(is_dead())
		color = "#554433"
		return
	color = null
	if(rods_pos > 0)
		AddOverlays("+on")

// ----------------------------------------------------------------------------
// ПАРОВОЙ ПОРТ (этап 3а)
// ----------------------------------------------------------------------------

/// Выход пара из сосуда реактора. Садится на настоящие трубы Бэя: пока он есть, давление в нём и есть давление в сосуде.
/// Ставить рядом с ядром (в радиусе NSR_SECTION_LINK_RANGE), поворачивать (dir) в сторону трубы.
/obj/machinery/atmospherics/unary/tank/submarine_reactor_steam_port
	name = "reactor steam port"
	desc = "The steam outlet of the reactor vessel. Superheated steam leaves through here under high pressure."
	volume = NSR_VESSEL_VOLUME
	// Временно: оранжевый цвет, чтобы отличать от обычного бака. Заменить своим спрайтом.
	color = "#c47a2c"
	/// Метка реактора, к которому подключён порт. Должна совпадать с reactor_id ядра.
	var/reactor_id = "main"
	var/obj/machinery/submarine_reactor_core/core

/obj/machinery/atmospherics/unary/tank/submarine_reactor_steam_port/Destroy()
	if(core)
		core.steam_port = null
	core = null
	return ..()

/obj/machinery/atmospherics/unary/tank/submarine_reactor_steam_port/use_tool(obj/item/tool, mob/living/user, list/click_params)
	// Порт приварен к сосуду: отвернуть его, как обычный бак, нельзя.
	if(isWrench(tool))
		to_chat(user, SPAN_WARNING("\The [src] is welded to the reactor vessel."))
		return TRUE
	return ..()

// ----------------------------------------------------------------------------
// ПУЛЬТ БЩУ
// ----------------------------------------------------------------------------

/obj/machinery/computer/submarine_reactor_console
	name = "reactor control panel"
	desc = "A heavy control panel with buttons for the control rods, the feedwater valve, the steam valve and the emergency SCRAM."
	machine_name = "reactor control panel"
	machine_desc = "Used to operate the submarine reactor: control rods, feedwater valve, steam valve and emergency SCRAM."
	// Спрайт временный: блок управления из стокового Бэя. Заменить на свой.
	icon = 'icons/obj/machines/power/antimatter.dmi'
	icon_state = "control_on"
	// Нажатия кнопок, а не стук по клавиатуре, и на пульт нельзя залезть как на компьютер.
	clicksound = "button"
	atom_flags = ATOM_FLAG_NO_TEMP_CHANGE
	// Пульт не собирается из деталей: для него нет платы-чертежа, а значит нет деталей «экран» и «клавиатура».
	// Без этой строки Бэй считает пульт сломанным или без экрана и не даёт с ним взаимодействовать
	// («It is missing a screen, making it hard to interact with»).
	construct_state = null
	// ВРЕМЕННО: пульт работает без питания, чтобы реактор можно было запустить на карте без АКБ-контура.
	// Когда контур АКБ будет готов (GDD, задача 5), убрать из этой строки только MACHINE_STAT_NOPOWER.
	stat_immune = MACHINE_STAT_NOPOWER | MACHINE_STAT_NOSCREEN | MACHINE_STAT_NOINPUT

	/// Метка реактора, которым управляет пульт. Должна совпадать с reactor_id ядра.
	var/reactor_id = "main"
	var/obj/machinery/submarine_reactor_core/reactor

/obj/machinery/computer/submarine_reactor_console/on_update_icon()
	// Не вызываем родителя: он рисует экран и клавиатуру компьютера, которых у пульта нет.
	ClearOverlays()
	icon_state = "control_on"

/obj/machinery/computer/submarine_reactor_console/proc/get_reactor()
	if(reactor && !QDELETED(reactor))
		return reactor
	reactor = null
	for(var/obj/machinery/submarine_reactor_core/R in GLOB.submarine_reactors)
		if(R.reactor_id == reactor_id)
			reactor = R
			break
	return reactor

/obj/machinery/computer/submarine_reactor_console/interface_interact(mob/user)
	ui_interact(user)
	return TRUE

/// Цвет шкалы по порогам: good ниже warn, average от warn, bad от crit.
/obj/machinery/computer/submarine_reactor_console/proc/level_class(value, warn, crit)
	if(value >= crit)
		return "bad"
	if(value >= warn)
		return "average"
	return "good"

/// Данные для окна NanoUI. Шаблон: nano/templates/submarine_reactor_panel.tmpl.
/obj/machinery/computer/submarine_reactor_console/proc/build_ui_data()
	var/list/data = list()
	var/obj/machinery/submarine_reactor_core/R = get_reactor()
	data["linked"] = !!R
	data["reactorId"] = reactor_id
	if(!R)
		return data
	data["dead"] = R.is_dead()
	data["status"] = R.get_status_text()
	data["statusClass"] = R.get_status_class()
	data["temp"] = round(R.core_temperature)
	data["tempMax"] = NSR_MELTDOWN_TEMP
	data["tempClass"] = level_class(R.core_temperature, NSR_TEMP_WARN, NSR_TEMP_CRIT)
	data["pressure"] = round(R.steam_pressure, 0.1)
	data["pressureMax"] = NSR_PRESSURE_BURST
	data["pressureClass"] = level_class(R.steam_pressure, NSR_PRESSURE_WARN, NSR_PRESSURE_CRIT)
	data["coolant"] = round(R.coolant_level, 0.1)
	// У воды всё наоборот: чем её меньше, тем хуже.
	data["coolantClass"] = "good"
	if(R.coolant_level < NSR_COOLANT_CRIT)
		data["coolantClass"] = "bad"
	else if(R.coolant_level < NSR_COOLANT_WARN)
		data["coolantClass"] = "average"
	data["rods"] = R.rods_pos
	data["feedwater"] = R.feedwater_valve
	data["steamValve"] = R.steam_valve
	data["steamFlow"] = round(R.steam_flow, 0.1)
	data["hasPort"] = !!R.steam_port
	data["scrammed"] = R.scrammed
	data["casingsOpen"] = R.count_open_casings()
	data["casingsTotal"] = R.count_casings()
	return data

/obj/machinery/computer/submarine_reactor_console/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = 1)
	var/list/data = build_ui_data()
	// Обновляет окно, если оно уже открыто. Если окна нет, возвращает null.
	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "submarine_reactor_panel.tmpl", "Reactor control panel", 540, 640)
		ui.set_initial_data(data)
		ui.open()
		// Окно само обновляется каждый тик подсистемы NanoUI, пока открыто.
		ui.set_auto_update(1)

/obj/machinery/computer/submarine_reactor_console/OnTopic(mob/user, href_list, datum/topic_state/state)
	var/action = href_list["action"]

	if(action == "rescan")
		reactor = null
		var/obj/machinery/submarine_reactor_core/found = get_reactor()
		if(found)
			var/section_count = found.find_sections()
			var/port_text = found.find_steam_port() ? "steam port connected" : "no steam port (sealed test vessel)"
			to_chat(user, SPAN_NOTICE("Linked to reactor unit '[found.reactor_id]', [section_count] hull section(s) detected, plus the core, [port_text]."))
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
		if("steam_up", "steam_down")
			if(R.steam_port)
				to_chat(user, SPAN_WARNING("The steam line is controlled by the valves on the pipes, not from this panel."))
			else
				R.adjust_steam_valve(action == "steam_up" ? NSR_VALVE_STEP : -NSR_VALVE_STEP)
		if("scram")
			R.scram()
		if("reset")
			if(!R.scrammed)
				to_chat(user, SPAN_NOTICE("SCRAM is not engaged."))
			else if(!R.reset_scram())
				to_chat(user, SPAN_WARNING("Cannot reset SCRAM: the core must cool below [NSR_SCRAM_RESET_TEMP] C first."))
	return TOPIC_REFRESH
