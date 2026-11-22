/*
	МАЯКИ ТРЕВОГ (ревизия 29)

	Стоковая вращающаяся лампа (rotating_alarm) на стене, привязанная к табло реактора или турбины: загорается жёлтой при предупреждении
	и красной при аварии, гаснет, когда тревоги нет. Сирена звучит только при аварии и только пока тревогу не подтвердили на пульте
	(у реактора это заглушка сигнала, у турбины подтверждение плиток табло): лампа продолжает гореть до конца аварии.
	Лампе не нужно питание: это аварийная лампа с автономной подсветкой. Ставится на карте на пол у стены, dir как у стоковой лампы
	(лампа смотрит в сторону dir, висит на противоположной стене). Реактор находится по reactor_id, турбина по turbine_id.
	Спрайт и звук временные (стоковые).
*/

/obj/machinery/rotating_alarm/submarine
	name = "alarm beacon"
	desc = "A rotating beacon wired to the alarm board of the plant. Amber means a warning, red means an alarm. The siren stays quiet once the alarm is acknowledged at the console."
	/// "reactor" или "turbine": табло чего показывает маяк.
	var/watch = "reactor"
	/// Метка реактора (reactor_id) или турбины (turbine_id), за которой следит маяк.
	var/unit_id = "main"
	/// Какой уровень сейчас показан (0 погашен, 1 жёлтый, 2 красный).
	var/shown_level = 0
	var/datum/sound_token/horn_token

/obj/machinery/rotating_alarm/submarine/reactor
	name = "reactor alarm beacon"
	watch = "reactor"

/obj/machinery/rotating_alarm/submarine/turbine
	name = "turbine alarm beacon"
	watch = "turbine"

/obj/machinery/rotating_alarm/submarine/Destroy()
	QDEL_NULL(horn_token)
	return ..()

/// Раз в такт машин смотрим на табло. Родительский Process здесь не зовём: он останавливает обработку.
/obj/machinery/rotating_alarm/submarine/Process()
	var/level = 0
	var/horn = FALSE
	if(watch == "turbine")
		for(var/obj/machinery/power/submarine_turbine_generator/G in GLOB.submarine_turbines)
			if(QDELETED(G) || G.turbine_id != unit_id)
				continue
			for(var/id in G.annunciator.levels)
				level = max(level, G.annunciator.levels[id] || 0)
			horn = (level >= 2 && G.annunciator.has_unacked())
			break
	else
		for(var/obj/machinery/submarine_reactor_core/R in GLOB.submarine_reactors)
			if(QDELETED(R) || R.reactor_id != unit_id)
				continue
			level = R.alarm_level
			horn = (level >= 2 && !R.alarm_mute_level)
			break
	show_level(level, horn)

/obj/machinery/rotating_alarm/submarine/proc/show_level(level, horn)
	if(level != shown_level)
		shown_level = level
		if(level <= 0)
			set_off()
		else
			// Лампа оранжевая; для красного поворачиваем оттенок спрайта и луча (так делает и лампа суперматерии).
			angle = (level >= 2) ? -30 : 0
			color = color_rotation(angle)
			set_color(COLOR_ORANGE)
			if(on)
				set_light(2, 0.5, alarm_light_color)
			else
				set_on()
	if(horn && !horn_token)
		horn_token = GLOB.sound_player.PlayLoopingSound(src, "nsb_\ref[src]", NS_SND_BEACON_HORN, volume = 40, range = 10, falloff = 3, prefer_mute = TRUE)
	else if(!horn && horn_token)
		QDEL_NULL(horn_token)
