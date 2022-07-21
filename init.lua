-------------------
-- Edit Mod v1.0 --
-------------------

local player_data = {}

local paste_preview_max_entities = tonumber(minetest.settings:get("paste_preview_max_entities") or 2000)
local max_operation_volume = tonumber(minetest.settings:get("max_operation_volume") or 20000)

local function create_paste_preview(player)
	local player_pos = player:get_pos()
	local base_objref = minetest.add_entity(player_pos, "edit:preview_base")
	local schematic = player_data[player].schematic

	local count = 0
	for i, map_node in pairs(schematic.data) do
		if map_node.name ~= "air" then count = count + 1 end
	end
	local probability = paste_preview_max_entities / count
	
	local start = vector.new(1, 1, 1)
	local voxel_area = VoxelArea:new({MinEdge = start, MaxEdge = schematic.size})
	local size = schematic.size
	for i in voxel_area:iterp(start, size) do
		local pos = voxel_area:position(i)
		
		if schematic._rotation == 90 then
			pos = vector.new(pos.z, pos.y, size.x - pos.x + 1)
		elseif schematic._rotation == 180 then
			pos = vector.new(size.x - pos.x + 1, pos.y, size.z - pos.z + 1)
		elseif schematic._rotation == 270 then
			pos = vector.new(size.z - pos.z + 1, pos.y, pos.x)
		end
		
		local name = schematic.data[i].name
		if name ~= "air" and math.random() < probability then
			local attach_pos = vector.multiply(vector.subtract(vector.add(pos, schematic._offset), 1), 10)
			local objref = minetest.add_entity(player_pos, "edit:preview_node")
			objref:set_properties({wield_item = name})
			objref:set_attach(base_objref, "", attach_pos)
		end
	end
	player_data[player].paste_preview = base_objref
	player_data[player].paste_preview_yaw = 0
end

local function delete_paste_preview(player)
	local paste_preview = player_data[player].paste_preview
	if not paste_preview or not paste_preview:get_pos() then return end
	
	local objrefs = paste_preview:get_children()
	for i, objref in pairs(objrefs) do
		objref:remove()
	end
	player_data[player].paste_preview:remove()
	player_data[player].paste_preview_visable = false
	player_data[player].paste_preview = nil
end

local function set_schematic_rotation(schematic, angle)
	if not schematic._rotation then schematic._rotation = 0 end
	schematic._rotation = schematic._rotation + angle
	if schematic._rotation < 0 then
		schematic._rotation = schematic._rotation + 360
	elseif schematic._rotation > 270 then
		schematic._rotation = schematic._rotation - 360
	end
	
	local size = schematic.size
	if schematic._rotation == 90 or schematic._rotation == 270 then
		size = vector.new(size.z, size.y, size.x)
	end
	
	local sign = vector.apply(schematic._offset, math.sign)
	schematic._offset = vector.apply(
		vector.multiply(size, sign),
		function(n) return n < 0 and n or 1 end
	)
	--[[local old_schematic = player_data[player].schematic
	local new_schematic = {data = {}}
	player_data[player].schematic = new_schematic
	
	local old_size = old_schematic.size
	local new_size
	if direction == "L" or direction == "R" then
		new_size = vector.new(old_size.z, old_size.y, old_size.x)
	elseif direction == "U" or direction == "D" then
		new_size = vector.new(old_size.y, old_size.x, old_size.z)
	end
	new_schematic.size = new_size
	
	local sign = vector.apply(old_schematic._offset, math.sign)
	new_schematic._offset = vector.apply(
		vector.multiply(new_size, sign),
		function(n) return n < 0 and n or 1 end
	)

	local start = vector.new(1, 1, 1)
	local old_voxel_area = VoxelArea:new({MinEdge = start, MaxEdge = old_size})
	local new_voxel_area = VoxelArea:new({MinEdge = start, MaxEdge = new_size})
	for old_index in old_voxel_area:iterp(start, old_schematic.size) do
		local old_pos = old_voxel_area:position(old_index)
		local new_pos
		local node = old_schematic.data[old_index]
		
		if direction == "L" then
			new_pos = vector.new(old_pos.z, old_pos.y, old_size.x - old_pos.x + 1)
		elseif direction == "R" then
			new_pos = vector.new(old_size.z - old_pos.z + 1, old_pos.y, old_pos.x)
		elseif direction == "U" then
			new_pos = vector.new(old_pos.y, old_size.x - old_pos.x + 1, old_pos.z)
		elseif direction == "D" then
			new_pos = vector.new(old_size.y - old_pos.y + 1, old_pos.x, old_pos.z)
		end
		
		local new_index = new_voxel_area:indexp(new_pos)
		new_schematic.data[new_index] = node
	end
	delete_paste_preview(player)]]
end

minetest.register_privilege("edit", {
	description = "Allows usage of edit mod nodes",
	give_to_singleplayer = true,
	give_to_admin = true,
})

local function has_privilege(player)
	local name = player:get_player_name()
	if minetest.check_player_privs(name, {edit = true}) then
		return true
	else
		minetest.chat_send_player(name, "Using edit nodes requires the edit privilege.")
		return false
	end
end

local function on_place_checks(player)
	return player and
	player:is_player() and
	has_privilege(player)
end


local function schematic_from_map(pos, size)
	local schematic = {data = {}}
	schematic.size = size
	schematic._pos = pos
			
	local start = vector.new(1, 1, 1)
	local voxel_area = VoxelArea:new({MinEdge = start, MaxEdge = size})
	
	for i in voxel_area:iterp(start, size) do
		local offset = voxel_area:position(i)
		local node_pos = vector.subtract(vector.add(pos, offset), start)
		local node = minetest.get_node(node_pos)
		node.param1 = nil
		schematic.data[i] = node
	end
	
	return schematic
end

minetest.register_node("edit:delete", {
	description = "Edit Delete",
	inventory_image = "edit_delete.png",
	groups = {snappy = 2, oddly_breakable_by_hand = 3},
	tiles = {"edit_delete.png"},
	range = 10,
	on_place = function(itemstack, player, pointed_thing)
		if not on_place_checks(player) then return end
		
		local itemstack, pos = minetest.item_place_node(itemstack, player, pointed_thing)
		
		if player_data[player].delete_node1_pos and pos then
			local p1 = player_data[player].delete_node1_pos
			player_data[player].delete_node1_pos = nil
			local p2 = pos
			
			minetest.remove_node(p1)
			minetest.remove_node(p2)
			
			-- Is the volume of the selected area 0?
			local test = vector.apply(vector.subtract(p2, p1), math.abs)
			if test.x <= 1 or test.y <= 1 or test.z <= 1 then return end
			
			local sign = vector.new(vector.apply(vector.subtract(p2, p1), math.sign))
			p1 = vector.add(p1, sign)
			p2 = vector.add(p2, vector.multiply(sign, -1))
			
			local start = vector.new(
				math.min(p1.x, p2.x),
				math.min(p1.y, p2.y),
				math.min(p1.z, p2.z)
			)
			local _end = vector.new(
				math.max(p1.x, p2.x),
				math.max(p1.y, p2.y),
				math.max(p1.z, p2.z)
			)
			local size = vector.add(vector.subtract(_end, start), 1)
			if size.x * size.y * size.z > max_operation_volume then
				minetest.chat_send_player(player:get_player_name(), "Delete operation too big.")
				return
			end
			player_data[player].undo_schematic = schematic_from_map(start, size)
			
			for x = start.x, _end.x, 1 do
				for y = start.y, _end.y, 1 do
					for z = start.z, _end.z, 1 do
						minetest.remove_node(vector.new(x, y, z))
					end
				end
			end
		elseif pos then
			player_data[player].delete_node1_pos = pos
		end
	end,
	on_dig = function(pos, node, digger)
		minetest.remove_node(pos)
		for player, data in pairs(player_data) do
			if
				data.delete_node1_pos and
				vector.equals(data.delete_node1_pos, pos)
			then
				data.delete_node1_pos = nil
				break
			end
		end
	end
})

minetest.register_node("edit:copy",{
	description = "Edit Copy",
	tiles = {"edit_copy.png"},
	inventory_image = "edit_copy.png",
	groups = {snappy = 2, oddly_breakable_by_hand = 3},
	range = 10,
	on_place = function(itemstack, player, pointed_thing)
		if not on_place_checks(player) then return end
		
		local itemstack, pos = minetest.item_place_node(itemstack, player, pointed_thing)
		
		if player_data[player].copy_node1_pos and pos then
			local p1 = player_data[player].copy_node1_pos
			local p2 = pos
			
			player_data[player].copy_node1_pos = nil
			minetest.remove_node(p1)
			minetest.remove_node(p2)
			
			local diff = vector.subtract(p2, p1)
			
			-- Is the volume of the selected area 0?
			local test = vector.apply(diff, math.abs)
			if test.x <= 1 or test.y <= 1 or test.z <= 1 then return itemstack end
			
			local sign = vector.apply(vector.subtract(p2, p1), math.sign)
			p1 = vector.add(p1, sign)
			p2 = vector.add(p2, vector.multiply(sign, -1))
			
			local start = vector.new(
				math.min(p1.x, p2.x),
				math.min(p1.y, p2.y),
				math.min(p1.z, p2.z)
			)
			local _end = vector.new(
				math.max(p1.x, p2.x),
				math.max(p1.y, p2.y),
				math.max(p1.z, p2.z)
			)
			
			local size = vector.add(vector.subtract(_end, start), vector.new(1, 1, 1))
			if size.x * size.y * size.z > max_operation_volume then
				minetest.chat_send_player(player:get_player_name(), "Copy operation too big.")
				return
			end
			
			player_data[player].schematic = schematic_from_map(start, size)
			player_data[player].schematic._offset = vector.apply(
				diff,
				function(n) return n < 0 and n + 1 or 1 end
			)
			delete_paste_preview(player)
		elseif pos then
			player_data[player].copy_node1_pos = pos
		end
	end,
	on_dig = function(pos, node, digger)
		minetest.remove_node(pos)
		for player, data in pairs(player_data) do
			if
				data.copy_node1_pos and
				vector.equals(data.copy_node1_pos, pos)
			then
				data.copy_node1_pos = nil
				break
			end
		end
	end
})

local function pointed_thing_to_pos(pointed_thing)
	local pos = pointed_thing.under
	local node = minetest.get_node_or_nil(pos)
	local def = node and minetest.registered_nodes[node.name]
	if def and def.buildable_to then
		return pos
	end
	
	pos = pointed_thing.above
	node = minetest.get_node_or_nil(pos)
	def = node and minetest.registered_nodes[node.name]
	if def and def.buildable_to then
		return pos
	end
end

minetest.register_tool("edit:paste", {
	description = "Edit Paste",
	tiles = {"edit_paste.png"},
	inventory_image = "edit_paste.png",
	groups = {snappy = 2, oddly_breakable_by_hand = 3},
	range = 10,
	on_place = function(itemstack, player, pointed_thing)
		if not on_place_checks(player) then return end
		
		if not player_data[player].schematic then
			minetest.chat_send_player(player:get_player_name(), "Nothing to paste.")
			return
		end
		
		local schematic = player_data[player].schematic
		local pos = pointed_thing_to_pos(pointed_thing)
		if not pos then return end
		local pos = vector.add(pos, schematic._offset)
		local size = schematic.size
		if schematic._rotation == 90 or schematic._rotation == 270 then
			size = vector.new(size.z, size.y, size.x)
		end
		player_data[player].undo_schematic = schematic_from_map(pos, size)
		minetest.place_schematic(pos, schematic, tostring(schematic._rotation or 0), nil, true)
	end
})

local function delete_schematics_dialog(player)
	local path = minetest.get_worldpath() .. "/schems"
	local dir_list = minetest.get_dir_list(path)
	if #path > 40 then path = "..." .. path:sub(#path - 40, #path) end
	local formspec = "size[10,10]label[0.5,0.5;Delete Schematics from:\n" ..
		minetest.formspec_escape(path) .. "]button_exit[9,0;1,1;quit;X]" ..
		"textlist[0.5,2;9,7;schems;" .. table.concat(dir_list, ",") .. "]"
		
	reliable_show_formspec(player, "edit:delete_schem", formspec)
end

minetest.register_tool("edit:open",{
	description = "Edit Open",
	inventory_image = "edit_open.png",
	range = 10,
	on_place = function(itemstack, player, pointed_thing)
		if not on_place_checks(player) then return end
		
		local path = minetest.get_worldpath() .. "/schems"
		local dir_list = minetest.get_dir_list(path)
		if #path > 40 then path = "..." .. path:sub(#path - 40, #path) end
		local formspec = "size[10,10]label[0.5,0.5;Load a schematic into copy buffer from:\n" ..
			minetest.formspec_escape(path) .. "]button_exit[9,0;1,1;quit;X]" ..
			"textlist[0.5,2;9,7;schems;" .. table.concat(dir_list, ",") .. "]" ..
			"button_exit[3,9.25;4,1;delete;Delete schematics...]"
		
		minetest.show_formspec(player:get_player_name(), "edit:open", formspec)
	end
})

minetest.register_tool("edit:undo",{
	description = "Edit Undo",
	inventory_image = "edit_undo.png",
	range = 10,
	on_place = function(itemstack, player, pointed_thing)
		if not on_place_checks(player) then return end
	
		local schem = player_data[player].undo_schematic
		if schem then
			player_data[player].undo_schematic = schematic_from_map(schem._pos, schem.size)
			minetest.place_schematic(schem._pos, schem, nil, nil, true)
		else
			minetest.chat_send_player(player:get_player_name(), "Nothing to undo.")
		end
	end
})

function reliable_show_formspec(player, name, formspec)
	-- We need to do this nonsense because there is bug in Minetest
	-- Sometimes no formspec is shown if you call minetest.show_formspec
	-- from minetest.register_on_player_receive_fields
	minetest.after(0.1, function()
		if not player or not player:is_player() then return end
		minetest.show_formspec(player:get_player_name(), name, formspec)
	end)
end

local function show_save_dialog(player, filename, save_error)
	if not player_data[player].schematic then
		minetest.chat_send_player(player:get_player_name(), "Nothing to save.")
		return
	end
	
	filename = filename or "untitled"
	
	local path = minetest.get_worldpath() .. "/schems"
	if #path > 40 then path = "..." .. path:sub(#path - 40, #path) end
	
	local formspec = "size[8,3]label[0.5,0.1;Save schematic in:\n" ..
		minetest.formspec_escape(path) .. "]button_exit[7,0;1,1;cancel;X]" ..
		"field[0.5,1.5;5.5,1;schem_filename;;" .. filename .. "]" ..
		"button_exit[5.7,1.2;2,1;save;Save]"
	
	if save_error then
		formspec = formspec ..
			"label[0.5,2.5;" .. save_error .. "]"
	end
	reliable_show_formspec(player, "edit:save", formspec)
end

minetest.register_tool("edit:save",{
	description = "Edit Save",
	inventory_image = "edit_save.png",
	range = 10,
	on_place = function(itemstack, player, pointed_thing)
		if on_place_checks(player) then show_save_dialog(player) end
	end
})

minetest.register_node("edit:fill",{
	description = "Edit Fill",
	tiles = {"edit_fill.png"},
	inventory_image = "edit_fill.png",
	groups = {snappy = 2, oddly_breakable_by_hand = 3},
	range = 10,
	on_place = function(itemstack, player, pointed_thing)
		if not on_place_checks(player) then return end
		
		local itemstack, pos = minetest.item_place_node(itemstack, player, pointed_thing)
		
		if player_data[player].fill1_pos and pos then
			player_data[player].fill2_pos = pos
			player_data[player].fill_pointed_thing = pointed_thing
				
			local inv = minetest.get_inventory({type = "player", name = player:get_player_name()})
			local formspec = "size[8,6]label[2,0.5;Select item for filling]button_exit[7,0;1,1;quit;X]"
			for y = 1, 4 do
				for x = 1, 8 do
					local name = inv:get_stack("main", ((y - 1) * 8) + x):get_name()
					formspec =
						formspec ..
						"item_image_button[" ..
						(x - 1) .. "," ..
						(y + 1) .. ";1,1;" ..
						name .. ";" ..
						name .. ";]"
				end
			end
			minetest.show_formspec(player:get_player_name(), "edit:fill", formspec)
		elseif pos then
			player_data[player].fill1_pos = pos
		end
	end,
	on_dig = function(pos, node, digger)
		minetest.remove_node(pos)
		for player, data in pairs(player_data) do
			local p1 = data.fill1_pos
			local p2 = data.fill2_pos
			if p1 and vector.equals(p1, pos) then
				data.fill1_pos = nil
				data.fill2_pos = nil
				data.fill_pointed_thing = nil
				minetest.remove_node(p1)
				return
			end
			if p2 and vector.equals(p2, pos) then
				data.fill1_pos = nil
				data.fill2_pos = nil
				data.fill_pointed_thing = nil
				minetest.remove_node(p2)
				return
			end
		end
	end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "edit:fill" then
		minetest.close_formspec(player:get_player_name(), "edit:fill")
		
		local p1 = player_data[player].fill1_pos
		local p2 = player_data[player].fill2_pos
		local pointed_thing = player_data[player].fill_pointed_thing
		
		if
			not p1 or not p2 or
			not pointed_thing or
			not has_privilege(player)
		then return true end
		
		player_data[player].fill1_pos = nil
		player_data[player].fill2_pos = nil
		player_data[player].fill_pointed_thing = nil
		minetest.remove_node(p1)
		minetest.remove_node(p2)
		
		local name
		local def
		for key, val in pairs(fields) do
			if key == "quit" then return true end
			if key == "" then item = "air" end

			name = key
			def = minetest.registered_nodes[name] or
				minetest.registered_craftitems[name] or
				minetest.registered_tools[name] or
				minetest.registered_items[name]
			
			if def then break end
		end
		
		if not def then return true end
			
		local is_node = minetest.registered_nodes[name]
			
		local param2
		if def.paramtype2 == "facedir" then
			param2 = minetest.dir_to_facedir(player:get_look_dir())
		elseif def.paramtype2 == "wallmounted" then
			param2 = minetest.dir_to_wallmounted(player:get_look_dir(), true)
		end
		
		local on_place = def.on_place
		
		local start = vector.new(
			math.min(p1.x, p2.x),
			math.min(p1.y, p2.y),
			math.min(p1.z, p2.z)
		)
		local _end = vector.new(
			math.max(p1.x, p2.x),
			math.max(p1.y, p2.y),
			math.max(p1.z, p2.z)
		)
		
		local size = vector.add(vector.subtract(_end, start), 1)
		if size.x * size.y * size.z > max_operation_volume then
			minetest.chat_send_player(player:get_player_name(), "Fill operation too large.")
			return true
		end
		player_data[player].undo_schematic = schematic_from_map(start, size)
		
		for x = start.x, _end.x, 1 do
			for y = start.y, _end.y, 1 do
				for z = start.z, _end.z, 1 do
					local pos = vector.new(x, y, z)
					if is_node then
						minetest.set_node(pos, {name = name, param2 = param2})
					else
						minetest.remove_node(pos)
					end
					if on_place then
						local itemstack = ItemStack(name)
						pointed_thing.intersection_point = vector.new(x + 0.5, y, z + 0.5)
						pointed_thing.above = pos
						pointed_thing.below = vector.new(x, y - 1, z)
						on_place(itemstack, player, pointed_thing)
					end
				end
			end
		end
		return true
	elseif formname == "edit:open" then
		minetest.close_formspec(player:get_player_name(), "edit:open")
		
		if
			fields.cancel
			or not has_privilege(player)
		then return true end
		
		if fields.delete then
			delete_schematics_dialog(player)
			return true
		end
		
		if not fields.schems then return end
		
		local index = tonumber(fields.schems:sub(5, #(fields.schems)))
		if not index then return true end
		index = math.floor(index)
		
		local path = minetest.get_worldpath() .. "/schems"
		local dir_list = minetest.get_dir_list(path)
		if index > 0 and index <= #dir_list then
			local file_path = path .. "/" .. dir_list[index]
			local schematic = minetest.read_schematic(file_path, {})
			if not schematic then return true end
			player_data[player].schematic = schematic
			player_data[player].schematic._offset = vector.new(1, 1, 1)
			minetest.chat_send_player(player:get_player_name(), dir_list[index] .. " loaded.")
			delete_paste_preview(player)
		end
		return true
	elseif formname == "edit:save" then
		minetest.close_formspec(player:get_player_name(), "edit:save")
	
		local schematic = player_data[player].schematic
		local schem_filename = fields.schem_filename
		
		if
			fields.cancel or
			not schem_filename or
			not schematic or
			not has_privilege(player)
		then return end
		
		local path = minetest.get_worldpath() .. "/schems"
		local schem_filename = schem_filename .. ".mts"
		local dir_list = minetest.get_dir_list(path)
		for _, filename in pairs(dir_list) do
			if filename == schem_filename then
				show_save_dialog(player, fields.schem_filename, fields.schem_filename .. " already exists.")
				return true
			end
		end
		
		local mts = minetest.serialize_schematic(schematic, "mts", {})
		if not mts then return true end
		
		minetest.mkdir(path)
		local schem_path = path .. "/" .. schem_filename
		local f = io.open(schem_path, "wb");
		if not f then
			minetest.chat_send_player(player:get_player_name(), "IO error saving schematic.")
			return true
		end
		f:write(mts);
		f:close()
		minetest.chat_send_player(player:get_player_name(), schem_filename .. " saved.")
		return true
	elseif formname == "edit:delete_schem" then
		if
			fields.cancel
			or not has_privilege(player)
		then return true end
		
		if not fields.schems then return end
		
		local index = tonumber(fields.schems:sub(5, #(fields.schems)))
		if not index then return true end
		index = math.floor(index)
		
		local path = minetest.get_worldpath() .. "/schems"
		local dir_list = minetest.get_dir_list(path)
		if index > 0 and index <= #dir_list then
			player_data[player].schem_for_delete = path .. "/" .. dir_list[index]
			formspec = "size[8,3]label[0.5,0.5;Confirm delete \"" ..
				dir_list[index] .. "\"]" ..
				"button_exit[1,2;2,1;delete;Delete]" ..
				"button_exit[5,2;2,1;quit;Cancel]"
			
			reliable_show_formspec(player, "edit:confirm_delete_schem", formspec)
		end
		return true
	elseif formname == "edit:confirm_delete_schem" then
		if not has_privilege(player) then return end
	
		if fields.delete then
			os.remove(player_data[player].schem_for_delete)
		end
		player_data[player].schem_for_delete = nil
		delete_schematics_dialog(player)
	end
	return false
end)

minetest.register_entity("edit:select_preview", {
	initial_properties = {
		visual = "cube",
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
		use_texture_alpha = true,
		glow = -1,
		backface_culling = false,
		textures = {
			"edit_select_preview.png",
			"edit_select_preview.png",
			"edit_select_preview.png",
			"edit_select_preview.png",
			"edit_select_preview.png",
			"edit_select_preview.png",
		},
	}
})

minetest.register_entity("edit:preview_base", {
	initial_properties = {
		visual = "sprite",
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
		visual_size  = {x = 1, y = 1},
		textures = {"blank.png"},
	}
})

minetest.register_entity("edit:preview_node", {
	initial_properties = {
		visual = "item",
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
		visual_size  = {x = 0.69, y = 0.69},
		glow = -1,
	}
})

local function hide_paste_preview(player)
	local d = player_data[player]
	--d.paste_preview:set_properties({is_visible = false})
	-- This does not work right.
	-- Some child entities do not become visable when you set is_visable back to true
			
	for _, objref in pairs(d.paste_preview:get_children()) do
		objref:set_properties({is_visible = false})
	end
	d.paste_preview:set_attach(player)
	player:hud_remove(d.paste_preview_hud)
	d.paste_preview_hud = nil
end

local function show_paste_preview(player)
	local d = player_data[player]
	for _, objref in pairs(d.paste_preview:get_children()) do
		objref:set_properties({is_visible = true})
	end
	d.paste_preview:set_detach()
	d.paste_preview_hud = player:hud_add({
		hud_elem_type = "text",
		text = "Press sneak + right or left to rotate.",
		position = {x = 0.5, y = 0.8},
		z_index = 100,
		number = 0xffffff
	})
	
	-- Minetset bug: set_pos does not get to the client
	-- sometimes after showing a ton of children
	minetest.after(0.3,
		function(objref)
			local pos = objref:get_pos()
			if pos then objref:set_pos(pos) end
		end,
		d.paste_preview
	)
end

local function get_player_pointed_thing_pos(player)
	local look_dir = player:get_look_dir()
	local pos1 = player:get_pos()
	local eye_height = player:get_properties().eye_height
	pos1.y = pos1.y + eye_height
	local pos2 = vector.add(pos1, vector.multiply(look_dir, 10))
	local pointed_thing = minetest.raycast(pos1, pos2, false, false):next()
	if pointed_thing then
		return pointed_thing_to_pos(pointed_thing)
	end
end

local function hide_select_preview(player)
	local d = player_data[player]
	d.select_preview_shown = false
	d.select_preview:set_properties({is_visible = false})
	d.select_preview:set_attach(player)
end

minetest.register_globalstep(function(dtime)
	for _, player in pairs(minetest.get_connected_players()) do
		local item = player:get_wielded_item():get_name()
		local d = player_data[player]
		
		-- Paste preview
		if item == "edit:paste" and d.schematic then
			local pos = get_player_pointed_thing_pos(player)
			if pos then
				if not d.paste_preview or not d.paste_preview:get_pos() then
					create_paste_preview(player)
				end
			
				if not d.paste_preview_hud then show_paste_preview(player) end
				
				local old_pos = player_data[player].paste_preview:get_pos()
				if not vector.equals(old_pos, pos) then
					player_data[player].paste_preview:set_pos(pos)
				end
				local control = player:get_player_control()
				if control.sneak and control.left then
					if d.paste_preview_can_rotate then
						set_schematic_rotation(d.schematic, -90)
						delete_paste_preview(player)
						d.paste_preview_can_rotate = false
					end
				elseif control.sneak and control.right then
					if d.paste_preview_can_rotate then
						set_schematic_rotation(d.schematic, 90)
						delete_paste_preview(player)
						d.paste_preview_can_rotate = false
					end
				else d.paste_preview_can_rotate = true end
			elseif d.paste_preview_hud then hide_paste_preview(player) end
		elseif d.paste_preview_hud then hide_paste_preview(player) end
		
		-- Select preview
		local node1_pos
		local node2_pos
		local include_node_pos = false
		if item == "edit:fill" and d.fill1_pos then
			node1_pos = d.fill1_pos
			if d.fill2_pos then node2_pos = d.fill2_pos end
			include_node_pos = true
		elseif item == "edit:copy" and d.copy_node1_pos then
			node1_pos = d.copy_node1_pos
		elseif item == "edit:delete" and d.delete_node1_pos then
			node1_pos = d.delete_node1_pos
		end
		
		if node1_pos then
			if not node2_pos then
				node2_pos = get_player_pointed_thing_pos(player)
			end
			
			if node2_pos then
				local diff = vector.subtract(node1_pos, node2_pos)
				local size = vector.apply(diff, math.abs)
				if include_node_pos then size = vector.add(size, vector.new(1, 1, 1))
				else size = vector.add(size, vector.new(-1, -1, -1)) end
				
				local test = vector.apply(diff, math.abs)
				local has_volume = test.x > 1 and test.y > 1 and test.z > 1
				local size_too_big = size.x * size.y * size.z > max_operation_volume
				if (include_node_pos or has_volume) and not size_too_big then
					if not d.select_preview or not d.select_preview:get_pos() then
						d.select_preview = minetest.add_entity(node2_pos, "edit:select_preview")
						d.select_preview_shown = true
					elseif not d.select_preview_shown then
						d.select_preview:set_detach()
						d.select_preview:set_properties({is_visible = true})
						d.select_preview_shown = true
					end
					local preview_pos = vector.add(node2_pos, vector.multiply(diff, 0.5))
					local preview = d.select_preview
					if not vector.equals(preview_pos, preview:get_pos()) then
						preview:set_pos(preview_pos)
						local preview_size = vector.add(size, vector.new(0.01, 0.01, 0.01))
						preview:set_properties({visual_size = preview_size})
					end
				elseif d.select_preview_shown then hide_select_preview(player) end
			elseif d.select_preview_shown then hide_select_preview(player) end
		elseif d.select_preview_shown then hide_select_preview(player) end
	end
end)

minetest.register_on_joinplayer(function(player)
	player_data[player] = {}
end)

minetest.register_on_leaveplayer(function(player)
	delete_paste_preview(player)
	if player_data[player].select_preview then
		player_data[player].select_preview:remove()
	end
	player_data[player] = nil
end)
