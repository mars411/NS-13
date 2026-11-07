/*
	ТАБЛО ТРЕВОГ (ревизия 18, вынесено из реактора ревизии 17)

	Общий класс для пультов реактора и турбины. Хранит уровень каждой плитки (0 норма, 1 жёлтая, 2 красная), что оператор уже подтвердил
	и плитку-«первопричину» (загорелась первой при новом событии, как на настоящих щитах). Тревоги сами считает владелец (реактор или
	турбина) и раз в тик отдаёт готовый список уровней в update(). Плитка мигает, пока не подтверждена; подтверждение теряется, когда
	плитка ослабла или погасла, поэтому новое ухудшение снова мигает.
*/

/datum/ns_annunciator
	/// id плитки -> подпись. Порядок списка это порядок плиток на пульте.
	var/list/labels
	/// id плитки -> текущий уровень, 0-2.
	var/list/levels = list()
	/// id плитки -> подтверждённый уровень.
	var/list/ack = list()
	/// id плитки, загоревшейся первой при последнем событии (null, когда всё погасло).
	var/first_out

/datum/ns_annunciator/New(list/label_list)
	..()
	labels = label_list
	for(var/id in labels)
		levels[id] = 0

/// Пустой список уровней (все плитки погашены): заготовка для владельца.
/datum/ns_annunciator/proc/blank()
	var/list/tiles = list()
	for(var/id in labels)
		tiles[id] = 0
	return tiles

/// Принимает новые уровни плиток. Подтверждение теряется у погасших и ослабших плиток, «первая» плитка берётся у нового события.
/datum/ns_annunciator/proc/update(list/tiles)
	var/was_active = has_active()
	var/now_active = FALSE
	for(var/id in tiles)
		var/lvl = tiles[id]
		if(!lvl)
			ack -= id
			continue
		now_active = TRUE
		if(!was_active && !first_out)
			first_out = id
		if(ack[id] > lvl)
			ack[id] = lvl
	if(!now_active)
		first_out = null
	levels = tiles

/// Горит ли хоть одна плитка.
/datum/ns_annunciator/proc/has_active()
	for(var/id in levels)
		if(levels[id])
			return TRUE
	return FALSE

/// Есть ли горящая плитка, которую ещё не подтвердили (она мигает).
/datum/ns_annunciator/proc/has_unacked()
	for(var/id in levels)
		var/lvl = levels[id]
		if(lvl && lvl > ack[id])
			return TRUE
	return FALSE

/// Подтвердить все горящие плитки (мигание прекращается).
/datum/ns_annunciator/proc/acknowledge()
	for(var/id in levels)
		if(levels[id])
			ack[id] = levels[id]

/// Плитки для шаблона NanoUI: подпись, уровень, мигает ли, первая ли.
/datum/ns_annunciator/proc/ui_tiles()
	var/list/tile_list = list()
	for(var/id in labels)
		var/lvl = levels[id] || 0
		tile_list += list(list("label" = labels[id], "level" = lvl, "blink" = (lvl > 0 && lvl > (ack[id] || 0)), "first" = (first_out == id)))
	return tile_list
