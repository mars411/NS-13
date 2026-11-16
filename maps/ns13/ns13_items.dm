// Предметы, которые нужны только карте палубы 3.

/// Ящик радиационной защиты: у стокового ящика только костюмы, а к костюму положен ещё и капюшон (шлем).
/obj/structure/closet/crate/radiation_gear/ns13/WillContain()
	return list(
		/obj/item/clothing/suit/radiation = 4,
		/obj/item/clothing/head/radiation = 4
	)
