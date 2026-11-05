/*
	NS-13: компенсатор давления и насос подпитки первичного контура (ревизия 15, второй контур, часть 2).
	Подробности и проверка: README.md в этой же папке, GDD §5.2 (схема двух контуров).

	КАК ЭТО РАБОТАЕТ
	- Компенсатор давления (/obj/machinery/submarine_pressurizer) держит давление первичного контура. Сам он только хранит настройки и
	  состояние (нагреватели, впрыск, предохранительный клапан, блок-клапан, автоматика); давление и запас воды считает ядро
	  (submarine_reactor_core/proc/update_primary), как и у остальных деталей контура. Связь с реактором по метке reactor_id.
	- Нагреватели поднимают давление и берут электричество от щитка, впрыск (от главного насоса, поэтому нужен расход) снижает его.
	  Нагреватели работают только пока вода в компенсаторе их покрывает (NSR_PZR_HEATER_MIN_LEVEL): при низком уровне они оголены и не греют.
	- Предохранительный клапан открывается сам при NSR_PZR_RELIEF_OPEN, закрывается ниже NSR_PZR_RELIEF_CLOSE и уносит воду из контура.
	  После каждого закрытия он залипает открытым с шансом NSR_PZR_RELIEF_STICK_PCT: утечка воды и падение давления. Блок-клапан на пульте изолирует его.
	  Клапан оператор может открыть и вручную (контролируемый сброс давления).
	- Автоматика (ПИ-регулятор по давлению, уставка NSR_PZR_SETPOINT) по умолчанию включена: нагреватели и впрыск без неё надо вести руками.
	- Насос подпитки (/obj/machinery/submarine_makeup_pump) добавляет воду в контур (плюс) или сливает (минус). Бак подпитки неограничен
	  (запас воды и фильтр забортной воды пока не сделаны, см. GDD). Нужен щиток.
*/

// ----------------------------------------------------------------------------
// КОМПЕНСАТОР ДАВЛЕНИЯ
// ----------------------------------------------------------------------------

/obj/machinery/submarine_pressurizer
	name = "pressurizer"
	desc = "A tall vessel on top of the reactor circuit. A bubble of steam inside keeps the reactor water under pressure so it does not boil: electric heaters raise the pressure, a spray of cooler water lowers it, and a relief valve vents the excess."
	// Временный спрайт: стоковый бак, окрашенный в жёлтый. Заменить своим.
	icon = 'icons/atmos/tank.dmi'
	icon_state = "air"
	color = "#d9a441"
	density = TRUE
	anchored = TRUE
	use_power = POWER_USE_OFF

	/// Метка реактора. Должна совпадать с reactor_id ядра.
	var/reactor_id = "main"
	var/obj/machinery/submarine_reactor_core/core
	/// Нагреватели, уставка 0-100%. В автоматическом режиме её ставит автоматика.
	var/heater = NSR_PZR_AUTO_BASE
	/// Впрыск, уставка 0-100%. В автоматическом режиме её ставит автоматика.
	var/spray = 0
	/// Автоматика давления включена.
	var/auto = TRUE
	/// Уставка автоматики, бар.
	var/setpoint = NSR_PZR_SETPOINT
	/// Интегральная часть регулятора, %.
	var/integral = 0
	/// Сколько нагреватели реально греют на этом шаге (0-1): уставка, если есть питание и вода их покрывает.
	var/heating = 0
	/// Нагреватели оголены: уровень воды в компенсаторе ниже NSR_PZR_HEATER_MIN_LEVEL.
	var/uncovered = FALSE
	/// Предохранительный клапан сейчас открыт.
	var/relief_open = FALSE
	/// Клапан залип открытым (виден только по тому, что он открыт при давлении ниже порога закрытия).
	var/relief_stuck = FALSE
	/// Оператор открыл клапан вручную.
	var/relief_manual = FALSE
	/// Блок-клапан закрыт: клапан изолирован, вода и давление через него не уходят.
	var/block_closed = FALSE

/obj/machinery/submarine_pressurizer/Initialize()
	. = ..()
	GLOB.submarine_pressurizers += src
	return INITIALIZE_HINT_LATELOAD

/obj/machinery/submarine_pressurizer/LateInitialize(mapload, ...)
	for(var/obj/machinery/submarine_reactor_core/R in GLOB.submarine_reactors)
		if(R.reactor_id == reactor_id)
			R.find_pressurizer()

/obj/machinery/submarine_pressurizer/Destroy()
	GLOB.submarine_pressurizers -= src
	if(core)
		core.pressurizer = null
	core = null
	return ..()

/// Автоматика: ПИ-регулятор по давлению. Нужны питание; без него впрыск закрывается, нагреватели и так не греют.
/obj/machinery/submarine_pressurizer/proc/run_auto(pressure, dt)
	if(inoperable())
		spray = 0
		return
	var/error = setpoint - pressure
	integral = clamp(integral + error * NSR_PZR_AUTO_KI * dt, -NSR_PZR_AUTO_I_MAX, NSR_PZR_AUTO_I_MAX)
	var/demand = NSR_PZR_AUTO_BASE + NSR_PZR_AUTO_KP * error + integral
	heater = clamp(demand, 0, 100)
	spray = clamp(-demand, 0, 100)

/// Сколько нагреватели греют на этом шаге (0-1). level_raw: расчётный уровень воды в компенсаторе.
/obj/machinery/submarine_pressurizer/proc/update_heating(level_raw)
	uncovered = (level_raw < NSR_PZR_HEATER_MIN_LEVEL)
	if(inoperable() || uncovered)
		heating = 0
	else
		heating = heater / 100
	return heating

/// Состояние предохранительного клапана на этом шаге. Возвращает TRUE, если он сейчас открыт и выпускает воду.
/obj/machinery/submarine_pressurizer/proc/update_relief(pressure)
	if(block_closed)
		relief_open = FALSE
		return FALSE
	var/was_open = relief_open
	if(relief_stuck || relief_manual)
		relief_open = TRUE
	else if(relief_open)
		relief_open = pressure > NSR_PZR_RELIEF_CLOSE
	else
		relief_open = pressure >= NSR_PZR_RELIEF_OPEN
	if(was_open && !relief_open && prob(NSR_PZR_RELIEF_STICK_PCT))
		// Закрыться должен был, но залип. Никакой надписи нет: это видно по пульту.
		relief_stuck = TRUE
		relief_open = TRUE
	if(relief_open && !was_open)
		playsound(src, NS_SND_RELIEF, 60, TRUE)
		visible_message(SPAN_WARNING("The relief valve of \the [src] opens with a hiss."))
	return relief_open

/// Включает или выключает автоматику давления. user может быть null.
/obj/machinery/submarine_pressurizer/proc/toggle_auto(mob/user)
	auto = !auto
	integral = 0
	if(user)
		to_chat(user, SPAN_NOTICE("Pressure automation [auto ? "on" : "off"]."))

/// Разовая работа нагревателей: электричество от щитка пропорционально нагреву.
/obj/machinery/submarine_pressurizer/Process(wait)
	// Родительский Process() не зовём: у /obj/machinery он возвращает PROCESS_KILL и остановил бы обработку.
	if(heating > 0 && !inoperable())
		use_power_oneoff(NSR_PZR_HEATER_POWER * heating)

/// Текст о нагревателях для пульта.
/obj/machinery/submarine_pressurizer/proc/get_heater_text()
	if(inoperable())
		return "NO POWER"
	if(uncovered)
		return "UNCOVERED"
	if(heating <= 0)
		return "OFF"
	return "HEATING"

/// Текст о предохранительном клапане для пульта.
/obj/machinery/submarine_pressurizer/proc/get_relief_text()
	if(block_closed)
		return "ISOLATED"
	return relief_open ? "OPEN" : "CLOSED"

/obj/machinery/submarine_pressurizer/examine(mob/user, distance)
	. = ..()
	if(distance <= 3 && core && !QDELETED(core))
		to_chat(user, "Its gauge shows [round(core.primary_pressure)] bar and [round(core.pzr_level())]% water. The relief valve is [lowertext(get_relief_text())].")

// ----------------------------------------------------------------------------
// НАСОС ПОДПИТКИ
// ----------------------------------------------------------------------------

/// Насос подпитки: добавляет воду в первичный контур или сливает её (отрицательная уставка). Бак пока неограничен.
/// Ему нужно электропитание от щитка.
/obj/machinery/submarine_makeup_pump
	name = "makeup pump"
	desc = "A small high-pressure pump on a tank of clean water. Pushes water into the reactor circuit to make up what is lost, or drains water out of it when the setting is negative. It needs electric power."
	// Временный спрайт: стоковый насос, окрашенный в синий. Заменить своим.
	icon = 'icons/atmos/pump.dmi'
	icon_state = "off"
	color = "#3f8fb5"
	density = TRUE
	anchored = TRUE
	use_power = POWER_USE_OFF

	/// Метка реактора. Должна совпадать с reactor_id ядра.
	var/reactor_id = "main"
	var/obj/machinery/submarine_reactor_core/core
	/// Уставка, -100 (слив) .. 100 (подпитка). По умолчанию насос стоит.
	var/setting = 0
	/// Фактический расход, -100 .. 100: уставка, если есть питание.
	var/flow = 0

/obj/machinery/submarine_makeup_pump/Initialize()
	. = ..()
	GLOB.submarine_makeup_pumps += src
	return INITIALIZE_HINT_LATELOAD

/obj/machinery/submarine_makeup_pump/LateInitialize(mapload, ...)
	for(var/obj/machinery/submarine_reactor_core/R in GLOB.submarine_reactors)
		if(R.reactor_id == reactor_id)
			R.find_makeup_pump()

/obj/machinery/submarine_makeup_pump/Destroy()
	GLOB.submarine_makeup_pumps -= src
	if(core)
		core.makeup_pump = null
	core = null
	return ..()

/obj/machinery/submarine_makeup_pump/Process(wait)
	// Родительский Process() не зовём: у /obj/machinery он возвращает PROCESS_KILL и остановил бы обработку.
	if(inoperable())
		flow = 0
		return
	flow = setting
	if(flow != 0)
		use_power_oneoff(NSR_MAKEUP_POWER * abs(flow) / 100)

/// Состояние для пульта.
/obj/machinery/submarine_makeup_pump/proc/get_state_text()
	if(inoperable())
		return "NO POWER"
	if(setting > 0)
		return "MAKING UP"
	if(setting < 0)
		return "DRAINING"
	return "STOPPED"

/obj/machinery/submarine_makeup_pump/examine(mob/user, distance)
	. = ..()
	if(distance <= 3)
		to_chat(user, "It is [lowertext(get_state_text())].")
