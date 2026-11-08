/*
	ТРУБЫ ПЕРВИЧНОГО КОНТУРА (ревизия 18)

	Первичный контур считает модель реактора (давление, температура, запас воды), а трубы это его «тело»: сегменты с прочностью, которые
	можно разрушить, и которые рвутся, когда давление выше прочности. Сегменты привязаны к реактору по reactor_id.
	- Целый сегмент ничего не делает.
	- Трещина (прочность ниже NSR_PIPE_CRACK_FRAC): слабая течь, доля NSR_PIPE_CRACK_WEIGHT от разрыва.
	- Разрыв (прочность 0): «потеря теплоносителя». Запас воды и давление быстро падают, горячая вода вскипает (пар в помещение),
	  рядом растут радиоактивные лужи, разрыв фонит. Ядро теряет охлаждение так же, как при любой другой потере воды.
	Прочность убавляют взрыв и удары (стоковая система здоровья) и давление выше порога: труба слабее сосуда, ядро бьёт самый слабый сегмент
	(`stress_pipes`). Ремонт: сварщик, когда реактор холодный (ниже 60 C) и давление ниже 5 бар.
	Если на карте нет ни одной такой трубы, ядро работает как раньше (течь только в сосуде).
	Спрайты временные: стоковые трубы, окрашенные цветом.
*/

GLOBAL_LIST_EMPTY(submarine_primary_pipes)

/obj/structure/submarine_primary_pipe
	name = "primary coolant pipe"
	desc = "A thick steel pipe of the reactor's primary circuit. Whatever flows inside it is hot and radioactive."
	icon = 'icons/atmos/pipes.dmi'
	icon_state = "intact"
	color = "#d4872f"
	density = FALSE
	anchored = TRUE
	health_max = NSR_PIPE_HEALTH
	/// Метка реактора, к которому относится труба. Должна совпадать с reactor_id ядра.
	var/reactor_id = "main"
	/// 0 цела, 1 трещина, 2 разрыв.
	var/leak_stage = 0
	/// Сколько процентов запаса воды вытекло с прошлой лужи.
	var/spill_acc = 0
	/// Лужи у этой трубы (для предела NSR_PUDDLE_MAX).
	var/list/puddles
	var/next_hiss = 0

/obj/structure/submarine_primary_pipe/manifold
	name = "primary coolant junction"
	icon = 'icons/atmos/manifold.dmi'
	icon_state = "core"

/obj/structure/submarine_primary_pipe/Initialize()
	. = ..()
	GLOB.submarine_primary_pipes += src
	update_stage(TRUE)

/obj/structure/submarine_primary_pipe/Destroy()
	GLOB.submarine_primary_pipes -= src
	STOP_PROCESSING(SSobj, src)
	puddles = null
	return ..()

/// Ядро этого контура.
/obj/structure/submarine_primary_pipe/proc/get_core()
	RETURN_TYPE(/obj/machinery/submarine_reactor_core)
	for(var/obj/machinery/submarine_reactor_core/R in GLOB.submarine_reactors)
		if(R.reactor_id == reactor_id)
			return R

/// Какую долю полного разрыва уносит этот сегмент (0, NSR_PIPE_CRACK_WEIGHT или 1).
/obj/structure/submarine_primary_pipe/proc/leak_weight()
	switch(leak_stage)
		if(1)
			return NSR_PIPE_CRACK_WEIGHT
		if(2)
			return 1
	return 0

/// Стадия по прочности. Меняется стадия: сообщение, звук, начало или конец течи.
/obj/structure/submarine_primary_pipe/proc/update_stage(silent = FALSE)
	var/hp = get_current_health()
	var/new_stage = 0
	if(hp <= 0)
		new_stage = 2
	else if(hp < health_max * NSR_PIPE_CRACK_FRAC)
		new_stage = 1
	if(new_stage == leak_stage)
		return
	var/old_stage = leak_stage
	leak_stage = new_stage
	if(new_stage > 0)
		START_PROCESSING(SSobj, src)
	else
		STOP_PROCESSING(SSobj, src)
	update_look()
	if(silent)
		return
	if(new_stage == 2)
		visible_message(SPAN_DANGER("\The [src] bursts open! Radioactive water and steam gush out of it!"))
		playsound(src, NS_SND_RELIEF, 90, TRUE)
		var/obj/machinery/submarine_reactor_core/R = get_core()
		if(R)
			R.sound_alarm(NS_SND_TRIP, 80)
	else if(new_stage == 1 && old_stage == 0)
		visible_message(SPAN_WARNING("\The [src] cracks and starts to weep hot water."))
		playsound(src, NS_SND_SPARKS, 40, TRUE)
	else if(new_stage == 0)
		visible_message(SPAN_NOTICE("\The [src] is sound again."))

/obj/structure/submarine_primary_pipe/proc/update_look()
	switch(leak_stage)
		if(0)
			color = initial(color)
		if(1)
			color = "#b3441f"
		if(2)
			color = "#4a2a1a"

/obj/structure/submarine_primary_pipe/post_health_change(health_mod, prior_health, damage_type = null)
	. = ..()
	update_stage()

/// Течёт, пока труба повреждена. Считает, сколько воды ушло, вскипает её часть в пар, растят лужи, фонит.
/obj/structure/submarine_primary_pipe/Process(wait)
	if(leak_stage <= 0)
		return PROCESS_KILL
	var/obj/machinery/submarine_reactor_core/R = get_core()
	if(!R)
		return
	var/dt = 2
	if(wait > 0)
		dt = clamp(wait / 10, 0.5, 5)
	var/pressure_frac = clamp((R.primary_pressure - 1) / NSR_PRIMARY_PRESSURE, 0, 1.5)
	if(pressure_frac <= 0.01)
		return
	var/weight = leak_weight()
	var/lost = NSR_PIPE_DRAIN * pressure_frac * weight * dt
	var/turf/T = get_turf(src)
	if(!T)
		return
	// Вода вскипает на выходе: чем горячее контур, тем больше пара в помещение.
	var/flash = clamp((R.core_temperature - 100) / 200, 0, 1)
	if(flash > 0 && lost > 0)
		T.assume_gas(GAS_STEAM, lost * NSR_SPILL_STEAM_MOLES * flash, max(R.core_temperature, 100) + T0C)
	// Лужи: одна на каждые NSR_PUDDLE_STEP процентов вытекшей воды.
	spill_acc += lost
	while(spill_acc >= NSR_PUDDLE_STEP)
		spill_acc -= NSR_PUDDLE_STEP
		spawn_puddle(R)
	var/rads = NSR_RADS_PIPE_BREAK * pressure_frac * weight
	if(rads > 0.01)
		SSradiation.radiate(src, rads)
	if(leak_stage >= 2 && world.time >= next_hiss)
		next_hiss = world.time + 6 SECONDS
		playsound(src, NS_SND_RELIEF, 50, TRUE)

/obj/structure/submarine_primary_pipe/proc/spawn_puddle(obj/machinery/submarine_reactor_core/R)
	if(LAZYLEN(puddles) >= NSR_PUDDLE_MAX)
		return
	var/list/spots = list()
	var/range = (leak_stage >= 2) ? 2 : 1
	for(var/turf/simulated/floor/F in range(range, src))
		if(!F.density)
			spots += F
	if(!length(spots))
		return
	var/turf/spot = pick(spots)
	var/obj/decal/cleanable/submarine_coolant/P = new(spot)
	P.strength = NSR_PUDDLE_RADS * (1 + R.core_damage / 20)
	P.source_pipe = src
	LAZYADD(puddles, P)

/// Сварка: цельная труба (сегмент снова на полную прочность). Только на холодном контуре без давления.
/obj/structure/submarine_primary_pipe/use_tool(obj/item/tool, mob/living/user, list/click_params)
	if(!isWelder(tool))
		return ..()
	if(get_current_health() >= health_max)
		to_chat(user, SPAN_NOTICE("\The [src] is sound, there is nothing to weld."))
		return TRUE
	var/obj/machinery/submarine_reactor_core/R = get_core()
	if(R && (R.core_temperature > NSR_PIPE_REPAIR_TEMP || R.primary_pressure > NSR_PIPE_REPAIR_PRESSURE))
		to_chat(user, SPAN_WARNING("The pipe is too hot and under too much pressure to weld. Let the circuit cool below [NSR_PIPE_REPAIR_TEMP] C and drop below [NSR_PIPE_REPAIR_PRESSURE] bar first."))
		return TRUE
	var/obj/item/weldingtool/welder = tool
	if(!welder.remove_fuel(NSR_PIPE_WELD_FUEL, user))
		return TRUE
	user.visible_message(SPAN_NOTICE("\The [user] starts welding \the [src]."), SPAN_NOTICE("You start welding \the [src]."))
	playsound(src, NS_SND_WELD, 50, TRUE)
	if(!do_after(user, NSR_PIPE_WELD_TIME, src))
		return TRUE
	if(R && (R.core_temperature > NSR_PIPE_REPAIR_TEMP || R.primary_pressure > NSR_PIPE_REPAIR_PRESSURE))
		return TRUE
	restore_health(health_max, skip_can_restore_check = TRUE)
	update_stage()
	user.visible_message(SPAN_NOTICE("\The [user] welds \the [src] whole."), SPAN_NOTICE("You weld \the [src] whole."))
	playsound(src, NS_SND_BUILT, 50, TRUE)
	return TRUE

/obj/structure/submarine_primary_pipe/examine(mob/user, distance)
	. = ..()
	if(leak_stage == 1)
		to_chat(user, SPAN_WARNING("It has a crack and weeps hot, radioactive water."))
	else if(leak_stage == 2)
		to_chat(user, SPAN_DANGER("It has burst open. The primary circuit is losing its water here."))
	else if(get_current_health() < health_max)
		to_chat(user, "It is dented but holds.")

// ----------------------------------------------------------------------------
// РАДИОАКТИВНАЯ ЛУЖА
// ----------------------------------------------------------------------------

/// Вода первичного контура на полу. Фонит, медленно распадается, смывается шваброй и уборщиком, как любая грязь на полу.
/obj/decal/cleanable/submarine_coolant
	name = "radioactive water"
	desc = "Primary coolant. It glows faintly, and a Geiger counter next to it will not stop clicking."
	gender = PLURAL
	icon = 'icons/effects/effects.dmi'
	icon_state = "greenglow"
	color = "#7fd8ff"
	light_range = 1
	light_color = "#7fd8ff"
	persistent = FALSE
	/// Сила излучения в «лёгкой радиации»; с временем падает.
	var/strength = NSR_PUDDLE_RADS
	var/obj/structure/submarine_primary_pipe/source_pipe

/obj/decal/cleanable/submarine_coolant/Initialize()
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/decal/cleanable/submarine_coolant/Destroy()
	STOP_PROCESSING(SSobj, src)
	if(source_pipe)
		LAZYREMOVE(source_pipe.puddles, src)
		source_pipe = null
	return ..()

/obj/decal/cleanable/submarine_coolant/Process(wait)
	var/dt = 2
	if(wait > 0)
		dt = clamp(wait / 10, 0.5, 5)
	strength *= max(0, 1 - NSR_PUDDLE_DECAY * dt)
	if(strength < NSR_PUDDLE_MIN)
		qdel(src)
		return PROCESS_KILL
	SSradiation.radiate(src, strength)
