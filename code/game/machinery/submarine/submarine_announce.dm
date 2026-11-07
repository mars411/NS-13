/*
	NS-13: оповещения подлодки: текст в чат и голос на двух языках (русский и английский).
	Тексты и файлы описаны в README.md этой папки, раздел «Аудио проекта». Голосовые файлы ElevenLabs лежат в sound/ns13/announcements/.

	ЯЗЫК. Пока один общий на раунд: GLOB.ns_announce_lang ("ru" или "en", по умолчанию NS_ANNOUNCE_LANG_DEFAULT из _submarine_defines.dm).
	Голосование в лобби или личная настройка игрока запланированы (GDD §9), тогда меняется только то, откуда берётся язык.
	Сообщение идёт через стоковую систему объявлений (datum/announcement), поэтому уважает настройку игрока «звук объявлений».
*/

#define NS_ANN_PRIMARY_PRESSURE "primary_pressure"

GLOBAL_VAR_AS(ns_announce_lang, NS_ANNOUNCE_LANG_DEFAULT)

var/global/datum/announcement/priority/ns_announcement = new(do_log = 0)

/// Оповещение NS-13 на выбранном языке. key: NS_ANN_*. zlevels: куда доставить, по умолчанию контактные уровни карты.
/proc/ns_announce(key, list/zlevels)
	var/ru = (GLOB.ns_announce_lang == NS_ANNOUNCE_LANG_RU)
	var/title
	var/message
	var/voice
	switch(key)
		if(NS_ANN_PRIMARY_PRESSURE)
			if(ru)
				title = "Реактор"
				message = "Внимание! Давление пара в первичном контуре превышает допустимые нормы. Угроза парового взрыва. Сбросьте давление."
				voice = 'sound/ns13/announcements/primary_pressure_high_ru.ogg'
			else
				title = "Reactor"
				message = "Warning. Steam pressure in primary loop exceeding tolerance limits. Risk of steam explosion. Vent excess pressure immediately."
				voice = 'sound/ns13/announcements/primary_pressure_high_en.ogg'
	if(!message)
		return
	if(!zlevels)
		zlevels = GLOB.using_map.contact_levels
	// Текст идёт через стоковую систему (без звука), голос играем сами: стоковая система играет его на полной громкости.
	ns_announcement.Announce(message, title, null, FALSE, TRUE, zlevels)
	if(voice)
		ns_announce_voice(voice, zlevels)

/// Голос оповещения тем, кто на нужных уровнях и не отключил звук объявлений, с громкостью NS_ANNOUNCE_VOLUME.
/proc/ns_announce_voice(voice, list/zlevels)
	if(!zlevels)
		zlevels = GLOB.using_map.contact_levels
	var/list/audible_levels = zlevels | GLOB.using_map.admin_levels
	for(var/mob/M in GLOB.player_list)
		if(!M.client || istype(M, /mob/new_player) || isdeaf(M))
			continue
		if(!(get_z(M) in audible_levels))
			continue
		if(M.client.get_preference_value(/datum/client_preference/play_announcement_sfx) != GLOB.PREF_YES)
			continue
		sound_to(M, sound(voice, repeat = 0, wait = 0, volume = NS_ANNOUNCE_VOLUME, channel = 0))
