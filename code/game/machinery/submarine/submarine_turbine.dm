/*
	NS-13: турбина подлодки. Этап 3в-1 («ход пара, вал, генератор, защиты, пульт»).
	Проект и расчётная модель: GDD, §5.2, п. 9. Подробное описание и проверка: README.md в этой же папке.

	ЧТО ЗДЕСЬ ЕСТЬ
	- Секция турбины (/obj/machinery/atmospherics/binary/submarine_turbine_section): двухпортовое устройство на паровых трубах.
	  Пар входит с тыла, выходит вперёд (по dir). Три типа: /hp (высокого давления), /lp1 и /lp2 (низкого). У каждой своё здоровье.
	  Сама секция ничего не считает: её двигает генератор (так вся турбина шагает в одном порядке, как в расчётной модели).
	- Генератор (/obj/machinery/power/submarine_turbine_generator): вал и электрическая часть. Знает три секции (ищет их по turbine_id
	  в радиусе NST_LINK_RANGE), держит обороты, регулятор, автомат (выключатель), стопорный клапан, повреждения. Отдаёт ток
	  в сеть (нужен узловой кабель под ним, как под любой энергомашиной Бэя).
	- Предохранительный клапан (/obj/machinery/atmospherics/binary/submarine_relief_valve): сбрасывает пар из горячей линии в вход
	  конденсатора мимо турбины, когда давление выше NST_RELIEF_BAR. Руками его можно запереть (чтобы показать, что без него плохо).
	- Нагрузочный блок (/obj/machinery/power/submarine_load_bank): ТЕСТОВАЯ вещь, «потребитель на заказ». Нажатие рукой переключает
	  нагрузку 0, 25, 50, 100, 150, 200 кВт, чтобы проверять регулятор, автомат и сброс нагрузки. Потом уберём или оставим как балласт.
	- Пульт турбины (/obj/machinery/computer/submarine_turbine_console): NanoUI, шаблон nano/templates/submarine_turbine_panel.tmpl.
	  Управляет заслонкой, регулятором, автоматом, стопорным клапаном и мощностью конденсатора.
	- Конденсатор остался в submarine_reactor.dm, но теперь принимает пар «по ёмкости» (NSR_CONDENSER_CAPACITY, мощность cooling 0-100%).

	КАК РАССТАВЛЯТЬ НА КАРТЕ
	- Ряд на трубах: горячая линия, секция /hp, труба, /lp1, труба, /lp2, труба, конденсатор. Каждая секция смотрит (dir) в сторону пара дальше.
	- Генератор рядом (в радиусе NST_LINK_RANGE от него все три секции), на тайле с узловым кабелем.
	- Предохранительный клапан: вход (с тыла) в горячей линии до турбины, выход (по dir) во входную трубу конденсатора.
	- Пульт находит генератор по turbine_id (по умолчанию "main" у всех), конденсатор и клапан тоже.

	ЧЕГО ЗДЕСЬ НАМЕРЕННО НЕТ (этап 3в-2 и дальше, GDD)
	- Лопасти, их рецепт в автолате, перестройка секции, ремонт генератора проводами и деталями.
	  Сейчас разрушенная секция остаётся «закупоркой»: пар не проходит, пока её не заменят (замены пока нет).
	- Автоматика серверной, радиатор, отказ регулятора (флаг governor_ok уже есть).

	Все числа ЧЕРНОВЫЕ, взяты из расчётной модели (не из игры). Они собраны в одном блоке ниже, меняйте только там.
*/

GLOBAL_LIST_EMPTY(submarine_turbines)
GLOBAL_LIST_EMPTY(submarine_turbine_consoles)
GLOBAL_LIST_EMPTY(submarine_relief_valves)

// ----------------------------------------------------------------------------
// ЧЕРНОВЫЕ ЧИСЛА [TBD]
// ----------------------------------------------------------------------------

// Секции
#define NST_STAGE_HP              1      // номер ступени: высокого давления
#define NST_STAGE_LP1             2      // низкого давления, первая
#define NST_STAGE_LP2             3      // низкого давления, вторая
#define NST_LINK_RANGE            6      // радиус поиска секций от генератора, тайлов
#define NST_VOL_HP                300    // л, объём газа на каждой стороне секции высокого давления
#define NST_VOL_LP                600    // л, то же для секций низкого давления
#define NST_K_HP                  0.032  // моль/с на кПа перепада при открытой заслонке
#define NST_K_LP1                 0.15
#define NST_K_LP2                 0.37
#define NST_W0                    1200   // Дж/моль на единицу ln(P_вх / P_вых)
#define NST_P_OUT_MIN             50     // кПа: ниже этого давления на выходе работа расширения не растёт (настоящего вакуума в игре нет)
#define NST_EXHAUST_MIN_TEMP      (T0C + 40) // K, ниже этого отработанный пар в расчёте температуры не остывает
#define NST_HEALTH_FLOOR          0.3    // доля работы, которую даёт секция с нулевым здоровьем (повреждённая работает хуже)

// Вал и генератор
#define NST_SHAFT_INERTIA         12     // кг*м^2, момент инерции вала со всеми секциями и ротором генератора
#define NST_RPM_PER_RADS          9.5493 // об/мин на рад/с (60 / 2 пи)
#define NST_WINDAGE               58.6   // Вт на (тыс. об/мин)^3: 30 кВт при 8000, около 240 кВт при 16000
#define NST_GEN_EFF               0.95   // КПД генератора
#define NST_GEN_MAX               250000 // Вт, максимум генератора
#define NST_RPM_SYNC_LO           5000   // рабочее окно: с этих оборотов генератор отдаёт полную мощность
#define NST_RPM_SYNC_HI           10000  // до этих
#define NST_RPM_TRIP_LO           4500   // ниже автомат отключается сам; между TRIP_LO и SYNC_LO выдача линейно растёт
#define NST_RPM_TRIP_HI           10500  // выше автомат отключается сам; между SYNC_HI и TRIP_HI выдача линейно падает
#define NST_RPM_STOP              11000  // стопорный клапан закрывается сам
#define NST_RPM_STOP_RESET        6000   // сбросить стопорный клапан можно, когда обороты ниже этих
#define NST_RPM_DAMAGE            12000  // выше этих оборотов секции получают повреждения
#define NST_RPM_EXPLODE           16000  // на этих оборотах самая слабая целая секция разрушается
#define NST_DAMAGE_RATE           0.02   // доля здоровья в секунду на каждую 1000 об/мин сверх NST_RPM_DAMAGE
#define NST_WRECK_ENERGY_KEEP     0.25   // какая доля энергии вала остаётся после разрушения секции (оторвало лопасть)
#define NST_SECTION_EXPLOSION     5      // параметр range для explosion(): меньше, чем у реактора (10); при 5 ядро взрыва это 1 тайл

// Регулятор оборотов
#define NST_GOV_GAIN              1      // процентов хода заслонки в секунду на каждую 1000 об/мин ошибки (медленный)
#define NST_GOV_SET_DEFAULT       7500   // об/мин, уставка по умолчанию
#define NST_GOV_SET_MIN           3000
#define NST_GOV_SET_MAX           10000
#define NST_GOV_SET_STEP          500

// Предохранительный сброс пара
#define NST_RELIEF_BAR            40     // бар, при таком давлении на входе клапан начинает сбрасывать пар в конденсатор
#define NST_RELIEF_COEF           0.03   // моль/с на каждый кПа превышения

// Следование за нагрузкой: генератор отдаёт сети столько, сколько она потребляет
#define NST_LOAD_MIN              2000   // Вт, подача при нулевом потреблении (чтобы было с чего начать)
#define NST_LOAD_SAFETY           1.05   // запас над потреблением
#define NST_LOAD_GROW             1.5    // во сколько раз растёт подача, когда сеть выбирает всё, что дают
#define NST_LOAD_PROBE            10000  // Вт, прибавка подачи при таком росте

// ----------------------------------------------------------------------------
// ОБЩИЕ ФУНКЦИИ: газ по всей сети труб
// ----------------------------------------------------------------------------

/// Сколько моль газа gas_id во всех смесях сети труб.
/proc/nst_network_gas(datum/pipe_network/net, gas_id)
	. = 0
	if(!net)
		return
	for(var/datum/gas_mixture/G in net.gases)
		. += G.get_gas(gas_id)

/// Убирает из ВСЕЙ сети труб (поровну из каждой смеси) moles моль газа gas_id. Возвращает, сколько убрано.
/// Нужна, потому что устройство Бэя видит только свою смесь, а это малая доля сети: за один такт оно бы унесло лишь её.
/proc/nst_network_remove_gas(datum/pipe_network/net, gas_id, moles)
	if(!net || moles <= 0)
		return 0
	var/total = nst_network_gas(net, gas_id)
	if(total <= 0)
		return 0
	var/ratio = min(1, moles / total)
	for(var/datum/gas_mixture/G in net.gases)
		var/have = G.get_gas(gas_id)
		if(have > 0)
			G.adjust_gas(gas_id, -have * ratio)
	net.update = 1
	return min(moles, total)

/// Забирает из ВСЕЙ сети труб около moles моль газа любого состава (поровну из каждой смеси). Возвращает смесь с отобранным или null.
/proc/nst_network_take(datum/pipe_network/net, moles)
	if(!net || moles <= 0)
		return null
	var/total = 0
	for(var/datum/gas_mixture/G in net.gases)
		total += G.total_moles
	if(total <= 0)
		return null
	var/ratio = min(1, moles / total)
	var/datum/gas_mixture/taken = new
	for(var/datum/gas_mixture/G in net.gases)
		taken.merge(G.remove_ratio(ratio))
	net.update = 1
	return taken

// ----------------------------------------------------------------------------
// СЕКЦИЯ ТУРБИНЫ
// ----------------------------------------------------------------------------

/obj/machinery/atmospherics/binary/submarine_turbine_section
	name = "turbine section"
	desc = "One section of the steam turbine. Steam enters at the back, expands against the blades and leaves colder and at a lower pressure."
	// Временно: спрайт насоса из стока, окрашенный. Заменить своим.
	icon = 'icons/atmos/pump.dmi'
	icon_state = "off"
	color = "#d9822b"
	level = ATOM_LEVEL_OVER_TILE
	use_power = POWER_USE_OFF
	uncreated_component_parts = null
	connect_types = CONNECT_TYPE_REGULAR
	/// Метка турбины, к которой относится секция. Должна совпадать с turbine_id генератора.
	var/turbine_id = "main"
	/// Ступень: NST_STAGE_HP, NST_STAGE_LP1 или NST_STAGE_LP2.
	var/stage = NST_STAGE_HP
	/// Моль/с на кПа перепада при открытой заслонке. Задаётся ступенью.
	var/flow_coef = NST_K_HP
	/// Здоровье секции, 0-1. Влияет на работу, которую секция берёт у пара.
	var/health_frac = 1
	/// TRUE, если секция разрушена: пар через неё не идёт.
	var/broken = FALSE
	/// Пар через секцию за последний тик, моль/с.
	var/last_flow = 0
	/// Мощность на валу от этой секции за последний тик, Вт.
	var/last_work = 0
	/// Когда секция может в следующий раз пожаловаться на тряску.
	var/next_shake_message = 0

/obj/machinery/atmospherics/binary/submarine_turbine_section/hp
	name = "high-pressure turbine section"
	stage = NST_STAGE_HP

/obj/machinery/atmospherics/binary/submarine_turbine_section/lp1
	name = "low-pressure turbine section"
	stage = NST_STAGE_LP1
	color = "#e3c55a"

/obj/machinery/atmospherics/binary/submarine_turbine_section/lp2
	name = "low-pressure turbine section"
	stage = NST_STAGE_LP2
	color = "#e3c55a"

/obj/machinery/atmospherics/binary/submarine_turbine_section/Initialize()
	. = ..()
	switch(stage)
		if(NST_STAGE_HP)
			flow_coef = NST_K_HP
			air1.volume = NST_VOL_HP
			air2.volume = NST_VOL_HP
		if(NST_STAGE_LP1)
			flow_coef = NST_K_LP1
			air1.volume = NST_VOL_LP
			air2.volume = NST_VOL_LP
		if(NST_STAGE_LP2)
			flow_coef = NST_K_LP2
			air1.volume = NST_VOL_LP
			air2.volume = NST_VOL_LP

/obj/machinery/atmospherics/binary/submarine_turbine_section/use_tool(obj/item/tool, mob/living/user, list/click_params)
	// Секция закреплена на фундаменте: отвернуть её гаечным ключом нельзя.
	if(isWrench(tool))
		to_chat(user, SPAN_WARNING("\The [src] is bolted to its foundation."))
		return TRUE
	return ..()

/obj/machinery/atmospherics/binary/submarine_turbine_section/update_underlays()
	if(..())
		underlays.Cut()
		var/turf/T = get_turf(src)
		if(!istype(T))
			return
		add_underlay(T, node1, turn(dir, -180))
		add_underlay(T, node2, dir)

/obj/machinery/atmospherics/binary/submarine_turbine_section/hide(i)
	update_underlays()

/// Двигает пар через секцию на dt секунд. admission это степень открытия заслонки, 0-1 (у ступеней низкого давления всегда 1).
/// Возвращает работу, которую секция взяла у пара, в джоулях: её добавляет к валу генератор.
/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/run_section(dt, admission)
	last_flow = 0
	last_work = 0
	if(broken || !network1 || !network2 || admission <= 0 || dt <= 0)
		return 0
	var/pressure_in = air1.return_pressure()
	var/pressure_out = air2.return_pressure()
	var/delta_pressure = pressure_in - pressure_out
	if(delta_pressure <= 0 || air1.total_moles <= 0)
		return 0
	var/temp_in = air1.temperature
	var/temp_out = max(air2.temperature, T0C)
	var/volume_in = max(network1.volume, 1)
	var/volume_out = max(network2.volume, 1)
	// Поток пропорционален перепаду и заслонке, но не больше половины того, что выровняло бы давление (иначе шаг перескочит).
	var/moles = flow_coef * admission * delta_pressure * dt
	var/equalize = delta_pressure / (R_IDEAL_GAS_EQUATION * temp_in / volume_in + R_IDEAL_GAS_EQUATION * temp_out / volume_out)
	moles = min(moles, 0.5 * equalize)
	if(moles <= 0)
		return 0
	var/datum/gas_mixture/passed = nst_network_take(network1, moles)
	if(!passed || passed.total_moles <= 0)
		return 0
	var/passed_moles = passed.total_moles
	// Работа на моль: от логарифма отношения давлений, слабее у повреждённой секции.
	var/work_per_mole = NST_W0 * max(0, log(pressure_in / max(pressure_out, NST_P_OUT_MIN))) * (NST_HEALTH_FLOOR + (1 - NST_HEALTH_FLOOR) * health_frac)
	var/heat_capacity_per_mole = passed.heat_capacity() / passed_moles
	if(heat_capacity_per_mole > 0)
		passed.temperature = min(temp_in, max(NST_EXHAUST_MIN_TEMP, temp_in - work_per_mole / heat_capacity_per_mole))
	air2.merge(passed)
	network2.update = 1
	last_flow = passed_moles / dt
	var/work = passed_moles * work_per_mole
	last_work = work / dt
	return work

/// Повреждение от переборов оборотов. Возвращает TRUE, если секция из-за него разрушилась.
/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/take_overspeed_damage(amount)
	if(broken)
		return FALSE
	health_frac = max(0, health_frac - amount)
	if(health_frac <= 0)
		wreck()
		return TRUE
	if(world.time >= next_shake_message)
		next_shake_message = world.time + 8 SECONDS
		visible_message(SPAN_DANGER("\The [src] shakes violently and screams on the blades!"))
		playsound(src, 'sound/machines/warning-buzzer.ogg', 50, TRUE)
	return FALSE

/// Секция разрушена: лопасть срывается, пар вырывается в зал, взрыв меньше, чем у реактора. Замены лопасти и перестройки пока нет (этап 3в-2).
/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/wreck()
	if(broken)
		return
	broken = TRUE
	health_frac = 0
	last_flow = 0
	last_work = 0
	color = "#443a33"
	visible_message(SPAN_DANGER("A blade tears loose and \the [src] bursts apart in a cloud of steam!"))
	var/turf/here = get_turf(src)
	if(here)
		// Весь газ секции вырывается в помещение (клубы пара). Остальной газ труб выйдет через лопнувшие рядом трубы, если взрыв их сломает.
		var/datum/gas_mixture/spill_in = air1.remove_ratio(1)
		var/datum/gas_mixture/spill_out = air2.remove_ratio(1)
		if(spill_in)
			here.assume_air(spill_in)
		if(spill_out)
			here.assume_air(spill_out)
		explosion(here, NST_SECTION_EXPLOSION)
	if(network1)
		network1.update = 1
	if(network2)
		network2.update = 1

// ----------------------------------------------------------------------------
// ПРЕДОХРАНИТЕЛЬНЫЙ КЛАПАН
// ----------------------------------------------------------------------------

/// Сбрасывает пар из горячей линии в вход конденсатора мимо турбины, когда давление на входе выше NST_RELIEF_BAR.
/// Без него при отказе турбины (сброс нагрузки, стопорный клапан) пар копится в сосуде, и он рвётся. Это просто устройство на трубах:
/// его можно запереть рукой, перекрыть трубу или сломать, и тогда реактор защищён только пультом (SCRAM).
/obj/machinery/atmospherics/binary/submarine_relief_valve
	name = "steam relief valve"
	desc = "A spring-loaded valve that dumps steam straight into the condenser when the line pressure gets too high. A red wheel locks it shut."
	// Временно: спрайт насоса из стока, окрашенный в красный. Заменить своим.
	icon = 'icons/atmos/pump.dmi'
	icon_state = "off"
	color = "#c0392b"
	level = ATOM_LEVEL_OVER_TILE
	use_power = POWER_USE_OFF
	uncreated_component_parts = null
	connect_types = CONNECT_TYPE_REGULAR
	/// Метка турбины, пульт которой показывает этот клапан.
	var/turbine_id = "main"
	/// TRUE, если клапан заперт колесом (не сбрасывает ничего).
	var/locked_shut = FALSE
	/// Давление срабатывания, бар.
	var/set_bar = NST_RELIEF_BAR
	/// Сброшено за последний тик, моль/с.
	var/last_flow = 0
	/// Всего сброшено, моль (для пульта).
	var/total_dumped = 0

/obj/machinery/atmospherics/binary/submarine_relief_valve/Initialize()
	. = ..()
	air1.volume = 100
	air2.volume = 100
	GLOB.submarine_relief_valves += src

/obj/machinery/atmospherics/binary/submarine_relief_valve/Destroy()
	GLOB.submarine_relief_valves -= src
	return ..()

/obj/machinery/atmospherics/binary/submarine_relief_valve/update_underlays()
	if(..())
		underlays.Cut()
		var/turf/T = get_turf(src)
		if(!istype(T))
			return
		add_underlay(T, node1, turn(dir, -180))
		add_underlay(T, node2, dir)

/obj/machinery/atmospherics/binary/submarine_relief_valve/hide(i)
	update_underlays()

/obj/machinery/atmospherics/binary/submarine_relief_valve/physical_attack_hand(mob/user)
	locked_shut = !locked_shut
	if(locked_shut)
		visible_message(SPAN_NOTICE("\The [user] locks \the [src] shut."))
	else
		visible_message(SPAN_NOTICE("\The [user] unlocks \the [src]."))
	playsound(src, 'sound/items/Ratchet.ogg', 40, TRUE)
	return TRUE

/obj/machinery/atmospherics/binary/submarine_relief_valve/proc/get_state_text()
	if(locked_shut)
		return "LOCKED SHUT"
	if(last_flow > 0)
		return "DUMPING"
	return "ARMED"

/obj/machinery/atmospherics/binary/submarine_relief_valve/Process(wait)
	. = ..()
	last_flow = 0
	if(locked_shut || !network1 || !network2)
		return
	var/dt = 2
	if(wait > 0)
		dt = clamp(wait / 10, 0.5, 5)
	var/pressure_in = air1.return_pressure()
	var/limit = set_bar * NSR_KPA_PER_BAR
	if(pressure_in <= limit)
		return
	var/pressure_out = air2.return_pressure()
	var/delta_pressure = pressure_in - pressure_out
	if(delta_pressure <= 0)
		return
	var/temp_in = air1.temperature
	var/temp_out = max(air2.temperature, T0C)
	var/volume_in = max(network1.volume, 1)
	var/volume_out = max(network2.volume, 1)
	var/moles = NST_RELIEF_COEF * (pressure_in - limit) * dt
	var/equalize = delta_pressure / (R_IDEAL_GAS_EQUATION * temp_in / volume_in + R_IDEAL_GAS_EQUATION * temp_out / volume_out)
	moles = min(moles, 0.5 * equalize)
	if(moles <= 0)
		return
	var/datum/gas_mixture/dumped = nst_network_take(network1, moles)
	if(!dumped)
		return
	air2.merge(dumped)
	network2.update = 1
	last_flow = dumped.total_moles / dt
	total_dumped += dumped.total_moles

// ----------------------------------------------------------------------------
// ГЕНЕРАТОР (вал, автомат, стопорный клапан, регулятор)
// ----------------------------------------------------------------------------

/obj/machinery/power/submarine_turbine_generator
	name = "turbine generator"
	desc = "A heavy generator on the same shaft as the turbine sections. It only feeds the grid while the shaft turns in the working window."
	// Временно: корпус ТЭГа из стока. Заменить своим.
	icon = 'icons/obj/machines/power/teg.dmi'
	icon_state = "teg-assembled"
	color = "#8aa0b4"
	density = TRUE
	anchored = TRUE
	construct_state = null
	uncreated_component_parts = null
	can_use_tools = FALSE
	/// Метка турбины. Секции, клапан и конденсатор находятся по ней.
	var/turbine_id = "main"
	var/obj/machinery/atmospherics/binary/submarine_turbine_section/hp
	var/obj/machinery/atmospherics/binary/submarine_turbine_section/lp1
	var/obj/machinery/atmospherics/binary/submarine_turbine_section/lp2
	/// Энергия вращения вала, Дж.
	var/shaft_energy = 0
	/// Обороты вала, об/мин (кэш для пульта).
	var/rpm = 0
	/// Заслонка высокого давления, 0-100%. При включённом регуляторе её двигает регулятор.
	var/admission = 0
	var/governor_on = TRUE
	/// FALSE, если регулятор отказал (отказов пока нет, флаг для автоматики и поломок).
	var/governor_ok = TRUE
	var/governor_set = NST_GOV_SET_DEFAULT
	/// TRUE, если автомат генератора включён (генератор подключён к сети).
	var/breaker_closed = FALSE
	/// TRUE, если стопорный клапан закрыт (сработал сам или по кнопке). Сбрасывается только вручную.
	var/stop_tripped = FALSE
	/// Мощность пара на валу за последний тик, Вт.
	var/steam_power = 0
	/// Электрическая мощность в сеть за последний тик, Вт.
	var/last_output = 0
	/// Сколько сеть запросила в этот раз, Вт.
	var/last_demand = 0
	/// Последняя причина отключения автомата, для пульта.
	var/trip_reason = ""

/obj/machinery/power/submarine_turbine_generator/Initialize()
	. = ..()
	GLOB.submarine_turbines += src
	find_parts()

/obj/machinery/power/submarine_turbine_generator/Destroy()
	GLOB.submarine_turbines -= src
	hp = null
	lp1 = null
	lp2 = null
	return ..()

/// Ищет три секции своей турбины в радиусе. Возвращает, сколько нашёл.
/obj/machinery/power/submarine_turbine_generator/proc/find_parts()
	hp = null
	lp1 = null
	lp2 = null
	for(var/obj/machinery/atmospherics/binary/submarine_turbine_section/S in range(NST_LINK_RANGE, src))
		if(S.turbine_id != turbine_id)
			continue
		switch(S.stage)
			if(NST_STAGE_HP)
				hp = S
			if(NST_STAGE_LP1)
				lp1 = S
			if(NST_STAGE_LP2)
				lp2 = S
	return (hp ? 1 : 0) + (lp1 ? 1 : 0) + (lp2 ? 1 : 0)

/obj/machinery/power/submarine_turbine_generator/proc/parts_intact()
	return hp && !QDELETED(hp) && lp1 && !QDELETED(lp1) && lp2 && !QDELETED(lp2)

/// Три секции по порядку пара, пустые места это null.
/obj/machinery/power/submarine_turbine_generator/proc/get_sections()
	return list(hp, lp1, lp2)

/obj/machinery/power/submarine_turbine_generator/proc/count_broken()
	. = 0
	for(var/obj/machinery/atmospherics/binary/submarine_turbine_section/S in get_sections())
		if(S.broken)
			.++

/obj/machinery/power/submarine_turbine_generator/proc/shaft_rpm()
	return sqrt(2 * max(shaft_energy, 0) / NST_SHAFT_INERTIA) * NST_RPM_PER_RADS

/// Сколько запросить у турбины для сети. Генератор следует за нагрузкой: отдаёт чуть больше, чем сеть брала в прошлый такт,
/// а если сеть выбрала всё, что дают, поднимает подачу (так нагрузка, появившаяся с нуля, набирается за несколько тактов).
/obj/machinery/power/submarine_turbine_generator/proc/grid_demand()
	if(!powernet)
		return 0
	var/load = powernet.viewload
	var/avail = powernet.avail
	if(avail > 0 && load >= avail * 0.98)
		return avail * NST_LOAD_GROW + NST_LOAD_PROBE
	return max(load * NST_LOAD_SAFETY, NST_LOAD_MIN)

/obj/machinery/power/submarine_turbine_generator/proc/open_breaker(reason)
	if(!breaker_closed)
		return
	breaker_closed = FALSE
	last_output = 0
	trip_reason = reason
	visible_message(SPAN_WARNING("The generator breaker trips open ([reason])!"))
	playsound(src, 'sound/machines/warning-buzzer.ogg', 60, TRUE)

/// Пытается подключить генератор к сети. Только в рабочем окне оборотов и если под генератором есть сеть.
/obj/machinery/power/submarine_turbine_generator/proc/try_close_breaker(mob/user)
	if(breaker_closed)
		return TRUE
	var/rpm_now = shaft_rpm()
	if(rpm_now < NST_RPM_SYNC_LO || rpm_now > NST_RPM_SYNC_HI)
		to_chat(user, SPAN_WARNING("Cannot connect: the shaft must be within [NST_RPM_SYNC_LO]-[NST_RPM_SYNC_HI] rpm (now [round(rpm_now)])."))
		return FALSE
	if(!powernet)
		to_chat(user, SPAN_WARNING("Cannot connect: there is no grid cable under the generator."))
		return FALSE
	breaker_closed = TRUE
	trip_reason = ""
	visible_message(SPAN_NOTICE("The generator breaker closes with a heavy clunk."))
	playsound(src, 'sound/machines/switch2.ogg', 40, TRUE)
	return TRUE

/obj/machinery/power/submarine_turbine_generator/proc/trip_stop_valve(reason)
	if(stop_tripped)
		return
	stop_tripped = TRUE
	visible_message(SPAN_DANGER("The turbine stop valve slams shut ([reason])!"))
	playsound(src, 'sound/machines/warning-buzzer.ogg', 80, TRUE)

/// Сброс стопорного клапана оператором. Только когда обороты упали ниже NST_RPM_STOP_RESET; заслонка при этом закрывается.
/obj/machinery/power/submarine_turbine_generator/proc/reset_stop_valve(mob/user)
	if(!stop_tripped)
		return TRUE
	if(shaft_rpm() >= NST_RPM_STOP_RESET)
		to_chat(user, SPAN_WARNING("Cannot reset the stop valve: the shaft must slow below [NST_RPM_STOP_RESET] rpm first."))
		return FALSE
	stop_tripped = FALSE
	admission = 0
	visible_message(SPAN_NOTICE("The turbine stop valve is reset and the admission valve is closed."))
	return TRUE

/// Повреждения от оборотов выше NST_RPM_DAMAGE и разрушение секций на NST_RPM_EXPLODE. Возвращает TRUE, если что-то разрушилось.
/obj/machinery/power/submarine_turbine_generator/proc/apply_overspeed(rpm_now, dt)
	var/broken_before = count_broken()
	var/damage = (rpm_now - NST_RPM_DAMAGE) / 1000 * NST_DAMAGE_RATE * dt
	for(var/obj/machinery/atmospherics/binary/submarine_turbine_section/S in get_sections())
		S.take_overspeed_damage(damage)
	if(rpm_now >= NST_RPM_EXPLODE)
		var/obj/machinery/atmospherics/binary/submarine_turbine_section/weakest
		for(var/obj/machinery/atmospherics/binary/submarine_turbine_section/S in get_sections())
			if(!S.broken && (!weakest || S.health_frac < weakest.health_frac))
				weakest = S
		if(weakest)
			weakest.wreck()
	var/wrecked = count_broken() - broken_before
	if(wrecked > 0)
		// Сорванная лопасть уносит часть энергии вала, а автомат срабатывает от удара.
		shaft_energy *= NST_WRECK_ENERGY_KEEP ** wrecked
		open_breaker("SECTION WRECKED")
		return TRUE
	return FALSE

/obj/machinery/power/submarine_turbine_generator/Process(wait)
	// Родительский Process() не зовём: у /obj/machinery он возвращает PROCESS_KILL и остановил бы обработку.
	var/dt = 2
	if(wait > 0)
		dt = clamp(wait / 10, 0.5, 5)
	if(!parts_intact())
		find_parts()
	var/rpm_now = shaft_rpm()

	// Регулятор оборотов: медленный интегральный. Пока стопорный клапан закрыт, он стоит, чтобы заслонка не «накручивалась».
	if(governor_on && governor_ok && !stop_tripped)
		admission = clamp(admission + NST_GOV_GAIN * (governor_set - rpm_now) / 1000 * dt, 0, 100)

	// Пар идёт через секции по порядку; заслонка есть только у высокого давления.
	var/work = 0
	for(var/obj/machinery/atmospherics/binary/submarine_turbine_section/S in get_sections())
		work += S.run_section(dt, S.stage == NST_STAGE_HP ? (stop_tripped ? 0 : admission / 100) : 1)
	steam_power = work / dt

	// Трение (парусность) растёт с кубом оборотов.
	var/friction_power = NST_WINDAGE * (rpm_now / 1000) ** 3

	// Генератор: рабочее окно, защита автомата, подача в сеть.
	var/electric_power = 0
	last_demand = 0
	if(breaker_closed)
		if(rpm_now < NST_RPM_TRIP_LO)
			open_breaker("UNDERSPEED")
		else if(rpm_now > NST_RPM_TRIP_HI)
			open_breaker("OVERSPEED")
		else if(powernet)
			var/sync = clamp((rpm_now - NST_RPM_TRIP_LO) / (NST_RPM_SYNC_LO - NST_RPM_TRIP_LO), 0, 1) * clamp((NST_RPM_TRIP_HI - rpm_now) / (NST_RPM_TRIP_HI - NST_RPM_SYNC_HI), 0, 1)
			last_demand = grid_demand()
			electric_power = min(NST_GEN_MAX * sync, last_demand)
			add_avail(electric_power)
		else
			open_breaker("NO GRID")
	last_output = electric_power

	// Баланс энергии вала: пар даёт, генератор и трение забирают.
	shaft_energy = max(0, shaft_energy + (steam_power - electric_power / NST_GEN_EFF - friction_power) * dt)
	rpm = shaft_rpm()

	// Защиты.
	if(!stop_tripped && rpm >= NST_RPM_STOP)
		trip_stop_valve("OVERSPEED")
	if(rpm > NST_RPM_DAMAGE)
		apply_overspeed(rpm, dt)
		rpm = shaft_rpm()

// ----------------------------------------------------------------------------
// НАГРУЗОЧНЫЙ БЛОК (ТЕСТ)
// ----------------------------------------------------------------------------

/// Потребитель на заказ для проверки турбины: нажатие рукой переключает нагрузку. Тянет ток из сети под собой (нужен узловой кабель).
/obj/machinery/power/submarine_load_bank
	name = "test load bank"
	desc = "A bank of resistors that burns electricity as heat. Touch it to change the load. A test fixture for the turbine."
	// Временно: корпус СМЭС из стока. Заменить своим.
	icon = 'icons/obj/machines/power/smes.dmi'
	icon_state = "smes"
	color = "#b07a3a"
	density = TRUE
	anchored = TRUE
	construct_state = null
	uncreated_component_parts = null
	can_use_tools = FALSE
	/// Ступени нагрузки, Вт.
	var/list/load_steps = list(0, 25000, 50000, 100000, 150000, 200000)
	var/step_index = 1
	var/load_w = 0
	/// Сколько удалось взять из сети в прошлый такт, Вт.
	var/drawn = 0

/obj/machinery/power/submarine_load_bank/physical_attack_hand(mob/user)
	step_index = (step_index % length(load_steps)) + 1
	load_w = load_steps[step_index]
	visible_message(SPAN_NOTICE("\The [user] sets \the [src] to [load_w / 1000] kW."))
	playsound(src, 'sound/machines/switch2.ogg', 40, TRUE)
	update_desc()
	return TRUE

/obj/machinery/power/submarine_load_bank/proc/update_desc()
	desc = "[initial(desc)] Set to [load_w / 1000] kW, getting [round(drawn / 1000, 0.1)] kW."

/obj/machinery/power/submarine_load_bank/Process()
	// Родительский Process() не зовём, см. генератор.
	var/before = drawn
	drawn = 0
	if(load_w > 0 && powernet)
		drawn = draw_power(load_w)
	if(drawn != before)
		update_desc()

// ----------------------------------------------------------------------------
// ПУЛЬТ ТУРБИНЫ
// ----------------------------------------------------------------------------

/obj/machinery/computer/submarine_turbine_console
	name = "turbine control panel"
	desc = "A heavy control panel with the admission valve, the governor, the generator breaker and the stop valve of the steam turbine."
	machine_name = "turbine control panel"
	machine_desc = "Used to operate the steam turbine: admission valve, speed governor, generator breaker, stop valve and condenser cooling."
	// Спрайт временный: блок управления из стокового Бэя, окрашенный. Заменить на свой.
	icon = 'icons/obj/machines/power/antimatter.dmi'
	icon_state = "control_on"
	color = "#9fc4ff"
	clicksound = "button"
	atom_flags = ATOM_FLAG_NO_TEMP_CHANGE
	// Как у пульта реактора: не собирается из деталей, без экрана и клавиатуры.
	construct_state = null
	// ВРЕМЕННО: пульт работает без питания (до АКБ-контура), как пульт реактора. Убрать MACHINE_STAT_NOPOWER из этой строки вместе с ним.
	stat_immune = MACHINE_STAT_NOPOWER | MACHINE_STAT_NOSCREEN | MACHINE_STAT_NOINPUT

	/// Метка турбины, которой управляет пульт. Должна совпадать с turbine_id генератора.
	var/turbine_id = "main"
	var/obj/machinery/power/submarine_turbine_generator/unit

/obj/machinery/computer/submarine_turbine_console/Initialize()
	. = ..()
	GLOB.submarine_turbine_consoles += src

/obj/machinery/computer/submarine_turbine_console/Destroy()
	GLOB.submarine_turbine_consoles -= src
	unit = null
	return ..()

/obj/machinery/computer/submarine_turbine_console/on_update_icon()
	// Не вызываем родителя: он рисует экран и клавиатуру компьютера, которых у пульта нет.
	ClearOverlays()
	icon_state = "control_on"

/obj/machinery/computer/submarine_turbine_console/proc/get_unit()
	if(unit && !QDELETED(unit))
		return unit
	unit = null
	for(var/obj/machinery/power/submarine_turbine_generator/G in GLOB.submarine_turbines)
		if(G.turbine_id == turbine_id)
			unit = G
			break
	return unit

/obj/machinery/computer/submarine_turbine_console/proc/get_condenser()
	for(var/obj/machinery/atmospherics/binary/submarine_condenser/C in GLOB.submarine_condensers)
		if(C.turbine_id == turbine_id)
			return C

/obj/machinery/computer/submarine_turbine_console/proc/get_relief()
	for(var/obj/machinery/atmospherics/binary/submarine_relief_valve/V in GLOB.submarine_relief_valves)
		if(V.turbine_id == turbine_id)
			return V

/obj/machinery/computer/submarine_turbine_console/interface_interact(mob/user)
	ui_interact(user)
	return TRUE

/// Давление в трубах рядом с секцией, бар. Для пульта.
/obj/machinery/computer/submarine_turbine_console/proc/bar_of(datum/gas_mixture/air)
	if(!air)
		return 0
	return round(air.return_pressure() / NSR_KPA_PER_BAR, 0.1)

/// Данные для окна NanoUI. Шаблон: nano/templates/submarine_turbine_panel.tmpl.
/obj/machinery/computer/submarine_turbine_console/proc/build_ui_data()
	var/list/data = list()
	var/obj/machinery/power/submarine_turbine_generator/G = get_unit()
	data["linked"] = !!G
	data["turbineId"] = turbine_id
	if(!G)
		return data
	var/rpm_now = round(G.rpm)
	data["rpm"] = rpm_now
	data["rpmMax"] = NST_RPM_EXPLODE
	data["rpmClass"] = "average"
	if(rpm_now >= NST_RPM_STOP)
		data["rpmClass"] = "bad"
	else if(rpm_now >= NST_RPM_SYNC_LO && rpm_now <= NST_RPM_SYNC_HI)
		data["rpmClass"] = "good"
	data["rpmWindowLow"] = NST_RPM_SYNC_LO
	data["rpmWindowHigh"] = NST_RPM_SYNC_HI
	data["admission"] = round(G.admission, 0.1)
	data["effAdmission"] = G.stop_tripped ? 0 : round(G.admission, 0.1)
	data["governorOn"] = G.governor_on
	data["governorOk"] = G.governor_ok
	data["governorSet"] = G.governor_set
	data["breaker"] = G.breaker_closed
	data["tripReason"] = G.trip_reason
	data["hasGrid"] = !!G.powernet
	data["stopTripped"] = G.stop_tripped
	data["steamKw"] = round(G.steam_power / 1000, 0.1)
	data["outputKw"] = round(G.last_output / 1000, 0.1)
	data["demandKw"] = round(G.last_demand / 1000, 0.1)
	data["maxKw"] = NST_GEN_MAX / 1000
	data["shaftMj"] = round(G.shaft_energy / 1000000, 0.01)
	var/list/section_list = list()
	for(var/obj/machinery/atmospherics/binary/submarine_turbine_section/S in G.get_sections())
		var/state_class = "good"
		if(S.broken)
			state_class = "bad"
		else if(S.health_frac < 0.5)
			state_class = "bad"
		else if(S.health_frac < 0.9)
			state_class = "average"
		section_list += list(list("name" = (S.stage == NST_STAGE_HP) ? "High-pressure" : "Low-pressure [S.stage - 1]", "health" = round(S.health_frac * 100), "broken" = S.broken, "flow" = round(S.last_flow, 0.1), "kw" = round(S.last_work / 1000, 0.1), "class" = state_class))
	data["sections"] = section_list
	data["missing"] = 3 - length(section_list)
	// Давления по ходу пара: перед турбиной, после высокого, после первой низкого, у конденсатора.
	if(G.hp)
		data["p0"] = bar_of(G.hp.air1)
		data["p1"] = bar_of(G.hp.air2)
	if(G.lp1)
		data["p2"] = bar_of(G.lp1.air2)
	if(G.lp2)
		data["p3"] = bar_of(G.lp2.air2)
	var/obj/machinery/atmospherics/binary/submarine_condenser/C = get_condenser()
	data["hasCondenser"] = !!C
	if(C)
		data["cooling"] = C.cooling
		data["condenserFlow"] = round(C.last_flow, 0.1)
		data["condenserMax"] = round(NSR_CONDENSER_CAPACITY * C.cooling / 100, 0.1)
	var/obj/machinery/atmospherics/binary/submarine_relief_valve/V = get_relief()
	data["hasRelief"] = !!V
	if(V)
		data["reliefState"] = V.get_state_text()
		data["reliefClass"] = V.locked_shut ? "bad" : (V.last_flow > 0 ? "average" : "good")
		data["reliefFlow"] = round(V.last_flow, 0.1)
		data["reliefBar"] = V.set_bar
	return data

/obj/machinery/computer/submarine_turbine_console/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = 1)
	var/list/data = build_ui_data()
	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "submarine_turbine_panel.tmpl", "Turbine control panel", 540, 780)
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(1)

/obj/machinery/computer/submarine_turbine_console/OnTopic(mob/user, href_list, datum/topic_state/state)
	var/action = href_list["action"]

	if(action == "rescan")
		unit = null
		var/obj/machinery/power/submarine_turbine_generator/found = get_unit()
		if(found)
			var/part_count = found.find_parts()
			to_chat(user, SPAN_NOTICE("Linked to turbine '[found.turbine_id]', [part_count] of 3 turbine sections detected, [get_condenser() ? "condenser" : "no condenser"], [get_relief() ? "relief valve" : "no relief valve"]."))
		else
			to_chat(user, SPAN_WARNING("No turbine '[turbine_id]' found."))
		return TOPIC_REFRESH

	var/obj/machinery/power/submarine_turbine_generator/G = get_unit()
	if(!G)
		to_chat(user, SPAN_WARNING("No link to a turbine."))
		return TOPIC_HANDLED

	switch(action)
		if("adm_move")
			var/adm_amount = text2num(href_list["amount"])
			if(!(adm_amount in list(-10, -1, 1, 10)))
				return TOPIC_HANDLED
			if(G.governor_on && G.governor_ok)
				to_chat(user, SPAN_WARNING("The governor holds the admission valve. Switch it off for manual control."))
			else if(G.stop_tripped)
				to_chat(user, SPAN_WARNING("The stop valve is shut: reset it first."))
			else
				G.admission = clamp(G.admission + adm_amount, 0, 100)
		if("gov_toggle")
			if(!G.governor_ok)
				to_chat(user, SPAN_WARNING("The governor has failed."))
			else
				G.governor_on = !G.governor_on
		if("gov_set")
			var/gov_amount = text2num(href_list["amount"])
			if(!(gov_amount in list(-NST_GOV_SET_STEP, NST_GOV_SET_STEP)))
				return TOPIC_HANDLED
			G.governor_set = clamp(G.governor_set + gov_amount, NST_GOV_SET_MIN, NST_GOV_SET_MAX)
		if("breaker")
			if(G.breaker_closed)
				G.open_breaker("MANUAL")
			else
				G.try_close_breaker(user)
		if("stop_trip")
			G.trip_stop_valve("EMERGENCY STOP")
		if("stop_reset")
			G.reset_stop_valve(user)
		if("cool_move")
			var/cool_amount = text2num(href_list["amount"])
			var/obj/machinery/atmospherics/binary/submarine_condenser/cond = get_condenser()
			if(!cond)
				to_chat(user, SPAN_WARNING("No condenser is connected to this turbine."))
			else if(cool_amount in list(-10, -1, 1, 10))
				cond.cooling = clamp(cond.cooling + cool_amount, 0, 100)
	return TOPIC_REFRESH
