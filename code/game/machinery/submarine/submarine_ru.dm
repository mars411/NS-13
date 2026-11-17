/*
	РУССКИЕ ПОДПИСИ ПУЛЬТОВ (ревизия 24).

	Логика реактора и турбины по-прежнему работает на английских идентификаторах состояний ("RUNNING", "SPINNING UP", "HIGH CORE TEMP"):
	на них держатся сравнения, цвета и журналы. На экран пульта текст идёт через nsr_ru(), которая берёт перевод из таблицы ниже.
	Нет в таблице: текст остаётся как есть (так сразу видно забытую строку). Подписи плиток табло и длинные фразы заданы по-русски прямо в коде.
	Кодировка окон NanoUI переключена на UTF-8 (code/modules/nano/nanoui.dm), шаблоны пультов лежат в UTF-8.
*/

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

/// Русский текст для пульта. Пустое и неизвестное возвращает как есть.
/proc/nsr_ru(text)
	if(!istext(text) || !length(text))
		return text
	var/ru = nsr_ru_table[text]
	return ru ? ru : text
