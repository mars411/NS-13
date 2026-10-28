#if !defined(using_map_DATUM)
	#include "reactor_test_define.dm"
	#include "reactor_test_areas.dm"
	#include "reactor_test_shuttles.dm"
	#include "reactor_test_radio.dm"
	#include "reactor_test_unit_testing.dm"
	#include "reactor_test_signs.dm"

	#include "reactor_test-1.dmm"
	#include "reactor_test-2.dmm"
	#include "reactor_test-3.dmm"

	#define using_map_DATUM /datum/map/reactor_test

#elif !defined(MAP_OVERRIDE)

	#warn A map has already been included, ignoring reactor_test

#endif
