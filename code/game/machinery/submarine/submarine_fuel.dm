/*
	ТВЭЛ (ревизия 23).

	- /obj/item/submarine_fuel_element: тепловыделяющий элемент. Четыре штуки стоят в ядре реактора (NSR_FUEL_SLOTS), каждый со своим изотопом и выгоранием.
	- Изотоп задаёт мощность (во сколько раз ТВЭЛ греет против обогащённого урана) и реакцию (как быстро поток догоняет стержни).
	- Выгорание идёт от потока нейтронов, а не от времени (см. burn_fuel в submarine_reactor.dm): 10 минут на полностью поднятых стержнях,
	  около 20 на 60-80%, около 30 на средних. Последние NSR_FUEL_TAIL процентов выгорания отдача падает до нуля.
	- Выгоревший ТВЭЛ фонит и снаружи ядра. Менять ТВЭЛы можно только на холодном остановленном реакторе со снятой плитой ядра, в радиационном костюме.
	- /obj/structure/closet/crate/submarine_fuel: ящик запасных ТВЭЛов (по одному на каждый изотоп и четыре обогащённых) и двух стержней СУЗ.
	- /obj/item/submarine_control_rod (ревизия 26): сменный стержень СУЗ с износом. Стержни в ядре изнашиваются, меняются на холодном реакторе со снятой плитой.
*/

/// Изотопы топлива: ключ - значение поля isotope. power: относительная мощность, response: реакция (поток догоняет стержни быстрее при большем числе).
var/global/list/nsr_fuel_types = list(
	"enriched" = list("name" = "enriched uranium", "power" = 1, "response" = 1, "color" = "#8fd14f"),
	"natural" = list("name" = "natural uranium", "power" = 0.6, "response" = 1, "color" = "#9aa38a"),
	"thorium" = list("name" = "thorium", "power" = 0.8, "response" = 0.35, "color" = "#d8c26a"),
	"cesium" = list("name" = "cesium", "power" = 1.15, "response" = 2.5, "color" = "#79c7e8")
)

/obj/item/submarine_fuel_element
	name = "TVEL fuel element"
	desc = "A sealed fuel element for a submarine reactor."
	// Временно: сборка твэлов из стока, окрашенная под изотоп. Заменить своим.
	icon = 'icons/obj/fusion_fuel_assembly.dmi'
	icon_state = "fuel_assembly"
	w_class = ITEM_SIZE_LARGE
	/// Ключ из nsr_fuel_types.
	var/isotope = "enriched"
	/// Выгорание, 0-100%.
	var/burnup = 0
	/// Целое выгорание, которое сейчас написано в названии и описании (-1 пока ничего не писали).
	var/shown_burnup = -1

/obj/item/submarine_fuel_element/Initialize(mapload)
	. = ..()
	set_burnup(burnup)

/obj/item/submarine_fuel_element/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/submarine_fuel_element/natural
	isotope = "natural"

/obj/item/submarine_fuel_element/thorium
	isotope = "thorium"

/obj/item/submarine_fuel_element/cesium
	isotope = "cesium"

/obj/item/submarine_fuel_element/proc/fuel_name()
	var/list/type_info = nsr_fuel_types[isotope]
	return type_info ? type_info["name"] : "unknown fuel"

/// Мощность изотопа (относительная), без учёта выгорания.
/obj/item/submarine_fuel_element/proc/power_mult()
	var/list/type_info = nsr_fuel_types[isotope]
	return type_info ? type_info["power"] : 1

/// Реакция изотопа.
/obj/item/submarine_fuel_element/proc/response()
	var/list/type_info = nsr_fuel_types[isotope]
	return type_info ? type_info["response"] : 1

/// Текущая отдача: мощность изотопа, падающая до нуля на последних NSR_FUEL_TAIL процентах выгорания.
/obj/item/submarine_fuel_element/proc/fuel_output()
	return power_mult() * clamp((100 - burnup) / NSR_FUEL_TAIL, 0, 1)

/// Задаёт выгорание и обновляет название, описание и цвет; фонит, пока выгорание не мало.
/obj/item/submarine_fuel_element/proc/set_burnup(value)
	burnup = clamp(value, 0, 100)
	// Название и описание перестраиваем только когда меняется целое число процентов: реактор зовёт это каждый шаг.
	if(round(burnup) != shown_burnup)
		shown_burnup = round(burnup)
		var/list/type_info = nsr_fuel_types[isotope]
		if(type_info)
			color = type_info["color"]
		SetName("[fuel_name()] TVEL")
		desc = "A sealed fuel element for a submarine reactor. Isotope: [fuel_name()]. Burnup: [shown_burnup] %.[burnup >= 5 ? " It is radioactive: handle it in a radiation suit with its hood." : ""]"
	if(burnup >= 5)
		START_PROCESSING(SSobj, src)
	else
		STOP_PROCESSING(SSobj, src)

/obj/item/submarine_fuel_element/Process()
	// Внутри ядра их суммарную радиацию считает само ядро.
	if(istype(loc, /obj/machinery/submarine_reactor_core))
		return
	SSradiation.radiate(src, NSR_RADS_SPENT_MAX * burnup / 100)

/obj/structure/closet/crate/submarine_fuel
	name = "fuel element crate"
	desc = "A lead-lined crate of spare TVEL fuel elements and control rods for the reactor."
	closet_appearance = /singleton/closet_appearance/crate/radiation

/obj/structure/closet/crate/submarine_fuel/WillContain()
	return list(
		/obj/item/submarine_fuel_element = 4,
		/obj/item/submarine_fuel_element/natural = 2,
		/obj/item/submarine_fuel_element/thorium = 2,
		/obj/item/submarine_fuel_element/cesium = 1,
		/obj/item/submarine_control_rod = 2
	)

// ----------------------------------------------------------------------------
// СТЕРЖЕНЬ СУЗ (ревизия 26)
// ----------------------------------------------------------------------------

/// Сменный стержень системы управления и защиты. Новый имеет износ 0. Снятый с реактора сохраняет износ, его можно поставить обратно.
/obj/item/submarine_control_rod
	name = "control rod"
	desc = "A boron-steel control rod for the submarine reactor."
	// Временно: сборка из стока, окрашенная в тёмную сталь. Заменить своим.
	icon = 'icons/obj/fusion_fuel_assembly.dmi'
	icon_state = "fuel_assembly"
	color = "#59636e"
	w_class = ITEM_SIZE_LARGE
	/// Износ, 0-100%.
	var/wear = 0

/obj/item/submarine_control_rod/Initialize(mapload)
	. = ..()
	set_wear(wear)

/obj/item/submarine_control_rod/proc/set_wear(value)
	wear = clamp(value, 0, 100)
	SetName(wear > 0 ? "control rod ([round(wear)] % worn)" : "control rod")
	desc = initial(desc) + (wear >= NSR_ROD_JAM_WEAR ? " It is worn to the limit and will seize in the drive." : (wear >= NSR_ROD_WEAR_WARN ? " It is badly worn: time to replace it." : (wear > 0 ? " It has some wear." : " It is new.")))
