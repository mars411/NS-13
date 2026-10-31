// Бумажные гайды тестовой карты. Лежат на столах. Тексты хранятся здесь, а не в .dmm: в файле карты длинные строки опасны
// (компилятор может не загрузить карту).
//
// Язык: в этом форке «Sol Common» называется "Zurich Accord Common" (LANGUAGE_HUMAN_EURO), он же язык бумаги по умолчанию.
// Но он белый (WHITELISTED), и персонаж с другим родным языком видит на такой бумаге кашу. Поэтому гайд ещё и читается
// всеми независимо от языка персонажа (show_content ниже). Писать на нём ничего нельзя.

/obj/item/paper/reactor_test
	name = "reactor test notes"
	language = LANGUAGE_HUMAN_EURO

/obj/item/paper/reactor_test/show_content(mob/user, force, editable)
	return ..(user, TRUE, FALSE)

/obj/item/paper/reactor_test/control_room
	name = "reactor test: start-up"
	info = {"\[large\]\[b\]Reactor test lab: start-up\[/b\]\[/large\]
\[hr\]
1. Click the reactor panel on the north wall.
2. Set the feedwater pump to about 100%. The pump needs power from the APC.
3. Raise the control rods: use the All rods links, or move each rod by itself. Rods move slowly.
4. Watch the temperature, the steam pressure and the water level. Keep the water level up.
5. SCRAM drops all rods fast. It can be reset once the core has cooled."}

/obj/item/paper/reactor_test/hatches
	name = "reactor test: hatches"
	info = {"\[large\]\[b\]Pressure hatches\[/b\]\[/large\]
\[hr\]
The reactor hall is to the east, behind two pressure hatches.
Click a hatch to turn its wheel. It takes a few seconds and needs no power.
A hatch will not close while someone stands in it."}

/obj/item/paper/reactor_test/blackout
	name = "reactor test: blackout"
	info = {"\[large\]\[b\]Blackout test\[/b\]\[/large\]
\[hr\]
Switch off the main breaker of the APC at the west end of the start hall.
The feedwater pump loses power and stops, and the core starts to dry out. SCRAM the reactor before it overheats."}

/obj/item/paper/reactor_test/hall
	name = "reactor test: the hall"
	info = {"\[large\]\[b\]Reactor hall\[/b\]\[/large\]
\[hr\]
The core and three sections form a 2x2 block. Steam leaves east of the core, passes a gauge and a manual valve and goes through the gap in the east wall to the turbine hall.
Water comes back from the condenser through the cyan pipes of the south line (through the second gap in the wall) to the feedwater pump, and from the pump through a pipe to the inlet on the vessel.
To test leaks, unwrench a water pipe with the wrench: the water runs out onto the floor as a puddle, and air does not get into the pipe."}

/obj/item/paper/reactor_test/warning
	name = "reactor test: warning"
	info = {"\[large\]\[b\]Warning\[/b\]\[/large\]
\[hr\]
Close the steam valve with the rods up and the vessel bursts within a few minutes. Stay away.
A wrench lies on the floor: unbolt an armour plate and the radiation grows fourfold."}

/obj/item/paper/reactor_test/turbine
	name = "reactor test: turbine"
	info = {"\[large\]\[b\]Turbine hall: start-up\[/b\]\[/large\]
\[hr\]
1. Bring the reactor up first: rods at about 40-60%, the feedwater pump running. The steam comes through the gap in the west wall.
2. Click the turbine panel. Keep the speed governor ON at 7500 rpm: it opens the admission valve slowly by itself.
3. Watch the shaft speed. At 5000-10000 rpm click Close breaker: the generator now feeds the test load bank.
4. Touch the load bank to change the load from 0 to 200 kW. The generator follows the load; the rods decide how much power the plant can make, about 2.4 kW per 1% of rods.
5. The red relief valve dumps steam straight to the condenser above 40 bar. Touch it to lock it shut.
6. The stop valve slams shut by itself at 11000 rpm. It can be reset only below 6000 rpm."}

/obj/item/paper/reactor_test/turbine_warning
	name = "reactor test: turbine warning"
	info = {"\[large\]\[b\]Turbine warning\[/b\]\[/large\]
\[hr\]
Above 12000 rpm the sections take damage, and at 16000 the weakest one tears apart.
Dropping the load with the governor OFF can do exactly that. Lock the relief valve and then lose the turbine, and the reactor vessel is on its own: SCRAM it."}
