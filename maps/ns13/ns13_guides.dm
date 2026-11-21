// Бумажные гайды карты палубы 3 (ns13). Лежат на столах. Тексты хранятся здесь, а не в .dmm: в файле карты длинные строки опасны
// (компилятор может не загрузить карту).
//
// Язык: в этом форке «Sol Common» называется "Zurich Accord Common" (LANGUAGE_HUMAN_EURO), он же язык бумаги по умолчанию.
// Но он белый (WHITELISTED), и персонаж с другим родным языком видит на такой бумаге кашу. Поэтому гайд ещё и читается
// всеми независимо от языка персонажа (show_content ниже). Писать на нём ничего нельзя.

/obj/item/paper/ns13
	name = "deck 3 notes"
	language = LANGUAGE_HUMAN_EURO

/obj/item/paper/ns13/show_content(mob/user, force, editable)
	return ..(user, TRUE, FALSE)

/obj/item/paper/ns13/control_room
	name = "deck 3: start-up"
	info = {"\[large\]\[b\]Reactor: start-up\[/b\]\[/large\]
\[hr\]
0. If the boat is dark, start with emergency power: the generator room is south of the main corridor (see the paper on its table). The whole start-up chain needs about 28 kW, so one generator at output 2 is enough.
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
18. Three automations are off by default. Rod automation holds the core temperature (140 C by default) by moving all four rods together, so the manual rod buttons go dead while it is on. Makeup automation holds the pressurizer water level (50 %) by itself and makes up a slow leak, but it cannot save you from a burst pipe. Protection (Arm) drops the rods on its own at a high core temperature, a high or low pressure or pressurizer level, a dry steam generator, a seized main pump or lost cooling, and shows the reason in the status and as the AUTO SCRAM tile. It will not let you reset SCRAM while the cause is still there.
19. Overdrive (two circuits only) makes the same rods give 30 % more heat: more steam and up to 330 kW instead of 250, but a smaller margin to the limits, more radiation and more decay heat after a stop. Do not use it on a light load. It switches off by itself on SCRAM.
20. Xenon. After a SCRAM or a big power cut the core poisons itself: xenon builds up for about three minutes and fades over about twenty. While it is high the same rods give less power (the panel shows the rod travel lost, the XENON PIT tile lights). Under power xenon burns out, so raise the rods higher than you need, wait a minute and lower them again. At a steady full power it costs nothing; the rod automation compensates by itself until the rods run out.
21. Fuel. The core starts EMPTY: with no fuel elements the reactor makes no heat at all. Before the first start take four enriched uranium elements from the crate by the west wall of the reactor hall, unbolt the core armour plate with a wrench, click the core with each element in hand (the core must be cold, the rods in, the pressure low) and bolt the plate back. The core holds four TVEL fuel elements. They burn with the power, not with the clock: about 10 minutes at full rods, about 20 at 60-80 %, about 30 at half, and the output fades over the last 15 % of an element. The panel shows the burnup of every element and the minutes left; the FUEL LOW tile lights near the end. To refuel: SCRAM, all rods in, wait until the core is below 60 C and the pressure is low, unbolt the core armour plate with a wrench, pry an element out with a crowbar (with several inside, a menu asks which one, a fresh element too) and lower another in. Spent elements are radioactive: wear a radiation suit with its hood. Spare elements (enriched uranium, natural uranium, thorium, cesium) lie in the crate by the west wall of the reactor hall. Cesium is hot and quick, thorium is slow, natural uranium is weak.
22. Fuel supply. Fuel comes from the seabed. The seabed dredge in the workshop on deck 3 rakes nodules into its hopper while it runs (touch it, press Start; one nodule every 20 s, mostly uranium, less thorium, rarely cesium). Take the nodules out as a sack and pour the sack into the isotope centrifuge beside it (click the machine with the sack), then pick a product in its window: natural uranium (2 nodules, 30 s), enriched uranium (5 nodules, 90 s), thorium (3, 45 s), cesium (3, 45 s). The fuel element comes out in front of the centrifuge. Pouring a sack opens the centrifuge window; both windows open even without power and then say NO POWER (the machines need power from the grid). A test sack of nodules lies beside the machines. The dredge is a placeholder: it is not tied to the depth or the seabed yet. Both windows have a language button.
23. Control rod wear. Every rod wears: a little with every move, with the neutron flux (more at high power and deeper in the core) and a lot with a SCRAM drop. From 40 % wear the drive slows down, from 60 % the ROD WEAR tile lights yellow, and at 100 % the rod seizes: it will not go up (the panel says SEIZED) and only slowly goes down, so the power of the core is capped. The panel shows the wear of every rod. To replace one: SCRAM, all rods in, the core cold and depressurised, unbolt the core armour plate with a wrench, click the core with a new rod in hand (spare rods lie in the fuel crate), pick which rod to replace, and the old one comes into your hands. A worn rod can be put back. Fuel elements, rods and the crowbar work through any of the four parts of the reactor (the core or a section). Each part has its own fuel channel, the Fuel tab lists them by the side of the block (north-west, north-east and so on): a fuel element goes into the channel of the part you click, the crowbar pries that part's element out, and the armour plate of that part has to be off. So load the four channels one by one, opening each plate in turn. If the panel says the vessel is still under pressure, it quotes the pressure of the primary circuit (not the steam gauge): switch the pressure automation off, set the heaters to zero and open the relief valve by hand, it takes about two minutes from 150 bar.
24. The reactor panel is split into tabs: Overview (the main gauges), Rods and power (rods, xenon, rod automation, boost, protection), Fuel, Primary circuit (pump, pressurizer, makeup), Steam and feed (steam generators, feed pump, steam valve) and Help. The SCRAM button and the annunciator are visible on every tab; an exclamation mark before a tab name means a tile of that tab is lit.
25. The turbine panel has tabs too: Overview (shaft speed, vibration, power, pressures), Control (governor, setpoint, admission valve, generator breaker), Steam and condenser (pressures along the steam path, condenser cooling and its automation, relief valve), Sections (blade rows) and Help. The annunciator, alarm acknowledgement and EMERGENCY STOP are visible on every tab."}

/obj/item/paper/ns13/hatches
	name = "deck 3: hatches"
	info = {"\[large\]\[b\]Pressure hatches\[/b\]\[/large\]
\[hr\]
The reactor hall is to the east, behind two pressure hatches.
Click a hatch to turn its wheel. It takes a few seconds and needs no power.
A hatch will not close while someone stands in it."}

/obj/item/paper/ns13/blackout
	name = "deck 3: blackout"
	info = {"\[large\]\[b\]Blackout test\[/b\]\[/large\]
\[hr\]
Switch off the main breaker of the reactor hall APC (west wall of the hall, right of the first hatch), or stop all emergency generators and wait for the APC cell to run down.
The feedwater pump loses power and stops, and the core starts to dry out. SCRAM the reactor before it overheats.
The rods drop, but the residual heat stays: with the pump dead it boils away about half the water in the next minutes. Restore power in time."}

/obj/item/paper/ns13/hall
	name = "deck 3: the hall"
	info = {"\[large\]\[b\]Reactor hall\[/b\]\[/large\]
\[hr\]
The core and three sections form a 2x2 block. The main coolant pump stands west of it, the pressurizer (the yellow tank) stands above it and the makeup pump by the west wall. Two steam generators stand east of the core: the reactor water gives them its heat and boils clean water in them. The steam leaves through their ports, passes a gauge and a manual valve and goes through the gap in the east wall to the turbine hall.
Water comes back from the condenser through the cyan pipes of the south line (through the second gap in the wall) to the feedwater pump, and from the pump through a pipe to the feedwater inlet, which fills both steam generators.
To test leaks, unwrench a water pipe with the wrench: the water runs out onto the floor as a puddle, and air does not get into the pipe.
The table by the north wall holds a gas analyzer and a Geiger counter: scan the steam pipes and watch the radiation near the core."}

/obj/item/paper/ns13/warning
	name = "deck 3: warning"
	info = {"\[large\]\[b\]Warning\[/b\]\[/large\]
\[hr\]
Close the steam valve with the rods up and a steam generator bursts within a few minutes. Stay away.
A wrench lies on the floor: unbolt an armour plate and the radiation grows fourfold.
Overfill the primary circuit with the makeup pump and the vessel bursts. If the pressure falls and the pressurizer level drains, a relief valve may be stuck open: close its block valve at once."}

/obj/item/paper/ns13/turbine
	name = "deck 3: turbine"
	info = {"\[large\]\[b\]Turbine hall: start-up\[/b\]\[/large\]
\[hr\]
1. Bring the reactor up first: rods at about 40-60%, the feedwater pump running. The steam comes through the gap in the west wall.
2. Click a turbine panel (one stands next to the reactor panel in the control room, one here in the turbine hall). Keep the speed governor ON at 7500 rpm: it opens the admission valve slowly by itself.
3. Watch the shaft speed. At 5000-10000 rpm the governor connects the generator by itself after 5 s (with the governor off, click Close breaker yourself): the generator now feeds the test load bank.
4. Touch the load bank to change the load from 0 to 200 kW. The generator follows the load; the rods decide how much power the plant can make, about 2.4 kW per 1% of rods.
5. The red relief valve dumps steam straight to the condenser above 40 bar. Touch it to lock it shut.
6. The stop valve slams shut by itself at 11000 rpm. It can be reset only below 6000 rpm.
7. The autolathe in the south-east corner makes turbine blades from steel (two stacks of steel lie on the table beside it, spare blades on the other table). The blade service procedure is described on the turbine panel."}

/obj/item/paper/ns13/turbine_warning
	name = "deck 3: turbine warning"
	info = {"\[large\]\[b\]Turbine warning\[/b\]\[/large\]
\[hr\]
Above 12000 rpm the sections take damage, and at 16000 the weakest one tears apart.
Dropping the load with the governor OFF can do exactly that. Lock the relief valve and then lose the turbine, and the reactor vessel is on its own: SCRAM it."}

/obj/item/paper/ns13/emergency_power
	name = "deck 3: emergency power"
	info = {"\[large\]\[b\]Emergency power\[/b\]\[/large\]
\[hr\]
1. Three PACMAN generators stand along the south wall. The first is loaded with 50 phoron sheets, two more stacks lie on this table.
2. Click a generator, set its output to 2 (40 kW) and switch it on. Above output 4 it overheats and above 5 it can explode.
3. The generators feed the main cable run along the corridor and through it the APC of every room. The cables run under the floor plates, under the doors too.
4. The reactor start-up chain needs about 28 kW: the main pump 8, the feedwater pump 5, the pressurizer heaters 12, the makeup pump 3. One generator at output 2 covers it, the lights and the rest of the boat need more.
5. A sheet lasts about 96 s at output 1, half of that at output 2: the loaded stack runs about 40 minutes. Load more sheets in time.
6. The turbine generator feeds only the load bank in the turbine hall for now. Linking it to the boat grid comes with the battery stage."}

/obj/item/paper/ns13/battery
	name = "deck 3: battery bay"
	info = {"\[large\]\[b\]Battery bay (placeholder)\[/b\]\[/large\]
\[hr\]
The lead-acid battery banks go here, far from the reactor. The crates stand in for them until the battery stage is built."}

/obj/item/paper/ns13/algae
	name = "deck 3: algae bay"
	info = {"\[large\]\[b\]Algae bay (placeholder)\[/b\]\[/large\]
\[hr\]
The algae oxygen generators and the botanist's workplace come here. The trays stand in for them."}

/obj/item/paper/ns13/shaft
	name = "deck 3: shaft room"
	info = {"\[large\]\[b\]Propeller shaft room (placeholder)\[/b\]\[/large\]
\[hr\]
The turbine shaft will carry the propeller here. Its load will depend on the speed of the boat."}
