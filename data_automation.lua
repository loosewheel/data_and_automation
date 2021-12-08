--[[--------------------------------------------------------------------
								IMPLEMENTED HANDLERS

on_drop_item (itemstack, dropper, pos)
	returns itemstack to drop

on_pickup_item (itemstack, player)
	returns itemstack to picked up

on_destroy_item (itemstack)
	no return used

on_copy_item (itemstack)
	returns copied itemstack - the opportunity to duplicate the data and
	assign a new data_id

on_place_exact (itemstack, pos, look_dir, pointed_thing, player_name, controls, silent)
	returns if placed - true or false


									DATA MANAGEMENT

minetest.new_data_id ()
minetest.get_datapath (modname)
minetest.serialize_data (modname, data_id, data, context)
minetest.deserialize_data (modname, data_id, context)
minetest.remove_data (modname, data_id, context)


							MOD INTEGRATION AND AUTOMATION

minetest.destroy_item (itemstack)
minetest.destroy_inventory (inv, listname)
minetest.destroy_node (pos, force, silent, far_node)
minetest.dig_node (pos, toolname, silent, far_node)
minetest.drop_item (itemstack, dropper, pos)
minetest.pickup_item (entity, player, cleanup)
minetest.copy_item (itemstack)
minetest.place_item (itemstack, pos, look_dir, pointed_thing, placer_name, controls, silent)
minetest.can_break_node (pos, toolname)
minetest.get_adjacent_pos (pos, param2, side)
----------------------------------------------------------------------]]


--------------------------- HELPERS ------------------------------------

local function get_far_node (pos)
	local node = minetest.get_node_or_nil (pos)

	if not node then
		minetest.get_voxel_manip ():read_from_map (pos, pos)

		node = minetest.get_node_or_nil (pos)
	end

	return node
end



local function find_item_def (name)
	local def = minetest.registered_items[name]

	if not def then
		def = minetest.registered_craftitems[name]
	end

	if not def then
		def = minetest.registered_nodes[name]
	end

	if not def then
		def = minetest.registered_tools[name]
	end

	return def
end



local function get_palette_index (itemstack)
	local stack = ItemStack (itemstack)
	local color = 0

	if stack then
		local tab = stack:to_table ()

		if tab and tab.meta and tab.meta.palette_index then
			color = tonumber (tab.meta.palette_index) or 0
		end
	end

	return color
end



local function get_place_param2 (itemstack, look_dir)
	local stack = ItemStack (itemstack)
	local def = find_item_def (stack:get_name ())

	if def and def.paramtype2 then
		local pallet_index = get_palette_index (stack)

		if def.paramtype2 == "wallmounted" or
			def.paramtype2 == "colorwallmounted" then

			return minetest.dir_to_wallmounted (look_dir) + (pallet_index * 8)

		elseif def.paramtype2 == "facedir" or
				 def.paramtype2 == "colorfacedir" then

			return minetest.dir_to_facedir (look_dir, false) + (pallet_index * 32)

		elseif def.paramtype2 == "color" then
			return pallet_index

		else
			return def.param2 or 0

		end
	end

	return 0
end



----------------------- DATA MANAGEMENT --------------------------------


--[[--------------------------------------------------------------------
Returns a new integer data id. A unique identifier to link an item to
its data.
----------------------------------------------------------------------]]
function minetest.new_data_id ()
	return math.random (1000000)
end



--[[--------------------------------------------------------------------
Returns the mods data folder under the world folder.

modname: The string name of the mod.
----------------------------------------------------------------------]]
function minetest.get_datapath (modname)
	return minetest.get_worldpath ()..DIR_DELIM..modname
end



--[[--------------------------------------------------------------------
Serializes the data to the item's data storage.

modname: The string name of the mod.
data_id:	The item's unique integer data id.
data:		The data to store. This is passed to minetest.serialize.
context:	String context label, can be nil. An item can have more than
			one stored data with different contexts.

returns true if successful, false if not.
----------------------------------------------------------------------]]
function minetest.serialize_data (modname, data_id, data, context)
	local datapath = minetest.get_datapath (modname)

	minetest.mkdir (datapath)

	local filepath = string.format ("%s%s%s%d",
											  datapath,
											  DIR_DELIM,
											  tostring (context) or "",
											  data_id)

	return minetest.safe_file_write (filepath, minetest.serialize (data))
end



--[[--------------------------------------------------------------------
Deserializes item data from storage.

modname: The string name of the mod.
data_id:	The item's unique integer data id.
context:	String context label, can be nil. An item can have more than
			one stored data with different contexts.

returns the deserialized data or nil.
----------------------------------------------------------------------]]
function minetest.deserialize_data (modname, data_id, context)
	local filepath = string.format ("%s%s%s%d",
											  minetest.get_datapath (modname),
											  DIR_DELIM,
											  tostring (context) or "",
											  data_id)
	local file = io.open (filepath, "rb")

	if file then
		local data = file:read ("*a")

		file:close ()

		if data then
			return minetest.deserialize (data)
		end
	end

	return nil
end



--[[--------------------------------------------------------------------
Removes (deletes) stored item data.

modname: The string name of the mod.
data_id:	The item's unique integer data id.
context:	String context label, can be nil. An item can have more than
			one stored data with different contexts.

returns true if data was deleted, false if not.

*	Typically call this from the on_destroy_item handler.
----------------------------------------------------------------------]]
function minetest.remove_data (modname, data_id, context)
	local filepath = string.format ("%s%s%s%d",
											  minetest.get_datapath (modname),
											  DIR_DELIM,
											  tostring (context) or "",
											  data_id)

	return (os.remove (filepath)) ~= nil
end



----------------- MOD INTEGRATION AND AUTOMATION ----------------------



--[[--------------------------------------------------------------------
Calls the on_destroy_item handler for the item. When trashing an item,
calling this function allows the item definition to do any cleanup work.

itemstack: an itemstack of the item being destroyed.
----------------------------------------------------------------------]]
function minetest.destroy_item (itemstack)
	local stack = ItemStack (itemstack)

	if stack and not stack:is_empty () then
		local def = find_item_def (stack:get_name ())

		if def and def.on_destroy_item then
			def.on_destroy_item (stack)
		end
	end
end



--[[--------------------------------------------------------------------
Calls the on_destroy_item handler for every item in the inventory, and
clears the inventory. When trashing an item, calling this function allows
the item definition to do any cleanup work.

inv:			an InvRef containing the inventory.
listname:	list name of the inventory.
----------------------------------------------------------------------]]
function minetest.destroy_inventory (inv, listname)
	if inv then
		local slots = inv:get_size (listname)

		for i = 1, slots do
			local stack = inv:get_stack (listname, i)

			if stack then
				minetest.destroy_item (stack)

				inv:set_stack (listname, i, nil)
			end
		end
	end
end



--[[--------------------------------------------------------------------
Digs the node at pos with the tool and returns a list of the drops.

pos:			position of the node to dig.
toolname:	toolname can be string tool name, nil or true. if true the
				node is always dug with no specified tool.
silent:		if true any dig sound for the node is not played.
far_node:	true to load the node if not currently loaded

returns list of ItemStacks of drops, or nil on not dug (or no node).

* this function already exists in the api
----------------------------------------------------------------------]]
function minetest.dig_node (pos, toolname, silent, far_node)
	local node = nil
	local dig = false
	local drops = nil

	if far_node then
		node = get_far_node (pos)
	else
		node = minetest.get_node_or_nil (pos)
	end

	if toolname == true then
		dig = true
		toolname = nil
	end

	if silent == nil then
		silent = false
	end

	if node and node.name ~= "air" then
		local def = find_item_def (node.name)

		if not dig then
			if def and def.can_dig then
				local result, can_dig = pcall (def.can_dig, pos)

				dig = ((not result) or (result and (can_dig == nil or can_dig == true)))
			else
				dig = true
			end
		end

		if dig then
			local items = minetest.get_node_drops (node, toolname)

			if items then
				drops = { }

				for i = 1, #items do
					drops[i] = ItemStack (items[i])
				end

				if def and def.preserve_metadata then
					def.preserve_metadata (pos, node, minetest.get_meta (pos), drops)
				end
			end

			if not silent and def and def.sounds and def.sounds.dug then
				pcall (minetest.sound_play, def.sounds.dug, { pos = pos })
			end

			minetest.remove_node (pos)
		end
	end

	return drops
end



--[[--------------------------------------------------------------------
Removes a node calling the on_destroy_item handler.

pos:			position of the node to dig.
force:		if true removes the node even if can't be dug.
silent:		if true any dig sound for the node is not played.
far_node:	true to load the node if not currently loaded

returns true if removed, false if not
----------------------------------------------------------------------]]
function minetest.destroy_node (pos, force, silent, far_node)
	if force == false then
		force = nil
	else
		force = true
	end

	local drops = minetest.dig_node (pos, force, silent, far_node)

	if drops then
		for i = 1, #drops do
			minetest.destroy_item (drops[i])
		end

		return true
	end

	return false
end



--[[--------------------------------------------------------------------
Drops the item calling the item's on_drop_item handler if it has one.

itemstack: the item/s to drop.
dropper: the player dropping the item/s, can be nil.
pos: the world position the item/s is dropped.

Returns the leftover itemstack (calls minetest.item_drop).
----------------------------------------------------------------------]]
function minetest.drop_item (itemstack, dropper, pos)
	local stack = ItemStack (itemstack)

	if stack and not stack:is_empty () then
		local def = find_item_def (stack:get_name ())

		if def and def.on_drop_item then
			stack = def.on_drop_item (stack, dropper, pos)
		end
	end

	return minetest.item_drop (stack, dropper, pos)
end



--[[--------------------------------------------------------------------
Returns an ItemStack of the items in the given entity, and optionally
removes the entity, calling the on_pickup_item handler. On failure nil is
returned.

entity: this should be a "__builtin:item" entity, but is checked for
		  internally and returns nil if not.
cleanup: if not false, and the call succeeds, the entity is removed.

*	this function can be called first with cleanup as false to check the
	item, and if suitable called again with cleanup as nil or true to
	remove the entity.
----------------------------------------------------------------------]]
function minetest.pickup_item (entity, player, cleanup)
	local stack = nil

	if entity and entity.name and entity.name == "__builtin:item" and
		entity.itemstring and entity.itemstring ~= "" then

		stack = ItemStack (entity.itemstring)

		if stack and not stack:is_empty () then
			local def = find_item_def (stack:get_name ())

			if def and def.on_pickup_item then
				stack = def.on_pickup_item (stack, player)
			end
		end

		if cleanup ~= false then
			entity.itemstring = ""
			entity.object:remove ()
		end
	end

	return stack
end



--[[--------------------------------------------------------------------
Copies the itemstack and returns the copy. Calls the on_copy_item handler
to duplicate any data and assign a new data_id.
----------------------------------------------------------------------]]
function minetest.copy_item (itemstack)
	local stack = ItemStack (itemstack)

	if stack and not stack:is_empty () then
		local def = find_item_def (stack:get_name ())

		if def and def.on_copy_item then
			stack = def.on_copy_item (stack)
		end
	end

	return stack
end



--[[--------------------------------------------------------------------
Places a node at the position.

itemstack:		The item to place.
pos:				Position to place to.
look_dir:		Look direction or nil (straight down).
pointed_thing:	Can be nil (straight down placement).
placer_name:	Can be nil ("").
controls:		Table of player keys (player:get_player_control ()), can be nil.
silent:			if true any place sound for the node is not played.

returns stack, position - if not placed position is nil
----------------------------------------------------------------------]]
function minetest.place_item (itemstack, pos, look_dir, pointed_thing, placer_name, controls, silent)
	placer_name = tostring (placer_name or "")
	controls = controls or { }
	look_dir = (look_dir and vector.normalize (look_dir)) or { x = 0, y = -1, z = 0 }
	pointed_thing = pointed_thing or
						 {
							  type = "node",
							  under = { x = pos.x, y = pos.y, z = pos.z },
							  above = { x = pos.x, y = pos.y + 1, z = pos.z }
						  }


	local stack = ItemStack (itemstack)

	if stack and not stack:is_empty () then
		local itemdef = find_item_def (stack:get_name ())

		if itemdef and itemdef.on_place_exact then
			if itemdef.on_place_exact (stack, pos, look_dir, pointed_thing, player_name, controls, silent) then
				stack:take_item (1)

				return stack, pos
			end

			return stack, nil
		end

		local place_param2 = get_place_param2 (stack, look_dir)
		local place_param1 = (itemdef and itemdef.param1) or 0
		local take_item = true

		if not minetest.registered_nodes[stack:get_name ()] then
			return stack, nil
		end

		minetest.set_node (pos, { name = stack:get_name (), param1 = place_param1, param2 = place_param2 })

		if itemdef and itemdef.after_place_node then
			if itemdef.after_place_node (pos, nil, stack, pointed_thing) then
				take_item = false
			end
		end

		if not silent and itemdef and itemdef.sounds and itemdef.sounds.place then
			minetest.sound_play (itemdef.sounds.place, { pos = pos })
		end

		if take_item then
			stack:take_item (1)
		end

		return stack, pos
	end

	return stack, nil
end



--[[--------------------------------------------------------------------
Returns whether or not the given tool or hand can break the node at pos.

pos:			the position of the node to test.
toolname:	the name of the tool to test, can be nil to check hand only.

for tool returns
	true, toolname, wear

for hand returns
	true, nil, 0

can't break or no node returns
	false
----------------------------------------------------------------------]]
function minetest.can_break_node (pos, toolname)
	local node = minetest.get_node_or_nil (pos)

	if node and node.name ~= "air" then
		local node_def = minetest.registered_nodes[node.name]

		if node_def then
			local dig_params = nil

			-- try tool first
			if toolname then
				local tool_def = minetest.registered_items[toolname]

				if tool_def then
					dig_params =
						minetest.get_dig_params (node_def.groups,
														 tool_def.tool_capabilities)

					if dig_params.diggable then
						return true, toolname, dig_params.wear
					end
				end
			end

			-- then try hand
			dig_params =
				minetest.get_dig_params (node_def.groups,
												 minetest.registered_items[""].tool_capabilities)

			if dig_params.diggable then
				return true, nil, 0
			end
		end
	end

	return false
end



--[[--------------------------------------------------------------------
Get the position at the given side of the given position in relation to
the given facedir param2. returns nil if side is invalid.

pos:		reference position to get the side of.
param2:	ref facedir param2, 0 for none.
side:		side to get in relation to pos and param2. can be:
			"up", "down", "left", "left_up", "left_down", "right",
			"right_up", "right_down", "front", "front_up", "front_down" ,
			"back", "back_up", "back_down"
----------------------------------------------------------------------]]
function minetest.get_adjacent_pos (pos, param2, side)
	local base = nil

	if side == "up" then
		return { x = pos.x, y = pos.y + 1, z = pos.z }
	elseif side == "down" then
		return { x = pos.x, y = pos.y - 1, z = pos.z }
	elseif side == "left" then
		base = { x = -1, y = pos.y, z = 0 }
	elseif side == "left_up" then
		base = { x = -1, y = pos.y + 1, z = 0 }
	elseif side == "left_down" then
		base = { x = -1, y = pos.y - 1, z = 0 }
	elseif side == "right" then
		base = { x = 1, y = pos.y, z = 0 }
	elseif side == "right_up" then
		base = { x = 1, y = pos.y + 1, z = 0 }
	elseif side == "right_down" then
		base = { x = 1, y = pos.y - 1, z = 0 }
	elseif side == "front" then
		base = { x = 0, y = pos.y, z = 1 }
	elseif side == "front_up" then
		base = { x = 0, y = pos.y + 1, z = 1 }
	elseif side == "front_down" then
		base = { x = 0, y = pos.y - 1, z = 1 }
	elseif side == "back" then
		base = { x = 0, y = pos.y, z = -1 }
	elseif side == "back_up" then
		base = { x = 0, y = pos.y + 1, z = -1 }
	elseif side == "back_down" then
		base = { x = 0, y = pos.y - 1, z = -1 }
	else
		return nil
	end

	if param2 == 3 then -- +x
		return { x = base.z + pos.x, y = base.y, z = (base.x * -1) + pos.z }
	elseif param2 == 0 then -- -z
		return { x = (base.x * -1) + pos.x, y = base.y, z = (base.z * -1) + pos.z }
	elseif param2 == 1 then -- -x
		return { x = (base.z * -1) + pos.x, y = base.y, z = base.x + pos.z }
	elseif param2 == 2 then -- +z
		return { x = base.x + pos.x, y = base.y, z = base.z + pos.z }
	end

	return nil
end



--
