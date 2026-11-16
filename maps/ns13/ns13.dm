#if !defined(using_map_DATUM)
	#include "ns13_define.dm"
	#include "ns13_areas.dm"
	#include "ns13_guides.dm"
	#include "ns13_items.dm"

	#include "ns13-1.dmm"

	#define using_map_DATUM /datum/map/ns13

#elif !defined(MAP_OVERRIDE)

	#warn A map has already been included, ignoring ns13

#endif
