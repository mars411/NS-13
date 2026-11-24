/*
	ФИЗИЧЕСКИЙ ПУЛЬТ ТУРБИНЫ (ревизия 34, первый срез)

	Белый операторский стол с наклонной панелью, как в БЩУ настоящей станции: на нём настоящие кнопки и дисплей, а не окно на экране.
	Каждая кнопка кликается мышью. Стол стоит на переднем плане зала, оператор встаёт в его подкову и смотрит на панель.

	Что есть пока:
	- корпус (/obj/structure/turbine_desk): кусок стола на 8 направлений, из них собирается подкова;
	- кнопки: АВАРИЙНЫЙ ОСТАНОВ (под защитной крышкой), ПОДТВЕРДИТЬ ТРЕВОГИ, СБРОС СТОПОРНОГО КЛАПАНА;
	- дисплей: обороты и мощность на самом экране, полные данные по клику.

	Кнопки проводные, электричество им не нужно: как в БЩУ, где аварийные кнопки работают от своей цепи. Они зовут те же процедуры
	генератора (act_ack, act_emergency_stop, reset_stop_valve), что и окно пульта, поэтому поведение у обоих одинаковое.
	Кнопки связаны с турбиной по turbine_id (по умолчанию "main", как у остальных частей турбины).

	Заглушить сирену здесь нет: у турбины сирены пока нет, есть только табло. Когда появится, кнопка встанет рядом с подтверждением.

	Спрайты. Корпус стола: icons/obj/structures/reactor_panel.dmi из NuPhase, без изменений (CC BY-SA 3.0).
	Кнопки: вдвое увеличенные кнопки из NuPhase (icons/obj/power.dmi), перекрашенные. Дисплеи нарисованы для NS-13.
	Источник и лицензии: README, раздел «Заимствованные ресурсы».

	Как собирать стол на карте (раскладка NuPhase, подкова):
	  угол dir 6 (запад) | плиты dir 2 (с кнопками и дисплеем) | угол dir 10 (восток)
	  крыло dir 4 (запад)                                      крыло dir 8 (восток)
	У плит pixel_y = 6, у углов и крыльев pixel_y = 5. Кнопки и дисплей ставятся на клетку плиты со своими pixel_x и pixel_y.
*/

/// Корпус пульта. Сам ничего не делает: это мебель, на которой стоят кнопки и дисплей.
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
// КНОПКИ
// ----------------------------------------------------------------------------

/// Кнопка на столе. Подтипы задают действие в press().
/obj/structure/turbine_button
	name = "button"
	desc = "A hardwired control button."
	icon = 'icons/obj/submarine_controls.dmi'
	icon_state = "btn_red"
	anchored = TRUE
	density = FALSE
	layer = ABOVE_WINDOW_LAYER
	/// Метка турбины, которой управляет кнопка. Должна совпадать с turbine_id генератора.
	var/turbine_id = "main"
	/// Пауза между нажатиями, чтобы не стучали по кнопке десять раз в секунду.
	var/cooldown = 10
	var/next_press = 0
	/// Подпись на русском для осмотра (имя и описание в игре английские, как у остальных предметов).
	var/ru_desc = ""

/obj/structure/turbine_button/proc/find_unit()
	for(var/obj/machinery/power/submarine_turbine_generator/G in GLOB.submarine_turbines)
		if(G.turbine_id == turbine_id)
			return G

/obj/structure/turbine_button/examine(mob/user, distance)
	. = ..()
	nsr_lang_for(user)
	if(nsr_is_ru() && length(ru_desc))
		to_chat(user, ru_desc)

/obj/structure/turbine_button/attack_hand(mob/user)
	push(user)
	return TRUE

/// Любой предмет в руке это то же нажатие пальцем: бить кнопку нечем.
/obj/structure/turbine_button/use_tool(obj/item/tool, mob/living/user, list/click_params)
	SHOULD_CALL_PARENT(FALSE)
	push(user)
	return TRUE

/obj/structure/turbine_button/proc/push(mob/user)
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
/obj/structure/turbine_button/proc/press(mob/user, obj/machinery/power/submarine_turbine_generator/G)
	return

/// Подтвердить тревоги табло (жёлтая).
/obj/structure/turbine_button/ack
	name = "ACKNOWLEDGE ALARMS button"
	desc = "A yellow button. Acknowledges the alarms on the turbine annunciator."
	ru_desc = "Жёлтая кнопка. Подтверждает тревоги на табло турбины."
	icon_state = "btn_amber"

/obj/structure/turbine_button/ack/press(mob/user, obj/machinery/power/submarine_turbine_generator/G)
	G.act_ack(user)

/// Сброс стопорного клапана после останова (зелёная).
/obj/structure/turbine_button/reset
	name = "STOP VALVE RESET button"
	desc = "A green button. Resets the turbine stop valve after a trip, once the shaft has slowed down and the condenser has cooled."
	ru_desc = "Зелёная кнопка. Сбрасывает стопорный клапан турбины после останова, когда вал замедлился, а конденсатор остыл."
	icon_state = "btn_green"

/obj/structure/turbine_button/reset/press(mob/user, obj/machinery/power/submarine_turbine_generator/G)
	if(G.reset_stop_valve(user))
		to_chat(user, SPAN_NOTICE(nsr_tr("The stop valve is reset.", "Стопорный клапан сброшен.")))

/// Аварийный останов под защитной крышкой (красная). Первый клик поднимает крышку, второй жмёт кнопку.
/// Alt-клик по кнопке опускает крышку обратно.
/obj/structure/turbine_button/stop
	name = "EMERGENCY STOP button"
	desc = "A big red button under a protective cover. Slams the turbine stop valve shut at once."
	ru_desc = "Большая красная кнопка под защитной крышкой. Мгновенно закрывает стопорный клапан турбины."
	icon_state = "stop_closed"
	var/cover_open = FALSE

/obj/structure/turbine_button/stop/examine(mob/user, distance)
	. = ..()
	nsr_lang_for(user)
	to_chat(user, nsr_tr("The cover is [cover_open ? "up" : "down"]. Alt-click closes it.", "Крышка [cover_open ? "поднята" : "опущена"]. Alt-клик опускает её."))

/obj/structure/turbine_button/stop/on_update_icon()
	icon_state = cover_open ? "stop_open" : "stop_closed"

/obj/structure/turbine_button/stop/push(mob/user)
	if(!cover_open)
		nsr_lang_for(user)
		cover_open = TRUE
		update_icon()
		playsound(src, 'sound/machines/click.ogg', 40, TRUE)
		to_chat(user, SPAN_NOTICE(nsr_tr("You flip the protective cover up.", "Вы поднимаете защитную крышку.")))
		return
	..()

/obj/structure/turbine_button/stop/AltClick(mob/user)
	if(!in_range(src, user))
		return
	nsr_lang_for(user)
	cover_open = !cover_open
	update_icon()
	playsound(src, 'sound/machines/click.ogg', 40, TRUE)
	to_chat(user, SPAN_NOTICE(cover_open ? nsr_tr("You flip the protective cover up.", "Вы поднимаете защитную крышку.") : nsr_tr("You close the protective cover.", "Вы опускаете защитную крышку.")))

/obj/structure/turbine_button/stop/press(mob/user, obj/machinery/power/submarine_turbine_generator/G)
	G.act_emergency_stop(user)

// ----------------------------------------------------------------------------
// ДИСПЛЕЙ
// ----------------------------------------------------------------------------

/// Дисплей турбины: обороты и мощность на самом экране, красный и мигающий при останове или неподтверждённой тревоге.
/// По клику (и в осмотре вблизи) выдаёт в чат полное состояние.
/obj/structure/turbine_display
	name = "turbine display"
	desc = "A small display showing the turbine shaft speed and the electric output. Click it for the full status."
	icon = 'icons/obj/submarine_controls.dmi'
	icon_state = "disp_off"
	anchored = TRUE
	density = FALSE
	layer = ABOVE_WINDOW_LAYER
	maptext_width = 32
	maptext_y = 10
	var/turbine_id = "main"
	/// Что сейчас показано, чтобы не перерисовывать без нужды.
	var/shown_text = ""

/obj/structure/turbine_display/Initialize()
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/structure/turbine_display/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/turbine_display/proc/find_unit()
	for(var/obj/machinery/power/submarine_turbine_generator/G in GLOB.submarine_turbines)
		if(G.turbine_id == turbine_id)
			return G

/obj/structure/turbine_display/Process()
	var/obj/machinery/power/submarine_turbine_generator/G = find_unit()
	var/new_state = "disp_off"
	var/new_text = ""
	if(G)
		var/alarm = G.stop_tripped || G.annunciator.has_unacked()
		new_state = alarm ? "disp_alarm" : "disp_ok"
		var/line2 = G.stop_tripped ? "TRIP" : "[round(G.last_output / 1000, 0.1)]kW"
		new_text = "[round(G.rpm)]<br>[line2]"
	if(icon_state != new_state)
		icon_state = new_state
	if(new_text != shown_text)
		shown_text = new_text
		maptext = length(new_text) ? "<span style='font-family: Arial; font-size: 6px; color: [G.stop_tripped ? "#FF8080" : "#7CFC9A"]; text-align: center;'>[new_text]</span>" : ""

/// Полное состояние текстом, на языке игрока.
/obj/structure/turbine_display/proc/status_lines(mob/user)
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

/obj/structure/turbine_display/attack_hand(mob/user)
	to_chat(user, status_lines(user))
	return TRUE

/obj/structure/turbine_display/examine(mob/user, distance)
	. = ..()
	if(distance <= 3)
		to_chat(user, status_lines(user))
