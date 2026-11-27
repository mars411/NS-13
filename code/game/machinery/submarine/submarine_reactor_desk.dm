/*
	ФИЗИЧЕСКИЙ СТОЛ РЕАКТОРА (ревизия 38)

	Такой же операторский стол, как у турбины (submarine_desk.dm), только для реактора: корпус тот же /obj/structure/turbine_desk,
	детали свои, чтобы не путать с турбиной. Спрайты общие: icons/obj/submarine_controls.dmi (кнопки NuPhase, лампы и дисплеи свои).

	Что есть:
	- кнопки (/obj/structure/reactor_part/button): ПОДТВЕРДИТЬ И ЗАГЛУШИТЬ ТРЕВОГИ, СБРОС SCRAM, SCRAM под защитной крышкой,
	  четыре кнопки стержней (-10, -1, +1, +10 процентов, ревизия 39);
	- тумблеры (/obj/structure/reactor_part/toggle): ЗАЩИТА РЕАКТОРА и АВТОМАТИКА СТЕРЖНЕЙ (ревизия 39), вверху включено;
	- лампы (/obj/structure/reactor_part/lamp): SCRAM сработал, непринятая тревога (мигает), защита реактора включена, автоматика стержней включена;
	- дисплей (/obj/structure/reactor_part/display): температура ядра и положение стержней по очереди, полные данные по клику.

	Кнопки и тумблеры зовут те же процедуры реактора (scram, act_alarm_mute, act_reset_scram, act_rods_move, act_rps_toggle,
	toggle_auto_rods), что и окно пульта, поэтому поведение одинаковое.
	Связь с реактором по reactor_id (по умолчанию "main").

	Не сделано: насосы, подпитка, парогенераторы и клапаны со стола (они пока только в окне пульта), панель и провода, отдельные стержни.
*/

/// Общая основа деталей стола реактора: метка реактора, поиск ядра, подпись на русском, обновление вида по таймеру.
/obj/structure/reactor_part
	icon = 'icons/obj/submarine_controls.dmi'
	anchored = TRUE
	density = FALSE
	layer = ABOVE_WINDOW_LAYER
	/// Метка реактора, к которому привязана деталь. Должна совпадать с reactor_id ядра.
	var/reactor_id = "main"
	/// Описание на русском для осмотра (имя и описание в игре английские, как у остальных предметов).
	var/ru_desc = ""
	/// Показывает ли деталь состояние (лампы, дисплей): тогда она раз в такт SSobj зовёт refresh().
	var/shows_state = FALSE

/obj/structure/reactor_part/Initialize()
	. = ..()
	if(shows_state)
		START_PROCESSING(SSobj, src)

/obj/structure/reactor_part/Destroy()
	if(shows_state)
		STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/reactor_part/Process()
	refresh()

/// Подтянуть вид к текущему состоянию реактора. Подтипы с shows_state переопределяют.
/obj/structure/reactor_part/proc/refresh()
	return

/obj/structure/reactor_part/proc/find_unit()
	for(var/obj/machinery/submarine_reactor_core/R in GLOB.submarine_reactors)
		if(R.reactor_id == reactor_id)
			return R

/obj/structure/reactor_part/examine(mob/user, distance)
	. = ..()
	nsr_lang_for(user)
	if(nsr_is_ru() && length(ru_desc))
		to_chat(user, ru_desc)

// ----------------------------------------------------------------------------
// КНОПКИ
// ----------------------------------------------------------------------------

/// Кнопка на столе реактора. Подтипы задают действие в press().
/obj/structure/reactor_part/button
	name = "button"
	desc = "A hardwired control button."
	icon_state = "btn_red"
	var/cooldown = 10
	var/next_press = 0

/obj/structure/reactor_part/button/attack_hand(mob/user)
	push(user)
	return TRUE

/// Любой предмет в руке это то же нажатие пальцем: бить кнопку нечем.
/obj/structure/reactor_part/button/use_tool(obj/item/tool, mob/living/user, list/click_params)
	SHOULD_CALL_PARENT(FALSE)
	push(user)
	return TRUE

/obj/structure/reactor_part/button/proc/push(mob/user)
	if(world.time < next_press)
		return
	next_press = world.time + cooldown
	nsr_lang_for(user)
	var/obj/machinery/submarine_reactor_core/R = find_unit()
	playsound(src, pick('sound/machines/button1.ogg', 'sound/machines/button2.ogg', 'sound/machines/button3.ogg', 'sound/machines/button4.ogg'), 50, TRUE)
	if(!R)
		to_chat(user, SPAN_WARNING(nsr_tr("The button does nothing: there is no link to a reactor.", "Кнопка ничего не делает: нет связи с реактором.")))
		return
	if(R.is_dead())
		to_chat(user, SPAN_DANGER(nsr_tr("The reactor is beyond control.", "Реактор вышел из-под контроля.")))
		return
	press(user, R)

/// Действие кнопки. Язык игрока уже выбран, реактор жив.
/obj/structure/reactor_part/button/proc/press(mob/user, obj/machinery/submarine_reactor_core/R)
	return

/// Подтвердить горящие тревоги и заглушить сирену, а нажатая второй раз возвращает сирену (жёлтая).
/obj/structure/reactor_part/button/ack
	name = "ACKNOWLEDGE AND MUTE button"
	desc = "A yellow button. Acknowledges the lit alarms and mutes the siren until things get worse. Press again to bring the siren back."
	ru_desc = "Жёлтая кнопка. Подтверждает горящие тревоги и глушит сирену до ухудшения. Повторное нажатие возвращает сирену."
	icon_state = "btn_amber"

/obj/structure/reactor_part/button/ack/press(mob/user, obj/machinery/submarine_reactor_core/R)
	R.act_alarm_mute(user)

/// Сброс SCRAM (зелёная): сработает, когда ядро остыло и защита не держит.
/obj/structure/reactor_part/button/reset
	name = "RESET SCRAM button"
	desc = "A green button. Resets the SCRAM once the core has cooled and the protection condition is gone."
	ru_desc = "Зелёная кнопка. Сбрасывает SCRAM, когда ядро остыло и условие защиты ушло."
	icon_state = "btn_green"

/obj/structure/reactor_part/button/reset/press(mob/user, obj/machinery/submarine_reactor_core/R)
	var/was_scrammed = R.scrammed
	R.act_reset_scram(user)
	if(was_scrammed && !R.scrammed)
		to_chat(user, SPAN_NOTICE(nsr_tr("The SCRAM is reset. The control rods are free again.", "SCRAM сброшен. Стержни снова свободны.")))

/// SCRAM под защитной крышкой (красная). Первый клик поднимает крышку, второй жмёт кнопку, Alt-клик опускает крышку.
/obj/structure/reactor_part/button/scram
	name = "SCRAM button"
	desc = "A big red button under a protective cover. Drops all the control rods into the core at once."
	ru_desc = "Большая красная кнопка под защитной крышкой. Мгновенно сбрасывает все стержни СУЗ в активную зону."
	icon_state = "stop_closed"
	var/cover_open = FALSE

/obj/structure/reactor_part/button/scram/examine(mob/user, distance)
	. = ..()
	nsr_lang_for(user)
	to_chat(user, nsr_tr("The cover is [cover_open ? "up" : "down"]. Alt-click closes it.", "Крышка [cover_open ? "поднята" : "опущена"]. Alt-клик опускает её."))

/obj/structure/reactor_part/button/scram/on_update_icon()
	icon_state = cover_open ? "stop_open" : "stop_closed"

/obj/structure/reactor_part/button/scram/push(mob/user)
	if(!cover_open)
		nsr_lang_for(user)
		cover_open = TRUE
		update_icon()
		playsound(src, 'sound/machines/click.ogg', 40, TRUE)
		to_chat(user, SPAN_NOTICE(nsr_tr("You flip the protective cover up.", "Вы поднимаете защитную крышку.")))
		return
	..()

/obj/structure/reactor_part/button/scram/AltClick(mob/user)
	if(!in_range(src, user))
		return
	nsr_lang_for(user)
	cover_open = !cover_open
	update_icon()
	playsound(src, 'sound/machines/click.ogg', 40, TRUE)
	to_chat(user, SPAN_NOTICE(cover_open ? nsr_tr("You flip the protective cover up.", "Вы поднимаете защитную крышку.") : nsr_tr("You close the protective cover.", "Вы опускаете защитную крышку.")))

/obj/structure/reactor_part/button/scram/press(mob/user, obj/machinery/submarine_reactor_core/R)
	if(R.scrammed)
		to_chat(user, SPAN_NOTICE(nsr_tr("SCRAM is already engaged.", "SCRAM уже сработал.")))
		return
	R.scram()

/// Кнопка сдвига всех стержней на amount процентов (ревизия 39). Работает как кнопки «-10», «-1», «+1», «+10» в окне пульта.
/obj/structure/reactor_part/button/rods
	name = "ROD button"
	desc = "A button that moves all the control rods by a fixed step. Up raises the rods (more power), down lowers them."
	ru_desc = "Кнопка сдвигает все стержни СУЗ на фиксированный шаг. Вверх поднимает стержни (больше мощности), вниз опускает."
	cooldown = 4
	icon_state = "btn_amber"
	/// На сколько процентов сдвигать стержни, со знаком.
	var/amount = 1

/obj/structure/reactor_part/button/rods/Initialize()
	. = ..()
	name = "RODS [amount > 0 ? "+" : ""][amount]% button"

/obj/structure/reactor_part/button/rods/press(mob/user, obj/machinery/submarine_reactor_core/R)
	if(R.act_rods_move(user, amount))
		to_chat(user, SPAN_NOTICE(nsr_tr("Rod target: [round(R.rods_target)] %.", "Цель стержней: [round(R.rods_target)] %.")))

/obj/structure/reactor_part/button/rods/down10
	amount = -10

/obj/structure/reactor_part/button/rods/down1
	amount = -1

/obj/structure/reactor_part/button/rods/up1
	amount = 1
	icon_state = "btn_green"

/obj/structure/reactor_part/button/rods/up10
	amount = 10
	icon_state = "btn_green"

// ----------------------------------------------------------------------------
// ТУМБЛЕРЫ (ревизия 39)
// ----------------------------------------------------------------------------

/// Тумблер на столе реактора: вверху включено. Подтипы задают is_on() и flip(). Положение берётся из состояния реактора.
/obj/structure/reactor_part/toggle
	name = "switch"
	desc = "A hardwired toggle switch."
	icon_state = "sw_down"
	shows_state = TRUE
	var/cooldown = 10
	var/next_flip = 0
	var/icon_on = "sw_up"
	var/icon_off = "sw_down"

/// Включено ли то, чем управляет тумблер. Подтипы переопределяют.
/obj/structure/reactor_part/toggle/proc/is_on(obj/machinery/submarine_reactor_core/R)
	return FALSE

/// Само переключение. Подтипы переопределяют. Язык игрока уже выбран, реактор жив.
/obj/structure/reactor_part/toggle/proc/flip(mob/user, obj/machinery/submarine_reactor_core/R)
	return

/obj/structure/reactor_part/toggle/refresh()
	var/obj/machinery/submarine_reactor_core/R = find_unit()
	var/new_state = (R && is_on(R)) ? icon_on : icon_off
	if(icon_state != new_state)
		icon_state = new_state

/obj/structure/reactor_part/toggle/attack_hand(mob/user)
	toggle(user)
	return TRUE

/obj/structure/reactor_part/toggle/use_tool(obj/item/tool, mob/living/user, list/click_params)
	SHOULD_CALL_PARENT(FALSE)
	toggle(user)
	return TRUE

/obj/structure/reactor_part/toggle/proc/toggle(mob/user)
	if(world.time < next_flip)
		return
	next_flip = world.time + cooldown
	nsr_lang_for(user)
	var/obj/machinery/submarine_reactor_core/R = find_unit()
	playsound(src, pick('sound/machines/switch1.ogg', 'sound/machines/switch2.ogg', 'sound/machines/switch3.ogg', 'sound/machines/switch4.ogg'), 50, TRUE)
	if(!R)
		to_chat(user, SPAN_WARNING(nsr_tr("The switch does nothing: there is no link to a reactor.", "Тумблер ничего не делает: нет связи с реактором.")))
		return
	if(R.is_dead())
		to_chat(user, SPAN_DANGER(nsr_tr("The reactor is beyond control.", "Реактор вышел из-под контроля.")))
		return
	flip(user, R)
	refresh()

/obj/structure/reactor_part/toggle/examine(mob/user, distance)
	. = ..()
	nsr_lang_for(user)
	to_chat(user, nsr_tr("It is [icon_state == icon_on ? "up (on)" : "down (off)"].", "Он [icon_state == icon_on ? "вверху (включено)" : "внизу (выключено)"]."))

/// Защита реактора: вверху включена (аварийный SCRAM по условиям).
/obj/structure/reactor_part/toggle/protection
	name = "REACTOR PROTECTION switch"
	desc = "A toggle switch. Up means the reactor protection is armed: it drops the rods by itself when a limit is crossed."
	ru_desc = "Тумблер. Вверху защита реактора включена: при выходе за предел она сама сбрасывает стержни."

/obj/structure/reactor_part/toggle/protection/is_on(obj/machinery/submarine_reactor_core/R)
	return R.rps_enabled

/obj/structure/reactor_part/toggle/protection/flip(mob/user, obj/machinery/submarine_reactor_core/R)
	R.act_rps_toggle(user)

/// Автоматика стержней: вверху включена (держит заданную температуру ядра).
/obj/structure/reactor_part/toggle/rods_auto
	name = "ROD AUTOMATION switch"
	desc = "A toggle switch. Up means the rod automation is on and moves the rods by itself. Switch it off to move the rods by hand."
	ru_desc = "Тумблер. Вверху автоматика стержней включена и двигает стержни сама. Выключите её, чтобы двигать стержни вручную."

/obj/structure/reactor_part/toggle/rods_auto/is_on(obj/machinery/submarine_reactor_core/R)
	return R.auto_rods

/obj/structure/reactor_part/toggle/rods_auto/flip(mob/user, obj/machinery/submarine_reactor_core/R)
	R.toggle_auto_rods(user)

// ----------------------------------------------------------------------------
// ЛАМПЫ
// ----------------------------------------------------------------------------

/// Индикаторная лампа стола реактора. Подтипы задают, когда она горит (is_lit) и каким цветом (lit_color).
/obj/structure/reactor_part/lamp
	name = "indicator lamp"
	desc = "An indicator lamp."
	icon_state = "lamp_off"
	shows_state = TRUE
	/// Цвет, когда горит: "red", "green", "amber" или "red_blink".
	var/lit_color = "red"

/// Должна ли лампа гореть при таком состоянии реактора. Подтипы переопределяют.
/obj/structure/reactor_part/lamp/proc/is_lit(obj/machinery/submarine_reactor_core/R)
	return FALSE

/obj/structure/reactor_part/lamp/refresh()
	var/obj/machinery/submarine_reactor_core/R = find_unit()
	var/new_state = (R && is_lit(R)) ? "lamp_[lit_color]" : "lamp_off"
	if(icon_state != new_state)
		icon_state = new_state

/obj/structure/reactor_part/lamp/examine(mob/user, distance)
	. = ..()
	nsr_lang_for(user)
	to_chat(user, nsr_tr("It is [icon_state == "lamp_off" ? "dark" : "lit"].", "Она [icon_state == "lamp_off" ? "не горит" : "горит"]."))

/// Красная: SCRAM сработал, стержни сброшены.
/obj/structure/reactor_part/lamp/scram
	name = "SCRAM lamp"
	desc = "A red lamp. Lit while the SCRAM is engaged and the control rods are locked in."
	ru_desc = "Красная лампа. Горит, пока SCRAM сработал и стержни заперты внизу."
	lit_color = "red"

/obj/structure/reactor_part/lamp/scram/is_lit(obj/machinery/submarine_reactor_core/R)
	return R.scrammed

/// Красная мигающая: есть неподтверждённая тревога.
/obj/structure/reactor_part/lamp/alarm
	name = "UNACKNOWLEDGED ALARM lamp"
	desc = "A red lamp. Blinks while there are unacknowledged alarms on the annunciator."
	ru_desc = "Красная лампа. Мигает, пока на табло есть неподтверждённые тревоги."
	lit_color = "red_blink"

/obj/structure/reactor_part/lamp/alarm/is_lit(obj/machinery/submarine_reactor_core/R)
	return R.has_unacked_alarm()

/// Зелёная: защита реактора включена.
/obj/structure/reactor_part/lamp/protection
	name = "PROTECTION ARMED lamp"
	desc = "A green lamp. Lit while the reactor protection is armed."
	ru_desc = "Зелёная лампа. Горит, пока защита реактора включена."
	lit_color = "green"

/obj/structure/reactor_part/lamp/protection/is_lit(obj/machinery/submarine_reactor_core/R)
	return R.rps_enabled && R.automation_available()

/// Зелёная: автоматика стержней включена.
/obj/structure/reactor_part/lamp/rods_auto
	name = "ROD AUTOMATION lamp"
	desc = "A green lamp. Lit while the rod automation is on."
	ru_desc = "Зелёная лампа. Горит, пока автоматика стержней включена."
	lit_color = "green"

/obj/structure/reactor_part/lamp/rods_auto/is_lit(obj/machinery/submarine_reactor_core/R)
	return R.auto_rods && R.automation_available()

// ----------------------------------------------------------------------------
// ДИСПЛЕЙ
// ----------------------------------------------------------------------------

/// Дисплей реактора: температура ядра и положение стержней по очереди, при SCRAM надпись SCRAM красным.
/// По клику (и в осмотре вблизи) выдаёт в чат полное состояние.
/obj/structure/reactor_part/display
	name = "reactor display"
	desc = "A small display. It alternates between the core temperature (C) and the control rod position (%). Click it for the full status."
	icon_state = "disp_off"
	shows_state = TRUE
	maptext_width = 40
	maptext_x = -4
	maptext_y = 10
	var/show_rods = FALSE
	var/shown_text = ""

/obj/structure/reactor_part/display/refresh()
	var/obj/machinery/submarine_reactor_core/R = find_unit()
	var/new_state = "disp_off"
	var/new_text = ""
	if(R)
		if(R.is_dead())
			new_state = "disp_alarm"
			new_text = "ERR"
		else
			new_state = (R.scrammed || R.has_unacked_alarm()) ? "disp_alarm" : "disp_ok"
			show_rods = !show_rods
			new_text = R.scrammed ? "SCRAM" : (show_rods ? "[round(R.rods_pos)]%" : "[round(R.core_temperature)]C")
	if(icon_state != new_state)
		icon_state = new_state
	if(new_text != shown_text)
		shown_text = new_text
		maptext = length(new_text) ? "<span style='font-family: Arial; font-size: 5px; color: [(new_text == "SCRAM" || new_text == "ERR") ? "#ff8080" : "#7cfc9a"]; text-align: center;'>[new_text]</span>" : ""

/// Полное состояние текстом, на языке игрока.
/obj/structure/reactor_part/display/proc/status_lines(mob/user)
	nsr_lang_for(user)
	var/obj/machinery/submarine_reactor_core/R = find_unit()
	if(!R)
		return nsr_tr("The display is blank: no link to a reactor.", "Экран пуст: нет связи с реактором.")
	if(R.is_dead())
		return SPAN_DANGER(nsr_tr("The display shows only errors: the reactor is beyond control.", "Экран показывает только ошибки: реактор вышел из-под контроля."))
	var/list/L = list()
	L += nsr_tr("Core temperature: [round(R.core_temperature)] C.", "Температура ядра: [round(R.core_temperature)] C.")
	L += nsr_tr("Control rods: [round(R.rods_pos)] % (target [round(R.rods_target)] %).", "Стержни: [round(R.rods_pos)] % (цель [round(R.rods_target)] %).")
	L += nsr_tr("Rod automation [R.auto_rods ? "on" : "off"]. Protection [R.rps_enabled ? "armed" : "disarmed"].", "Автоматика стержней [R.auto_rods ? "включена" : "выключена"]. Защита [R.rps_enabled ? "включена" : "отключена"].")
	if(R.scrammed)
		L += SPAN_DANGER(nsr_tr("SCRAM engaged: [R.scram_reason].", "SCRAM сработал: [R.scram_reason]."))
	if(R.has_unacked_alarm())
		L += SPAN_WARNING(nsr_tr("There are unacknowledged alarms.", "Есть неподтверждённые тревоги."))
	return jointext(L, "\n")

/obj/structure/reactor_part/display/attack_hand(mob/user)
	to_chat(user, status_lines(user))
	return TRUE

/obj/structure/reactor_part/display/examine(mob/user, distance)
	. = ..()
	if(distance <= 3)
		to_chat(user, status_lines(user))
