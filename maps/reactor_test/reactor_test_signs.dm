// Таблички тестовой карты. Тексты лежат здесь, а не в .dmm: в файле карты длинные строки опасны (компилятор может не загрузить карту).
// Это таблички, а не бумага: бумага написана на языке "Zurich Accord Common" и непонятна тем, кто его не знает.

/obj/structure/sign/reactor_test
	icon_state = "atmosplaque"

/obj/structure/sign/reactor_test/control_room
	name = "reactor test notes"
	desc = "Reactor test lab, control room. Open the reactor panel on the north wall. Raise the control rods one by one, they move slowly. Set the feedwater pump to about 100 percent, the pump needs power."

/obj/structure/sign/reactor_test/hatches
	name = "hatch notes"
	desc = "The reactor hall is to the east, behind two pressure hatches. Click a hatch to turn its wheel: it takes four seconds and needs no power. SCRAM drops the rods fast and can be reset once the core has cooled."

/obj/structure/sign/reactor_test/blackout
	name = "blackout test notes"
	desc = "To test a blackout, switch off the main breaker of the APC at the west end of the start hall. The feedwater pump stops and the core starts to dry out."

/obj/structure/sign/reactor_test/hall
	name = "reactor hall notes"
	icon_state = "radiation"
	desc = "Reactor hall. The core and three sections form a 2x2 block. Steam leaves east of the core, passes a gauge and a manual valve and reaches the condenser. Water returns through the cyan pipes of the south line to the feedwater pump."

/obj/structure/sign/reactor_test/hall_warning
	name = "reactor hall warning"
	icon_state = "radiation"
	desc = "Close the valve with the rods up and the vessel bursts in a few minutes, stay away. A wrench lies on the floor: unbolt an armour plate and the radiation grows fourfold."
