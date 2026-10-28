/*
	ПЕРЕБОРОЧНАЯ ДВЕРЬ ПОДЛОДКИ (гермодверь)

	Большая дверь между отсеками, как на настоящих подлодках. Работает БЕЗ ЭЛЕКТРИЧЕСТВА: у неё штурвал.
	Игрок кликает по двери, крутит штурвал (долго, прерывается, если отойти или упасть), и только после этого
	дверь открывается или закрывается. От простого прикосновения или удара об неё дверь не открывается.

	Где ставить (GDD, §5.2, решения автора, ревизия 6): две такие двери подряд между БЩУ и реактором и две
	между реактором и турбинным залом, с коротким тамбуром между ними. Обычные шлюзы остаются в других местах.

	Спрайты временные: стоковая бронедверь (blast door). Свой спрайт и размер (1 тайл или 2 в ширину) решает автор,
	имена состояний тогда согласуем заранее.

	Все числа ЧЕРНОВЫЕ и лежат в блоке #define ниже.
*/

#define HATCH_TURN_TIME   (8 SECONDS) // сколько крутить штурвал, прежде чем дверь начнёт двигаться
#define HATCH_OPEN_SOUND  'sound/machines/blastdoor_open.ogg'
#define HATCH_CLOSE_SOUND 'sound/machines/blastdoor_close.ogg'

/obj/machinery/door/submarine_hatch
	name = "pressure hatch"
	desc = "A massive submarine pressure hatch. A hand wheel turns the locking gear: it takes a while, but needs no power."
	// Временно: стоковая бронедверь. Заменить своим спрайтом.
	icon = 'icons/obj/doors/rapid_pdoor.dmi'
	icon_state = "pdoor1"
	dir = 1
	closed_layer = ABOVE_WINDOW_LAYER
	health_max = 1000
	health_min_damage = 30
	explosion_resistance = 25
	// Своих прав доступа у двери нет: открыть может любой, кто провернёт штурвал.
	autoset_access = FALSE
	// Никакого электричества: ни питания, ни связи с АПС.
	use_power = POWER_USE_OFF
	uncreated_component_parts = null
	/// Кто сейчас крутит штурвал. Двоим сразу крутить нельзя.
	var/mob/wheel_user

/obj/machinery/door/submarine_hatch/Destroy()
	wheel_user = null
	return ..()

/// Дверь не открывается от касания или удара об неё. Только штурвал.
/obj/machinery/door/submarine_hatch/Bumped(atom/AM)
	return

/// Электронных замков нет, ломать нечем.
/obj/machinery/door/submarine_hatch/emag_act()
	return -1

/obj/machinery/door/submarine_hatch/attack_hand(mob/user)
	turn_wheel(user)
	return TRUE

/// Любой предмет в руке это та же рука на штурвале.
/obj/machinery/door/submarine_hatch/use_tool(obj/item/tool, mob/living/user, list/click_params)
	turn_wheel(user)
	return TRUE

/// Закрыть нельзя, пока в проёме кто-то стоит.
/obj/machinery/door/submarine_hatch/can_close()
	if(!..())
		return 0
	if(locate(/mob/living) in loc)
		return 0
	return 1

/// Крутить штурвал: долго, и только потом дверь двигается. Прерывается, если отойти или потерять способность действовать.
/obj/machinery/door/submarine_hatch/proc/turn_wheel(mob/user)
	if(!user || user.incapacitated() || !user.Adjacent(src))
		return
	if(operating)
		to_chat(user, SPAN_WARNING("\The [src] is already moving."))
		return
	if(wheel_user && wheel_user != user)
		to_chat(user, SPAN_WARNING("\The [wheel_user] is already turning the wheel."))
		return
	var/was_dense = density
	if(!was_dense && (locate(/mob/living) in loc))
		to_chat(user, SPAN_WARNING("Something is in the way of \the [src]."))
		return
	user.visible_message(
		SPAN_NOTICE("\The [user] starts turning the wheel of \the [src]."),
		SPAN_NOTICE("You start turning the wheel of \the [src]. It is stiff and heavy."))
	playsound(src, 'sound/items/Ratchet.ogg', 60, TRUE)
	add_fingerprint(user)
	wheel_user = user
	var/finished = do_after(user, HATCH_TURN_TIME, src)
	wheel_user = null
	if(!finished || QDELETED(src) || operating)
		return
	// Пока крутили, состояние могло поменяться (взрыв, админ): двигаем только если всё как было.
	if(density != was_dense)
		return
	toggle()

/obj/machinery/door/submarine_hatch/do_animate(animation)
	switch(animation)
		if("opening")
			flick("pdoorc0", src)
		if("closing")
			flick("pdoorc1", src)

/obj/machinery/door/submarine_hatch/open(forced = 0)
	set waitfor = FALSE
	if(!can_open(forced))
		return
	operating = DOOR_OPERATING_YES
	playsound(loc, HATCH_OPEN_SOUND, 80, TRUE)
	do_animate("opening")
	sleep(5)
	set_density(0)
	set_opacity(0)
	update_nearby_tiles()
	sleep(10)
	layer = open_layer
	update_icon()
	operating = DOOR_OPERATING_NO
	return 1

/obj/machinery/door/submarine_hatch/close(forced = 0)
	set waitfor = FALSE
	if(!can_close(forced))
		return
	operating = DOOR_OPERATING_YES
	playsound(loc, HATCH_CLOSE_SOUND, 80, TRUE)
	do_animate("closing")
	set_density(1)
	sleep(5)
	layer = closed_layer
	update_nearby_tiles()
	sleep(10)
	update_icon()
	set_opacity(1)
	operating = DOOR_OPERATING_NO
	return 1

/obj/machinery/door/submarine_hatch/on_update_icon()
	icon_state = density ? "pdoor1" : "pdoor0"
	SSradiation.resistance_cache.Remove(get_turf(src))

/// Открытая дверь для карты: стоит открытой с начала раунда. Имя не `open`, чтобы не совпасть с процедурой open().
/obj/machinery/door/submarine_hatch/begins_open
	icon_state = "pdoor0"
	density = FALSE
	opacity = FALSE
	layer = OPEN_DOOR_LAYER
