/*
	ГУДЯЩИЕ ЛАМПЫ (ревизия 35)

	Пожелание автора: лампы гудят, как в NuPhase. Там это делает общий механизм composite_sound, в NS-13 его нет,
	поэтому здесь лёгкая версия под одну задачу.

	Как работает. Один общий таймер раз в NS_LIGHT_HUM_LENGTH десятых секунды берёт случайную запись из четырёх
	и проигрывает её от каждой включённой лампы, которая стоит рядом с клиентом (в радиусе NS_LIGHT_HUM_RANGE клеток).
	Лампы далеко от игроков ничего не делают, так что стоимость растёт с числом игроков, а не ламп.
	Записи идут как «ambiance»: игрок, отключивший фоновые звуки в настройках, гула не слышит.

	Запись в оригинале длится 4,99 с, интервал 4,8 с, поэтому петля идёт без дырок (с небольшим наложением, как у NuPhase).
	Громкость NS_LIGHT_HUM_VOLUME и слышимость (extrarange -5, то есть только рядом с лампой) взяты оттуда же.

	Звуки: sound/machines/lights/buzz1-4.ogg. Источник: NuPhase-2026 (коммит d30f871), buzz1-4.wav, у нас перекодированы
	в моно ogg (160 КБ вместо 3,4 МБ). Подробности и лицензии: README, раздел «Заимствованные ресурсы».

	Громкость файлов (ревизия 40). Оригиналы очень тихие: средняя громкость около -57 дБ, пик -43 дБ (обычные звуки игры
	около -25...-30 дБ). В ревизии 35 мы перекодировали их как есть, и автор гула в игре не услышал. Теперь каждый файл
	усилен до средней громкости около -26 дБ (ffmpeg -ac 1 -af volume=<усиление> -c:a libvorbis -q:a 1; усиление 28...32 дБ
	от оригинального wav, пик остаётся ниже -11 дБ, обрезания нет). Если гул громковат или тиховат, меняйте NS_LIGHT_HUM_VOLUME.
*/

/// Интервал между проигрываниями, в десятых секунды. Чуть короче записи (4,99 с).
#define NS_LIGHT_HUM_LENGTH 48
/// Громкость гула.
#define NS_LIGHT_HUM_VOLUME 30
/// Дополнительная дальность слышимости (отрицательная: слышно только рядом с лампой).
#define NS_LIGHT_HUM_EXTRARANGE -5
/// В каком радиусе от клиента искать лампы, которые стоит проигрывать.
#define NS_LIGHT_HUM_RANGE 6

/// Общий для всех ламп цикл гула. Создаётся при первой лампе и дальше живёт сам.
var/global/datum/light_hum/light_hum_loop

/datum/light_hum
	var/list/sounds = list('sound/machines/lights/buzz1.ogg', 'sound/machines/lights/buzz2.ogg', 'sound/machines/lights/buzz3.ogg', 'sound/machines/lights/buzz4.ogg')
	var/timer_id

/datum/light_hum/New()
	..()
	timer_id = addtimer(new Callback(src, PROC_REF(hum)), NS_LIGHT_HUM_LENGTH, TIMER_LOOP | TIMER_STOPPABLE)

/datum/light_hum/Destroy()
	if(timer_id)
		deltimer(timer_id)
		timer_id = null
	return ..()

/datum/light_hum/proc/hum()
	var/list/hummers = list()
	for(var/mob/M in GLOB.player_list)
		if(!M.client)
			continue
		var/turf/T = get_turf(M)
		if(!T)
			continue
		for(var/obj/machinery/light/L in range(NS_LIGHT_HUM_RANGE, T))
			if(L.on)
				hummers |= L
	if(!length(hummers))
		return
	var/hum_sound = pick(sounds)
	for(var/obj/machinery/light/L as anything in hummers)
		playsound(L, hum_sound, NS_LIGHT_HUM_VOLUME, 0, NS_LIGHT_HUM_EXTRARANGE, is_ambiance = 1)

/// Лампа зовёт это при создании: первая запускает общий цикл, остальные ничего не делают.
/proc/light_hum_ensure()
	if(!light_hum_loop)
		light_hum_loop = new /datum/light_hum()
