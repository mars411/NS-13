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
	- Входной порт питательной воды (/obj/machinery/atmospherics/unary/tank/submarine_feed_inlet): приварен к сосуду рядом
	  с ядром, принимает воду из напорной трубы и сливает её в сосуд. Между насосом и портом ставится обычная водяная труба.
	- Без насоса работает прежняя заглушка: клапан питательной воды берёт воду из ниоткуда.
	- Водяная труба (submarine_water) только выпускает воду наружу, воздух помещения в неё не входит.
	  Конденсатор пропускает дальше по холодной ветке только пар (воду), прочие газы остаются на паровой стороне.

	НЕ РЕАЛИЗОВАНО НАМЕРЕННО (TBD в GDD, не подменяю догадками)
	- Износ стержней СУЗ и их замена (скафандр, радиация при замене).
	- Подключение к АКБ-контуру: пульт пока не требует питания (stat_immune ниже).

	Все числа ЧЕРНОВЫЕ. Они собраны в одном блоке ниже, меняйте только там.
*/

GLOBAL_LIST_EMPTY(submarine_reactors)
GLOBAL_LIST_EMPTY(submarine_reactor_consoles)
GLOBAL_LIST_EMPTY(submarine_condensers)

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

// Замкнутый контур (этап 3б)
#define GAS_LIQUID_WATER          "liquid_water" // идентификатор вещества Water (вода контура). Не равен GAS_STEAM: у того идентификатор "water", имя Steam
#define NSR_CONDENSER_VOLUME      1000   // л, объём газа на каждой стороне конденсатора
#define NSR_CONDENSER_CAPACITY    60     // моль пара в секунду, которые конденсатор принимает при мощности 100% (реактор даёт около 50)
#define NSR_CONDENSER_OUT_TEMP    (T0C + 30) // K, температура конденсата на выходе (забортная вода)
#define NSR_FEED_TANK_VOLUME      3000   // л, всасывающая сторона питательного насоса (запас конденсата)
#define NSR_FEED_INLET_VOLUME     1500   // л, входной порт питательной воды на сосуде
#define NSR_FEED_LINE_MAX         10     // бар, при таком давлении в напорной трубе насос уже не качает (сосуд полон)
#define NSR_WATER_DRAIN_MIN       0.25   // доля воды из участка открытой водяной трубы, которая вытекает за тик даже без давления (самотёк)
#define NSR_FEED_PUMP_MAX         90     // моль/с при скорости 100% и нулевом давлении в сосуде
#define NSR_FEED_PUMP_HEAD        100    // бар, при таком давлении в сосуде насос уже не может подавать воду
#define NSR_FEED_PUMP_POWER       5000   // Вт при скорости 100%

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
#define NSR_ROD_COUNT             4      // число стержней, у каждого свой привод
#define NSR_ROD_SPEED             2      // ход стержней, процентов в секунду: шаг в 10% занимает 5 секунд
#define NSR_ROD_SPEED_SCRAM       25     // ход стержней при SCRAM, процентов в секунду: полный ход за 4 секунды
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

/obj/machinery/submarine_reactor_core/Initialize()
	. = ..()
	GLOB.submarine_reactors += src
	vessel_air = new /datum/gas_mixture(NSR_VESSEL_VOLUME, T0C + NSR_AMBIENT_TEMP)
	rod_pos = list()
	rod_target = list()
	for(var/i in 1 to NSR_ROD_COUNT)
		rod_pos += 0
		rod_target += 0
	find_sections()
	find_steam_port()
	find_feed_pump()
	find_feed_inlet()
	queue_icon_update()

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
	var/room = (100 - coolant_level) * NSR_MOLES_PER_PERCENT
	var/added = clamp(moles, 0, room)
	coolant_level = min(100, coolant_level + added / NSR_MOLES_PER_PERCENT)
	return added

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

	// Питательная вода (заглушка). Если стоит питательный насос, воду подаёт он, и заглушка не работает.
	if(!feed_pump)
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
		sound_alarm('sound/machines/buzz-two.ogg', 60, TRUE)
	if(new_level >= 2 && world.time >= next_alarm_time)
		sound_alarm('sound/machines/warning-buzzer.ogg', 70)
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
	explosion(here, NSR_RUPTURE_RANGE)

/// Расплав от потери воды. Взрыва нет, но зона остаётся радиоактивной навсегда.
/obj/machinery/submarine_reactor_core/proc/meltdown()
	melted = TRUE
	zero_rods()
	queue_icon_update()
	visible_message(SPAN_DANGER("\The [src] collapses into a glowing molten mass!"))
	sound_alarm('sound/machines/warning-buzzer.ogg', 100)

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

/obj/machinery/atmospherics/binary/submarine_condenser/Process(wait)
	. = ..()
	last_flow = 0
	if(!network1 || !network2)
		return
	var/dt = 2
	if(wait > 0)
		dt = clamp(wait / 10, 0.5, 5)
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
	/// Скорость насоса, 0-100%.
	var/speed = 0
	/// Подача воды в напорную трубу за последний тик, моль/с.
	var/last_flow = 0
	/// Состояние для пульта: RUNNING, STOPPED, NO POWER, NOT PIPED, NO REACTOR, NO INLET, NO SUCTION, NO HEAD, VESSEL FULL.
	var/pump_state = "STOPPED"

/obj/machinery/atmospherics/binary/submarine_feed_pump/Initialize()
	. = ..()
	// Всасывающая сторона большая: это запас конденсата, из него насос берёт воду.
	air1.volume = NSR_FEED_TANK_VOLUME

/obj/machinery/atmospherics/binary/submarine_feed_pump/Destroy()
	if(core)
		core.feed_pump = null
	core = null
	return ..()

/obj/machinery/atmospherics/binary/submarine_feed_pump/use_tool(obj/item/tool, mob/living/user, list/click_params)
	// Насос закреплён на палубе: отвернуть его гаечным ключом нельзя.
	if(isWrench(tool))
		to_chat(user, SPAN_WARNING("\The [src] is bolted to the deck."))
		return TRUE
	return ..()

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
	if(speed <= 0)
		pump_state = "STOPPED"
		return
	if(inoperable())
		pump_state = "NO POWER"
		return
	if(!network1 || !network2)
		pump_state = "NOT PIPED"
		return
	if(!core || QDELETED(core) || core.is_dead())
		pump_state = "NO REACTOR"
		return
	if(!core.feed_inlet)
		pump_state = "NO INLET"
		return
	use_power_oneoff(NSR_FEED_PUMP_POWER * speed / 100)
	var/dt = 2
	if(wait > 0)
		dt = clamp(wait / 10, 0.5, 5)
	// Чем выше давление в сосуде, тем слабее подача.
	var/head_factor = clamp(1 - core.steam_pressure / NSR_FEED_PUMP_HEAD, 0, 1)
	if(head_factor <= 0)
		pump_state = "NO HEAD"
		return
	var/available = air1.get_gas(GAS_LIQUID_WATER)
	if(available <= 0)
		pump_state = "NO SUCTION"
		return
	// Напорная труба не должна перегружаться: если сосуд не принимает воду, насос упирается в предел давления трубы.
	if(air2.return_pressure() >= NSR_FEED_LINE_MAX * NSR_KPA_PER_BAR)
		pump_state = "VESSEL FULL"
		return
	var/wanted = (speed / 100) * NSR_FEED_PUMP_MAX * head_factor * dt
	var/moved = min(wanted, available)
	air1.adjust_gas(GAS_LIQUID_WATER, -moved)
	air2.adjust_gas_temp(GAS_LIQUID_WATER, moved, air1.temperature)
	last_flow = moved / dt
	pump_state = "RUNNING"
	network1.update = 1
	network2.update = 1

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
	data["hasPort"] = !!R.steam_port
	data["hasPump"] = !!R.feed_pump
	if(R.feed_pump)
		var/obj/machinery/atmospherics/binary/submarine_feed_pump/pump = R.feed_pump
		data["pumpSpeed"] = pump.speed
		data["pumpState"] = pump.pump_state
		data["pumpClass"] = (pump.pump_state == "RUNNING") ? "good" : ((pump.pump_state == "STOPPED") ? "average" : "bad")
		data["pumpFlow"] = round(pump.last_flow, 0.1)
		data["feedPressure"] = round(pump.air2.return_pressure() / NSR_KPA_PER_BAR, 0.1)
	data["scrammed"] = R.scrammed
	data["casingsOpen"] = R.count_open_casings()
	data["casingsTotal"] = R.count_casings()
	return data

/obj/machinery/computer/submarine_reactor_console/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = 1)
	var/list/data = build_ui_data()
	// Обновляет окно, если оно уже открыто. Если окна нет, возвращает null.
	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "submarine_reactor_panel.tmpl", "Reactor control panel", 540, 860)
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
			var/pump_text = found.find_feed_pump() ? "feedwater pump connected" : "no feedwater pump (free water valve)"
			var/inlet_text = found.find_feed_inlet() ? "feedwater inlet connected" : "no feedwater inlet"
			to_chat(user, SPAN_NOTICE("Linked to reactor unit '[found.reactor_id]', [section_count] hull section(s) detected, plus the core, [port_text], [pump_text], [inlet_text]."))
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
			else if(pump_amount in list(-10, -1, 1, 10))
				R.feed_pump.speed = clamp(R.feed_pump.speed + pump_amount, 0, 100)
		if("feed_up", "feed_down")
			if(R.feed_pump)
				to_chat(user, SPAN_WARNING("The vessel is fed by the pump, not by the valve."))
			else
				R.adjust_feedwater(action == "feed_up" ? NSR_VALVE_STEP : -NSR_VALVE_STEP)
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
