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
	Четыре секции блоком 2x2: core, left_end, middle, right_end (какая где, не важно, они одинаковые).
	Ядро находит секции в радиусе NSR_SECTION_LINK_RANGE тайлов (по умолчанию 3).
	Пульт находит ядро по reactor_id (по умолчанию "main" у обоих), расстояние не важно.
	Между пультом и залом реактора должно быть минимум две двери (требование ТЗ, это вопрос карты).

	ЗАГЛУШКИ ДО ЭТАПА 3 (трубы и существующий в Бэе газ пар, GAS_STEAM)
	- Клапан питательной воды: добавляет воду в сосуд из ниоткуда. Работает только пока нет питательного насоса.
	- Клапан пара: стравливает пар. Потом заменится турбиной (steam_flow уже считается для неё).

	ПАРОВОЙ ПОРТ (этап 3а)
	- Паровой порт (/obj/machinery/atmospherics/unary/tank/submarine_reactor_steam_port) садится на настоящие трубы.
	  Пока порт стоит рядом с ядром, давление пара в сосуде равно давлению в этих трубах, а пар из кипения уходит в трубы.
	- Без порта работает прежний режим: запечатанный сосуд с заглушкой клапана пара. Старая карта продолжает работать.

	СТЕРЖНИ ХОДЯТ НЕ МГНОВЕННО (ревизия 4)
	- Оператор задаёт цель (rods_target), а стержни (rods_pos) идут к ней с конечной скоростью NSR_ROD_SPEED.
	- SCRAM вставляет стержни быстрее (NSR_ROD_SPEED_SCRAM), но тоже не мгновенно.

	СТЕРЖНИ ПО ОТДЕЛЬНОСТИ (ревизия 5)
	- Четыре стержня (NSR_ROD_COUNT), у каждого своя цель и свой привод. Тепловая мощность идёт от их среднего положения.
	  rods_pos и rods_target это средние значения, они считаются сами.

	ЗАМКНУТЫЙ КОНТУР (этап 3б)
	- Вода идёт по кругу: сосуд, пар, паровой порт, трубы, конденсатор, холодная ветка, питательный насос, сосуд.
	  Моли не теряются: сколько воды ушло в пар, столько пара должно вернуться конденсатом.
	- Конденсатор (/obj/machinery/atmospherics/binary/submarine_condenser): остужает пар забортной водой и отдаёт воду
	  в холодную ветку. Холодная ветка это ВОДЯНЫЕ ТРУБЫ (/obj/machinery/atmospherics/pipe/simple/visible/submarine_water,
	  тип соединения CONNECT_TYPE_WATER): к паровым трубам они не стыкуются. В Бэе по трубам ходят только газы, поэтому
	  внутри вода это счёт в молях отдельного вещества Water (GAS_LIQUID_WATER, не пар): без облаков, не кипит, анализатор
	  показывает Water. При утечке зона ZAS сразу конденсирует его в настоящие лужи, так что игрок видит и получает воду, а не пар.
	- Питательный насос (/obj/machinery/atmospherics/binary/submarine_feed_pump): двухпортовое устройство на холодной ветке.
	  Всасывает с востока (по dir насос смотрит напорной стороной), качает воду по водяной трубе к входному порту.
	  Подача падает с ростом давления в сосуде. Ему нужно электропитание: пропало, и охлаждения нет.
	  Обороты насоса идут к уставке с разгоном (10 с до полных) и торможением (около 17 с), без питания насос выбегает,
	  но ещё какое-то время качает воду. На пульте у него круглая шкала оборотов, при работе он гудит (петля звука).
	- Входной порт питательной воды (/obj/machinery/atmospherics/unary/tank/submarine_feed_inlet): приварен к сосуду рядом
	  с ядром, принимает воду из напорной трубы и сливает её в сосуд. Между насосом и портом ставится обычная водяная труба.
	- Без насоса работает прежняя заглушка: клапан питательной воды берёт воду из ниоткуда.
	- Водяная труба (submarine_water) только выпускает воду наружу, воздух помещения в неё не входит.
	  Конденсатор пропускает дальше по холодной ветке только пар (воду), прочие газы остаются на паровой стороне.

	ДВА КОНТУРА (ревизия 14, файл submarine_steam_generator.dm)
	- Если на карте есть парогенераторы (/obj/machinery/submarine_steam_generator) с той же меткой reactor_id, ядро работает в режиме
	  двух контуров (two_circuit): оно не кипит, а греет первичную воду, и тепло уходит в парогенераторы. Первичный контур держит
	  главный насос (/obj/machinery/submarine_primary_pump) и естественная циркуляция. Паровой порт и питательный вход в этом режиме
	  принадлежат парогенераторам и коллектору питательной воды. Без парогенераторов всё работает по-старому.

	НЕ РЕАЛИЗОВАНО НАМЕРЕННО (TBD в GDD, не подменяю догадками)
	- Износ стержней СУЗ и их замена (скафандр, радиация при замене).
	- Подключение к АКБ-контуру: пульт пока не требует питания (stat_immune ниже).

	Все числа ЧЕРНОВЫЕ. Они собраны в одном блоке в файле _submarine_defines.dm, меняйте только там.
*/


GLOBAL_LIST_EMPTY(submarine_reactors)
GLOBAL_LIST_EMPTY(submarine_reactor_consoles)
GLOBAL_LIST_EMPTY(submarine_steam_gens)
GLOBAL_LIST_EMPTY(submarine_primary_pumps)
GLOBAL_LIST_EMPTY(submarine_pressurizers)
GLOBAL_LIST_EMPTY(submarine_makeup_pumps)

/// Давление насыщения воды при температуре, бар (таблица, между точками линейно). Ниже 100 C считается пропорционально.
/proc/nsr_saturation_pressure(temp)
	var/static/list/temps = list(100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375)
	var/static/list/pressures = list(1.01, 2.32, 4.76, 8.92, 15.54, 25.5, 39.7, 59.4, 85.9, 120.5, 165.2, 221)
	if(temp <= 100)
		return 1.01 * max(temp, 0) / 100
	for(var/i in 1 to length(temps) - 1)
		if(temp <= temps[i + 1])
			return pressures[i] + (pressures[i + 1] - pressures[i]) * (temp - temps[i]) / (temps[i + 1] - temps[i])
	return 221 + (temp - 375) * 8

/// Плитки табло тревог (ревизия 17): порядок и подписи. Плитка жёлтая при предупреждении, красная при критической тревоге, мигает, пока её не подтвердили.
var/global/list/nsr_alarm_labels = list(
	"temp" = "CORE TEMP",
	"steam" = "STEAM PRESSURE",
	"water" = "SG WATER LOW",
	"cooling" = "COOLING LOST",
	"ppress_hi" = "PRIMARY PRESS HIGH",
	"ppress_lo" = "PRIMARY PRESS LOW",
	"plevel_hi" = "PZR LEVEL HIGH",
	"plevel_lo" = "PZR LEVEL LOW",
	"damage" = "FUEL DAMAGE",
	"leak" = "PRIMARY LEAK",
	"sg" = "STEAM GENERATOR",
	"valve" = "STEAM VALVE CLOSED",
	"pump" = "MAIN PUMP"
)

/// Уровень тревоги по верхнему порогу: 2, если значение не ниже критического, 1, если не ниже предупредительного, иначе 0.
/proc/nsr_high_level(value, warn, crit)
	if(value >= crit)
		return 2
	return (value >= warn) ? 1 : 0

/// То же по нижнему порогу: 2, если значение не выше критического, 1, если не выше предупредительного.
/proc/nsr_low_level(value, warn, crit)
	if(value <= crit)
		return 2
	return (value <= warn) ? 1 : 0

/// Радиус взрыва по энергии. Растёт с кубическим корнем энергии (вдвое больше энергии даёт радиус в 1,26 раза больше). ref_energy даёт ref_range.
/proc/nsr_blast_range(energy, ref_energy, ref_range)
	var/range = ref_range * (energy / max(ref_energy, 0.01)) ** (1 / 3)
	return round(clamp(range, ref_range * NSR_BLAST_RANGE_MIN, ref_range * NSR_BLAST_RANGE_MAX), 0.1)

/// Длина закрашенной части круглой шкалы для доли frac (0-1). Шкала в пульте нарисована дугой в 270 градусов.
/proc/nsr_gauge_len(frac)
	return round(clamp(frac, 0, 1) * NSR_GAUGE_ARC, 0.1)

/// Угол стрелки круглой шкалы для доли frac (0-1): от -135 (слева внизу) до +135 градусов (справа внизу).
/proc/nsr_gauge_angle(frac)
	return round(-135 + 270 * clamp(frac, 0, 1), 0.1)
GLOBAL_LIST_EMPTY(submarine_condensers)

// Все define'ы с числами (черновые [TBD]) лежат в _submarine_defines.dm: так порядок включения файлов в .dme не важен.

/// Снятая броневая плита секции реактора. Это настоящий тяжёлый предмет: его можно таскать (Ctrl+клик, pull).
/// Закрутить плиту обратно можно, только когда она лежит рядом с секцией (в радиусе 1 тайла).
/obj/structure/submarine_reactor_plate
	name = "reactor armour plate"
	desc = "A heavy lead-composite armour plate unbolted from a reactor section. Drag it with Ctrl+click. Leave it next to the section and use a wrench on the section to bolt it back on."
	// Временно: спрайт брони из стокового Бэя, окрашенный. Заменить своим.
	icon = 'icons/obj/robot_component.dmi'
	icon_state = "armor"
	color = "#6b6b75"
	density = TRUE
	anchored = FALSE

/// Общий порядок снятия и установки броневой плиты для всех четырёх секций корпуса (три секции и ядро).
/// Снятая плита ложится на тайл рабочего. Чтобы закрутить обратно, плита должна лежать рядом: её забирает секция.
/// Возвращает TRUE, если плиту после этого нужно переключить: вызывающий сам меняет свой casing_open.
/proc/nsr_wrench_casing(obj/machinery/hull, mob/living/user, is_open)
	if(is_open && !(locate(/obj/structure/submarine_reactor_plate) in range(1, hull)))
		to_chat(user, SPAN_WARNING("The armour plate has to lie next to \the [hull] to bolt it back on."))
		return FALSE
	hull.visible_message(SPAN_NOTICE("\The [user] starts [is_open ? "securing" : "unbolting"] the armour plate of \the [hull]."))
	playsound(hull, NS_SND_WRENCH, 50, TRUE)
	if(!do_after(user, NSR_CASING_TIME, hull))
		return FALSE
	if(is_open)
		var/obj/structure/submarine_reactor_plate/plate = locate(/obj/structure/submarine_reactor_plate) in range(1, hull)
		if(!plate)
			to_chat(user, SPAN_WARNING("The armour plate is gone."))
			return FALSE
		qdel(plate)
	else
		new /obj/structure/submarine_reactor_plate(get_turf(user))
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

// Три типа ради совместимости со старыми картами: секции одинаковые, их место в блоке 2x2 не важно.
/obj/machinery/submarine_reactor_section/left_end

/obj/machinery/submarine_reactor_section/middle

/obj/machinery/submarine_reactor_section/right_end

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
	desc = casing_open ? "The armour plate is off. The fuel channels, the coolant pipework and the bare vessel wall show through the open frame, and the radiation is much stronger here. Bolt the plate back on with a wrench." : initial(desc)

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
	/// Среднее фактическое положение стержней, 0-100%. Считается из rod_pos, руками не менять. От него зависит тепловая мощность.
	/// Остаточное тепло, доля от NSR_MAX_HEAT_RATE (0 .. NSR_DECAY_FRACTION). Растёт, пока реактор работает, после остановки медленно спадает (Е1).
	var/decay_heat = 0
	var/rods_pos = 0
	/// Средняя цель стержней, 0-100%. Считается из rod_target, руками не менять.
	var/rods_target = 0
	/// Фактическое положение каждого стержня, 0-100%. Идёт к цели с конечной скоростью.
	var/list/rod_pos
	/// Куда оператор послал каждый стержень, 0-100%.
	var/list/rod_target
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
	/// 0 - звук тревог включён. Иначе уровень тревоги, при котором звук заглушили: он молчит, пока тревога не станет сильнее или не кончится (ревизия 16).
	var/alarm_mute_level = 0
	/// Табло (ревизия 17, общий класс с ревизии 18): уровни плиток, подтверждения и «первопричина» нового события; ниже прошлое повреждение топлива.
	var/datum/ns_annunciator/annunciator
	var/alarm_last_damage = 0
	/// Повреждение топлива, 0-100% (ревизия 16). Растёт, пока зона горячее NSR_DAMAGE_TEMP, и необратимо. При 100% зона плавится.
	var/core_damage = 0
	/// Течь первичного контура: сосуд лопнул без взрыва (холодный гидравлический разрыв). Вода уходит, пока есть давление. Заваривается сваркой в холодном сосуде без давления.
	var/leaking = FALSE

	/// Привязанные секции корпуса (три штуки). Само ядро тоже секция, его плита учитывается отдельно.
	var/list/sections
	/// TRUE, если броневая плита самого ядра снята.
	var/casing_open = FALSE

	/// Паровой порт на трубах. Если есть, пар и давление берутся оттуда.
	var/obj/machinery/atmospherics/unary/tank/submarine_reactor_steam_port/steam_port
	/// Собственный пар сосуда для режима без порта (запечатанный сосуд).
	var/datum/gas_mixture/vessel_air
	/// Питательный насос на холодной ветке. Если есть, воду подаёт он, а клапан питательной воды-заглушка не работает.
	var/obj/machinery/atmospherics/binary/submarine_feed_pump/feed_pump
	/// Входной порт питательной воды на сосуде. Принимает воду из напорной трубы насоса и сливает её в сосуд.
	var/obj/machinery/atmospherics/unary/tank/submarine_feed_inlet/feed_inlet

	/// Режим двух контуров (ревизия 14): ядро не кипит, греет первичную воду и отдаёт тепло парогенераторам. Включается, когда найден
	/// хотя бы один парогенератор, и остаётся, даже если их потом разорвало (тогда теплоотвода нет, и это авария, а не возврат к котлу).
	var/two_circuit = FALSE
	/// Парогенераторы этого реактора (режим двух контуров).
	var/list/steam_gens
	/// Главный циркуляционный насос первичного контура.
	var/obj/machinery/submarine_primary_pump/primary_pump
	/// Компенсатор давления (ревизия 15). Без него первичное давление постоянное NSR_PRIMARY_PRESSURE и новых аварий нет.
	var/obj/machinery/submarine_pressurizer/pressurizer
	/// Насос подпитки и слива первичного контура (ревизия 15).
	var/obj/machinery/submarine_makeup_pump/makeup_pump
	/// Давление первичного контура, бар.
	var/primary_pressure = NSR_PRIMARY_PRESSURE
	/// Запас первичной воды, % от номинального (100 - полный контур). Убывает через клапан, растёт подпиткой, влияет на уровень в компенсаторе.
	var/primary_inventory = 100
	/// Охлаждение ядра, доля от нормального (1 - норма). Падает, когда давление ниже давления насыщения: вода кипит в ядре.
	var/cooling_eff = 1
	/// Голосовое оповещение о высоком давлении первичного контура уже прозвучало и ждёт, пока давление упадёт (чтобы не повторяться).
	var/pressure_announced = FALSE

/obj/machinery/submarine_reactor_core/Initialize()
	. = ..()
	GLOB.submarine_reactors += src
	annunciator = new /datum/ns_annunciator(nsr_alarm_labels)
	vessel_air = new /datum/gas_mixture(NSR_VESSEL_VOLUME, T0C + NSR_AMBIENT_TEMP)
	rod_pos = list()
	rod_target = list()
	for(var/i in 1 to NSR_ROD_COUNT)
		rod_pos += 0
		rod_target += 0
	steam_gens = list()
	// Привязка деталей откладывается до конца загрузки карты: парогенераторы должны успеть зарегистрироваться, прежде чем ядро решит, в каком оно режиме.
	return INITIALIZE_HINT_LATELOAD

/obj/machinery/submarine_reactor_core/LateInitialize(mapload, ...)
	link_parts()

/// Привязывает всё, что стоит рядом: секции, парогенераторы, паровой порт (только без парогенераторов), питательный насос, вход, главный насос.
/// Возвращает текст для пульта о том, что найдено.
/obj/machinery/submarine_reactor_core/proc/link_parts()
	find_sections()
	find_steam_gens()
	find_steam_port()
	find_feed_pump()
	find_feed_inlet()
	find_primary_pump()
	find_pressurizer()
	find_makeup_pump()
	queue_icon_update()

/// Ищет парогенераторы с той же меткой реактора (расстояние не важно) и привязывает их. Если найден хотя бы один, включает режим двух контуров.
/obj/machinery/submarine_reactor_core/proc/find_steam_gens()
	for(var/obj/machinery/submarine_steam_generator/G in steam_gens)
		G.core = null
	steam_gens = list()
	for(var/obj/machinery/submarine_steam_generator/G in GLOB.submarine_steam_gens)
		if(QDELETED(G) || G.reactor_id != reactor_id)
			continue
		steam_gens += G
		G.core = src
	if(length(steam_gens))
		two_circuit = TRUE
		// Паровые порты в этом режиме принадлежат парогенераторам.
		if(steam_port)
			steam_port.core = null
			steam_port = null
		for(var/obj/machinery/submarine_steam_generator/G in steam_gens)
			G.find_steam_port()
	return length(steam_gens)

/// Ищет главный насос с той же меткой реактора (расстояние не важно). Возвращает TRUE, если найден.
/obj/machinery/submarine_reactor_core/proc/find_primary_pump()
	if(primary_pump)
		primary_pump.core = null
	primary_pump = null
	for(var/obj/machinery/submarine_primary_pump/P in GLOB.submarine_primary_pumps)
		if(QDELETED(P) || P.reactor_id != reactor_id)
			continue
		primary_pump = P
		P.core = src
		break
	return !!primary_pump

/// Ищет компенсатор давления с той же меткой реактора (расстояние не важно). Возвращает TRUE, если найден.
/obj/machinery/submarine_reactor_core/proc/find_pressurizer()
	if(pressurizer)
		pressurizer.core = null
	pressurizer = null
	for(var/obj/machinery/submarine_pressurizer/P in GLOB.submarine_pressurizers)
		if(QDELETED(P) || P.reactor_id != reactor_id)
			continue
		pressurizer = P
		P.core = src
		break
	return !!pressurizer

/// Ищет насос подпитки с той же меткой реактора. Возвращает TRUE, если найден.
/obj/machinery/submarine_reactor_core/proc/find_makeup_pump()
	if(makeup_pump)
		makeup_pump.core = null
	makeup_pump = null
	for(var/obj/machinery/submarine_makeup_pump/P in GLOB.submarine_makeup_pumps)
		if(QDELETED(P) || P.reactor_id != reactor_id)
			continue
		makeup_pump = P
		P.core = src
		break
	return !!makeup_pump

/// Расчётный уровень воды в компенсаторе, %: от запаса воды и от расширения при нагреве. Может выйти за 0..100 (за 100 это «сплошная вода»).
/obj/machinery/submarine_reactor_core/proc/pzr_level_raw()
	return NSR_PZR_LEVEL_NOM + NSR_PZR_LEVEL_PER_INV * (primary_inventory - 100) + NSR_PZR_LEVEL_PER_C * (core_temperature - NSR_PZR_LEVEL_T_REF)

/// Уровень воды в компенсаторе для пульта и тревог, 0-100%.
/obj/machinery/submarine_reactor_core/proc/pzr_level()
	return clamp(pzr_level_raw(), 0, 100)

/// Расход первичной воды, доля от полного (0-1): от оборотов главного насоса, но не меньше естественной циркуляции.
/obj/machinery/submarine_reactor_core/proc/primary_flow()
	var/flow = NSR_NATURAL_CIRC
	if(primary_pump && !QDELETED(primary_pump))
		flow = max(flow, primary_pump.spin / 100)
	return flow

/// Уровень воды, который видит питательный насос, %: в режиме одного контура это сосуд, в режиме двух самый низкий уровень среди целых парогенераторов.
/obj/machinery/submarine_reactor_core/proc/feed_level()
	if(!two_circuit)
		return coolant_level
	var/lowest = 100
	var/found = FALSE
	for(var/obj/machinery/submarine_steam_generator/G in steam_gens)
		if(G.ruptured)
			continue
		found = TRUE
		lowest = min(lowest, G.coolant_level)
	return found ? lowest : 0

/obj/machinery/submarine_reactor_core/Destroy()
	GLOB.submarine_reactors -= src
	for(var/obj/machinery/submarine_reactor_section/S in sections)
		S.core = null
	sections = null
	if(steam_port)
		steam_port.core = null
		steam_port = null
	if(feed_pump)
		feed_pump.core = null
		feed_pump = null
	if(feed_inlet)
		feed_inlet.core = null
		feed_inlet = null
	for(var/obj/machinery/submarine_steam_generator/G in steam_gens)
		G.core = null
	steam_gens = null
	if(primary_pump)
		primary_pump.core = null
		primary_pump = null
	if(pressurizer)
		pressurizer.core = null
		pressurizer = null
	if(makeup_pump)
		makeup_pump.core = null
		makeup_pump = null
	vessel_air = null
	rod_pos = null
	rod_target = null
	return ..()

/// Ищет питательный насос рядом (с той же меткой реактора) и привязывает его. Возвращает TRUE, если насос найден.
/obj/machinery/submarine_reactor_core/proc/find_feed_pump()
	feed_pump = null
	for(var/obj/machinery/atmospherics/binary/submarine_feed_pump/P in range(NSR_SECTION_LINK_RANGE, src))
		if(P.reactor_id != reactor_id)
			continue
		feed_pump = P
		P.core = src
		break
	return !!feed_pump

/// Ищет входной порт питательной воды рядом (с той же меткой реактора) и привязывает его. Возвращает TRUE, если порт найден.
/obj/machinery/submarine_reactor_core/proc/find_feed_inlet()
	feed_inlet = null
	for(var/obj/machinery/atmospherics/unary/tank/submarine_feed_inlet/P in range(NSR_SECTION_LINK_RANGE, src))
		if(P.reactor_id != reactor_id)
			continue
		feed_inlet = P
		P.core = src
		break
	return !!feed_inlet

/// Питательный насос вливает в сосуд воду (в молях). Возвращает, сколько моль влезло.
/obj/machinery/submarine_reactor_core/proc/add_water(moles)
	if(two_circuit)
		// Питательная вода идёт в парогенераторы, поровну по свободному месту.
		var/total_room = 0
		for(var/obj/machinery/submarine_steam_generator/G in steam_gens)
			if(!G.ruptured)
				total_room += (100 - G.coolant_level) * NSR_SG_MOLES_PER_PERCENT
		if(total_room <= 0)
			return 0
		var/given = min(moles, total_room)
		. = 0
		for(var/obj/machinery/submarine_steam_generator/G in steam_gens)
			if(G.ruptured)
				continue
			var/share = given * ((100 - G.coolant_level) * NSR_SG_MOLES_PER_PERCENT) / total_room
			. += G.add_water(share)
		return .
	var/room = (100 - coolant_level) * NSR_MOLES_PER_PERCENT
	var/added = clamp(moles, 0, room)
	coolant_level = min(100, coolant_level + added / NSR_MOLES_PER_PERCENT)
	return added

/// Ищет паровой порт рядом (с той же меткой реактора) и привязывает его. Возвращает TRUE, если порт найден.
/obj/machinery/submarine_reactor_core/proc/find_steam_port()
	steam_port = null
	if(two_circuit)
		return FALSE
	for(var/obj/machinery/atmospherics/unary/tank/submarine_reactor_steam_port/P in range(NSR_SECTION_LINK_RANGE, src))
		if(P.reactor_id != reactor_id)
			continue
		steam_port = P
		P.core = src
		break
	return !!steam_port

/// Газ, в котором живёт пар реактора: газ порта на трубах или собственный газ запечатанного сосуда.
/obj/machinery/submarine_reactor_core/proc/get_steam_air()
	RETURN_TYPE(/datum/gas_mixture)
	if(steam_port && !QDELETED(steam_port) && steam_port.air_contents)
		return steam_port.air_contents
	return vessel_air

/// Ищет секции корпуса рядом и привязывает их к ядру. Возвращает число найденных.
/obj/machinery/submarine_reactor_core/proc/find_sections()
	sections = list()
	for(var/obj/machinery/submarine_reactor_section/S in range(NSR_SECTION_LINK_RANGE, src))
		// Секция уходит к тому ядру, которое к ней ближе: два реактора рядом не путают друг другу корпус.
		if(S.core && S.core != src && !QDELETED(S.core) && get_dist(S, S.core) <= get_dist(S, src))
			continue
		if(S.core && S.core != src && S.core.sections)
			S.core.sections -= S
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
	if(leaking && isWelder(tool))
		return weld_leak(tool, user)
	if(!isWrench(tool))
		return ..()
	if(nsr_wrench_casing(src, user, casing_open))
		casing_open = !casing_open
		queue_icon_update()
	return TRUE

/obj/machinery/submarine_reactor_core/proc/is_dead()
	return ruptured || melted

// --- Управление (вызывается консолью) ---

/// Двигает цель одного стержня (номер от 1 до NSR_ROD_COUNT) или всех сразу (номер 0).
/obj/machinery/submarine_reactor_core/proc/adjust_rod(index, amount)
	if(is_dead() || scrammed)
		return FALSE
	if(!isnum(index) || index < 0 || index > NSR_ROD_COUNT)
		return FALSE
	for(var/i in 1 to NSR_ROD_COUNT)
		if(index == 0 || index == i)
			rod_target[i] = clamp(rod_target[i] + amount, 0, 100)
	update_rod_averages()
	return TRUE

/// Двигает цель всех стержней сразу.
/obj/machinery/submarine_reactor_core/proc/adjust_rods(amount)
	return adjust_rod(0, amount)

/// Пересчитывает средние значения по стержням.
/obj/machinery/submarine_reactor_core/proc/update_rod_averages()
	var/pos_sum = 0
	var/target_sum = 0
	for(var/i in 1 to NSR_ROD_COUNT)
		pos_sum += rod_pos[i]
		target_sum += rod_target[i]
	rods_pos = pos_sum / NSR_ROD_COUNT
	rods_target = target_sum / NSR_ROD_COUNT

/// Мгновенно обнуляет все стержни. Только для катастроф, в обычной работе стержни идут с конечной скоростью.
/obj/machinery/submarine_reactor_core/proc/zero_rods()
	for(var/i in 1 to NSR_ROD_COUNT)
		rod_pos[i] = 0
		rod_target[i] = 0
	rods_pos = 0
	rods_target = 0

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
	for(var/i in 1 to NSR_ROD_COUNT)
		rod_target[i] = 0
	update_rod_averages()
	playsound(src, NS_SND_SCRAM, 60, FALSE)
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

	if(two_circuit)
		// В режиме двух контуров давление пара рвёт парогенератор, а давление первичного контура (если есть компенсатор) рвёт сосуд реактора.
		for(var/obj/machinery/submarine_steam_generator/G in steam_gens.Copy())
			if(!QDELETED(G) && !G.ruptured && G.steam_pressure >= NSR_PRESSURE_BURST)
				G.rupture()
		// Давление разрыва падает, когда сосуд горячий: горячий металл слабее (ревизия 16).
		if(pressurizer && primary_pressure >= vessel_burst_pressure())
			if(vessel_failure())
				return
	else if(steam_pressure >= NSR_PRESSURE_BURST)
		rupture()
		return
	// Расплав это не порог температуры, а накопленное повреждение топлива (ревизия 16).
	update_damage(dt)
	if(core_damage >= 100)
		meltdown()
		return

	update_alarm()
	emit_radiation()

/// Двигает каждый стержень к его цели с конечной скоростью. При SCRAM скорость выше, но не бесконечная.
/obj/machinery/submarine_reactor_core/proc/move_rods(dt)
	var/was_up = rods_pos > 0
	var/step = (scrammed ? NSR_ROD_SPEED_SCRAM : NSR_ROD_SPEED) * dt
	for(var/i in 1 to NSR_ROD_COUNT)
		var/pos = rod_pos[i]
		var/target = rod_target[i]
		if(pos < target)
			rod_pos[i] = min(pos + step, target)
		else if(pos > target)
			rod_pos[i] = max(pos - step, target)
	update_rod_averages()
	// Значок зависит только от того, стоят ли стержни в нуле, поэтому обновляем его не каждый тик.
	if(was_up != (rods_pos > 0))
		queue_icon_update()

/// Один шаг физики. dt - длительность шага в секундах.
/obj/machinery/submarine_reactor_core/proc/simulate(dt)
	move_rods(dt)
	var/datum/gas_mixture/steam_air = get_steam_air()
	var/pressure_bar = steam_air.return_pressure() / NSR_KPA_PER_BAR

	var/rods_frac = rods_pos / 100
	var/coolant_frac = coolant_level / 100

	// Остаточное тепло: стремится к доле от мощности стержней, копится быстро, спадает медленно. SCRAM останавливает деление,
	// но не его осколки: после остановки зона ещё долго греется и кипит воду, поэтому охлаждение нужно и после SCRAM.
	var/decay_target = NSR_DECAY_FRACTION * rods_frac
	var/decay_tau = (decay_heat < decay_target) ? NSR_DECAY_BUILD_TAU : NSR_DECAY_TAU
	decay_heat += (decay_target - decay_heat) * min(1, dt / decay_tau)
	if(decay_heat < 0.0005 && decay_target <= 0)
		decay_heat = 0
	// Сразу после подъёма стержней идёт (1 - доля) мощности, остальное набегает с NSR_DECAY_BUILD_TAU. На устойчивом режиме сумма равна rods_frac,
	// поэтому пар при 100% стержней не превышает ёмкость конденсатора, как до ревизии 13.
	var/heat_in = ((1 - NSR_DECAY_FRACTION) * rods_frac + decay_heat) * NSR_MAX_HEAT_RATE
	var/heat_cap = NSR_CORE_HEAT_CAP + coolant_frac * NSR_COOLANT_HEAT_CAP
	var/heat_loss = max(0, core_temperature - NSR_AMBIENT_TEMP) * NSR_PASSIVE_LOSS

	if(two_circuit)
		// Два контура: ядро не кипит. Оно греет первичную воду, а тепло забирают парогенераторы (расход от главного насоса или естественный).
		// Давление ниже давления насыщения: вода кипит в ядре, паровая плёнка мешает теплоотдаче (расход падает).
		cooling_eff = primary_cooling_eff()
		var/flow = primary_flow() * cooling_eff
		var/heat_out = 0
		var/pressure_max = 0
		steam_flow = 0
		for(var/obj/machinery/submarine_steam_generator/G in steam_gens)
			heat_out += G.transfer_heat(core_temperature, flow, dt)
			steam_flow += G.steam_flow
			pressure_max = max(pressure_max, G.steam_pressure)
		// Первичный контур всегда считается полным: его запас воды и давление ведёт компенсатор (update_primary).
		coolant_level = 100
		var/prev_temp = core_temperature
		core_temperature += (heat_in - heat_loss - heat_out) * dt / (NSR_CORE_HEAT_CAP + NSR_PRIMARY_HEAT_CAP)
		core_temperature = max(core_temperature, NSR_AMBIENT_TEMP)
		update_primary(dt, core_temperature - prev_temp)
		// Течи трубок парогенераторов уносят воду первичного контура во вторичный (ревизия 17).
		for(var/obj/machinery/submarine_steam_generator/G in steam_gens)
			primary_inventory = max(0, primary_inventory - G.update_tubes(primary_pressure, core_temperature, dt))
		// Питательная заглушка и клапан пара в этом режиме не работают: воду подаёт насос, пар идёт в трубы парогенераторов.
		steam_pressure = pressure_max
		return

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

	// Питательная вода (заглушка). Если стоит питательный насос, воду подаёт он, и заглушка не работает.
	if(!feed_pump)
		coolant_level = min(100, coolant_level + (feedwater_valve / 100) * NSR_FEEDWATER_MAX * dt)

	// Режим без порта: клапан пара стравливает часть пара в никуда (заглушка).
	if(!steam_port)
		var/vent_ratio = (steam_valve / 100) * NSR_STEAM_VENT_COEF * dt
		if(vent_ratio > 0)
			steam_air.remove_ratio(vent_ratio)

	steam_pressure = steam_air.return_pressure() / NSR_KPA_PER_BAR

/// Охлаждение ядра как доля от нормального: 1, пока давление первичного контура выше давления насыщения воды при температуре ядра.
/// Если давление упало ниже, вода кипит в ядре и охлаждение падает до NSR_VOID_MIN (вторая сторона аварии «потеря давления»).
/// Если воды в контуре меньше NSR_INV_COVER процентов, охлаждение падает ещё и пропорционально остатку воды. Без компенсатора всегда 1.
/obj/machinery/submarine_reactor_core/proc/primary_cooling_eff()
	if(!pressurizer || QDELETED(pressurizer))
		return 1
	var/saturation = nsr_saturation_pressure(core_temperature)
	var/deficit = saturation - primary_pressure
	var/eff = 1
	if(deficit > 0)
		eff = max(NSR_VOID_MIN, 1 - NSR_VOID_SLOPE * deficit / saturation)
	// Когда воды в контуре почти не осталось, зона обнажается: охлаждение падает пропорционально, при пустом контуре его нет (ревизия 16).
	if(primary_inventory < NSR_INV_COVER)
		eff *= clamp(primary_inventory / NSR_INV_COVER, 0, 1)
	return eff

/// Один шаг давления и запаса воды первичного контура. delta_temp: на сколько C изменилась температура ядра за этот шаг.
/// Давление складывается из: расширения воды (нагрев сжимает паровой пузырь), нагревателей, впрыска, потерь тепла компенсатором,
/// предохранительного клапана и «сплошной воды» (уровень выше NSR_PZR_SOLID_LEVEL). Запас воды: подпитка и слив, клапан.
/// Без компенсатора давление постоянное NSR_PRIMARY_PRESSURE.
/obj/machinery/submarine_reactor_core/proc/update_primary(dt, delta_temp)
	if(!pressurizer || QDELETED(pressurizer))
		primary_pressure = NSR_PRIMARY_PRESSURE
		return
	var/obj/machinery/submarine_pressurizer/pz = pressurizer
	var/level_raw = pzr_level_raw()
	var/flow = primary_flow()
	var/pressure_change = NSR_PRIMARY_SWELL * delta_temp
	if(level_raw >= NSR_PZR_SOLID_LEVEL)
		// Парового пузыря нет: вода несжимаема, давление скачет и от нагрева, и от каждого лишнего процента.
		pressure_change *= NSR_PZR_SOLID_SWELL_MULT
		pressure_change += NSR_PZR_SOLID_GAIN * (level_raw - NSR_PZR_SOLID_LEVEL) * dt
	else if(level_raw <= 0)
		pressure_change -= NSR_PZR_EMPTY_DECAY * dt
	if(pz.auto)
		pz.run_auto(primary_pressure, dt)
	pressure_change += NSR_PZR_HEAT_RATE * pz.update_heating(level_raw) * dt
	pressure_change -= NSR_PZR_SPRAY_RATE * (pz.spray / 100) * flow * dt
	pressure_change -= (primary_pressure - 1) * NSR_PRIMARY_LOSS * dt
	if(pz.update_relief(primary_pressure))
		pressure_change -= NSR_PZR_RELIEF_RATE * dt
		primary_inventory -= NSR_PZR_RELIEF_DRAIN * dt
	if(leaking)
		// Течь в сосуде: чем выше давление, тем сильнее уходит вода и тем быстрее падает давление.
		pressure_change -= (primary_pressure - 1) * NSR_LEAK_LOSS * dt
		primary_inventory -= NSR_LEAK_DRAIN * (primary_pressure - 1) / NSR_PRIMARY_PRESSURE * dt
	if(makeup_pump && !QDELETED(makeup_pump))
		primary_inventory += (makeup_pump.flow / 100) * NSR_MAKEUP_RATE * dt
	primary_inventory = clamp(primary_inventory, 0, 150)
	primary_pressure = clamp(primary_pressure + pressure_change, 1, 400)

/// Уровень каждой плитки табло (id из nsr_alarm_labels): 0 норма, 1 предупреждение, 2 критично.
/obj/machinery/submarine_reactor_core/proc/compute_alarm_tiles()
	var/list/tiles = annunciator.blank()
	// Нехватка воды и низкие значения важны только когда реактор греется или греет.
	var/hot = (rods_pos > 0 || core_temperature > NSR_BOIL_TEMP)
	tiles["temp"] = nsr_high_level(core_temperature, NSR_TEMP_WARN, NSR_TEMP_CRIT)
	tiles["steam"] = nsr_high_level(steam_pressure, NSR_PRESSURE_WARN, NSR_PRESSURE_CRIT)
	// В режиме двух контуров вода, которой может не хватить, это вода парогенераторов (самая низкая).
	var/water_level = feed_level()
	if(hot)
		if(water_level < NSR_COOLANT_CRIT)
			tiles["water"] = 2
		else if(water_level < NSR_COOLANT_WARN)
			tiles["water"] = 1
	if(two_circuit)
		if(pressurizer)
			var/pzr_now = pzr_level()
			tiles["ppress_hi"] = nsr_high_level(primary_pressure, NSR_PRIMARY_WARN_HIGH, NSR_PRIMARY_CRIT_HIGH)
			tiles["plevel_hi"] = nsr_high_level(pzr_now, NSR_PZR_LEVEL_WARN_HIGH, NSR_PZR_LEVEL_CRIT_HIGH)
			if(hot)
				tiles["ppress_lo"] = nsr_low_level(primary_pressure, NSR_PRIMARY_WARN_LOW, NSR_PRIMARY_CRIT_LOW)
				tiles["plevel_lo"] = nsr_low_level(pzr_now, NSR_PZR_LEVEL_WARN_LOW, NSR_PZR_LEVEL_CRIT_LOW)
		if(hot)
			if(cooling_eff < 0.5)
				tiles["cooling"] = 2
			else if(cooling_eff < 0.9)
				tiles["cooling"] = 1
		var/sg_level = 0
		var/valve_closed = FALSE
		for(var/obj/machinery/submarine_steam_generator/G in steam_gens)
			if(G.ruptured || G.tube_leak)
				sg_level = 2
			else if(G.tube_damage >= NSR_TUBE_WARN)
				sg_level = max(sg_level, 1)
			if(G.steam_valve_closed && !G.ruptured)
				valve_closed = TRUE
		tiles["sg"] = sg_level
		// Закрытый клапан это решение оператора: плитка горит, но сирену не включает.
		if(valve_closed && rods_pos > 0)
			tiles["valve"] = 1
		if(primary_pump && !QDELETED(primary_pump))
			if(primary_pump.seized)
				tiles["pump"] = hot ? 2 : 1
			else if(primary_pump.wear >= NSR_PPUMP_WEAR_WARN)
				tiles["pump"] = 1
	// Повреждённое топливо остаётся на табло навсегда; сирену оно включает только пока растёт.
	if(core_damage >= NSR_DAMAGE_CRIT)
		tiles["damage"] = 2
	else if(core_damage >= NSR_DAMAGE_WARN)
		tiles["damage"] = 1
	if(leaking)
		tiles["leak"] = hot ? 2 : 1
	return tiles

/// Подтвердить все горящие плитки (мигание прекращается) и заглушить сирену до ухудшения (кнопка на пульте).
/obj/machinery/submarine_reactor_core/proc/acknowledge_alarms()
	annunciator.acknowledge()
	if(alarm_level > 0)
		alarm_mute_level = alarm_level

/// Есть ли горящая плитка, которую ещё не подтвердили (она мигает).
/obj/machinery/submarine_reactor_core/proc/has_unacked_alarm()
	return annunciator.has_unacked()

/obj/machinery/submarine_reactor_core/proc/update_alarm()
	var/list/tiles = compute_alarm_tiles()
	var/damage_rising = core_damage > alarm_last_damage + 0.001
	alarm_last_damage = core_damage
	// Уровень сирены: худшая плитка, кроме информационных (закрытый клапан; повреждение топлива, пока оно не растёт).
	var/new_level = 0
	for(var/id in tiles)
		if(id == "valve" || (id == "damage" && !damage_rising))
			continue
		new_level = max(new_level, tiles[id])
	// Табло: подтверждение, «первопричина» и мигание ведёт общий класс.
	annunciator.update(tiles)

	// Голосовое оповещение на всю лодку о высоком давлении первичного контура: один раз за превышение, снова только после того,
	// как давление упало хотя бы на NSR_ANNOUNCE_REARM бар ниже порога. Сигнал на пультах звучит как обычно, голос не повторяется.
	if(two_circuit && pressurizer)
		if(primary_pressure >= NSR_PRIMARY_WARN_HIGH)
			if(!pressure_announced)
				pressure_announced = TRUE
				ns_announce(NS_ANN_PRIMARY_PRESSURE)
		else if(primary_pressure < NSR_PRIMARY_WARN_HIGH - NSR_ANNOUNCE_REARM)
			pressure_announced = FALSE

	// Заглушенный звук возвращается, когда тревога стала сильнее, чем была при заглушке. Если она ослабла, порог заглушки опускается вместе с ней,
	// поэтому новое ухудшение после улучшения снова зазвучит. Когда тревога кончилась совсем, звук включается сам.
	if(alarm_mute_level)
		if(new_level < alarm_mute_level)
			alarm_mute_level = new_level
		else if(new_level > alarm_mute_level)
			alarm_mute_level = 0
	var/muted = alarm_mute_level > 0
	if(new_level > alarm_level && !muted)
		sound_alarm(NS_SND_ALARM_WARN, 60, TRUE)
	if(new_level >= 2 && !muted && world.time >= next_alarm_time)
		sound_alarm(NS_SND_ALARM_CRIT, 70)
		next_alarm_time = world.time + NSR_ALARM_REPEAT
	alarm_level = new_level

/// Сигнал тревоги звучит на пультах БЩУ этого реактора, а не у самого реактора.
/// Если у реактора нет ни одного пульта, сигнал звучит у ядра, чтобы авария не прошла молча.
/obj/machinery/submarine_reactor_core/proc/sound_alarm(alarm_sound, volume, announce = FALSE)
	var/heard = FALSE
	for(var/obj/machinery/computer/submarine_reactor_console/C in GLOB.submarine_reactor_consoles)
		if(QDELETED(C) || C.reactor_id != reactor_id)
			continue
		heard = TRUE
		playsound(C, alarm_sound, volume, FALSE)
		if(announce)
			C.audible_message(SPAN_WARNING("\The [C] emits a warning tone."))
	if(!heard)
		playsound(src, alarm_sound, volume, FALSE)
		if(announce)
			audible_message(SPAN_WARNING("\The [src] emits a warning tone."))

/obj/machinery/submarine_reactor_core/proc/emit_radiation()
	// Заражённые парогенераторы фонят сами по себе (ревизия 17).
	if(two_circuit && steam_gens)
		for(var/obj/machinery/submarine_steam_generator/G in steam_gens)
			G.emit_contamination()
	var/rads = (rods_pos / 100) * NSR_RADS_RUNNING_MAX + (decay_heat / NSR_DECAY_FRACTION) * NSR_RADS_DECAY_MAX
	// Повреждённое топливо фонит и без работы: продукты деления в теплоносителе. Течь первичного контура фонит, пока в нём есть давление.
	rads += (core_damage / 100) * NSR_RADS_DAMAGE_MAX
	if(leaking)
		rads += NSR_RADS_LEAK * clamp((primary_pressure - 1) / NSR_PRIMARY_PRESSURE, 0, 1)
	if(rads <= 0.01)
		return
	if(count_open_casings())
		rads *= NSR_RADS_OPEN_CASING_MULT
	SSradiation.radiate(src, rads)

// --- Катастрофы (ревизия 16: «по-честному») ---
// Исход зависит от состояния в момент отказа, а не от того, какой порог перешагнули: давление, температура, вода и пузырь в компенсаторе
// вместе дают энергию взрыва (blast_energy), а радиус взрыва растёт с кубическим корнем энергии.
//  - горячий сосуд лопнул под давлением: вода разом вскипает, большой взрыв;
//  - холодный сосуд лопнул под давлением: вода почти несжимаема, взрыва нет, только течь (leaking);
//  - зона расплавилась при воде и давлении: паровой взрыв расплава; при потерянной воде и давлении: тихий расплав без взрыва.

/// Накопление повреждения топлива. Скорость растёт с квадратом превышения температуры над NSR_DAMAGE_TEMP, при NSR_MELTDOWN_TEMP это NSR_DAMAGE_RATE процентов в секунду.
/// Повреждение необратимо: остыв, зона остаётся повреждённой и фонит.
/obj/machinery/submarine_reactor_core/proc/update_damage(dt)
	if(core_temperature <= NSR_DAMAGE_TEMP || core_damage >= 100)
		return
	var/excess = (core_temperature - NSR_DAMAGE_TEMP) / (NSR_MELTDOWN_TEMP - NSR_DAMAGE_TEMP)
	core_damage = min(100, core_damage + NSR_DAMAGE_RATE * excess * excess * dt)

/// Давление, при котором рвётся сосуд первичного контура. Выше NSR_BURST_DERATE_TEMP горячий металл слабеет, и оно падает.
/obj/machinery/submarine_reactor_core/proc/vessel_burst_pressure()
	return NSR_PRIMARY_BURST * clamp(1 - max(0, core_temperature - NSR_BURST_DERATE_TEMP) / NSR_BURST_DERATE_SPAN, NSR_BURST_DERATE_MIN, 1)

/// Энергия взрыва в МДж, если сосуд лопнет или зона упадёт в воду прямо сейчас. yield_: какая доля тепла жидкой воды идёт во взрыв.
/// Газовый пузырь даёт энергию по давлению (в «сплошной воде» его нет), перегретая вода даёт её вскипанием. Вода, уже ставшая паром, как жидкость не считается.
/obj/machinery/submarine_reactor_core/proc/blast_energy(yield_)
	var/gas = 0
	var/flash = 0
	if(two_circuit)
		var/bubble = NSR_PZR_GAS_M3 * 0.5
		if(pressurizer && !QDELETED(pressurizer))
			bubble = NSR_PZR_GAS_M3 * (100 - pzr_level()) / 100
		gas = NSR_BLAST_BAR_M3 * max(0, primary_pressure - 1) * bubble
		var/liquid = clamp(primary_pressure / max(nsr_saturation_pressure(core_temperature), 1), 0, 1)
		flash = yield_ * NSR_PRIMARY_KG_PER_PERCENT * primary_inventory * NSR_WATER_MJ_PER_KG_C * max(0, core_temperature - NSR_BOIL_TEMP) * liquid
	else
		gas = NSR_BLAST_BAR_M3 * max(0, steam_pressure - 1) * (NSR_VESSEL_VOLUME / 1000)
		var/boil_point = NSR_BOIL_TEMP + steam_pressure * NSR_BOIL_TEMP_PER_BAR
		flash = yield_ * NSR_VESSEL_KG_PER_PERCENT * coolant_level * NSR_WATER_MJ_PER_KG_C * max(0, boil_point - NSR_BOIL_TEMP)
	return gas + flash

/// Энергия, при которой взрыв сосуда имеет эталонный радиус NSR_RUPTURE_RANGE. Режим одного контура рвёт только пар, поэтому там эталон меньше.
/obj/machinery/submarine_reactor_core/proc/blast_reference()
	return two_circuit ? NSR_RUPTURE_ENERGY_REF : NSR_SG_ENERGY_REF

/// Давление первичного контура достигло давления разрыва. Если энергии на взрыв хватает, сосуд рвётся (rupture), иначе (холодный, без пузыря) он только даёт течь.
/// Возвращает TRUE, если сосуд разорван и реактор потерян.
/obj/machinery/submarine_reactor_core/proc/vessel_failure()
	if(blast_energy(NSR_BLAST_FLASH_YIELD) < NSR_BLAST_MIN)
		start_leak()
		return FALSE
	rupture()
	return TRUE

/// Гидравлический разрыв: трещина в сосуде, взрыва нет. Давление резко падает, вода уходит, пока есть давление.
/obj/machinery/submarine_reactor_core/proc/start_leak()
	if(leaking)
		return
	leaking = TRUE
	primary_pressure = max(1, primary_pressure * 0.6)
	visible_message(SPAN_DANGER("\The [src] cracks with a bang, and water sprays from the vessel under pressure!"))
	playsound(src, NS_SND_RELIEF, 80, TRUE)
	sound_alarm(NS_SND_TRIP, 80)

/// Сварка трещины. Заварить можно холодный сосуд без давления.
/obj/machinery/submarine_reactor_core/proc/weld_leak(obj/item/tool, mob/living/user)
	if(core_temperature > NSR_LEAK_REPAIR_TEMP || primary_pressure > NSR_LEAK_REPAIR_PRESSURE)
		to_chat(user, SPAN_WARNING("The crack is too hot and under too much pressure to weld. Let the vessel cool below [NSR_LEAK_REPAIR_TEMP] C and drop below [NSR_LEAK_REPAIR_PRESSURE] bar first."))
		return TRUE
	var/obj/item/weldingtool/welder = tool
	if(!welder.remove_fuel(3, user))
		return TRUE
	user.visible_message(SPAN_NOTICE("\The [user] starts welding the crack in \the [src]."))
	playsound(src, NS_SND_WELD, 50, TRUE)
	if(!do_after(user, NSR_LEAK_WELD_TIME, src) || !leaking)
		return TRUE
	if(core_temperature > NSR_LEAK_REPAIR_TEMP || primary_pressure > NSR_LEAK_REPAIR_PRESSURE)
		return TRUE
	leaking = FALSE
	user.visible_message(SPAN_NOTICE("\The [user] welds the crack in \the [src] shut."))
	playsound(src, NS_SND_BUILT, 50, TRUE)
	return TRUE

/// Взрыв от давления. Рвёт сосуд и всё вокруг; радиус по энергии (blast_energy): горячий контур даёт эталонный NSR_RUPTURE_RANGE, пустой и холодный меньше.
/// Батареи должны стоять дальше (вопрос карты).
/obj/machinery/submarine_reactor_core/proc/rupture()
	var/blast_range = nsr_blast_range(blast_energy(NSR_BLAST_FLASH_YIELD), blast_reference(), NSR_RUPTURE_RANGE)
	ruptured = TRUE
	zero_rods()
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
	explosion(here, blast_range)

/// Расплав: повреждение топлива дошло до 100%. Если в этот момент вокруг есть вода и давление, расплав падает в воду и она вскипает разом (паровой взрыв,
/// сила по blast_energy). Если воды или давления нет (потеря теплоносителя), расплав тихий, но зона остаётся радиоактивной навсегда.
/obj/machinery/submarine_reactor_core/proc/meltdown()
	var/energy = blast_energy(NSR_BLAST_FCI_YIELD)
	var/blast_range = nsr_blast_range(energy, blast_reference(), NSR_RUPTURE_RANGE)
	melted = TRUE
	core_damage = 100
	zero_rods()
	queue_icon_update()
	sound_alarm(NS_SND_TRIP, 100)
	if(energy < NSR_BLAST_MIN)
		visible_message(SPAN_DANGER("\The [src] collapses into a glowing molten mass!"))
		return
	visible_message(SPAN_DANGER("\The [src] collapses into a molten mass, and the water around it flashes into steam in one blast!"))
	var/turf/here = get_turf(src)
	if(here)
		explosion(here, blast_range)

// --- Текст для пульта ---

/obj/machinery/submarine_reactor_core/proc/get_status_text()
	if(melted)
		return "CORE MELTDOWN"
	if(ruptured)
		return "VESSEL RUPTURED"
	if(leaking)
		return "PRIMARY LEAK"
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
	if(is_dead() || leaking || alarm_level >= 2)
		return "bad"
	if(alarm_level >= 1)
		return "average"
	return "good"

/obj/machinery/submarine_reactor_core/on_update_icon()
	ClearOverlays()
	// Временная индикация: со снятой бронёй ядро полупрозрачно.
	alpha = casing_open ? 150 : 255
	desc = casing_open ? "The core's armour plate is off. The control rod drives, the fuel channels and the coolant pipes of the vessel are bare, and the radiation is much stronger here. Bolt the plate back on with a wrench." : initial(desc)
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
	/// Парогенератор, которому принадлежит порт (режим двух контуров). Тогда core пуст.
	var/obj/machinery/submarine_steam_generator/sg

/obj/machinery/atmospherics/unary/tank/submarine_reactor_steam_port/Destroy()
	if(core)
		core.steam_port = null
	core = null
	if(sg)
		sg.steam_port = null
	sg = null
	return ..()

/obj/machinery/atmospherics/unary/tank/submarine_reactor_steam_port/use_tool(obj/item/tool, mob/living/user, list/click_params)
	// Порт приварен к сосуду: отвернуть его, как обычный бак, нельзя.
	if(isWrench(tool))
		to_chat(user, SPAN_WARNING("\The [src] is welded to the reactor vessel."))
		return TRUE
	return ..()

// ----------------------------------------------------------------------------
// ВОДА КОНТУРА (ревизия 7)
// ----------------------------------------------------------------------------

/// Вода за конденсатором и в напорной трубе. В этом Бэе по трубам ходят только газы, жидкости в них нет, поэтому это
/// отдельное газоподобное вещество, но именно ВОДА, а не пар: называется Water, не рисует облаков и не кипит.
/// Конденсируется в зоне ZAS при любой температуре, так что любая утечка сразу даёт настоящую лужу.
/// Объём и давление в трубах считаются по моли, как у всех газов (баланс контура тот же, что был с холодным паром).
/singleton/xgm_gas/submarine_water
	id = GAS_LIQUID_WATER
	name = "Water"
	specific_heat = 75 // J/(mol*K)
	molar_mass = 0.018 // kg/mol
	breathed_product = /datum/reagent/water
	condensation_point = INFINITY
	condensation_product = /datum/reagent/water
	hidden_from_codex = TRUE
	symbol_html = "H<sub>2</sub>O"
	symbol = "H2O"

// ----------------------------------------------------------------------------
// ВОДЯНАЯ ТРУБА (этап 3б)
// ----------------------------------------------------------------------------

/// Труба для воды контура: от конденсатора до питательного насоса и от насоса до входного порта. Своего типа соединения (CONNECT_TYPE_WATER), поэтому
/// к паровым трубам не стыкуется. Внутри счёт в молях вещества Water (GAS_LIQUID_WATER, не пар). Если труба лопнула или с неё сняли
/// соседа, вода вытекает в помещение и сразу конденсируется в лужи (ZAS), то есть утечка воды это лужа, без облака пара.
/// Свой спрайт подменит цвет: пока обычный спрайт трубы, окрашенный в голубой.
/obj/machinery/atmospherics/pipe/simple/visible/submarine_water
	name = "water pipe"
	desc = "A one meter section of pipe carrying water."
	connect_types = CONNECT_TYPE_WATER
	color = PIPE_COLOR_CYAN

/// Утечка только наружу. Стоковая труба с открытым концом выравнивает газ с помещением в обе стороны и «вдыхает» воздух.
/// В воде воздуха быть не должно, поэтому здесь из трубы может только вытекать: чем выше давление воды над давлением
/// в помещении, тем больше уходит за тик, но не меньше NSR_WATER_DRAIN_MIN: вода под своим весом всё равно вытекает, труба опустеет.
/// Воздух помещения труба не берёт никогда.
/obj/machinery/atmospherics/pipe/simple/visible/submarine_water/Process()
	if(!parent)
		return ..()
	if(!leaking)
		return PROCESS_KILL
	var/turf/T = loc
	var/datum/gas_mixture/pipe_air = parent.air
	if(!istype(T) || !pipe_air || pipe_air.volume <= 0)
		return
	var/pipe_pressure = pipe_air.return_pressure()
	if(pipe_pressure > 0)
		var/datum/gas_mixture/room_air = T.return_air()
		var/out_ratio = clamp(1 - room_air.return_pressure() / pipe_pressure, NSR_WATER_DRAIN_MIN, 1)
		if(out_ratio > 0)
			var/datum/gas_mixture/leaked = pipe_air.remove_ratio(out_ratio * min(1, volume / pipe_air.volume))
			if(leaked)
				T.assume_air(leaked)
			if(parent.network)
				parent.network.update = 1
	var/has_water = pipe_air.return_pressure() > 1 // кПа: шипение утечки пока в трубе остаётся заметное давление
	if(!sound_token && has_water)
		update_sound(1)
	else if(sound_token && !has_water)
		update_sound(0)

// ----------------------------------------------------------------------------
// КОНДЕНСАТОР (этап 3б)
// ----------------------------------------------------------------------------

/// Конденсатор пара. Двухпортовое устройство на трубах: пар входит с тыла (паровая труба), вода выходит вперёд (по dir,
/// водяная труба). Холодит забортной водой, поэтому питания не требует. Принимает не больше NSR_CONDENSER_CAPACITY моль пара
/// в секунду при мощности cooling 100% (мощность задают с пульта турбины, метка turbine_id). Сколько пара он не успел принять,
/// копится в трубах, и давление перед ним растёт. Конденсирует пар из ВСЕЙ паровой сети, а не только из своего объёма.
/obj/machinery/atmospherics/binary/submarine_condenser
	name = "steam condenser"
	desc = "Cools steam against the cold sea outside the hull and turns it back into water. Steam enters at the back."
	// Временно: спрайт насоса из стока, окрашенный в голубой. Заменить своим.
	icon = 'icons/atmos/pump.dmi'
	icon_state = "off"
	color = "#6fb7d9"
	level = ATOM_LEVEL_OVER_TILE
	use_power = POWER_USE_OFF
	uncreated_component_parts = null
	// С одной стороны паровая труба, с другой водяная. Какая где, решает только карта: код этого не проверяет.
	connect_types = CONNECT_TYPE_REGULAR | CONNECT_TYPE_WATER
	/// Метка турбины, пульт которой управляет этим конденсатором. Должна совпадать с turbine_id турбины.
	var/turbine_id = "main"
	/// Мощность охлаждения, 0-100%.
	var/cooling = 100
	/// Сколько пара принято за последний тик, моль/с.
	var/last_flow = 0
	/// Автоматика: если включена, мощностью охлаждения управляет регулятор, который держит давление пара перед конденсатором. По умолчанию выключена.
	var/auto = FALSE
	/// Давление пара перед конденсатором, которое держит автоматика, бар.
	var/auto_set = NSR_COND_AUTO_SET
	/// Интегральная часть регулятора, % охлаждения.
	var/auto_i = 0
	/// Сглаженное давление пара перед конденсатором, бар.
	var/auto_pressure = 0

/obj/machinery/atmospherics/binary/submarine_condenser/Initialize()
	. = ..()
	air1.volume = NSR_CONDENSER_VOLUME
	air2.volume = NSR_CONDENSER_VOLUME
	GLOB.submarine_condensers += src

/obj/machinery/atmospherics/binary/submarine_condenser/Destroy()
	GLOB.submarine_condensers -= src
	return ..()

/obj/machinery/atmospherics/binary/submarine_condenser/update_underlays()
	if(..())
		underlays.Cut()
		var/turf/T = get_turf(src)
		if(!istype(T))
			return
		add_underlay(T, node1, turn(dir, -180))
		add_underlay(T, node2, dir)

/obj/machinery/atmospherics/binary/submarine_condenser/hide(i)
	update_underlays()

/// Автоматика конденсатора: ПИ-регулятор держит давление пара перед конденсатором на уставке auto_set, меняя мощность охлаждения (cooling).
/// Давление сглаживается: пар приходит порциями. Если давление выше уставки, охлаждение растёт, если ниже, падает до нуля и пар копится.
/// Позже эту автоматику переведём в серверную (см. GDD), логика останется.
/obj/machinery/atmospherics/binary/submarine_condenser/proc/run_auto(dt)
	var/pressure = air1.return_pressure() / NSR_KPA_PER_BAR
	auto_pressure += (pressure - auto_pressure) * min(1, dt / NSR_COND_AUTO_FILTER)
	var/error = auto_pressure - auto_set
	auto_i = clamp(auto_i + NSR_COND_AUTO_KI * error * dt, 0, 100)
	cooling = clamp(auto_i + NSR_COND_AUTO_KP * error, 0, 100)

/// Включает и выключает автоматику. При включении регулятор подхватывает текущую мощность без рывка, при выключении мощность остаётся как есть.
/obj/machinery/atmospherics/binary/submarine_condenser/proc/toggle_auto()
	auto = !auto
	auto_i = cooling
	auto_pressure = air1.return_pressure() / NSR_KPA_PER_BAR

/obj/machinery/atmospherics/binary/submarine_condenser/Process(wait)
	. = ..()
	last_flow = 0
	if(!network1 || !network2)
		return
	var/dt = 2
	if(wait > 0)
		dt = clamp(wait / 10, 0.5, 5)
	if(auto)
		run_auto(dt)
	// Конденсируется только пар. Прочие газы (воздух, попавший в паровую ветку) остаются на паровой стороне,
	// так что в водяной ветке газов не бывает.
	var/capacity = NSR_CONDENSER_CAPACITY * clamp(cooling, 0, 100) / 100 * dt
	if(capacity <= 0)
		return
	// Пар берётся из всей паровой сети, а не только из объёма самого конденсатора: иначе он принимал бы лишь долю сети за такт.
	var/moved = nst_network_remove_gas(network1, GAS_STEAM, capacity)
	if(moved <= 0)
		return
	// Пар превращается в воду (другое вещество), моль в моль. Тепло уходит в океан: на выходе вода имеет температуру забортной воды.
	air2.adjust_gas_temp(GAS_LIQUID_WATER, moved, NSR_CONDENSER_OUT_TEMP)
	last_flow = moved / dt
	network2.update = 1

// ----------------------------------------------------------------------------
// ПИТАТЕЛЬНЫЙ НАСОС (этап 3б)
// ----------------------------------------------------------------------------

/// Питательный насос. Двухпортовое устройство на водяной ветке: с тыла (против dir) всасывает воду, вперёд (по dir) качает её
/// по водяной трубе к входному порту на сосуде. Стоит рядом с ядром (в радиусе NSR_SECTION_LINK_RANGE).
/// Подача падает с ростом давления в сосуде и доходит до нуля при NSR_FEED_PUMP_HEAD. Нужно электропитание: без него насос стоит.
/// Питание берётся из щитка зоны через стандартную деталь (uncreated_component_parts по умолчанию), блэкаут его останавливает.
/obj/machinery/atmospherics/binary/submarine_feed_pump
	name = "reactor feedwater pump"
	desc = "Pushes water through the pipe to the reactor vessel against the steam pressure. It needs electric power."
	// Временно: спрайт насоса из стока, окрашенный в синий. Заменить своим.
	icon = 'icons/atmos/pump.dmi'
	icon_state = "off"
	color = "#3f6f9f"
	level = ATOM_LEVEL_OVER_TILE
	// Подключается только к водяным трубам.
	connect_types = CONNECT_TYPE_WATER
	/// Метка реактора, в который качает насос. Должна совпадать с reactor_id ядра.
	var/reactor_id = "main"
	var/obj/machinery/submarine_reactor_core/core
	/// Заданная скорость насоса (уставка), 0-100%.
	var/speed = 0
	/// Фактическая скорость, 0-100%: идёт к уставке с разгоном и торможением, при потере питания выбегает. Подача берётся от неё.
	var/spin = 0
	/// Петля звука работы насоса (стоковый sound_player).
	var/datum/sound_token/sound_token
	/// Подача воды в напорную трубу за последний тик, моль/с.
	var/last_flow = 0
	/// Состояние для пульта: RUNNING, STOPPED, NO POWER, NOT PIPED, NO REACTOR, NO INLET, NO SUCTION, NO HEAD, VESSEL FULL, BURNT OUT.
	var/pump_state = "STOPPED"
	/// Нагрев мотора, 0-100. Растёт от сухого хода и работы против закрытой линии, иначе остывает. На NSR_PUMP_HEAT_MAX мотор сгорает.
	var/heat = 0
	/// TRUE, если мотор сгорел: насос не крутится, пока его не перемотают (NSR_PUMP_REPAIR_WIRE кусков провода, мотор должен остыть).
	var/burnt_out = FALSE
	/// Доля запрошенной воды, которой не хватило в последний тик, 0-1 (для расчёта нагрева от сухого хода).
	var/dryness = 0
	/// Когда мотор в следующий раз пожалуется вслух на перегрев.
	var/next_heat_message = 0
	/// Автоматика: если включена, уставкой скорости управляет регулятор, который держит уровень воды в сосуде. По умолчанию выключена.
	var/auto = FALSE
	/// Уровень воды в сосуде, который держит автоматика, %.
	var/auto_set = NSR_AUTO_PUMP_SET
	/// Интегральная часть регулятора, % скорости.
	var/auto_i = 0
	/// Потолок скорости для автоматики, % (опускается при недодаче воды и медленно возвращается).
	var/auto_cap = 100
	/// Что сейчас делает автоматика, для пульта (пусто, если всё в порядке).
	var/auto_text = ""

/obj/machinery/atmospherics/binary/submarine_feed_pump/Initialize()
	. = ..()
	// Всасывающая сторона большая: это запас конденсата, из него насос берёт воду.
	air1.volume = NSR_FEED_TANK_VOLUME

/obj/machinery/atmospherics/binary/submarine_feed_pump/Destroy()
	QDEL_NULL(sound_token)
	if(core)
		core.feed_pump = null
	core = null
	return ..()

/// Обороты насоса для пульта, об/мин.
/obj/machinery/atmospherics/binary/submarine_feed_pump/proc/get_rpm()
	return round(spin / 100 * NSR_FEED_PUMP_RPM_MAX)

/// Что делает ротор насоса: для пульта.
/obj/machinery/atmospherics/binary/submarine_feed_pump/proc/get_spin_text()
	if(burnt_out)
		return "SEIZED"
	if(spin <= 0)
		return "STOPPED"
	if(inoperable())
		return "COASTING DOWN"
	if(spin < speed - 0.5)
		return "SPINNING UP"
	if(spin > speed + 0.5)
		return "SPINNING DOWN"
	return "AT SPEED"

/// Гул насоса: петля звука с громкостью по оборотам. Выключается, когда насос встал.
/obj/machinery/atmospherics/binary/submarine_feed_pump/proc/update_sound()
	if(spin < 3)
		if(sound_token)
			QDEL_NULL(sound_token)
		return
	var/volume = 6 + 16 * spin / 100
	if(!sound_token)
		sound_token = GLOB.sound_player.PlayLoopingSound(src, "nsr_pump_\ref[src]", NS_SND_PUMP_LOOP, volume = volume, range = 6, falloff = 3, prefer_mute = TRUE)
	else
		sound_token.SetVolume(volume)

/obj/machinery/atmospherics/binary/submarine_feed_pump/use_tool(obj/item/tool, mob/living/user, list/click_params)
	// Насос закреплён на палубе: отвернуть его гаечным ключом нельзя.
	if(isWrench(tool))
		to_chat(user, SPAN_WARNING("\The [src] is bolted to the deck."))
		return TRUE
	// Сгоревший мотор перематывают проводом, когда он остыл.
	if(isCoil(tool) && burnt_out)
		var/obj/item/stack/coil = tool
		if(heat > NSR_PUMP_REPAIR_COOL)
			to_chat(user, SPAN_WARNING("The motor of \the [src] is still too hot to touch. Let it cool down first."))
			return TRUE
		if(coil.get_amount() < NSR_PUMP_REPAIR_WIRE)
			to_chat(user, SPAN_WARNING("You need [NSR_PUMP_REPAIR_WIRE] pieces of cable to rewind the motor."))
			return TRUE
		user.visible_message(SPAN_NOTICE("\The [user] starts rewinding the burnt motor of \the [src]."))
		if(!do_after(user, 6 SECONDS, src) || !burnt_out || !coil.use(NSR_PUMP_REPAIR_WIRE))
			return TRUE
		burnt_out = FALSE
		heat = 0
		color = initial(color)
		user.visible_message(SPAN_NOTICE("\The [user] rewinds the motor of \the [src]."))
		playsound(src, NS_SND_BUILT, 50, TRUE)
		return TRUE
	return ..()

/// Мотор сгорел от перегрева: насос встаёт, уставка сбрасывается, чинится проводом после остывания.
/obj/machinery/atmospherics/binary/submarine_feed_pump/proc/burn_out()
	burnt_out = TRUE
	speed = 0
	spin = 0
	auto = FALSE
	auto_i = 0
	auto_text = ""
	color = "#4a3a3a"
	visible_message(SPAN_DANGER("The motor of \the [src] burns out with a bang and a puff of smoke!"))
	playsound(src, NS_SND_TRIP, 70, TRUE)
	QDEL_NULL(sound_token)

/// Нагрев мотора за dt секунд по состоянию гидравлики: полный сухой ход нагревает быстро, работа против закрытой линии медленно,
/// небольшая недодача воды (до NSR_PUMP_DRY_DEADZONE) не греет вовсе. Обдув мотора остужает его всегда (NSR_PUMP_COOL).
/obj/machinery/atmospherics/binary/submarine_feed_pump/proc/update_heat(dt)
	var/load = spin / 100
	var/gain = 0
	switch(pump_state)
		if("NO SUCTION")
			gain = NSR_PUMP_HEAT_DRY * load
		if("RUNNING")
			gain = NSR_PUMP_HEAT_DRY * load * max(0, dryness - NSR_PUMP_DRY_DEADZONE) / (1 - NSR_PUMP_DRY_DEADZONE)
		if("NOT PIPED", "NO REACTOR", "NO INLET", "NO HEAD", "VESSEL FULL")
			gain = NSR_PUMP_HEAT_BLOCKED * load
	heat = clamp(heat + (gain - NSR_PUMP_COOL) * dt, 0, NSR_PUMP_HEAT_MAX)
	if(heat >= NSR_PUMP_HEAT_MAX)
		burn_out()
	else if(heat >= NSR_PUMP_HEAT_WARN && world.time >= next_heat_message)
		next_heat_message = world.time + 15 SECONDS
		visible_message(SPAN_WARNING("The motor of \the [src] whines and smells of hot varnish."))

/obj/machinery/atmospherics/binary/submarine_feed_pump/update_underlays()
	if(..())
		underlays.Cut()
		var/turf/T = get_turf(src)
		if(!istype(T))
			return
		add_underlay(T, node1, turn(dir, -180))
		add_underlay(T, node2, dir)

/obj/machinery/atmospherics/binary/submarine_feed_pump/hide(i)
	update_underlays()

/obj/machinery/atmospherics/binary/submarine_feed_pump/Process(wait)
	. = ..()
	last_flow = 0
	var/dt = 2
	if(wait > 0)
		dt = clamp(wait / 10, 0.5, 5)
	if(burnt_out)
		// Сгоревший мотор стоит и остывает, пока его не перемотают.
		spin = 0
		last_flow = 0
		pump_state = "BURNT OUT"
		heat = max(0, heat - NSR_PUMP_COOL * dt)
		update_sound()
		return
	// Ротор идёт к уставке с разгоном и торможением. Без питания уставка считается нулевой: насос выбегает, но ещё какое-то время качает.
	var/powered = !inoperable()
	if(auto && powered)
		run_auto(dt)
	var/goal = powered ? speed : 0
	if(spin < goal)
		spin = min(goal, spin + NSR_FEED_PUMP_SPINUP * dt)
	else if(spin > goal)
		spin = max(goal, spin - NSR_FEED_PUMP_SPINDOWN * dt)
	if(spin < 0.5 && goal <= 0)
		spin = 0
	if(powered && spin > 0)
		use_power_oneoff(NSR_FEED_PUMP_POWER * spin / 100)
	pump_state = pump_water(dt)
	// Если питания нет и насос должен был работать, пульт показывает причину, даже пока ротор ещё крутится.
	if(!powered && speed > 0)
		pump_state = "NO POWER"
	update_heat(dt)
	update_sound()

/// Почему автоматика не может сейчас качать воду (пустая строка, если может). Автоматика не даёт насосу крутиться вхолостую.
/obj/machinery/atmospherics/binary/submarine_feed_pump/proc/auto_block_reason()
	if(!core || QDELETED(core) || core.is_dead())
		return "NO REACTOR"
	if(!core.feed_inlet)
		return "NO INLET"
	if(!network1 || !network2)
		return "NOT PIPED"
	if(core.steam_pressure >= NSR_FEED_PUMP_HEAD)
		return "NO HEAD"
	if(air1.get_gas(GAS_LIQUID_WATER) < NSR_AUTO_PUMP_MIN_WATER)
		return "NO WATER"
	return ""

/// Автоматика насоса: ПИ-регулятор держит уровень воды в сосуде на уставке auto_set, сам меняя скорость насоса (speed).
/// Не качает, если качать нечем или некуда (auto_block_reason), и не даёт насосу работать с недодачей воды выше мёртвой зоны:
/// потолок auto_cap опускается и медленно возвращается. Позже эту автоматику переведём в серверную (см. GDD), логика останется.
/obj/machinery/atmospherics/binary/submarine_feed_pump/proc/run_auto(dt)
	auto_text = auto_block_reason()
	if(auto_text)
		auto_i = 0
		speed = 0
		return
	// Недодача воды выше мёртвой зоны: потолок скорости падает, пока приток не догонит насос.
	if(dryness > NSR_PUMP_DRY_DEADZONE)
		auto_cap = min(auto_cap, spin * (1 - dryness) / (1 - NSR_PUMP_DRY_DEADZONE))
	else
		auto_cap = min(100, auto_cap + 2 * dt)
	if(auto_cap < 99)
		auto_text = "LIMITED BY SUPPLY"
	var/error = auto_set - core.feed_level()
	auto_i = clamp(auto_i + NSR_AUTO_PUMP_KI * error * dt, 0, auto_cap)
	speed = clamp(auto_i + NSR_AUTO_PUMP_KP * error, 0, auto_cap)

/// Включает и выключает автоматику. При включении регулятор подхватывает текущую скорость без рывка, при выключении скорость остаётся как есть.
/obj/machinery/atmospherics/binary/submarine_feed_pump/proc/toggle_auto(mob/user)
	if(burnt_out)
		to_chat(user, SPAN_WARNING("The pump motor is burnt out."))
		return
	auto = !auto
	auto_i = speed
	auto_cap = 100
	auto_text = ""

/// Гидравлика насоса за dt секунд при текущих оборотах. Возвращает состояние для пульта.
/obj/machinery/atmospherics/binary/submarine_feed_pump/proc/pump_water(dt)
	dryness = 0
	if(spin <= 0)
		return "STOPPED"
	if(!network1 || !network2)
		return "NOT PIPED"
	if(!core || QDELETED(core) || core.is_dead())
		return "NO REACTOR"
	if(!core.feed_inlet)
		return "NO INLET"
	// Чем выше давление в сосуде, тем слабее подача.
	var/head_factor = clamp(1 - core.steam_pressure / NSR_FEED_PUMP_HEAD, 0, 1)
	if(head_factor <= 0)
		return "NO HEAD"
	var/available = air1.get_gas(GAS_LIQUID_WATER)
	if(available <= 0)
		return "NO SUCTION"
	// Напорная труба не должна перегружаться: если сосуд не принимает воду, насос упирается в предел давления трубы.
	if(air2.return_pressure() >= NSR_FEED_LINE_MAX * NSR_KPA_PER_BAR)
		return "VESSEL FULL"
	var/wanted = (spin / 100) * NSR_FEED_PUMP_MAX * head_factor * dt
	var/moved = min(wanted, available)
	// Воды не хватает: чем меньше хватило, тем выше сухой ход.
	if(wanted > 0)
		dryness = clamp(1 - moved / wanted, 0, 1)
	air1.adjust_gas(GAS_LIQUID_WATER, -moved)
	air2.adjust_gas_temp(GAS_LIQUID_WATER, moved, air1.temperature)
	last_flow = moved / dt
	network1.update = 1
	network2.update = 1
	return "RUNNING"

/// Входной порт питательной воды. Приварен к сосуду рядом с ядром (в радиусе NSR_SECTION_LINK_RANGE), смотрит (dir) на водяную трубу.
/// Принимает воду из напорной трубы и сливает её в сосуд. Сколько сосуд готов принять, столько и уходит.
/obj/machinery/atmospherics/unary/tank/submarine_feed_inlet
	name = "reactor feedwater inlet"
	desc = "The feedwater inlet of the reactor vessel. The pump line ends here."
	volume = NSR_FEED_INLET_VOLUME
	connect_types = CONNECT_TYPE_WATER
	// Временно: тёмно-голубой, чтобы отличать от парового порта и баков. Заменить своим спрайтом.
	color = "#2f8fb0"
	/// Метка реактора, в который сливается вода. Должна совпадать с reactor_id ядра.
	var/reactor_id = "main"
	var/obj/machinery/submarine_reactor_core/core

/obj/machinery/atmospherics/unary/tank/submarine_feed_inlet/Destroy()
	if(core)
		core.feed_inlet = null
	core = null
	return ..()

/obj/machinery/atmospherics/unary/tank/submarine_feed_inlet/use_tool(obj/item/tool, mob/living/user, list/click_params)
	// Порт приварен к сосуду: отвернуть его, как обычный бак, нельзя.
	if(isWrench(tool))
		to_chat(user, SPAN_WARNING("\The [src] is welded to the reactor vessel."))
		return TRUE
	return ..()

/obj/machinery/atmospherics/unary/tank/submarine_feed_inlet/Process(wait)
	. = ..()
	if(!core || QDELETED(core) || core.is_dead())
		return
	var/available = air_contents.get_gas(GAS_LIQUID_WATER)
	if(available <= 0)
		return
	var/added = core.add_water(available)
	if(added <= 0)
		return
	air_contents.adjust_gas(GAS_LIQUID_WATER, -added)
	if(network)
		network.update = 1

// ----------------------------------------------------------------------------
// ПУЛЬТ БЩУ
// ----------------------------------------------------------------------------

/obj/machinery/computer/submarine_reactor_console
	name = "reactor control panel"
	desc = "A heavy control panel with buttons for the control rods, the feedwater pump and the emergency SCRAM. The rods set how much steam the reactor makes, the pump keeps it supplied with water, and SCRAM drops every rod at once."
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
	/// Положение стрелки и дуги насоса в прошлый раз, когда окно обновлялось: от него шкала плавно доезжает до нового значения (SVG-анимация).
	var/last_pump_angle
	var/last_pump_fill

/obj/machinery/computer/submarine_reactor_console/Initialize()
	. = ..()
	GLOB.submarine_reactor_consoles += src

/obj/machinery/computer/submarine_reactor_console/Destroy()
	GLOB.submarine_reactor_consoles -= src
	reactor = null
	return ..()

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
	data["alarmLevel"] = R.alarm_level
	data["alarmMuted"] = R.alarm_mute_level > 0
	data["alarmUnacked"] = R.has_unacked_alarm()
	data["alarmTiles"] = R.annunciator.ui_tiles()
	data["damage"] = round(R.core_damage, 0.1)
	data["damageClass"] = (R.core_damage >= NSR_DAMAGE_CRIT) ? "bad" : ((R.core_damage >= NSR_DAMAGE_WARN) ? "average" : "good")
	data["leaking"] = R.leaking
	data["burstPressure"] = round(R.vessel_burst_pressure())
	data["temp"] = round(R.core_temperature)
	data["decay"] = round(R.decay_heat * 100, 0.1)
	data["decayMax"] = NSR_DECAY_FRACTION * 100
	data["tempMax"] = NSR_MELTDOWN_TEMP
	data["tempClass"] = level_class(R.core_temperature, NSR_TEMP_WARN, NSR_TEMP_CRIT)
	data["pressure"] = round(R.steam_pressure, 0.1)
	data["pressureMax"] = NSR_PRESSURE_BURST
	data["pressureClass"] = level_class(R.steam_pressure, NSR_PRESSURE_WARN, NSR_PRESSURE_CRIT)
	// В режиме двух контуров это самый низкий уровень воды среди парогенераторов.
	var/water_level = R.feed_level()
	data["coolant"] = round(water_level, 0.1)
	// У воды всё наоборот: чем её меньше, тем хуже.
	data["coolantClass"] = "good"
	if(water_level < NSR_COOLANT_CRIT)
		data["coolantClass"] = "bad"
	else if(water_level < NSR_COOLANT_WARN)
		data["coolantClass"] = "average"
	data["rods"] = round(R.rods_pos, 0.1)
	var/list/rod_list = list()
	for(var/i in 1 to NSR_ROD_COUNT)
		rod_list += list(list("n" = i, "pos" = round(R.rod_pos[i], 0.1), "target" = R.rod_target[i], "moving" = abs(R.rod_pos[i] - R.rod_target[i]) >= 0.5, "locked" = R.scrammed))
	data["rodList"] = rod_list
	data["rodsTarget"] = R.rods_target
	data["rodsMoving"] = abs(R.rods_pos - R.rods_target) >= 0.5
	data["feedwater"] = R.feedwater_valve
	data["steamValve"] = R.steam_valve
	data["steamFlow"] = round(R.steam_flow, 0.1)
	data["hasPort"] = R.two_circuit || !!R.steam_port
	data["hasPump"] = !!R.feed_pump
	if(R.feed_pump)
		var/obj/machinery/atmospherics/binary/submarine_feed_pump/pump = R.feed_pump
		data["pumpSpeed"] = round(pump.speed, 0.1)
		data["pumpAuto"] = pump.auto
		data["pumpAutoSet"] = pump.auto_set
		data["pumpAutoText"] = pump.auto_text
		data["pumpHeat"] = round(pump.heat)
		data["pumpHeatClass"] = (pump.heat >= NSR_PUMP_HEAT_WARN) ? "bad" : ((pump.heat >= NSR_PUMP_HEAT_WARN / 2) ? "average" : "good")
		data["pumpBurnt"] = pump.burnt_out
		data["pumpRpm"] = pump.get_rpm()
		data["pumpRpmMax"] = NSR_FEED_PUMP_RPM_MAX
		data["pumpSpin"] = pump.get_spin_text()
		data["pumpAngle"] = nsr_gauge_angle(pump.spin / 100)
		data["pumpAnglePrev"] = isnull(last_pump_angle) ? data["pumpAngle"] : last_pump_angle
		last_pump_angle = data["pumpAngle"]
		data["pumpTargetAngle"] = nsr_gauge_angle(pump.speed / 100)
		data["pumpFillLen"] = nsr_gauge_len(pump.spin / 100)
		data["pumpFillPrev"] = isnull(last_pump_fill) ? data["pumpFillLen"] : last_pump_fill
		last_pump_fill = data["pumpFillLen"]
		data["pumpState"] = pump.pump_state
		data["pumpClass"] = (pump.pump_state == "RUNNING") ? "good" : ((pump.pump_state == "STOPPED") ? "average" : "bad")
		data["pumpFlow"] = round(pump.last_flow, 0.1)
		data["feedPressure"] = round(pump.air2.return_pressure() / NSR_KPA_PER_BAR, 0.1)
	// Два контура (ревизия 14).
	data["twoCircuit"] = R.two_circuit
	if(R.two_circuit)
		data["primaryPressure"] = round(R.primary_pressure, 0.1)
		data["primaryBurst"] = NSR_PRIMARY_BURST
		data["primaryBurstNow"] = round(R.vessel_burst_pressure())
		data["primaryFlow"] = round(R.primary_flow() * 100)
		data["coolEff"] = round(R.cooling_eff * 100)
		data["voiding"] = R.cooling_eff < 0.98
		data["hasPzr"] = !!R.pressurizer
		var/hot = (R.rods_pos > 0 || R.core_temperature > NSR_BOIL_TEMP)
		var/pressure_class = "good"
		var/pzr_class = "good"
		if(R.pressurizer)
			var/pzr_now = R.pzr_level()
			if(R.primary_pressure >= NSR_PRIMARY_CRIT_HIGH || (hot && R.primary_pressure <= NSR_PRIMARY_CRIT_LOW))
				pressure_class = "bad"
			else if(R.primary_pressure >= NSR_PRIMARY_WARN_HIGH || (hot && R.primary_pressure <= NSR_PRIMARY_WARN_LOW))
				pressure_class = "average"
			if(pzr_now >= NSR_PZR_LEVEL_CRIT_HIGH || (hot && pzr_now <= NSR_PZR_LEVEL_CRIT_LOW))
				pzr_class = "bad"
			else if(pzr_now >= NSR_PZR_LEVEL_WARN_HIGH || (hot && pzr_now <= NSR_PZR_LEVEL_WARN_LOW))
				pzr_class = "average"
			var/obj/machinery/submarine_pressurizer/pz = R.pressurizer
			data["pzrLevel"] = round(pzr_now, 0.1)
			data["pzrLevelClass"] = pzr_class
			data["pzrSolid"] = R.pzr_level_raw() >= NSR_PZR_SOLID_LEVEL
			data["pzrHeater"] = round(pz.heater)
			data["pzrHeating"] = round(pz.heating * 100)
			data["pzrHeaterText"] = pz.get_heater_text()
			data["pzrHeaterClass"] = (pz.get_heater_text() in list("NO POWER", "UNCOVERED")) ? "bad" : "good"
			data["pzrSpray"] = round(pz.spray)
			data["pzrAuto"] = pz.auto
			data["pzrSet"] = pz.setpoint
			data["pzrRelief"] = pz.get_relief_text()
			data["pzrReliefClass"] = pz.relief_open ? "bad" : (pz.block_closed ? "average" : "good")
			data["pzrReliefManual"] = pz.relief_manual
			data["pzrBlock"] = pz.block_closed
		data["primaryPressureClass"] = pressure_class
		data["inventory"] = round(R.primary_inventory, 0.1)
		data["hasMakeup"] = !!R.makeup_pump
		if(R.makeup_pump)
			var/obj/machinery/submarine_makeup_pump/mk = R.makeup_pump
			data["mkSetting"] = mk.setting
			data["mkState"] = mk.get_state_text()
			data["mkClass"] = (mk.get_state_text() == "NO POWER") ? "bad" : "good"
		data["hasPrimaryPump"] = !!R.primary_pump
		if(R.primary_pump)
			var/obj/machinery/submarine_primary_pump/pp = R.primary_pump
			data["ppSpeed"] = round(pp.speed)
			data["ppSpin"] = round(pp.spin)
			data["ppRpm"] = pp.get_rpm()
			data["ppRpmMax"] = NSR_PRIMARY_PUMP_RPM_MAX
			data["ppState"] = pp.get_state_text()
			data["ppClass"] = (pp.get_state_text() in list("AT SPEED", "SPINNING UP", "SPINNING DOWN")) ? "good" : "bad"
			data["ppWear"] = round(pp.wear)
			data["ppWearClass"] = pp.seized ? "bad" : ((pp.wear >= NSR_PPUMP_WEAR_WARN) ? "average" : "good")
			data["ppSeized"] = pp.seized
		var/list/sg_list = list()
		var/sg_index = 0
		for(var/obj/machinery/submarine_steam_generator/G in R.steam_gens)
			sg_index++
			var/level_class = "good"
			if(G.coolant_level < NSR_COOLANT_CRIT)
				level_class = "bad"
			else if(G.coolant_level < NSR_COOLANT_WARN)
				level_class = "average"
			var/state_text = G.get_state_text()
			sg_list += list(list("n" = sg_index, "level" = round(G.coolant_level, 0.1), "levelClass" = level_class, "flow" = round(G.steam_flow, 0.1), "heat" = round(G.heat_transfer, 0.1), "pressure" = round(G.steam_pressure, 0.1), "state" = state_text, "stateClass" = (state_text == "RUPTURED" || state_text == "DRY" || state_text == "NO STEAM PORT") ? "bad" : ((state_text == "LOW WATER" || state_text == "VALVE CLOSED") ? "average" : "good"), "valveClosed" = G.steam_valve_closed, "ruptured" = G.ruptured, "tube" = G.get_tube_text(), "tubeClass" = G.tube_leak ? "bad" : ((G.tube_damage >= NSR_TUBE_WARN) ? "average" : "good"), "tubeDamage" = round(G.tube_damage), "leakRate" = round(G.leak_rate, 0.01), "plugged" = round(G.tubes_plugged), "contam" = round(G.contamination)))
		data["sgList"] = sg_list
	data["scrammed"] = R.scrammed
	data["casingsOpen"] = R.count_open_casings()
	data["casingsTotal"] = R.count_casings()
	return data

/obj/machinery/computer/submarine_reactor_console/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = 1)
	var/list/data = build_ui_data()
	// Обновляет окно, если оно уже открыто. Если окна нет, возвращает null.
	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "submarine_reactor_panel.tmpl", "Reactor control panel", 540, 960)
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
			var/gen_count = found.find_steam_gens()
			var/port_text = gen_count ? "[gen_count] steam generator(s), two-circuit mode" : (found.find_steam_port() ? "steam port connected" : "no steam port (sealed test vessel)")
			var/pump_text = found.find_feed_pump() ? "feedwater pump connected" : "no feedwater pump (free water valve)"
			var/inlet_text = found.find_feed_inlet() ? "feedwater inlet connected" : "no feedwater inlet"
			var/primary_text = found.find_primary_pump() ? ", main coolant pump connected" : (gen_count ? ", no main coolant pump (natural circulation only)" : "")
			if(gen_count)
				primary_text += found.find_pressurizer() ? ", pressurizer connected" : ", no pressurizer (primary pressure fixed)"
				primary_text += found.find_makeup_pump() ? ", makeup pump connected" : ", no makeup pump"
			to_chat(user, SPAN_NOTICE("Linked to reactor unit '[found.reactor_id]', [section_count] hull section(s) detected, plus the core, [port_text], [pump_text], [inlet_text][primary_text]."))
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
		if("rods_move")
			var/rods_amount = text2num(href_list["amount"])
			if(!(rods_amount in list(-10, -1, 1, 10)))
				return TOPIC_HANDLED
			if(R.scrammed)
				to_chat(user, SPAN_WARNING("The control rods are locked by SCRAM. Reset it first."))
			else
				R.adjust_rods(rods_amount)
		if("rod_move")
			var/rod = text2num(href_list["rod"])
			var/rod_amount = text2num(href_list["amount"])
			if(isnull(rod) || !(rod_amount in list(-10, -1, 1, 10)))
				return TOPIC_HANDLED
			if(R.scrammed)
				to_chat(user, SPAN_WARNING("The control rods are locked by SCRAM. Reset it first."))
			else
				R.adjust_rod(rod, rod_amount)
		if("pump_move")
			var/pump_amount = text2num(href_list["amount"])
			if(!R.feed_pump)
				to_chat(user, SPAN_WARNING("No feedwater pump is connected."))
			else if(R.feed_pump.auto)
				to_chat(user, SPAN_WARNING("The pump is in automatic mode. Switch the automation off to set its speed by hand."))
			else if(pump_amount in list(-10, -1, 1, 10))
				R.feed_pump.speed = clamp(R.feed_pump.speed + pump_amount, 0, 100)
		if("ppump_move")
			var/pp_amount = text2num(href_list["amount"])
			if(!R.primary_pump)
				to_chat(user, SPAN_WARNING("No main coolant pump is connected."))
			else if(R.primary_pump.seized)
				to_chat(user, SPAN_WARNING("The main coolant pump rotor is jammed. The bearings have to be replaced on site."))
			else if(pp_amount in list(-10, -1, 1, 10))
				R.primary_pump.speed = clamp(R.primary_pump.speed + pp_amount, 0, 100)
		if("pzr_heater", "pzr_spray")
			var/pz_amount = text2num(href_list["amount"])
			if(!R.pressurizer)
				to_chat(user, SPAN_WARNING("No pressurizer is connected."))
			else if(R.pressurizer.auto)
				to_chat(user, SPAN_WARNING("The pressure automation is on. Switch it off to set the heaters and the spray by hand."))
			else if(pz_amount in list(-10, -1, 1, 10))
				if(action == "pzr_heater")
					R.pressurizer.heater = clamp(R.pressurizer.heater + pz_amount, 0, 100)
				else
					R.pressurizer.spray = clamp(R.pressurizer.spray + pz_amount, 0, 100)
		if("pzr_auto")
			if(!R.pressurizer)
				to_chat(user, SPAN_WARNING("No pressurizer is connected."))
			else
				R.pressurizer.toggle_auto(user)
		if("pzr_set")
			var/set_amount = text2num(href_list["amount"])
			if(R.pressurizer && (set_amount in list(-5, -1, 1, 5)))
				R.pressurizer.setpoint = clamp(R.pressurizer.setpoint + set_amount, NSR_PZR_SET_MIN, NSR_PZR_SET_MAX)
		if("pzr_relief")
			if(!R.pressurizer)
				to_chat(user, SPAN_WARNING("No pressurizer is connected."))
			else if(R.pressurizer.block_closed)
				to_chat(user, SPAN_WARNING("The relief valve is isolated by its block valve."))
			else
				R.pressurizer.relief_manual = !R.pressurizer.relief_manual
		if("pzr_block")
			if(!R.pressurizer)
				to_chat(user, SPAN_WARNING("No pressurizer is connected."))
			else
				R.pressurizer.block_closed = !R.pressurizer.block_closed
				if(R.pressurizer.block_closed)
					R.pressurizer.relief_manual = FALSE
		if("makeup_move")
			var/mk_amount = text2num(href_list["amount"])
			if(!R.makeup_pump)
				to_chat(user, SPAN_WARNING("No makeup pump is connected."))
			else if(mk_amount in list(-10, -1, 1, 10))
				R.makeup_pump.setting = clamp(R.makeup_pump.setting + mk_amount, -100, 100)
		if("makeup_stop")
			if(R.makeup_pump)
				R.makeup_pump.setting = 0
		if("pump_auto")
			if(!R.feed_pump)
				to_chat(user, SPAN_WARNING("No feedwater pump is connected."))
			else
				R.feed_pump.toggle_auto(user)
		if("pump_auto_set")
			var/level_amount = text2num(href_list["amount"])
			if(R.feed_pump && (level_amount in list(-5, -1, 1, 5)))
				R.feed_pump.auto_set = clamp(R.feed_pump.auto_set + level_amount, 10, 95)
		if("feed_up", "feed_down")
			if(R.two_circuit)
				to_chat(user, SPAN_WARNING("The steam generators are fed by the pump, not by a valve."))
			else if(R.feed_pump)
				to_chat(user, SPAN_WARNING("The vessel is fed by the pump, not by the valve."))
			else
				R.adjust_feedwater(action == "feed_up" ? NSR_VALVE_STEP : -NSR_VALVE_STEP)
		if("steam_up", "steam_down")
			if(R.steam_port || R.two_circuit)
				to_chat(user, SPAN_WARNING("The steam line is controlled by the valves on the pipes, not from this panel."))
			else
				R.adjust_steam_valve(action == "steam_up" ? NSR_VALVE_STEP : -NSR_VALVE_STEP)
		if("alarm_mute")
			if(R.alarm_mute_level)
				R.alarm_mute_level = 0
			else if(R.alarm_level > 0 || R.has_unacked_alarm())
				R.acknowledge_alarms()
			else
				to_chat(user, SPAN_NOTICE("No alarm is lit."))
		if("sg_valve")
			var/sg_n = text2num(href_list["n"])
			var/obj/machinery/submarine_steam_generator/target_sg
			var/sg_count = 0
			for(var/obj/machinery/submarine_steam_generator/G in R.steam_gens)
				sg_count++
				if(sg_count == sg_n)
					target_sg = G
					break
			if(!target_sg)
				return TOPIC_HANDLED
			if(target_sg.ruptured)
				to_chat(user, SPAN_WARNING("The steam generator is ruptured."))
			else
				target_sg.set_steam_valve(!target_sg.steam_valve_closed)
		if("scram")
			R.scram()
		if("reset")
			if(!R.scrammed)
				to_chat(user, SPAN_NOTICE("SCRAM is not engaged."))
			else if(!R.reset_scram())
				to_chat(user, SPAN_WARNING("Cannot reset SCRAM: the core must cool below [NSR_SCRAM_RESET_TEMP] C first."))
	return TOPIC_REFRESH
