/*
	ФИЗИЧЕСКИЙ ПУЛЬТ ТУРБИНЫ (ревизии 34 и 36)

	Белый операторский стол с наклонной панелью, как в БЩУ настоящей станции: на нём настоящие кнопки, тумблеры, лампы и дисплей,
	а не окно на экране. Всё кликается мышью. Стол стоит на переднем плане зала, оператор встаёт в его подкову и смотрит на панель.

	Что есть:
	- корпус (/obj/structure/turbine_desk): кусок стола на 8 направлений, из них собирается подкова;
	- кнопки (/obj/structure/turbine_part/button): ПОДТВЕРДИТЬ ТРЕВОГИ, СБРОС СТОПОРНОГО КЛАПАНА, АВАРИЙНЫЙ ОСТАНОВ под защитной крышкой;
	- тумблеры (/obj/structure/turbine_part/toggle): АВТОМАТ ГЕНЕРАТОРА и РЕГУЛЯТОР ОБОРОТОВ, стоят вверху, когда включено;
	- лампы (/obj/structure/turbine_part/lamp): стопорный клапан закрыт, автомат замкнут, непринятая тревога (мигает), защита отключена;
	- дисплей (/obj/structure/turbine_part/display): обороты и мощность на самом экране, полные данные по клику.

	Всё проводное, электричество не нужно: как в БЩУ, где аварийные цепи работают от своего питания. Кнопки и тумблеры зовут те же процедуры
	генератора (act_ack, act_emergency_stop, reset_stop_valve, act_breaker_toggle, act_governor_toggle), что и окно пульта, поэтому поведение
	у обоих одинаковое. Всё привязано к турбине по turbine_id (по умолчанию "main", как у остальных частей турбины).

	Заглушить сирену здесь нет: у турбины сирены пока нет, есть только табло. Когда появится, кнопка встанет рядом с подтверждением.

	Спрайты. Корпус стола: icons/obj/structures/reactor_panel.dmi из NuPhase, без изменений (CC BY-SA 3.0).
	Кнопки и тумблеры: из NuPhase (icons/obj/power.dmi), в исходном размере, кнопки перекрашены. Лампы и дисплеи нарисованы для NS-13.
	Источник и лицензии: README, раздел «Заимствованные ресурсы».

	Как собирать стол на карте (раскладка NuPhase, подкова):
	  угол dir 6 (запад, pixel_x -2) | плиты dir 2 (с деталями) | угол dir 10 (восток)
	  крыло dir 4 (запад, pixel_x 8)                              крыло dir 8 (восток)
	У плит pixel_y = 6, у углов и крыльев pixel_y = 5. Детали ставятся на клетку плиты со своими pixel_x и pixel_y (-2 на наклонной панели).
*/

/// Корпус пульта. Сам ничего не делает: это мебель, на которой стоят детали.
/obj/structure/turbine_desk
	name = "control desk"
	desc = "A white operator's desk with a sloped panel for buttons and displays, like in the control room of a real power plant."
	icon = 'icons/obj/structures/reactor_panel.dmi'
	icon_state = ""
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	throwpass = TRUE
	layer = STRUCTURE_LAYER

// ----------------------------------------------------------------------------
// ОБЩАЯ ОСНОВА: всё, что стоит на столе
// ----------------------------------------------------------------------------

/// Общая основа кнопок, тумблеров, ламп и дисплея: метка турбины, поиск генератора, подпись на русском при осмотре,
/// обновление вида по таймеру, если деталь показывает состояние.
/obj/structure/turbine_part
	icon = 'icons/obj/submarine_controls.dmi'
	anchored = TRUE
	density = FALSE
	layer = ABOVE_WINDOW_LAYER
	/// Метка турбины, к которой привязана деталь. Должна совпадать с turbine_id генератора.
	var/turbine_id = "main"
	/// Описание на русском для осмотра (имя и описание в игре английские, как у остальных предметов).
	var/ru_desc = ""
	/// Показывает ли деталь состояние (лампы, дисплей, тумблеры): тогда она раз в такт SSobj зовёт refresh().
	var/shows_state = FALSE

/obj/structure/turbine_part/Initialize()
	. = ..()
	if(shows_state)
		START_PROCESSING(SSobj, src)

/obj/structure/turbine_part/Destroy()
	if(shows_state)
		STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/turbine_part/Process()
	refresh()

/// Подтянуть вид к текущему состоянию турбины. Подтипы с shows_state переопределяют.
/obj/structure/turbine_part/proc/refresh()
	return

/obj/structure/turbine_part/proc/find_unit()
	for(var/obj/machinery/power/submarine_turbine_generator/G in GLOB.submarine_turbines)
		if(G.turbine_id == turbine_id)
			return G

/obj/structure/turbine_part/examine(mob/user, distance)
	. = ..()
	nsr_lang_for(user)
	if(nsr_is_ru() && length(ru_desc))
		to_chat(user, ru_desc)

// ----------------------------------------------------------------------------
// КНОПКИ
// ----------------------------------------------------------------------------

/// Кнопка на столе. Подтипы задают действие в press().
/obj/structure/turbine_part/button
	name = "button"
	desc = "A hardwired control button."
	icon_state = "btn_red"
	/// Пауза между нажатиями, чтобы не стучали по кнопке десять раз в секунду.
	var/cooldown = 10
	var/next_press = 0

/obj/structure/turbine_part/button/attack_hand(mob/user)
	push(user)
	return TRUE

/// Любой предмет в руке это то же нажатие пальцем: бить кнопку нечем.
/obj/structure/turbine_part/button/use_tool(obj/item/tool, mob/living/user, list/click_params)
	SHOULD_CALL_PARENT(FALSE)
	push(user)
	return TRUE

/obj/structure/turbine_part/button/proc/push(mob/user)
	if(world.time < next_press)
		return
	next_press = world.time + cooldown
	nsr_lang_for(user)
	var/obj/machinery/power/submarine_turbine_generator/G = find_unit()
	playsound(src, pick('sound/machines/button1.ogg', 'sound/machines/button2.ogg', 'sound/machines/button3.ogg', 'sound/machines/button4.ogg'), 50, TRUE)
	if(!G)
		to_chat(user, SPAN_WARNING(nsr_tr("The button does nothing: there is no link to a turbine.", "Кнопка ничего не делает: нет связи с турбиной.")))
		return
	press(user, G)

/// Действие кнопки. Язык игрока уже выбран.
/obj/structure/turbine_part/button/proc/press(mob/user, obj/machinery/power/submarine_turbine_generator/G)
	return

/// Подтвердить тревоги табло (жёлтая).
/obj/structure/turbine_part/button/ack
	name = "ACKNOWLEDGE ALARMS button"
	desc = "A yellow button. Acknowledges the alarms on the turbine annunciator."
	ru_desc = "Жёлтая кнопка. Подтверждает тревоги на табло турбины."
	icon_state = "btn_amber"

/obj/structure/turbine_part/button/ack/press(mob/user, obj/machinery/power/submarine_turbine_generator/G)
	G.act_ack(user)

/// Сброс стопорного клапана после останова (зелёная).
/obj/structure/turbine_part/button/reset
	name = "STOP VALVE RESET button"
	desc = "A green button. Resets the turbine stop valve after a trip, once the shaft has slowed down and the condenser has cooled."
	ru_desc = "Зелёная кнопка. Сбрасывает стопорный клапан турбины после останова, когда вал замедлился, а конденсатор остыл."
	icon_state = "btn_green"

/obj/structure/turbine_part/button/reset/press(mob/user, obj/machinery/power/submarine_turbine_generator/G)
	if(G.reset_stop_valve(user))
		to_chat(user, SPAN_NOTICE(nsr_tr("The stop valve is reset.", "Стопорный клапан сброшен.")))

/// Аварийный останов под защитной крышкой (красная). Первый клик поднимает крышку, второй жмёт кнопку.
/// Alt-клик по кнопке опускает крышку обратно.
/obj/structure/turbine_part/button/stop
	name = "EMERGENCY STOP button"
	desc = "A big red button under a protective cover. Slams the turbine stop valve shut at once."
	ru_desc = "Большая красная кнопка под защитной крышкой. Мгновенно закрывает стопорный клапан турбины."
	icon_state = "stop_closed"
	var/cover_open = FALSE

/obj/structure/turbine_part/button/stop/examine(mob/user, distance)
	. = ..()
	nsr_lang_for(user)
	to_chat(user, nsr_tr("The cover is [cover_open ? "up" : "down"]. Alt-click closes it.", "Крышка [cover_open ? "поднята" : "опущена"]. Alt-клик опускает её."))

/obj/structure/turbine_part/button/stop/on_update_icon()
	icon_state = cover_open ? "stop_open" : "stop_closed"

/obj/structure/turbine_part/button/stop/push(mob/user)
	if(!cover_open)
		nsr_lang_for(user)
		cover_open = TRUE
		update_icon()
		playsound(src, 'sound/machines/click.ogg', 40, TRUE)
		to_chat(user, SPAN_NOTICE(nsr_tr("You flip the protective cover up.", "Вы поднимаете защитную крышку.")))
		return
	..()

/obj/structure/turbine_part/button/stop/AltClick(mob/user)
	if(!in_range(src, user))
		return
	nsr_lang_for(user)
	cover_open = !cover_open
	update_icon()
	playsound(src, 'sound/machines/click.ogg', 40, TRUE)
	to_chat(user, SPAN_NOTICE(cover_open ? nsr_tr("You flip the protective cover up.", "Вы поднимаете защитную крышку.") : nsr_tr("You close the protective cover.", "Вы опускаете защитную крышку.")))

/obj/structure/turbine_part/button/stop/press(mob/user, obj/machinery/power/submarine_turbine_generator/G)
	G.act_emergency_stop(user)

// ----------------------------------------------------------------------------
// ТУМБЛЕРЫ
// ----------------------------------------------------------------------------

/// Тумблер на столе: стоит вверху, когда включено, внизу, когда выключено. Клик переключает, положение берётся из состояния турбины.
/obj/structure/turbine_part/toggle
	name = "switch"
	desc = "A hardwired toggle switch."
	icon_state = "sw_down"
	shows_state = TRUE
	var/cooldown = 10
	var/next_flip = 0

/// Включено ли то, чем управляет тумблер. Подтипы переопределяют.
/obj/structure/turbine_part/toggle/proc/is_on(obj/machinery/power/submarine_turbine_generator/G)
	return FALSE

/// Само переключение. Подтипы переопределяют. Язык игрока уже выбран.
/obj/structure/turbine_part/toggle/proc/flip(mob/user, obj/machinery/power/submarine_turbine_generator/G)
	return

/obj/structure/turbine_part/toggle/refresh()
	var/obj/machinery/power/submarine_turbine_generator/G = find_unit()
	var/new_state = (G && is_on(G)) ? "sw_up" : "sw_down"
	if(icon_state != new_state)
		icon_state = new_state

/obj/structure/turbine_part/toggle/attack_hand(mob/user)
	toggle(user)
	return TRUE

/obj/structure/turbine_part/toggle/use_tool(obj/item/tool, mob/living/user, list/click_params)
	SHOULD_CALL_PARENT(FALSE)
	toggle(user)
	return TRUE

/obj/structure/turbine_part/toggle/proc/toggle(mob/user)
	if(world.time < next_flip)
		return
	next_flip = world.time + cooldown
	nsr_lang_for(user)
	var/obj/machinery/power/submarine_turbine_generator/G = find_unit()
	playsound(src, pick('sound/machines/switch1.ogg', 'sound/machines/switch2.ogg', 'sound/machines/switch3.ogg', 'sound/machines/switch4.ogg'), 50, TRUE)
	if(!G)
		to_chat(user, SPAN_WARNING(nsr_tr("The switch does nothing: there is no link to a turbine.", "Тумблер ничего не делает: нет связи с турбиной.")))
		return
	flip(user, G)
	refresh()

/obj/structure/turbine_part/toggle/examine(mob/user, distance)
	. = ..()
	nsr_lang_for(user)
	to_chat(user, nsr_tr("It is [icon_state == "sw_up" ? "up (on)" : "down (off)"].", "Он [icon_state == "sw_up" ? "вверху (включено)" : "внизу (выключено)"]."))

/// Автомат генератора: вверху замкнут.
/obj/structure/turbine_part/toggle/breaker
	name = "GENERATOR BREAKER switch"
	desc = "A toggle switch. Up means the generator breaker is closed. Closing it needs the shaft near the grid speed, the same as in the console window."
	ru_desc = "Тумблер. Вверху автомат генератора замкнут. Замкнуть можно, когда вал близок к частоте сети, как и в окне пульта."

/obj/structure/turbine_part/toggle/breaker/is_on(obj/machinery/power/submarine_turbine_generator/G)
	return G.breaker_closed

/obj/structure/turbine_part/toggle/breaker/flip(mob/user, obj/machinery/power/submarine_turbine_generator/G)
	G.act_breaker_toggle(user)

/// Регулятор оборотов: вверху включён.
/obj/structure/turbine_part/toggle/governor
	name = "GOVERNOR switch"
	desc = "A toggle switch. Up means the speed governor is on and holds the shaft at its setpoint."
	ru_desc = "Тумблер. Вверху регулятор оборотов включён и держит вал на заданных оборотах."

/obj/structure/turbine_part/toggle/governor/is_on(obj/machinery/power/submarine_turbine_generator/G)
	return G.governor_on

/obj/structure/turbine_part/toggle/governor/flip(mob/user, obj/machinery/power/submarine_turbine_generator/G)
	G.act_governor_toggle(user)

// ----------------------------------------------------------------------------
// ЛАМПЫ
// ----------------------------------------------------------------------------

/// Индикаторная лампа. Подтипы задают, когда она горит и каким цветом, в lamp_color().
/obj/structure/turbine_part/lamp
	name = "indicator lamp"
	desc = "An indicator lamp."
	icon_state = "lamp_off"
	shows_state = TRUE

/// Цвет лампы по состоянию турбины: "off", "red", "green", "amber" или "red_blink". Подтипы переопределяют.
/obj/structure/turbine_part/lamp/proc/lamp_color(obj/machinery/power/submarine_turbine_generator/G)
	return "off"

/obj/structure/turbine_part/lamp/refresh()
	var/obj/machinery/power/submarine_turbine_generator/G = find_unit()
	var/new_state = "lamp_[G ? lamp_color(G) : "off"]"
	if(icon_state != new_state)
		icon_state = new_state

/obj/structure/turbine_part/lamp/examine(mob/user, distance)
	. = ..()
	nsr_lang_for(user)
	to_chat(user, nsr_tr("It is [icon_state == "lamp_off" ? "dark" : "lit"].", "Она [icon_state == "lamp_off" ? "не горит" : "горит"]."))

/// Красная: стопорный клапан закрыт.
/obj/structure/turbine_part/lamp/stop
	name = "STOP VALVE SHUT lamp"
	desc = "A red lamp. Lit while the turbine stop valve is shut."
	ru_desc = "Красная лампа. Горит, пока стопорный клапан турбины закрыт."

/obj/structure/turbine_part/lamp/stop/lamp_color(obj/machinery/power/submarine_turbine_generator/G)
	return G.stop_tripped ? "red" : "off"

/// Зелёная: автомат генератора замкнут.
/obj/structure/turbine_part/lamp/breaker
	name = "BREAKER CLOSED lamp"
	desc = "A green lamp. Lit while the generator breaker is closed."
	ru_desc = "Зелёная лампа. Горит, пока автомат генератора замкнут."

/obj/structure/turbine_part/lamp/breaker/lamp_color(obj/machinery/power/submarine_turbine_generator/G)
	return G.breaker_closed ? "green" : "off"

/// Красная мигающая: есть неподтверждённая тревога.
/obj/structure/turbine_part/lamp/alarm
	name = "UNACKNOWLEDGED ALARM lamp"
	desc = "A red lamp. Blinks while there are unacknowledged alarms on the annunciator."
	ru_desc = "Красная лампа. Мигает, пока на табло есть неподтверждённые тревоги."

/obj/structure/turbine_part/lamp/alarm/lamp_color(obj/machinery/power/submarine_turbine_generator/G)
	return G.annunciator.has_unacked() ? "red_blink" : "off"

/// Жёлтая: автоматическая защита отключена (обход, перерезанный провод).
/obj/structure/turbine_part/lamp/protection
	name = "PROTECTION OFF lamp"
	desc = "An amber lamp. Lit while the automatic protection of the turbine is off."
	ru_desc = "Жёлтая лампа. Горит, пока автоматическая защита турбины отключена."

/obj/structure/turbine_part/lamp/protection/lamp_color(obj/machinery/power/submarine_turbine_generator/G)
	return G.protection_active() ? "off" : "amber"

// ----------------------------------------------------------------------------
// ДИСПЛЕЙ
// ----------------------------------------------------------------------------

/// Дисплей турбины: обороты и мощность на самом экране по очереди, красный и мигающий при останове или неподтверждённой тревоге.
/// По клику (и в осмотре вблизи) выдаёт в чат полное состояние.
/obj/structure/turbine_part/display
	name = "turbine display"
	desc = "A small display. It alternates between the turbine shaft speed (rpm, digits only) and the electric output (kW). Click it for the full status."
	icon_state = "disp_off"
	shows_state = TRUE
	maptext_width = 40
	maptext_x = -4
	maptext_y = 10
	/// Что показывать сейчас: обороты или мощность. Меняется на каждом такте, в одну строку на экран больше не влезает.
	var/show_power = FALSE
	/// Что сейчас показано, чтобы не перерисовывать без нужды.
	var/shown_text = ""

/obj/structure/turbine_part/display/refresh()
	var/obj/machinery/power/submarine_turbine_generator/G = find_unit()
	var/new_state = "disp_off"
	var/new_text = ""
	if(G)
		var/alarm = G.stop_tripped || G.annunciator.has_unacked()
		new_state = alarm ? "disp_alarm" : "disp_ok"
		show_power = !show_power
		new_text = G.stop_tripped ? "TRIP" : (show_power ? "[round(G.last_output / 1000, 0.1)]kW" : "[round(G.rpm)]")
	if(icon_state != new_state)
		icon_state = new_state
	if(new_text != shown_text)
		shown_text = new_text
		maptext = length(new_text) ? "<span style='font-family: Arial; font-size: 5px; color: [G.stop_tripped ? "#ff8080" : "#7cfc9a"]; text-align: center;'>[new_text]</span>" : ""

/// Полное состояние текстом, на языке игрока.
/obj/structure/turbine_part/display/proc/status_lines(mob/user)
	nsr_lang_for(user)
	var/obj/machinery/power/submarine_turbine_generator/G = find_unit()
	if(!G)
		return nsr_tr("The display is blank: no link to a turbine.", "Экран пуст: нет связи с турбиной.")
	var/list/L = list()
	L += nsr_tr("Shaft speed: [round(G.rpm)] rpm.", "Обороты вала: [round(G.rpm)] об/мин.")
	L += nsr_tr("Electric output: [round(G.last_output / 1000, 0.1)] kW, demand [round(G.last_demand / 1000, 0.1)] kW.", "Выдача: [round(G.last_output / 1000, 0.1)] кВт, потребление [round(G.last_demand / 1000, 0.1)] кВт.")
	L += nsr_tr("Admission valve: [round(G.admission)] %. Governor [G.governor_on ? "on" : "off"].", "Впускной клапан: [round(G.admission)] %. Регулятор [G.governor_on ? "включён" : "выключен"].")
	L += nsr_tr("Generator breaker: [G.breaker_closed ? "closed" : "open"].", "Автомат генератора: [G.breaker_closed ? "замкнут" : "разомкнут"].")
	if(G.stop_tripped)
		L += SPAN_DANGER(nsr_tr("STOP VALVE SHUT: [G.stop_reason].", "СТОПОРНЫЙ КЛАПАН ЗАКРЫТ: [G.stop_reason]."))
	if(G.annunciator.has_unacked())
		L += SPAN_WARNING(nsr_tr("There are unacknowledged alarms.", "Есть неподтверждённые тревоги."))
	if(!G.protection_active())
		L += SPAN_WARNING(nsr_tr("The automatic protection is OFF.", "Автоматическая защита ОТКЛЮЧЕНА."))
	return jointext(L, "\n")

/obj/structure/turbine_part/display/attack_hand(mob/user)
	to_chat(user, status_lines(user))
	return TRUE

/obj/structure/turbine_part/display/examine(mob/user, distance)
	. = ..()
	if(distance <= 3)
		to_chat(user, status_lines(user))
