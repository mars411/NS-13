/*
	NS-13: обслуживание турбины подлодки. Этап 3в-2, часть 2 («лопасти как предмет, замена, перестройка, ремонт генератора»).
	Проект: GDD, §5.2, п. 9 («Реалистичные лопасти», ответы автора ревизии 8). Описание и проверка: README.md, «Ревизия 12».

	ЧТО ЗДЕСЬ ЕСТЬ
	- Лопасть (/obj/item/submarine_turbine_blade): малая для секции высокого давления, большая для низкого. Делается в автолате
	  (малая 2 листа стали, большая 5). Спрайт временный.
	- Замена лопастей по одной: гаечный ключ снимает крышку остановленной секции без давления; лопасть по секции заменяет самый
	  изношенный ряд; сварка приваривает новые лопасти; ключом крышка закрывается. Пока крышка снята, секция не работает.
	- Перестройка разрушенной секции по частям в любом порядке (сначала сварка вырезает обломки): сталь (20 для высокого давления,
	  10 для низкого), пять лопастей нужного размера, кусок трубы, сканирующий модуль, в конце сварка. Вентиля нет.
	- Ремонт генератора после перегрузки (он перегружается, если секцию разрушило под нагрузкой): 3 конденсатора и 10 кусков провода.

	- Влагоотделитель (/obj/machinery/atmospherics/pipe/simple/visible/submarine_separator, уровень Б): труба между высоким и низким
	  давлением. Без него множитель эрозии лопастей низкого давления 1, с чистым 0,4, слив засоряется со временем (до 1,3), чистится отвёрткой.

	Все числа ЧЕРНОВЫЕ. Сами секции и генератор лежат в submarine_turbine.dm, здесь их дополнения (DM позволяет дописывать тип в другом файле).
*/

#define NST_BLADE_STEEL_SMALL     2      // листов стали на малую лопасть (по ответу автора)
#define NST_BLADE_STEEL_LARGE     5      // листов стали на большую лопасть
#define NST_REBUILD_STEEL_HP      20     // листов стали на перестройку секции высокого давления
#define NST_REBUILD_STEEL_LP      10     // листов стали на перестройку секции низкого давления
#define NST_SERVICE_MAX_KPA       150    // кПа: при большем давлении в секции крышку не открыть
#define NST_SERVICE_STOP_RPM      100    // об/мин: при больших оборотах вала крышку не открыть
#define NST_COVER_LEAK            0.25   // доля газа секции в секунду, которая уходит в помещение, если в секцию со снятой крышкой пустили пар
#define NST_BLADE_WORN            0.95   // ряд лучше этого заменять незачем
#define NST_TIME_COVER            3 SECONDS
#define NST_TIME_BLADE            6 SECONDS
#define NST_TIME_WELD             6 SECONDS
#define NST_TIME_CUT_WRECK        10 SECONDS
#define NST_TIME_REBUILD_PART     4 SECONDS
#define NST_TIME_REBUILD_FINAL    10 SECONDS
#define NST_GEN_REPAIR_CAPS       3      // конденсаторов на ремонт перегруженного генератора
#define NST_GEN_REPAIR_WIRE       10     // кусков провода на ремонт генератора
#define NST_TIME_GEN_REPAIR       6 SECONDS
#define NST_SEP_CLOG_RATE         0.00005 // доля засорения слива в секунду при работающей турбине (около 18% в час)
#define NST_SEP_WET_CLEAN         0.4    // множитель эрозии у секций низкого давления с чистым влагоотделителем
#define NST_SEP_WET_CLOGGED       1.3    // то же с полностью засорённым сливом (хуже, чем совсем без влагоотделителя, где множитель 1)
#define NST_TIME_SEP_CLEAN        5 SECONDS

// ----------------------------------------------------------------------------
// ЛОПАСТИ
// ----------------------------------------------------------------------------

/// Лопасть турбины. Сама ничего не делает: вставляется в снятую крышку секции (замена ряда) или идёт на перестройку разрушенной секции.
/obj/item/submarine_turbine_blade
	name = "turbine blade"
	desc = "A forged steel turbine blade. It has to be fitted into an open turbine section and welded in."
	// Временно: осколок из стока, окрашенный в сталь. Заменить своим.
	icon = 'icons/obj/materials/shards.dmi'
	icon_state = "shardsmall"
	color = "#9a9aa5"
	w_class = ITEM_SIZE_NORMAL
	/// Для какой секции подходит: NST_STAGE_HP (малая) или NST_STAGE_LP1 (большая, подходит обеим секциям низкого давления).
	var/blade_stage = NST_STAGE_HP

/obj/item/submarine_turbine_blade/small
	name = "small turbine blade"
	desc = "A short forged steel blade for a high-pressure turbine section. It has to be fitted into an open section and welded in."
	icon_state = "shardsmall"
	// Цена в автолате берётся из matter с наценкой FABRICATOR_EXTRA_COST_FACTOR, поэтому делим на неё, чтобы вышло ровно NST_BLADE_STEEL_SMALL листов.
	matter = list(MATERIAL_STEEL = (SHEET_MATERIAL_AMOUNT * NST_BLADE_STEEL_SMALL / FABRICATOR_EXTRA_COST_FACTOR))
	blade_stage = NST_STAGE_HP

/obj/item/submarine_turbine_blade/large
	name = "large turbine blade"
	desc = "A long forged steel blade for a low-pressure turbine section. It has to be fitted into an open section and welded in."
	icon_state = "shardlarge"
	w_class = ITEM_SIZE_LARGE
	matter = list(MATERIAL_STEEL = (SHEET_MATERIAL_AMOUNT * NST_BLADE_STEEL_LARGE / FABRICATOR_EXTRA_COST_FACTOR))
	blade_stage = NST_STAGE_LP1

/datum/fabricator_recipe/engineering/turbine_blade_small
	path = /obj/item/submarine_turbine_blade/small

/datum/fabricator_recipe/engineering/turbine_blade_large
	path = /obj/item/submarine_turbine_blade/large

// ----------------------------------------------------------------------------
// СЕКЦИЯ: ОБСЛУЖИВАНИЕ
// ----------------------------------------------------------------------------

/obj/machinery/atmospherics/binary/submarine_turbine_section
	/// TRUE, пока крышка секции снята для обслуживания: секция не работает.
	var/cover_open = FALSE
	/// Сколько новых лопастей вставлено, но ещё не приварено.
	var/unwelded = 0
	/// Перестройка разрушенной секции: обломки вырезаны.
	var/wreck_cleared = FALSE
	/// Перестройка: сколько листов стали уже внесено.
	var/rebuild_steel = 0
	/// Перестройка: сколько лопастей вставлено.
	var/rebuild_blades = 0
	/// Перестройка: есть ли труба.
	var/rebuild_pipe = FALSE
	/// Перестройка: стоит ли сканирующий модуль.
	var/rebuild_sensor = FALSE

/// Генератор этой турбины (по turbine_id), нужен, чтобы знать обороты вала.
/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/find_generator()
	for(var/obj/machinery/power/submarine_turbine_generator/G in GLOB.submarine_turbines)
		if(G.turbine_id == turbine_id)
			return G

/// Какая лопасть подходит секции.
/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/blade_kind()
	return (stage == NST_STAGE_HP) ? NST_STAGE_HP : NST_STAGE_LP1

/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/rebuild_steel_needed()
	return (stage == NST_STAGE_HP) ? NST_REBUILD_STEEL_HP : NST_REBUILD_STEEL_LP

/// Перестройка: чего ещё не хватает (текст), пустая строка, если всё есть.
/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/rebuild_missing()
	var/list/missing = list()
	var/steel_left = rebuild_steel_needed() - rebuild_steel
	if(steel_left > 0)
		missing += "[steel_left] more steel"
	if(rebuild_blades < NST_ROWS)
		missing += "[NST_ROWS - rebuild_blades] more [stage == NST_STAGE_HP ? "small" : "large"] blade(s)"
	if(!rebuild_pipe)
		missing += "a pipe"
	if(!rebuild_sensor)
		missing += "a scanning module"
	return english_list(missing, "", " and ", ", ")

/// Описание секции при осмотре зависит от состояния обслуживания.
/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/update_service_desc()
	var/base = initial(desc)
	if(broken)
		if(!wreck_cleared)
			desc = "[base] It is a wreck: the rotor is torn apart. Cut the wreckage out with a welder to start rebuilding it."
		else
			var/missing = rebuild_missing()
			desc = missing ? "[base] The wreckage is cut out. To rebuild it you still need: [missing]. Then weld it all together." : "[base] Everything for the rebuild is in place. Weld it all together."
	else if(cover_open)
		desc = "[base] Its inspection cover is off, so the blade rows show[unwelded ? ". New blades are only tacked in place, they need welding" : ""]. Use a wrench to put the cover back."
	else
		desc = base

/// Крышку можно снять только с остановленной секции без давления.
/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/service_safe(mob/user)
	var/obj/machinery/power/submarine_turbine_generator/G = find_generator()
	if(G && G.rpm >= NST_SERVICE_STOP_RPM)
		to_chat(user, SPAN_WARNING("The shaft is still turning ([round(G.rpm)] rpm). Wait for it to stop."))
		return FALSE
	var/pressure = max(air1.return_pressure(), air2.return_pressure())
	if(pressure > NST_SERVICE_MAX_KPA)
		to_chat(user, SPAN_WARNING("The section is still under pressure ([round(pressure / NSR_KPA_PER_BAR, 0.1)] bar). Bleed the steam off first."))
		return FALSE
	return TRUE

/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/toggle_cover(mob/user)
	if(cover_open)
		if(unwelded > 0)
			to_chat(user, SPAN_WARNING("The new blades are only tacked in place. Weld them first."))
			return TRUE
		user.visible_message(SPAN_NOTICE("\The [user] starts bolting the cover back onto \the [src]."))
		if(!do_after(user, NST_TIME_COVER, src) || !cover_open)
			return TRUE
		cover_open = FALSE
		update_service_desc()
		user.visible_message(SPAN_NOTICE("\The [user] bolts the cover back onto \the [src]."))
		playsound(src, NS_SND_WRENCH, 50, TRUE)
		return TRUE
	if(!service_safe(user))
		return TRUE
	user.visible_message(SPAN_NOTICE("\The [user] starts unbolting the cover of \the [src]."))
	if(!do_after(user, NST_TIME_COVER, src) || cover_open || !service_safe(user))
		return TRUE
	cover_open = TRUE
	update_service_desc()
	user.visible_message(SPAN_NOTICE("\The [user] unbolts the cover of \the [src] and lifts it off."))
	playsound(src, NS_SND_WRENCH, 50, TRUE)
	return TRUE

/// Пока крышка снята, секция не работает, а пар, который в неё всё же пустили, уходит в помещение.
/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/vent_open_cover(dt)
	var/turf/here = get_turf(src)
	if(!here)
		return
	var/ratio = min(1, NST_COVER_LEAK * dt)
	if(air1.total_moles > 0)
		var/datum/gas_mixture/spill_in = air1.remove_ratio(ratio)
		if(spill_in)
			here.assume_air(spill_in)
			if(network1)
				network1.update = 1
	if(air2.total_moles > 0)
		var/datum/gas_mixture/spill_out = air2.remove_ratio(ratio)
		if(spill_out)
			here.assume_air(spill_out)
			if(network2)
				network2.update = 1

/// Вставляет лопасть вместо самого изношенного ряда (при снятой крышке).
/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/fit_blade(obj/item/submarine_turbine_blade/blade, mob/user)
	if(!cover_open)
		to_chat(user, SPAN_WARNING("The cover is on. Unbolt it with a wrench first."))
		return TRUE
	if(blade.blade_stage != blade_kind())
		to_chat(user, SPAN_WARNING("That blade does not fit here: this section takes [stage == NST_STAGE_HP ? "small" : "large"] blades."))
		return TRUE
	var/worst = 0
	var/lowest = NST_BLADE_WORN
	for(var/i = 1 to NST_ROWS)
		if(rows[i] < lowest)
			lowest = rows[i]
			worst = i
	if(!worst)
		to_chat(user, SPAN_NOTICE("All the blade rows of \the [src] are in good shape, there is nothing to replace."))
		return TRUE
	user.visible_message(SPAN_NOTICE("\The [user] starts fitting a new blade into row [worst] of \the [src]."))
	if(!do_after(user, NST_TIME_BLADE, src) || !cover_open || rows[worst] >= NST_BLADE_WORN)
		return TRUE
	if(!user.unEquip(blade, src))
		return TRUE
	qdel(blade)
	rows[worst] = 1
	unwelded++
	update_health()
	update_service_desc()
	user.visible_message(SPAN_NOTICE("\The [user] fits a new blade into row [worst] of \the [src]."))
	to_chat(user, SPAN_NOTICE("The blade is only tacked in place. Weld it before closing the cover."))
	return TRUE

/// Приваривает вставленные лопасти.
/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/weld_blades(obj/item/tool, mob/user)
	if(!cover_open || unwelded <= 0)
		return FALSE
	var/obj/item/weldingtool/welder = tool
	if(!welder.remove_fuel(2, user))
		return TRUE
	user.visible_message(SPAN_NOTICE("\The [user] starts welding the new blades of \the [src] in place."))
	playsound(src, NS_SND_WELD, 50, TRUE)
	if(!do_after(user, NST_TIME_WELD, src) || !cover_open || unwelded <= 0)
		return TRUE
	unwelded = 0
	update_service_desc()
	user.visible_message(SPAN_NOTICE("\The [user] welds the new blades of \the [src] in place."))
	return TRUE

/// Все работы с секцией: крышка, лопасти, сварка, перестройка. Возвращает TRUE, если инструмент использован.
/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/service_tool(obj/item/tool, mob/living/user)
	if(broken)
		return rebuild_tool(tool, user)
	if(isWrench(tool))
		return toggle_cover(user)
	if(istype(tool, /obj/item/submarine_turbine_blade))
		return fit_blade(tool, user)
	if(isWelder(tool))
		return weld_blades(tool, user)
	return FALSE

/// Перестройка разрушенной секции. Любой порядок, кроме двух: обломки вырезаются первыми, сварка в конце.
/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/rebuild_tool(obj/item/tool, mob/living/user)
	if(isWelder(tool))
		var/obj/item/weldingtool/welder = tool
		if(!wreck_cleared)
			if(!welder.remove_fuel(3, user))
				return TRUE
			user.visible_message(SPAN_NOTICE("\The [user] starts cutting the wreckage out of \the [src]."))
			playsound(src, NS_SND_WELD, 50, TRUE)
			if(!do_after(user, NST_TIME_CUT_WRECK, src) || wreck_cleared)
				return TRUE
			wreck_cleared = TRUE
			update_service_desc()
			user.visible_message(SPAN_NOTICE("\The [user] cuts the wreckage out of \the [src]."))
			to_chat(user, SPAN_NOTICE("To rebuild it you still need: [rebuild_missing()]. Then weld it all together."))
			return TRUE
		var/missing = rebuild_missing()
		if(missing)
			to_chat(user, SPAN_WARNING("The section is not ready to be welded together. Still missing: [missing]."))
			return TRUE
		if(!welder.remove_fuel(5, user))
			return TRUE
		user.visible_message(SPAN_NOTICE("\The [user] starts welding the rebuilt rotor of \the [src] together."))
		playsound(src, NS_SND_WELD, 50, TRUE)
		if(!do_after(user, NST_TIME_REBUILD_FINAL, src) || !broken || rebuild_missing())
			return TRUE
		finish_rebuild()
		user.visible_message(SPAN_NOTICE("\The [user] finishes rebuilding \the [src]."))
		return TRUE
	// Всё остальное принимается только после того, как обломки вырезаны.
	var/is_steel = FALSE
	if(istype(tool, /obj/item/stack/material))
		var/obj/item/stack/material/sheet = tool
		is_steel = (sheet.material && sheet.material.name == MATERIAL_STEEL && !sheet.reinf_material)
	var/is_blade = istype(tool, /obj/item/submarine_turbine_blade)
	var/is_pipe = istype(tool, /obj/item/pipe)
	var/is_sensor = istype(tool, /obj/item/stock_parts/scanning_module)
	if(!is_steel && !is_blade && !is_pipe && !is_sensor)
		return FALSE
	if(!wreck_cleared)
		to_chat(user, SPAN_WARNING("The wreckage is still in the way. Cut it out with a welder first."))
		return TRUE
	if(is_steel)
		var/need = rebuild_steel_needed() - rebuild_steel
		if(need <= 0)
			to_chat(user, SPAN_NOTICE("\The [src] already has all the steel it needs."))
			return TRUE
		var/obj/item/stack/material/steel_stack = tool
		var/amount = min(need, steel_stack.get_amount())
		user.visible_message(SPAN_NOTICE("\The [user] starts laying steel into \the [src]."))
		if(!do_after(user, NST_TIME_REBUILD_PART, src) || !steel_stack.use(amount))
			return TRUE
		rebuild_steel += amount
	else if(is_blade)
		var/obj/item/submarine_turbine_blade/blade = tool
		if(blade.blade_stage != blade_kind())
			to_chat(user, SPAN_WARNING("That blade does not fit here: this section takes [stage == NST_STAGE_HP ? "small" : "large"] blades."))
			return TRUE
		if(rebuild_blades >= NST_ROWS)
			to_chat(user, SPAN_NOTICE("\The [src] already has all [NST_ROWS] blade rows."))
			return TRUE
		user.visible_message(SPAN_NOTICE("\The [user] starts fitting a blade into the rotor of \the [src]."))
		if(!do_after(user, NST_TIME_REBUILD_PART, src) || !user.unEquip(blade, src))
			return TRUE
		qdel(blade)
		rebuild_blades++
	else if(is_pipe)
		if(rebuild_pipe)
			to_chat(user, SPAN_NOTICE("\The [src] already has its pipe."))
			return TRUE
		user.visible_message(SPAN_NOTICE("\The [user] starts fitting a pipe into \the [src]."))
		if(!do_after(user, NST_TIME_REBUILD_PART, src) || !user.unEquip(tool, src))
			return TRUE
		qdel(tool)
		rebuild_pipe = TRUE
	else
		if(rebuild_sensor)
			to_chat(user, SPAN_NOTICE("\The [src] already has a scanning module."))
			return TRUE
		user.visible_message(SPAN_NOTICE("\The [user] starts installing a scanning module into \the [src]."))
		if(!do_after(user, NST_TIME_REBUILD_PART, src) || !user.unEquip(tool, src))
			return TRUE
		qdel(tool)
		rebuild_sensor = TRUE
	update_service_desc()
	var/missing = rebuild_missing()
	to_chat(user, missing ? SPAN_NOTICE("Still needed: [missing].") : SPAN_NOTICE("Everything is in place. Weld it all together."))
	return TRUE

/// Секция перестроена: все ряды новые, датчик стоит, пар снова идёт.
/obj/machinery/atmospherics/binary/submarine_turbine_section/proc/finish_rebuild()
	broken = FALSE
	for(var/i = 1 to NST_ROWS)
		rows[i] = 1
	update_health()
	has_sensor = TRUE
	wreck_cleared = FALSE
	rebuild_steel = 0
	rebuild_blades = 0
	rebuild_pipe = FALSE
	rebuild_sensor = FALSE
	unwelded = 0
	cover_open = FALSE
	color = initial(color)
	update_service_desc()
	playsound(src, NS_SND_BUILT, 50, TRUE)

// ----------------------------------------------------------------------------
// ГЕНЕРАТОР: ПЕРЕГРУЗКА И РЕМОНТ
// ----------------------------------------------------------------------------

/obj/machinery/power/submarine_turbine_generator
	/// TRUE, если генератор перегружен (секцию разрушило под нагрузкой): автомат не включается, пока его не починят.
	var/overloaded = FALSE
	/// Сколько конденсаторов уже вставлено в ремонт.
	var/repair_caps = 0

/// Генератор сгорел от скачка: выдача невозможна, пока не починят.
/obj/machinery/power/submarine_turbine_generator/proc/overload()
	if(overloaded)
		return
	overloaded = TRUE
	repair_caps = 0
	visible_message(SPAN_DANGER("The generator windings flash over and \the [src] goes dead with a smell of burnt insulation!"))
	playsound(src, NS_SND_SPARKS, 70, TRUE)

/// Текст для пульта и осмотра: что нужно для ремонта.
/obj/machinery/power/submarine_turbine_generator/proc/repair_missing()
	var/list/missing = list()
	if(repair_caps < NST_GEN_REPAIR_CAPS)
		missing += "[NST_GEN_REPAIR_CAPS - repair_caps] more capacitor(s)"
	missing += "[NST_GEN_REPAIR_WIRE] pieces of cable"
	return english_list(missing, "", " and ", ", ")

/obj/machinery/power/submarine_turbine_generator/use_tool(obj/item/tool, mob/living/user, list/click_params)
	if(overloaded)
		if(istype(tool, /obj/item/stock_parts/capacitor))
			if(repair_caps >= NST_GEN_REPAIR_CAPS)
				to_chat(user, SPAN_NOTICE("The generator has all the capacitors it needs. It needs [NST_GEN_REPAIR_WIRE] pieces of cable now."))
				return TRUE
			user.visible_message(SPAN_NOTICE("\The [user] starts swapping a burnt capacitor in \the [src]."))
			if(!do_after(user, NST_TIME_GEN_REPAIR, src) || !overloaded || !user.unEquip(tool, src))
				return TRUE
			qdel(tool)
			repair_caps++
			to_chat(user, SPAN_NOTICE("Still needed: [repair_missing()]."))
			return TRUE
		if(isCoil(tool))
			if(repair_caps < NST_GEN_REPAIR_CAPS)
				to_chat(user, SPAN_WARNING("Swap the burnt capacitors first. Still needed: [repair_missing()]."))
				return TRUE
			var/obj/item/stack/cable_coil/coil = tool
			if(coil.get_amount() < NST_GEN_REPAIR_WIRE)
				to_chat(user, SPAN_WARNING("You need [NST_GEN_REPAIR_WIRE] pieces of cable to rewind the windings."))
				return TRUE
			user.visible_message(SPAN_NOTICE("\The [user] starts rewinding the windings of \the [src]."))
			if(!do_after(user, NST_TIME_GEN_REPAIR, src) || !overloaded || !coil.use(NST_GEN_REPAIR_WIRE))
				return TRUE
			overloaded = FALSE
			repair_caps = 0
			user.visible_message(SPAN_NOTICE("\The [user] rewinds the windings of \the [src]. It hums again."))
			playsound(src, NS_SND_BUILT, 50, TRUE)
			return TRUE
	return ..()

// ----------------------------------------------------------------------------
// ВЛАГООТДЕЛИТЕЛЬ (уровень Б)
// ----------------------------------------------------------------------------

/// Влагоотделитель: ставится вместо куска паровой трубы между секцией высокого давления и первой низкого. Сам пар не меняет
/// (это обычная труба), но от него зависит эрозия лопастей низкого давления: чистый снижает её, а засорённый слив делает хуже, чем без него.
/// Слив засоряется, пока турбина работает; чистится отвёрткой, когда в трубе нет давления.
/obj/machinery/atmospherics/pipe/simple/visible/submarine_separator
	name = "moisture separator"
	desc = "A pipe section that catches water droplets out of the steam between the high-pressure and the low-pressure turbine. Its drain gets clogged with scale and needs cleaning with a screwdriver."
	/// Метка турбины. Должна совпадать с turbine_id генератора.
	var/turbine_id = "main"
	/// Засорение слива, 0-1.
	var/clog = 0

/// Множитель эрозии лопастей низкого давления с этим влагоотделителем.
/obj/machinery/atmospherics/pipe/simple/visible/submarine_separator/proc/wet_mult()
	return NST_SEP_WET_CLEAN + (NST_SEP_WET_CLOGGED - NST_SEP_WET_CLEAN) * clamp(clog, 0, 1)

/// Слив засоряется, пока вал крутится.
/obj/machinery/atmospherics/pipe/simple/visible/submarine_separator/proc/age(dt, rpm_now)
	if(rpm_now >= NST_EROSION_MIN_RPM)
		clog = min(1, clog + NST_SEP_CLOG_RATE * dt)

/obj/machinery/atmospherics/pipe/simple/visible/submarine_separator/use_tool(obj/item/tool, mob/living/user, list/click_params)
	if(isScrewdriver(tool))
		var/pressure = parent ? parent.air.return_pressure() : 0
		if(pressure > NST_SERVICE_MAX_KPA)
			to_chat(user, SPAN_WARNING("The drain cover is under pressure ([round(pressure / NSR_KPA_PER_BAR, 0.1)] bar). Bleed the steam off first."))
			return TRUE
		if(clog <= 0.01)
			to_chat(user, SPAN_NOTICE("The drain of \the [src] is clean."))
			return TRUE
		user.visible_message(SPAN_NOTICE("\The [user] starts cleaning the drain of \the [src]."))
		if(!do_after(user, NST_TIME_SEP_CLEAN, src))
			return TRUE
		clog = 0
		user.visible_message(SPAN_NOTICE("\The [user] cleans the drain of \the [src]."))
		return TRUE
	return ..()

/obj/machinery/atmospherics/pipe/simple/visible/submarine_separator/examine(mob/user, distance, infix, suffix)
	. = ..()
	if(distance <= 2)
		to_chat(user, "Its drain looks [clog < 0.25 ? "clean" : (clog < 0.6 ? "partly clogged" : "badly clogged")].")

/obj/machinery/power/submarine_turbine_generator
	/// Влагоотделитель этой турбины (если стоит), его находим сами.
	var/obj/machinery/atmospherics/pipe/simple/visible/submarine_separator/separator
	var/next_separator_scan = 0

/// Ищет влагоотделитель рядом (раз в 10 секунд, пока не нашли) и обновляет множитель влажности. Зовётся каждый такт турбины.
/obj/machinery/power/submarine_turbine_generator/proc/update_separator(dt, rpm_now)
	if(separator && QDELETED(separator))
		separator = null
	if(!separator && world.time >= next_separator_scan)
		next_separator_scan = world.time + 10 SECONDS
		for(var/obj/machinery/atmospherics/pipe/simple/visible/submarine_separator/P in range(NST_LINK_RANGE, src))
			if(P.turbine_id == turbine_id)
				separator = P
				break
	if(separator)
		separator.age(dt, rpm_now)
		wet_mult = separator.wet_mult()
	else
		wet_mult = 1
