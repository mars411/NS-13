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
2. Set the feedwater pump to about 100%. It fills the two steam generators with water. The pump needs power from the APC.
3. Check that the main coolant pump runs (primary flow 100%). It drives the reactor water through the steam generators. If it is stopped, raise its speed.
4. Raise the control rods: use the All rods links, or move each rod by itself. Rods move slowly.
5. Watch the core temperature, the steam pressure and the water level of the steam generators. Keep their water up.
6. SCRAM drops all rods fast. It can be reset once the core has cooled.
7. The core keeps making residual heat after a SCRAM (up to 15% of full power, fading over about twenty minutes). Without the main pump only natural circulation is left: it copes with residual heat, not with power.
8. The pressurizer keeps the reactor water under about 150 bar so it does not boil. Its automation is on at the start: heaters and spray hold the pressure. Watch the primary pressure and the pressurizer water level on the panel.
9. The makeup pump (west wall of the reactor hall) adds water to the primary circuit (plus) or drains it (minus). It stands still at the start. Too much water leaves no steam bubble and the pressure jumps: keep the pressurizer level below 80%.
10. Each steam generator has a steam valve button in the Steam generators block. Closed, it traps the steam: the pressure climbs and the generator bursts at 110 bar, so do not leave it closed. Opening it with a high pressure inside hammers the pipes.
11. The Mute alarm button next to the status silences the siren. It comes back by itself if things get worse or after the alarm ends.
12. A hot burst and a cold one are not the same. A hot vessel flashes into steam and explodes. A cold, water-filled one only cracks and leaks: cool it, drop the pressure and weld the crack. The fuel damage bar only grows when the core is hot and never goes back.
13. The alarm board under the status shows every alarm as a tile: yellow is a warning, red is critical, a blinking tile is not acknowledged yet. The tile marked FIRST lit first and usually points at the cause. Acknowledge / mute stops the blinking and the siren.
14. A steam generator can spring a tube leak (the Tubes line shows LEAKING): the reactor water pours into the steam side, the primary water level drops and the generator fills. Raise the makeup pump, SCRAM, lower the primary pressure to cut the leak, and plug the tubes with a welder once the reactor is cold and both circuits are depressurised. A dry steam generator on a hot core ruins its tubes.
15. The main coolant pump wears out when it pumps steam (cavitation), hot water or runs dry. At 100% wear it jams. Stop the reactor, let it cool and replace the bearings with a wrench. Without the pump only natural circulation is left.
16. The orange pipes around the reactor are the primary circuit. Hits, explosions and too much pressure crack them: a cracked pipe weeps hot water, a burst pipe is a loss of coolant. The primary water and pressure drain away, the water boils into steam in the room and leaves radioactive puddles. SCRAM, raise the makeup pump, stay out of the puddles (a mop cleans them). When the core is below 60 C and the pressure below 5 bar, weld the pipe.
17. A gas analyzer and a Geiger counter lie on the table at the south wall. Hold the counter in hand and switch it on.
18. Three automations are off by default. Rod automation holds the core temperature (140 C by default) by moving all four rods together, so the manual rod buttons go dead while it is on. Makeup automation holds the pressurizer water level (50 %) by itself and makes up a slow leak, but it cannot save you from a burst pipe. Protection (Arm) drops the rods on its own at a high core temperature, a high or low pressure or pressurizer level, a dry steam generator, a seized main pump or lost cooling, and shows the reason in the status and as the AUTO SCRAM tile. It will not let you reset SCRAM while the cause is still there."}

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
The feedwater pump loses power and stops, and the core starts to dry out. SCRAM the reactor before it overheats.
The rods drop, but the residual heat stays: with the pump dead it boils away about half the water in the next minutes. Restore power in time."}

/obj/item/paper/reactor_test/hall
	name = "reactor test: the hall"
	info = {"\[large\]\[b\]Reactor hall\[/b\]\[/large\]
\[hr\]
The core and three sections form a 2x2 block. The main coolant pump stands west of it, the pressurizer (the yellow tank) stands above it and the makeup pump by the west wall. Two steam generators stand east of the core: the reactor water gives them its heat and boils clean water in them. The steam leaves through their ports, passes a gauge and a manual valve and goes through the gap in the east wall to the turbine hall.
Water comes back from the condenser through the cyan pipes of the south line (through the second gap in the wall) to the feedwater pump, and from the pump through a pipe to the feedwater inlet, which fills both steam generators.
To test leaks, unwrench a water pipe with the wrench: the water runs out onto the floor as a puddle, and air does not get into the pipe.
The table by the north wall holds a gas analyzer and a Geiger counter: scan the steam pipes and watch the radiation near the core."}

/obj/item/paper/reactor_test/warning
	name = "reactor test: warning"
	info = {"\[large\]\[b\]Warning\[/b\]\[/large\]
\[hr\]
Close the steam valve with the rods up and a steam generator bursts within a few minutes. Stay away.
A wrench lies on the floor: unbolt an armour plate and the radiation grows fourfold.
Overfill the primary circuit with the makeup pump and the vessel bursts. If the pressure falls and the pressurizer level drains, a relief valve may be stuck open: close its block valve at once."}

/obj/item/paper/reactor_test/turbine
	name = "reactor test: turbine"
	info = {"\[large\]\[b\]Turbine hall: start-up\[/b\]\[/large\]
\[hr\]
1. Bring the reactor up first: rods at about 40-60%, the feedwater pump running. The steam comes through the gap in the west wall.
2. Click a turbine panel (one stands next to the reactor panel in the control room, one here in the turbine hall). Keep the speed governor ON at 7500 rpm: it opens the admission valve slowly by itself.
3. Watch the shaft speed. At 5000-10000 rpm click Close breaker: the generator now feeds the test load bank.
4. Touch the load bank to change the load from 0 to 200 kW. The generator follows the load; the rods decide how much power the plant can make, about 2.4 kW per 1% of rods.
5. The red relief valve dumps steam straight to the condenser above 40 bar. Touch it to lock it shut.
6. The stop valve slams shut by itself at 11000 rpm. It can be reset only below 6000 rpm.
7. The autolathe in the south-east corner makes turbine blades from steel (two stacks of steel lie on the table beside it, spare blades on the other table). The blade service procedure is described on the turbine panel."}

/obj/item/paper/reactor_test/turbine_warning
	name = "reactor test: turbine warning"
	info = {"\[large\]\[b\]Turbine warning\[/b\]\[/large\]
\[hr\]
Above 12000 rpm the sections take damage, and at 16000 the weakest one tears apart.
Dropping the load with the governor OFF can do exactly that. Lock the relief valve and then lose the turbine, and the reactor vessel is on its own: SCRAM it."}
