/*
	ДОБЫЧА И ОБОГАЩЕНИЕ ТОПЛИВА (ревизия 25).

	Цепочка по решению автора (16-17.11): сырьё берут со дна океана, а центрифуга делает из него ТВЭЛы. Работают с ним исследователи
	и логисты. Пока этих отделов нет, оба станка стоят в мастерской (карта ns13) и рядом с ядром (лаборатория).

	- /obj/machinery/submarine_dredge: донный сборщик. Включённый (и питаемый) копит конкреции в бункере: одна штука раз в
	  NSR_DREDGE_PERIOD секунд, тип выпадает по весам из nsr_ore_types (урана больше всего, цезия мало). Бункер на NSR_DREDGE_CAPACITY штук,
	  полный бункер выключает станок. Содержимое достаётся мешком (/obj/item/submarine_ore_sack). ЗАГЛУШКА: сборщик пока не привязан к
	  глубине и дну (нет состояния «лодка на грунте» или манипулятора ROV), он просто работает от питания.
	- /obj/item/submarine_ore_sack: мешок с конкрециями по типам. Высыпается в центрифугу кликом.
	- /obj/machinery/submarine_centrifuge: центрифуга. Запас по типам (до NSR_CENTRIFUGE_ORE_MAX), по рецепту из nsr_centrifuge_recipes
	  делает ТВЭЛ нужного изотопа за заданное время (на питании), ТВЭЛ выходит перед станком (по его dir).
	- Окна обоих станков общие: nano/templates/submarine_machine_panel.tmpl. Тексты приходят из кода уже на языке игрока (nsr_tr),
	  поэтому шаблон один на оба языка.

	Баланс (цифры в таблицах ниже, подберём по игре): один сборщик даёт 3 конкреции в минуту, урана из них 1,8. Обогащённый ТВЭЛ стоит 5
	конкреций урана (около 2,8 минуты сборщика) и 90 секунд центрифуги; ядро из четырёх таких ТВЭЛов живёт 10 минут на полных стержнях,
	то есть на полной мощности один сборщик поддерживает почти весь расход, на половинной мощности есть запас.
*/

#define NSR_DREDGE_PERIOD        20      // с: одна конкреция
#define NSR_DREDGE_CAPACITY      15      // конкреций в бункере
#define NSR_DREDGE_POWER         6000    // Вт, пока сборщик работает
#define NSR_CENTRIFUGE_POWER     5000    // Вт, пока центрифуга крутит
#define NSR_CENTRIFUGE_ORE_MAX   30      // конкреций каждого типа в запасе центрифуги

/// Типы конкреций: ключ - тип. weight: вес выпадения в сборщике, name/ru: название для окна, color: оттенок мешка.
var/global/list/nsr_ore_types = list(
	"uranium" = list("name" = "uranium nodules", "ru" = "урановые конкреции", "color" = "#9bbf5a", "weight" = 60),
	"thorium" = list("name" = "thorium nodules", "ru" = "ториевые конкреции", "color" = "#d8c26a", "weight" = 30),
	"cesium" = list("name" = "cesium nodules", "ru" = "цезиевые конкреции", "color" = "#79c7e8", "weight" = 10)
)

/// Рецепты центрифуги по порядку кнопок. ore: тип сырья, cost: сколько конкреций, time: секунд.
var/global/list/nsr_centrifuge_recipes = list(
	list("id" = "natural", "ore" = "uranium", "cost" = 2, "time" = 30, "product" = /obj/item/submarine_fuel_element/natural, "name" = "Natural uranium", "ru" = "Природный уран"),
	list("id" = "enriched", "ore" = "uranium", "cost" = 5, "time" = 90, "product" = /obj/item/submarine_fuel_element, "name" = "Enriched uranium", "ru" = "Обогащённый уран"),
	list("id" = "thorium", "ore" = "thorium", "cost" = 3, "time" = 45, "product" = /obj/item/submarine_fuel_element/thorium, "name" = "Thorium", "ru" = "Торий"),
	list("id" = "cesium", "ore" = "cesium", "cost" = 3, "time" = 45, "product" = /obj/item/submarine_fuel_element/cesium, "name" = "Cesium", "ru" = "Цезий")
)

/// Название типа сырья на языке игрока (nsr_lang_for() уже вызвана).
/proc/nsr_ore_name(ore)
	var/list/info = nsr_ore_types[ore]
	return info ? nsr_tr(info["name"], info["ru"]) : ore

/// Строка вида «5 урановые конкреции, 2 ториевые конкреции» по списку количеств, или «пусто».
/proc/nsr_ore_summary(list/counts)
	var/list/parts = list()
	for(var/ore in nsr_ore_types)
		if(counts[ore] > 0)
			parts += "[counts[ore]] [nsr_ore_name(ore)]"
	return length(parts) ? jointext(parts, ", ") : nsr_tr("nothing", "ничего")

/// Один «ряд» окна: подпись, текст, цвет (good, average, bad или пусто).
/proc/nsr_row(label, text, cls = "")
	return list("label" = label, "text" = text, "cls" = cls)

/// Одна кнопка окна: подпись, действие, аргумент, недоступна ли, нажата ли.
/proc/nsr_button(label, action, arg = "", disabled = FALSE, selected = FALSE)
	return list("label" = label, "action" = action, "arg" = arg, "disabled" = disabled, "selected" = selected)


// ---------------------------------------------------------------- мешок

/obj/item/submarine_ore_sack
	name = "nodule sack"
	desc = "A sack of seabed nodules."
	// Временно: комок руды из стока, окрашенный в цвет сырья. Заменить своим.
	icon = 'icons/obj/materials/ore.dmi'
	icon_state = "lump"
	color = "#7f8a66"
	w_class = ITEM_SIZE_NORMAL
	/// Тип сырья -> сколько конкреций в мешке.
	var/list/ore

/obj/item/submarine_ore_sack/Initialize()
	. = ..()
	if(!ore)
		ore = list()
	for(var/type in nsr_ore_types)
		if(isnull(ore[type]))
			ore[type] = 0
	update_label()

/obj/item/submarine_ore_sack/proc/total()
	var/sum = 0
	for(var/type in ore)
		sum += ore[type]
	return sum

/obj/item/submarine_ore_sack/proc/update_label()
	SetName("nodule sack ([total()])")
	var/list/parts = list()
	for(var/type in nsr_ore_types)
		if(ore[type] > 0)
			var/list/info = nsr_ore_types[type]
			parts += "[ore[type]] [info["name"]]"
	desc = "A sack of seabed nodules: [length(parts) ? jointext(parts, ", ") : "empty"]. Pour it into the isotope centrifuge."


/// Для карт-полигонов: мешок с запасом конкреций, чтобы проверить центрифугу, не ждать сборщика.
/obj/item/submarine_ore_sack/test
	ore = list("uranium" = 12, "thorium" = 6, "cesium" = 4)

// ---------------------------------------------------------------- донный сборщик

/obj/machinery/submarine_dredge
	name = "seabed dredge"
	desc = "A suction manipulator on the keel hatch. While it runs it rakes nodules off the seabed into its hopper. Touch it for the controls."
	// Временно: голова бура из стока, окрашенная в синий. Заменить своим.
	icon = 'icons/obj/machines/mining/mining_drill.dmi'
	icon_state = "mining_drill"
	color = "#6f9fb3"
	density = TRUE
	anchored = TRUE
	construct_state = null
	uncreated_component_parts = null
	use_power = POWER_USE_IDLE
	idle_power_usage = 30
	active_power_usage = NSR_DREDGE_POWER
	power_channel = EQUIP
	interact_offline = TRUE
	/// Включён ли сборщик (он может стоять без питания, тогда не собирает).
	var/running = FALSE
	/// Секунды до следующей конкреции.
	var/progress = 0
	/// Тип сырья -> сколько конкреций в бункере.
	var/list/hopper

/obj/machinery/submarine_dredge/Initialize()
	. = ..()
	hopper = list()
	for(var/type in nsr_ore_types)
		hopper[type] = 0

/obj/machinery/submarine_dredge/proc/hopper_total()
	var/sum = 0
	for(var/type in hopper)
		sum += hopper[type]
	return sum

/obj/machinery/submarine_dredge/proc/set_running(state)
	running = state
	if(!running)
		progress = 0
	update_use_power(running ? POWER_USE_ACTIVE : POWER_USE_IDLE)
	update_icon()

/obj/machinery/submarine_dredge/on_update_icon()
	icon_state = (running && !inoperable()) ? "mining_drill_active" : "mining_drill"

/obj/machinery/submarine_dredge/Process(wait)
	if(!running || inoperable())
		return
	if(hopper_total() >= NSR_DREDGE_CAPACITY)
		set_running(FALSE)
		visible_message(SPAN_NOTICE("\The [src] shuts down: the hopper is full."))
		SSnano.update_uis(src)
		return
	progress += clamp(wait / 10, 0.5, 5)
	var/changed = FALSE
	while(progress >= NSR_DREDGE_PERIOD && hopper_total() < NSR_DREDGE_CAPACITY)
		progress -= NSR_DREDGE_PERIOD
		var/list/weights = list()
		for(var/type in nsr_ore_types)
			var/list/info = nsr_ore_types[type]
			weights[type] = info["weight"]
		hopper[pickweight(weights)]++
		changed = TRUE
	if(changed)
		SSnano.update_uis(src)

/obj/machinery/submarine_dredge/interface_interact(mob/user)
	ui_interact(user)
	return TRUE

/obj/machinery/submarine_dredge/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = 1)
	nsr_lang_for(user)
	var/list/data = build_ui_data()
	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "submarine_machine_panel.tmpl", nsr_tr("Seabed dredge", "Донный сборщик"), 460, 360)
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(1)

/obj/machinery/submarine_dredge/proc/build_ui_data()
	var/list/data = list()
	data["langLabel"] = nsr_tr("Русский", "English")
	data["title"] = nsr_tr("Seabed dredge", "Донный сборщик")
	data["note"] = nsr_tr("It rakes nodules off the seabed while it runs: one every [NSR_DREDGE_PERIOD] s, mostly uranium, less thorium, rarely cesium. Take them out as a sack and pour the sack into the isotope centrifuge.", \
		"Пока работает, сгребает со дна конкреции: одну раз в [NSR_DREDGE_PERIOD] с, больше всего урана, меньше тория, редко цезия. Достаньте их мешком и высыпьте мешок в центрифугу изотопов.")
	var/list/rows = list()
	var/status_text
	var/status_class
	if(!running)
		status_text = nsr_tr("STOPPED", "ВЫКЛЮЧЕН")
		status_class = "average"
	else if(inoperable())
		status_text = nsr_tr("NO POWER", "НЕТ ПИТАНИЯ")
		status_class = "bad"
	else
		status_text = nsr_tr("DREDGING", "СБОР")
		status_class = "good"
	rows += list(nsr_row(nsr_tr("Status:", "Состояние:"), status_text, status_class))
	var/total = hopper_total()
	rows += list(nsr_row(nsr_tr("Hopper:", "Бункер:"), "[total] / [NSR_DREDGE_CAPACITY]", (total >= NSR_DREDGE_CAPACITY) ? "bad" : ""))
	rows += list(nsr_row(nsr_tr("Contents:", "Содержимое:"), nsr_ore_summary(hopper)))
	if(running && !inoperable() && total < NSR_DREDGE_CAPACITY)
		data["hasProgress"] = TRUE
		data["progress"] = round(100 * progress / NSR_DREDGE_PERIOD)
		data["progressLabel"] = nsr_tr("Next nodule:", "Следующая конкреция:")
	else
		data["hasProgress"] = FALSE
	data["rows"] = rows
	data["buttons"] = list(
		nsr_button(running ? nsr_tr("Stop", "Остановить") : nsr_tr("Start", "Запустить"), "toggle", "", (!running && total >= NSR_DREDGE_CAPACITY), running),
		nsr_button(nsr_tr("Take everything out (sack)", "Достать всё (мешок)"), "take", "", total <= 0)
	)
	return data

/obj/machinery/submarine_dredge/OnTopic(mob/user, href_list, datum/topic_state/state)
	var/action = href_list["action"]
	nsr_lang_for(user)
	if(action == "lang")
		nsr_lang_toggle(user)
		SSnano.close_user_uis(user, src, "main")
		ui_interact(user)
		return TOPIC_HANDLED
	if(action == "toggle")
		if(!running && hopper_total() >= NSR_DREDGE_CAPACITY)
			to_chat(user, SPAN_WARNING(nsr_tr("The hopper is full. Take the nodules out first.", "Бункер полон. Сначала достаньте конкреции.")))
			return TOPIC_HANDLED
		set_running(!running)
		return TOPIC_REFRESH
	if(action == "take")
		if(hopper_total() <= 0)
			return TOPIC_HANDLED
		var/obj/item/submarine_ore_sack/sack = new(get_turf(user))
		for(var/type in nsr_ore_types)
			sack.ore[type] = hopper[type]
			hopper[type] = 0
		sack.update_label()
		user.put_in_hands(sack)
		to_chat(user, SPAN_NOTICE(nsr_tr("You pour the hopper into a sack.", "Вы высыпаете бункер в мешок.")))
		return TOPIC_REFRESH
	return TOPIC_NOACTION


// ---------------------------------------------------------------- центрифуга

/obj/machinery/submarine_centrifuge
	name = "isotope centrifuge"
	desc = "A cascade of ultracentrifuges that cleans seabed nodules, spins the isotopes apart and casts TVEL fuel elements. Pour a nodule sack into it; the fuel element comes out in front."
	// Временно: печь из стока, окрашенная в серо-стальной. Заменить своим.
	icon = 'icons/obj/machines/mining/mining_machines.dmi'
	icon_state = "furnace_0"
	color = "#8aa6b8"
	density = TRUE
	anchored = TRUE
	construct_state = null
	uncreated_component_parts = null
	use_power = POWER_USE_IDLE
	idle_power_usage = 50
	active_power_usage = NSR_CENTRIFUGE_POWER
	power_channel = EQUIP
	interact_offline = TRUE
	/// Тип сырья -> запас в центрифуге.
	var/list/stock
	/// id рецепта в работе или null.
	var/job
	/// Сколько секунд работает текущая партия и сколько ей нужно.
	var/progress = 0
	var/job_time = 0

/obj/machinery/submarine_centrifuge/Initialize()
	. = ..()
	stock = list()
	for(var/type in nsr_ore_types)
		stock[type] = 0

/obj/machinery/submarine_centrifuge/proc/get_recipe(id)
	for(var/list/recipe in nsr_centrifuge_recipes)
		if(recipe["id"] == id)
			return recipe

/obj/machinery/submarine_centrifuge/proc/set_job(id, time)
	job = id
	job_time = time
	progress = 0
	update_use_power(job ? POWER_USE_ACTIVE : POWER_USE_IDLE)
	update_icon()

/obj/machinery/submarine_centrifuge/on_update_icon()
	icon_state = (job && !inoperable()) ? "furnace_1" : "furnace_0"

/obj/machinery/submarine_centrifuge/use_tool(obj/item/tool, mob/user, click_params)
	if(istype(tool, /obj/item/submarine_ore_sack))
		nsr_lang_for(user)
		return load_sack(tool, user)
	return ..()

/// Высыпать мешок: сколько влезет по каждому типу, остаток остаётся в мешке.
/obj/machinery/submarine_centrifuge/proc/load_sack(obj/item/submarine_ore_sack/sack, mob/user)
	var/moved = 0
	for(var/type in nsr_ore_types)
		var/n = min(NSR_CENTRIFUGE_ORE_MAX - stock[type], sack.ore[type])
		if(n <= 0)
			continue
		stock[type] += n
		sack.ore[type] -= n
		moved += n
	if(!moved)
		to_chat(user, SPAN_WARNING(nsr_tr("Nothing goes in: the sack is empty or \the [src] is full of that material.", "Ничего не помещается: мешок пуст или центрифуга уже полна этого сырья.")))
		return TRUE
	user.visible_message(SPAN_NOTICE("\The [user] pours \a [sack] into \the [src]."))
	playsound(src, 'sound/effects/rustle1.ogg', 40, TRUE)
	sack.update_label()
	if(sack.total() <= 0)
		user.unEquip(sack)
		qdel(sack)
	SSnano.update_uis(src)
	ui_interact(user)
	return TRUE

/obj/machinery/submarine_centrifuge/proc/start_job(id, mob/user)
	if(job)
		return
	var/list/recipe = get_recipe(id)
	if(!recipe)
		return
	if(inoperable())
		to_chat(user, SPAN_WARNING(nsr_tr("\The [src] has no power.", "У центрифуги нет питания.")))
		return
	if(stock[recipe["ore"]] < recipe["cost"])
		to_chat(user, SPAN_WARNING(nsr_tr("Not enough nodules for that.", "Не хватает конкреций.")))
		return
	stock[recipe["ore"]] -= recipe["cost"]
	set_job(id, recipe["time"])

/obj/machinery/submarine_centrifuge/proc/cancel_job()
	var/list/recipe = get_recipe(job)
	if(recipe)
		stock[recipe["ore"]] = min(NSR_CENTRIFUGE_ORE_MAX, stock[recipe["ore"]] + recipe["cost"])
	set_job(null, 0)

/obj/machinery/submarine_centrifuge/proc/finish_job()
	var/list/recipe = get_recipe(job)
	set_job(null, 0)
	if(!recipe)
		return
	var/turf/out = get_step(src, dir)
	if(!out || out.density)
		out = get_turf(src)
	var/product_type = recipe["product"]
	new product_type(out)
	playsound(src, 'sound/machines/ping.ogg', 50, TRUE)
	visible_message(SPAN_NOTICE("\The [src] pings and pushes out a fuel element."))

/obj/machinery/submarine_centrifuge/Process(wait)
	if(!job)
		return
	if(inoperable())
		update_icon()
		return
	progress += clamp(wait / 10, 0.5, 5)
	if(progress >= job_time)
		finish_job()
	update_icon()
	SSnano.update_uis(src)

/obj/machinery/submarine_centrifuge/interface_interact(mob/user)
	ui_interact(user)
	return TRUE

/obj/machinery/submarine_centrifuge/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = 1)
	nsr_lang_for(user)
	var/list/data = build_ui_data()
	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "submarine_machine_panel.tmpl", nsr_tr("Isotope centrifuge", "Центрифуга изотопов"), 460, 420)
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(1)

/obj/machinery/submarine_centrifuge/proc/build_ui_data()
	var/list/data = list()
	data["langLabel"] = nsr_tr("Русский", "English")
	data["title"] = nsr_tr("Isotope centrifuge", "Центрифуга изотопов")
	data["note"] = nsr_tr("Pour a nodule sack into the machine (click it with the sack), then pick a product. The fuel element comes out in front of the machine. It needs power while it spins.", \
		"Высыпьте в машину мешок с конкрециями (кликните по ней мешком) и выберите продукт. ТВЭЛ выходит перед машиной. Пока крутит, нужно питание.")
	var/list/rows = list()
	var/list/recipe = job ? get_recipe(job) : null
	var/status_text
	var/status_class
	if(!job)
		status_text = nsr_tr("IDLE", "ЖДЁТ")
		status_class = "average"
	else if(inoperable())
		status_text = nsr_tr("NO POWER", "НЕТ ПИТАНИЯ")
		status_class = "bad"
	else
		status_text = nsr_tr("SPINNING: [recipe ? recipe["name"] : ""]", "КРУТИТ: [recipe ? recipe["ru"] : ""]")
		status_class = "good"
	rows += list(nsr_row(nsr_tr("Status:", "Состояние:"), status_text, status_class))
	for(var/type in nsr_ore_types)
		rows += list(nsr_row("[nsr_ore_name(type)]:", "[stock[type]] / [NSR_CENTRIFUGE_ORE_MAX]"))
	if(job)
		data["hasProgress"] = TRUE
		data["progress"] = round(100 * progress / max(1, job_time))
		data["progressLabel"] = nsr_tr("Batch:", "Партия:")
	else
		data["hasProgress"] = FALSE
	data["rows"] = rows
	var/list/buttons = list()
	for(var/list/r in nsr_centrifuge_recipes)
		var/label = nsr_tr("[r["name"]]: [r["cost"]] nodules, [r["time"]] s", "[r["ru"]]: [r["cost"]] конкр., [r["time"]] с")
		buttons += list(nsr_button(label, "make", r["id"], (job || stock[r["ore"]] < r["cost"]), (job == r["id"])))
	if(job)
		buttons += list(nsr_button(nsr_tr("Cancel the batch (nodules come back)", "Отменить партию (конкреции вернутся)"), "cancel"))
	data["buttons"] = buttons
	return data

/obj/machinery/submarine_centrifuge/OnTopic(mob/user, href_list, datum/topic_state/state)
	var/action = href_list["action"]
	nsr_lang_for(user)
	if(action == "lang")
		nsr_lang_toggle(user)
		SSnano.close_user_uis(user, src, "main")
		ui_interact(user)
		return TOPIC_HANDLED
	if(action == "make")
		start_job(href_list["arg"], user)
		return TOPIC_REFRESH
	if(action == "cancel")
		if(job)
			cancel_job()
		return TOPIC_REFRESH
	return TOPIC_NOACTION
