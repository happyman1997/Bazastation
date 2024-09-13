/obj/item/smithed_part/weapon_part/rapier_blade
	icon_state = "rapier_blade"
	base_name = "rapier blade"
	weapon_name = "rapier"

	hilt_icon = 'code/modules/smithing/icons/forge_items.dmi'
	hilt_icon_state = "rapier-hilt"

/obj/item/smithed_part/weapon_part/rapier_blade/finish_weapon()
	. = ..()
	sharpness = SHARP_POINTY
	wound_bonus = 10
	bare_wound_bonus = 25
	armour_penetration = -5
	AddComponent(/datum/component/multi_hit, icon_state = "stab", height = 2)

	attack_speed = CLICK_CD_LIGHT_WEAPON
	stamina_cost = round(20 * (100 / smithed_quality))

	force = round(((material_stats.density + material_stats.hardness) / 11) * (smithed_quality * 0.01))
	throwforce = force * 1.5
	w_class = WEIGHT_CLASS_NORMAL

/datum/component/multi_hit
	var/obj/item/item_parent
	///do we continue to travel after impacting the first mob
	var/continues_travel = FALSE
	///icon_state we use while attacking
	var/icon_state
	///icon file we use while attacking
	var/icon = 'code/modules/smithing/icons/multi_hit.dmi'
	///width we use from attacking - NOTE non odd widths will always offset 1 farther in the opposite of the direction traveled
	var/width = 1
	///height we use from attacking
	var/height = 1
	///the offset from center use for finding targets
	var/center_offset = 0
	///attacking direction if used (Goes from start to end so )
	var/attacking_direction = WEST
	///the callback we use after attacking something incase we have unique effects
	var/datum/callback/after_hit_callback
	///the prehit callback we use incase unique effects need to happen before hitting
	var/datum/callback/pre_hit_callback
	///the stamina cost for doing these swings
	var/stamina_cost = 20

///this is incredibly cursed i should probably move the default defines into this to make it not have a ton of if statements but that feels wrong aswell.
/datum/component/multi_hit/Initialize(continues_travel, icon_state, icon, width, height, center_offset, attacking_direction, after_hit_callback, pre_hit_callback, stamina_cost)
	if(!isitem(parent))
		return COMPONENT_INCOMPATIBLE

	if(continues_travel)
		src.continues_travel = continues_travel
	if(icon_state)
		src.icon_state = icon_state
	if(icon)
		src.icon = icon
	if(width)
		src.width = width
	if(height)
		src.height = height
	if(center_offset)
		src.center_offset = center_offset
	if(attacking_direction)
		src.attacking_direction = attacking_direction
	if(after_hit_callback)
		src.after_hit_callback = CALLBACK(parent, after_hit_callback)
	if(pre_hit_callback)
		src.pre_hit_callback = CALLBACK(parent, pre_hit_callback)
	if(stamina_cost)
		src.stamina_cost = stamina_cost
	item_parent = parent

/datum/component/multi_hit/Destroy(force, silent)
	after_hit_callback = null
	pre_hit_callback = null
	return ..()

/datum/component/multi_hit/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ITEM_PRE_ATTACK, PROC_REF(pre_hit_callback))

/datum/component/multi_hit/UnregisterFromParent()
	. = ..()
	UnregisterSignal(parent, COMSIG_ITEM_PRE_ATTACK)

/datum/component/multi_hit/proc/pre_hit_callback(datum/source, obj/item/thing, mob/user, params)
	SIGNAL_HANDLER

	if(HAS_TRAIT(user, TRAIT_PACIFISM))
		to_chat(user, span_warning("You can't bring youself to swing this!"))
		return COMPONENT_CANCEL_ATTACK_CHAIN

	///list of targeted turfs in order of apperance
	var/list/targeted_turfs = list()
	var/starting_offset = round(width * 0.5)
	var/turf/true_center = get_step(user, user.dir)
	var/turf/true_starting = true_center


	if(true_starting.density && true_center.density)
		return

	var/climbing_dir
	if(attacking_direction == WEST)
		climbing_dir = get_attacking_direction(EAST, user)
	else
		climbing_dir = get_attacking_direction(WEST, user)

	var/moving_direction = get_attacking_direction(attacking_direction, user)

	for(var/num in 1 to starting_offset)
		true_starting = get_step(true_starting, climbing_dir)

	var/turf/current_base = true_starting
	for(var/num in 1 to width)
		if(num != 1)
			current_base = get_step(current_base, moving_direction)
		for(var/num_h in 1 to height)
			if(num_h != 1)
				targeted_turfs += get_step(current_base, user.dir)
			else
				targeted_turfs += current_base

	if(pre_hit_callback)
		pre_hit_callback.Invoke(parent, null, user, targeted_turfs)

	var/breaks = FALSE
	for(var/turf/listed_turf as anything in targeted_turfs)
		if(breaks)
			break
		for(var/mob/living/target in listed_turf.contents)
			if(pre_hit_callback)
				pre_hit_callback.Invoke(parent, target, user, targeted_turfs)
			item_parent.multi_attack(target, user, attacking_direction)
			if(after_hit_callback)
				after_hit_callback.Invoke(parent, target, user, targeted_turfs)
			if(!continues_travel)
				breaks = TRUE
				break

	var/obj/effect/hit_effect = new(true_center)
	hit_effect.icon = icon
	hit_effect.icon_state = icon_state
	hit_effect.transform.Scale((width / 3), (height / 3))
	hit_effect.dir = user.dir
	switch(user.dir)
		if(NORTH)
			hit_effect.pixel_x = -32
		if(SOUTH)
			hit_effect.pixel_x = -32
			hit_effect.pixel_y = -64
		if(EAST)
			hit_effect.pixel_y = -32
		if(WEST)
			hit_effect.pixel_y = -32
			hit_effect.pixel_x = -64

	QDEL_IN(hit_effect, 3)

	user.changeNext_move(item_parent.attack_speed * 1.2)
	return COMPONENT_CANCEL_ATTACK_CHAIN


/datum/component/multi_hit/proc/get_attacking_direction(starting_dir, mob/user)
	switch(user.dir)
		if(NORTH)
			return starting_dir
		if(SOUTH)
			if(starting_dir == WEST)
				return EAST
			else
				return WEST
		if(EAST)
			if(starting_dir == WEST)
				return NORTH
			else
				return SOUTH
		if(WEST)
			if(starting_dir == WEST)
				return SOUTH
			else
				return NORTH


/obj/effect/hit_effect
	name = "Whoops!"
	desc = "Someone made an error and your seeing the name and description of this, please report this to the nearest code monkey."

/**
 * Called from multi_hit component
 *
 * Arguments:
 * * mob/living/target_mob - The mob being hit by this item
 * * mob/living/user - The mob hitting with this item
 * * params - Click params of this attack
 */
/obj/item/proc/multi_attack(mob/living/target_mob, mob/living/user, params, direction_traveled)
	var/signal_return = SEND_SIGNAL(src, COMSIG_ITEM_ATTACK, target_mob, user, params)
	if(signal_return & COMPONENT_CANCEL_ATTACK_CHAIN)
		return TRUE
	if(signal_return & COMPONENT_SKIP_ATTACK)
		return

	SEND_SIGNAL(user, COMSIG_MOB_ITEM_ATTACK, target_mob, user, params)

	if(item_flags & NOBLUDGEON)
		return

	if(damtype != STAMINA && force && HAS_TRAIT(user, TRAIT_PACIFISM))
		to_chat(user, span_warning("You don't want to harm other living beings!"))
		return

	if(!force && !HAS_TRAIT(src, TRAIT_CUSTOM_TAP_SOUND))
		playsound(loc, 'sound/weapons/tap.ogg', get_clamped_volume(), TRUE, -1)
	else if(hitsound)
		playsound(loc, hitsound, get_clamped_volume(), TRUE, extrarange = stealthy_audio ? SILENCED_SOUND_EXTRARANGE : -1, falloff_distance = 0)

	target_mob.lastattacker = user.real_name
	target_mob.lastattackerckey = user.ckey

	if(force && target_mob == user && user.client)
		user.client.give_award(/datum/award/achievement/misc/selfouch, user)

	target_mob.attacked_by(src, user)

	log_combat(user, target_mob, "attacked", src.name, "(DAMTYPE: [uppertext(damtype)])")
	add_fingerprint(user)
