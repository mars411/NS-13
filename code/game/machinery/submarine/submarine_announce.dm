/*
	NS-13: оповещения подлодки: текст в чат и голос на двух языках (русский и английский).
	Тексты и файлы описаны в README.md этой папки, раздел «Аудио проекта». Голосовые файлы ElevenLabs лежат в sound/ns13/announcements/.

	ЯЗЫК (ревизия 29). Личная настройка каждого игрока: nsr_lang_pref по ckey, переключается кнопкой языка в окнах пультов или командой
	«NS-13 Language» во вкладке OOC (работает и в лобби); без выбора действует NSR_LANG_DEFAULT. И текст в чат, и голос идут на языке игрока,
	поэтому оповещение собираем для каждого получателя отдельно, а не стоковым Announce(), который рассылает один текст всем.
	Уважается настройка игрока «звук объявлений»; глухие и новички лобби оповещение не получают, как в стоке.
*/

#define NS_ANN_PRIMARY_PRESSURE "primary_pressure"

/// Содержимое оповещения на языке lang: list(заголовок, текст, голосовой файл или null). null для неизвестного ключа.
/proc/ns_announce_content(key, lang)
	var/ru = (lang == NS_ANNOUNCE_LANG_RU)
	switch(key)
		if(NS_ANN_PRIMARY_PRESSURE)
			if(ru)
				return list("Реактор", "Внимание! Давление пара в первичном контуре превышает допустимые нормы. Угроза парового взрыва. Сбросьте давление.", 'sound/ns13/announcements/primary_pressure_high_ru.ogg')
			return list("Reactor", "Warning. Steam pressure in primary loop exceeding tolerance limits. Risk of steam explosion. Vent excess pressure immediately.", 'sound/ns13/announcements/primary_pressure_high_en.ogg')
	return null

/// Оповещение NS-13 каждому игроку на его языке. key: NS_ANN_*. zlevels: куда доставить, по умолчанию контактные уровни карты.
/proc/ns_announce(key, list/zlevels)
	if(!zlevels)
		zlevels = GLOB.using_map.contact_levels
	var/list/audible_levels = zlevels | GLOB.using_map.admin_levels
	// Текст и файл собираем один раз на язык: игроков может быть много, языков два.
	var/list/by_lang = list()
	for(var/mob/M in GLOB.player_list)
		if(!M.client || istype(M, /mob/new_player) || isdeaf(M))
			continue
		if(!(get_z(M) in audible_levels))
			continue
		var/lang = nsr_lang_code(M)
		if(!(lang in by_lang))
			var/list/content = ns_announce_content(key, lang)
			if(!content)
				return
			by_lang[lang] = list("<h1 class='alert'>[sanitizeSafe(content[1])]</h1><br>[SPAN_CLASS("alert", sanitize(content[2], extra = 0))]<br>", content[3])
		var/list/ready = by_lang[lang]
		to_chat(M, ready[1])
		var/voice = ready[2]
		if(voice && M.client.get_preference_value(/datum/client_preference/play_announcement_sfx) == GLOB.PREF_YES)
			sound_to(M, sound(voice, repeat = 0, wait = 0, volume = NS_ANNOUNCE_VOLUME, channel = 0))
