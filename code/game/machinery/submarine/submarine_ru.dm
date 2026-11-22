/*
	РУССКИЕ ПОДПИСИ ПУЛЬТОВ (ревизия 24).

	Логика реактора и турбины по-прежнему работает на английских идентификаторах состояний ("RUNNING", "SPINNING UP", "HIGH CORE TEMP"):
	на них держатся сравнения, цвета и журналы. На экран пульта текст идёт через nsr_ru(), которая берёт перевод из таблицы ниже.
	Нет в таблице: текст остаётся как есть (так сразу видно забытую строку). Длинные фразы заданы парой nsr_tr("English", "Русский").
	Кодировка окон NanoUI переключена на UTF-8 (code/modules/nano/nanoui.dm), шаблоны пультов лежат в UTF-8.

	ПЕРЕКЛЮЧАТЕЛЬ ЯЗЫКА (ревизия 24.1). Кнопка в шапке пульта переключает язык этого игрока (по ckey) до конца раунда, по умолчанию русский.
	На каждом входе (открытие и обновление окна, OnTopic, действия инструментами с ядром) вызывается nsr_lang_for(user): она кладёт язык игрока
	в nsr_lang_cur, и дальше nsr_ru() и nsr_tr() отвечают на нём. DM не прерывает код между входами, поэтому общей переменной хватает.
	Шаблонов два: submarine_*_panel.tmpl (русский) и submarine_*_panel_en.tmpl (английский). Правка вида пульта делается в обоих.
*/

#define NSR_LANG_DEFAULT "ru"

/// Язык пультов по ckey игрока: "en" или "ru". Нет записи: NSR_LANG_DEFAULT.
var/global/list/nsr_lang_pref = list()
/// Язык, на котором сейчас собирается окно или сообщение. Ставится nsr_lang_for().
var/global/nsr_lang_cur = NSR_LANG_DEFAULT

var/global/list/nsr_ru_table = list(
	// Статус реактора
	"CORE MELTDOWN" = "РАСПЛАВ АКТИВНОЙ ЗОНЫ",
	"VESSEL RUPTURED" = "КОРПУС РАЗОРВАН",
	"LOSS OF COOLANT" = "ПОТЕРЯ ТЕПЛОНОСИТЕЛЯ",
	"PRIMARY LEAK" = "ТЕЧЬ ПЕРВОГО КОНТУРА",
	"CRITICAL" = "КРИТИЧНО",
	"WARNING" = "ПРЕДУПРЕЖДЕНИЕ",
	"AUTO SCRAM" = "АВТО-SCRAM",
	"OVERDRIVE" = "ФОРСАЖ",
	"OFFLINE" = "ОСТАНОВЛЕН",
	"NOMINAL" = "НОРМА",
	// Причины SCRAM и условия защиты
	"MANUAL" = "ВРУЧНУЮ",
	"HIGH CORE TEMP" = "ВЫСОКАЯ ТЕМПЕРАТУРА ЯДРА",
	"HIGH STEAM PRESSURE" = "ВЫСОКОЕ ДАВЛЕНИЕ ПАРА",
	"HIGH PRIMARY PRESSURE" = "ВЫСОКОЕ ДАВЛЕНИЕ ПЕРВОГО КОНТУРА",
	"HIGH PZR LEVEL" = "ВЫСОКИЙ УРОВЕНЬ В КОМПЕНСАТОРЕ",
	"LOW PRIMARY PRESSURE" = "НИЗКОЕ ДАВЛЕНИЕ ПЕРВОГО КОНТУРА",
	"LOW PZR LEVEL" = "НИЗКИЙ УРОВЕНЬ В КОМПЕНСАТОРЕ",
	"LOW WATER" = "МАЛО ВОДЫ",
	"MAIN PUMP SEIZED" = "ЗАКЛИНИЛ ГЛАВНЫЙ НАСОС",
	"COOLING LOST" = "ПОТЕРЯНО ОХЛАЖДЕНИЕ",
	// Почему автоматика не работает и состояния насосов
	"NO CONTROL" = "НЕТ УПРАВЛЕНИЯ",
	"NO AUTOMATION" = "АВТОМАТИКА НЕДОСТУПНА",
	"TWO-CIRCUIT ONLY" = "ТОЛЬКО ПРИ ДВУХ КОНТУРАХ",
	"NO REACTOR" = "НЕТ РЕАКТОРА",
	"NO INLET" = "НЕТ ВХОДА ВОДЫ",
	"NOT PIPED" = "НЕ ПОДКЛЮЧЁН К ТРУБАМ",
	"NO HEAD" = "НЕТ НАПОРА",
	"NO WATER" = "НЕТ ВОДЫ",
	"LIMITED BY SUPPLY" = "ОГРАНИЧЕНО ПОДАЧЕЙ",
	"NO PRESSURIZER" = "НЕТ КОМПЕНСАТОРА ДАВЛЕНИЯ",
	"NO POWER" = "НЕТ ПИТАНИЯ",
	"NO SUCTION" = "НЕТ ВСАСЫВАНИЯ",
	"VESSEL FULL" = "СОСУД ПОЛОН",
	"STOPPED" = "ОСТАНОВЛЕН",
	"RUNNING" = "РАБОТАЕТ",
	"BURNT OUT" = "СГОРЕЛ",
	"SEIZED" = "ЗАКЛИНИЛ",
	"COASTING DOWN" = "ВЫБЕГ",
	"SPINNING UP" = "РАЗГОН",
	"SPINNING DOWN" = "ТОРМОЖЕНИЕ",
	"AT SPEED" = "НА РЕЖИМЕ",
	// Компенсатор давления и подпитка
	"UNCOVERED" = "ОБНАЖЕНЫ",
	"OFF" = "ВЫКЛ",
	"HEATING" = "НАГРЕВ",
	"ISOLATED" = "ОТСЕЧЁН",
	"OPEN" = "ОТКРЫТ",
	"CLOSED" = "ЗАКРЫТ",
	"MAKING UP" = "ПОДПИТКА",
	"DRAINING" = "СЛИВ",
	// Парогенераторы
	"RUPTURED" = "РАЗРЫВ",
	"NO STEAM PORT" = "НЕТ ПАРОВОГО ВЫХОДА",
	"DRY" = "СУХОЙ",
	"VALVE CLOSED" = "КЛАПАН ЗАКРЫТ",
	"BOILING" = "КИПИТ",
	"LEAKING" = "ТЕЧЬ",
	"DAMAGED" = "ПОВРЕЖДЕНЫ",
	"OK" = "В ПОРЯДКЕ",
	// Турбина
	"LOCKED SHUT" = "ЗАБЛОКИРОВАН",
	"DUMPING" = "СБРОС",
	"ARMED" = "ГОТОВ",
	"normal" = "норма",
	"still" = "покой",
	"DANGER" = "ОПАСНО",
	"HIGH" = "ВЫСОКАЯ",
	"UNDERSPEED" = "НЕДОБОР ОБОРОТОВ",
	"OVERSPEED" = "РАЗГОН",
	"NO GRID" = "НЕТ СЕТИ",
	"BLADE LOST" = "ПОТЕРЯНА ЛОПАСТЬ",
	"SECTION WRECKED" = "СЕКЦИЯ РАЗРУШЕНА",
	"WRECKED" = "РАЗРУШЕНА",
	"IN ORDER" = "В ПОРЯДКЕ",
	"WORN" = "ИЗНОШЕНА",
	"POOR" = "ПЛОХОЕ",
	// Топливо
	"enriched uranium" = "обогащённый уран",
	"natural uranium" = "природный уран",
	"thorium" = "торий",
	"cesium" = "цезий",
	"unknown fuel" = "неизвестное топливо"
)

/// Выбрать язык по игроку и сделать его текущим. Вызывать в начале каждой точки входа.
/proc/nsr_lang_for(mob/user)
	var/pref = (user && user.ckey) ? nsr_lang_pref[user.ckey] : null
	nsr_lang_cur = pref ? pref : NSR_LANG_DEFAULT
	return nsr_lang_cur

/// Язык игрока ("ru" или "en") без побочных эффектов (nsr_lang_cur не трогает): для оповещений, которые идут сразу многим игрокам.
/proc/nsr_lang_code(mob/user)
	var/pref = (user && user.ckey) ? nsr_lang_pref[user.ckey] : null
	return pref ? pref : NSR_LANG_DEFAULT

/// Переключить язык игрока (русский и английский по очереди).
/proc/nsr_lang_toggle(mob/user)
	if(!user || !user.ckey)
		return
	nsr_lang_pref[user.ckey] = (nsr_lang_for(user) == "en") ? "ru" : "en"
	nsr_lang_for(user)

/proc/nsr_is_ru()
	return nsr_lang_cur != "en"

/// Фраза на текущем языке: nsr_tr("English", "Русский").
/proc/nsr_tr(en, ru)
	return nsr_is_ru() ? ru : en

/// Русский текст для пульта по таблице. Пустое и неизвестное возвращает как есть, на английском всегда как есть.
/proc/nsr_ru(text)
	if(!nsr_is_ru() || !istext(text) || !length(text))
		return text
	var/ru = nsr_ru_table[text]
	return ru ? ru : text

/// Выбор языка без пульта, в том числе в лобби: тот же язык у окон пультов и у голосовых оповещений.
/client/verb/ns13_language()
	set name = "NS-13 Language"
	set category = "OOC"
	set desc = "Switch the language of NS-13 console windows and voice announcements (English or Russian)."

	if(!mob)
		return
	nsr_lang_toggle(mob)
	if(nsr_lang_cur == "en")
		to_chat(src, SPAN_NOTICE("NS-13 consoles and announcements: English. Use this command again to switch back to Russian."))
	else
		to_chat(src, SPAN_NOTICE("Пульты и оповещения NS-13: русский. Чтобы вернуть английский, вызовите эту команду ещё раз."))
