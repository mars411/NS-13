/*
	NS-13: звуки подлодки в одном месте. Замена любого звука это замена одной строки ниже, в остальном коде звуки не прописаны.
	Файлы лежат в sound/machines/submarine/ или в стоковых папках. Откуда взяты звуки из сборки NuPhase-2026, смотрите README.md
	(«Заимствованные ресурсы»): происхождение этих файлов в той сборке не указано, до релиза их надо подтвердить или заменить.
*/

// Тревоги и защиты
#define NS_SND_ALARM_WARN       'sound/machines/submarine/ann_soft.ogg'    // реактор: тревога первой ступени
#define NS_SND_ALARM_CRIT       'sound/machines/submarine/ann_crit.ogg'    // реактор: критическая тревога (повторяется)
#define NS_SND_SCRAM            'sound/machines/buzz-two.ogg'              // стержни сброшены
#define NS_SND_TRIP             'sound/machines/warning-buzzer.ogg'        // сработала защита, поломка, разрушение
// Турбина
#define NS_SND_TURBINE_START    'sound/machines/submarine/turbine_start.ogg' // раскрутка (один раз при разгоне)
#define NS_SND_TURBINE_LOOP     'sound/machines/submarine/turbine_loop.ogg'  // гул работы (петля, громкость по оборотам)
#define NS_SND_TURBINE_STOP     'sound/machines/submarine/turbine_stop.ogg'  // остановка (один раз при торможении)
#define NS_SND_VIBRATION        'sound/machines/submarine/vibration.ogg'
#define NS_SND_VIBRATION_HEAVY  'sound/machines/submarine/vibration_heavy.ogg'
#define NS_SND_BREAKER          'sound/machines/switch2.ogg'               // автомат генератора замкнулся
// Насос и мелочи
#define NS_SND_PUMP_LOOP        'sound/machines/pump.ogg'
#define NS_SND_HATCH_OPEN       'sound/machines/blastdoor_open.ogg'
#define NS_SND_HATCH_CLOSE      'sound/machines/blastdoor_close.ogg'
#define NS_SND_WRENCH           'sound/items/Ratchet.ogg'
#define NS_SND_WELD             'sound/items/Welder.ogg'
#define NS_SND_BUILT            'sound/items/Deconstruct.ogg'              // что-то собрано, починено
#define NS_SND_RELIEF           'sound/machines/hiss.ogg'                  // предохранительный клапан компенсатора открылся
#define NS_SND_SPARKS           'sound/effects/sparks4.ogg'
