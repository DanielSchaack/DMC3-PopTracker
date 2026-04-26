require("scripts/autotracking/item_mapping")
require("scripts/autotracking/location_mapping")
require("scripts/logic/tab_mapping")

CUR_INDEX = -1
--SLOT_DATA = nil

ALL_LOCATIONS = {}
SLOT_DATA = {}

MANUAL_CHECKED = true
ROOM_SEED = "default"
TROLL_PLAYER = false

if Highlight then
	HIGHLIGHT_LEVEL = {
		[0] = Highlight.Unspecified,
		[10] = Highlight.NoPriority,
		[20] = Highlight.Avoid,
		[30] = Highlight.Priority,
		[40] = Highlight.None,
		[100] = Highlight.Unspecified, --Filler
		[101] = Highlight.Priority, --Progression
		[102] = Highlight.NoPriority, --Useful
		[103] = Highlight.Priority, -- Prog + Useful
		[104] = Highlight.Avoid, --Trap
		[105] = Highlight.Priority, -- Prog + Trap
		[106] = Highlight.NoPriority, -- Useful + Trap
		[107] = Highlight.Priority, -- Prog + Useful + Trap
	}
end

Troll_Lookup = {
	["solarcell"] = true,
	["earthor"] = true,
}

function dump_table(o, depth)
	if depth == nil then
		depth = 0
	end
	if type(o) == "table" then
		local tabs = ("\t"):rep(depth)
		local tabs2 = ("\t"):rep(depth + 1)
		local s = "{\n"
		for k, v in pairs(o) do
			if type(k) ~= "number" then
				k = '"' .. k .. '"'
			end
			s = s .. tabs2 .. "[" .. k .. "] = " .. dump_table(v, depth + 1) .. ",\n"
		end
		return s .. tabs .. "}"
	else
		return tostring(o)
	end
end

function LocationHandler(location)
	if MANUAL_CHECKED then
		local custom_storage_item = Tracker:FindObjectForCode("manual_location_storage").ItemState
		if not custom_storage_item then
			return
		end
		if Archipelago.PlayerNumber == -1 then -- not connected
			if ROOM_SEED ~= "default" then -- seed is from previous connection
				ROOM_SEED = "default"
				custom_storage_item.MANUAL_LOCATIONS["default"] = {}
			else -- seed is default
			end
		end
		local full_path = location.FullID
		if not custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED] then
			custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED] = {}
		end
		if location.AvailableChestCount < location.ChestCount then --add to list
			print("add to list")
			custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED][full_path] = location.AvailableChestCount
		else --remove from list of set back to max chestcount
			print("remove from list")
			custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED][full_path] = nil
		end
	end
	-- local custom_storage_item = Tracker:FindObjectForCode("manual_location_storage").ItemState
	-- print(dump_table(custom_storage_item.ItemState.MANUAL_LOCATIONS))
	-- ForceUpdate()
end

function ForceUpdate()
	local update = Tracker:FindObjectForCode("update")
	if update == nil then
		return
	end
	update.Active = not update.Active
end

function onClearHandler(slot_data)
	local clear_timer = os.clock()

	ScriptHost:RemoveWatchForCode("StateChange")
	-- Disable tracker updates.
	Tracker.BulkUpdate = true
	-- Use a protected call so that tracker updates always get enabled again, even if an error occurred.
	local ok, err = pcall(onClear, slot_data)
	-- Enable tracker updates again.
	if ok then
		-- Defer re-enabling tracker updates until the next frame, which doesn't happen until all received items/cleared
		-- locations from AP have been processed.
		local handlerName = "AP onClearHandler"
		local function frameCallback()
			ScriptHost:AddWatchForCode("StateChange", "*", StateChanged)
			ScriptHost:RemoveOnFrameHandler(handlerName)
			Tracker.BulkUpdate = false
			-- ForceUpdate()
			print(string.format("Time taken total: %.2f", os.clock() - clear_timer))
		end
		ScriptHost:AddOnFrameHandler(handlerName, frameCallback)
	else
		Tracker.BulkUpdate = false
		print("Error: onClear failed:")
		print(err)
	end
end

function preOnClear()
	PLAYER_ID = Archipelago.PlayerNumber or -1
	TEAM_NUMBER = Archipelago.TeamNumber or 0
	if Archipelago.PlayerNumber > -1 then
		for key, _ in pairs(Troll_Lookup) do
			if string.find(string.lower(Archipelago:GetPlayerAlias(PLAYER_ID)), key, 1, true) ~= nil then
				TROLL_PLAYER = true
				break
			end
		end
		if #ALL_LOCATIONS > 0 then
			ALL_LOCATIONS = {}
		end
		for _, value in pairs(Archipelago.MissingLocations) do
			table.insert(ALL_LOCATIONS, #ALL_LOCATIONS + 1, value)
		end

		for _, value in pairs(Archipelago.CheckedLocations) do
			table.insert(ALL_LOCATIONS, #ALL_LOCATIONS + 1, value)
		end
		HINTS_ID = "_read_hints_" .. TEAM_NUMBER .. "_" .. PLAYER_ID
		Archipelago:SetNotify({ HINTS_ID })
		Archipelago:Get({ HINTS_ID })
	end

	print(Archipelago.Seed)
	local seed_base = (Archipelago.Seed or tostring(#ALL_LOCATIONS))
		.. "_"
		.. Archipelago.TeamNumber
		.. "_"
		.. Archipelago.PlayerNumber
	if ROOM_SEED == "default" or ROOM_SEED ~= seed_base then -- seed is default or from previous connection
		ROOM_SEED = seed_base --something like 2345_0_12
		for _, custom_item_code in pairs({ "manual_location_storage" }) do -- add more to the table if you created more storage cache items
			local custom_storage_item = Tracker:FindObjectForCode(custom_item_code).ItemState
			if custom_storage_item then
				if #custom_storage_item.MANUAL_LOCATIONS > 10 then
					custom_storage_item.MANUAL_LOCATIONS[custom_storage_item.MANUAL_LOCATIONS_ORDER[1]] = nil
					table.remove(custom_storage_item.MANUAL_LOCATIONS_ORDER, 1)
				end
				if custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED] == nil then
					custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED] = {}
					table.insert(custom_storage_item.MANUAL_LOCATIONS_ORDER, ROOM_SEED)
				end
			end
		end
	else -- seed is from previous connection
		-- do nothing
	end
end

AVAILABLE_DIFFICULTIES = {
	[1] = "Normal",
}
MISSION_ASSIGNMENTS = {
	[1] = 1,
	[2] = 2,
	[3] = 3,
	[4] = 4,
	[5] = 5,
	[6] = 6,
	[7] = 7,
	[8] = 8,
	[9] = 9,
	[10] = 10,
	[11] = 11,
	[12] = 12,
	[13] = 13,
	[14] = 14,
	[15] = 15,
	[16] = 16,
	[17] = 17,
	[18] = 18,
	[19] = 19,
	[20] = 20,
}

GOAL = 0
function onClear(slot_data)
	PLAYER_ID = Archipelago.PlayerNumber or -1
	TEAM_NUMBER = Archipelago.TeamNumber or 0
	SLOT_DATA = slot_data
	COMPLETED_LOCATIONS = {}

	print(PLAYER_ID, TEAM_NUMBER)

	for _, available_difficulty in pairs(slot_data["initially_unlocked_difficulties"]) do
		if available_difficulty == "Easy" then
			AVAILABLE_DIFFICULTIES[0] = available_difficulty
		elseif available_difficulty == "Hard" then
			AVAILABLE_DIFFICULTIES[2] = available_difficulty
		elseif available_difficulty == "Very Hard" then
			AVAILABLE_DIFFICULTIES[3] = available_difficulty
		elseif available_difficulty == "Dante Must Die" then
			AVAILABLE_DIFFICULTIES[4] = available_difficulty
		elseif available_difficulty == "Heaven or Hell" then
			AVAILABLE_DIFFICULTIES[5] = available_difficulty
		end
	end

	GOAL = tonumber(slot_data["goal"])
	if GOAL == 2 then
		MISSION_ASSIGNMENTS = slot_data["mission_order"]
	end

	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print("--- Provided Difficulties ---")
		print(dump_table(slot_data["initially_unlocked_difficulties"], 2))

		print("--- Available Difficulties ---")
		print("Count:", #AVAILABLE_DIFFICULTIES)
		print(dump_table(AVAILABLE_DIFFICULTIES, 2))

		print("--- Active Mission Assignments ---")
		print("Count:", #MISSION_ASSIGNMENTS)
		print(dump_table(MISSION_ASSIGNMENTS, 2))

		print("--- Current Goal ---")
		print(GOAL)
	end

	local has_ss_checks = slot_data["enabled_ss_rank"]
	if has_ss_checks then
		Tracker:FindObjectForCode("SS Rank Completions").CurrentStage = 1
	else
		Tracker:FindObjectForCode("SS Rank Completions").CurrentStage = 0
	end

	local has_orb_shop = slot_data["shop_orb_checks"]
	if has_orb_shop then
		Tracker:FindObjectForCode("Orb Checks").CurrentStage = 1
	else
		Tracker:FindObjectForCode("Orb Checks").CurrentStage = 0
	end

	MANUAL_CHECKED = false
	local custom_storage_item = Tracker:FindObjectForCode("manual_location_storage").ItemState
	if custom_storage_item == nil then
		CreateLuaManualStorageItem("manual_location_storage")
		custom_storage_item = Tracker:FindObjectForCode("manual_location_storage").ItemState
	end
	-- repeat that here for every cache-storage item you create just to be save

	preOnClear()

	ScriptHost:RemoveWatchForCode("StateChanged")
	ScriptHost:RemoveOnLocationSectionHandler("location_section_change_handler")
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("called onClear, slot_data:\n%s", dump_table(slot_data)))
	end
	CUR_INDEX = -1
	-- reset locations
	for _, location_array in pairs(LOCATION_MAPPING) do
		for _, location in pairs(location_array) do
			if location then
				if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
					print(string.format("onClear: clearing location %s", location))
				end
				local location_obj = Tracker:FindObjectForCode(location)
				if location_obj then
					if location:sub(1, 1) == "@" then
						location_obj.AvailableChestCount = location_obj.ChestCount
					else
						location_obj.Active = false
					end
				elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
					print(string.format("onClear: could not find object for code %s", location))
				end
			end
		end
	end
	-- reset items
	for _, item_array in pairs(ITEM_MAPPING) do
		for _, item_pair in pairs(item_array) do
			item_code = item_pair[1]
			item_type = item_pair[2]

			if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
				print(string.format("onClear: clearing item %s of type %s", item_code, item_type))
			end

			local item_obj = Tracker:FindObjectForCode(item_code)
			if item_obj then
				if item_obj.Type == "toggle" then
					item_obj.Active = false
				elseif item_obj.Type == "progressive" then
					item_obj.CurrentStage = 0
				elseif item_obj.Type == "consumable" then
					if item_obj.MinCount then
						item_obj.AcquiredCount = item_obj.MinCount
					else
						item_obj.AcquiredCount = 0
					end
				elseif item_obj.Type == "progressive_toggle" then
					item_obj.CurrentStage = 0
					item_obj.Active = false
				end
			elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
				print(string.format("onClear: could not find object for code %s", item_code))
			end
		end
	end

	if Archipelago.PlayerNumber > -1 then
		if #ALL_LOCATIONS > 0 then
			ALL_LOCATIONS = {}
		end
		for _, value in pairs(Archipelago.MissingLocations) do
			table.insert(ALL_LOCATIONS, #ALL_LOCATIONS + 1, value)
		end

		for _, value in pairs(Archipelago.CheckedLocations) do
			table.insert(ALL_LOCATIONS, #ALL_LOCATIONS + 1, value)
		end

		HINTS_ID = "_read_hints_" .. TEAM_NUMBER .. "_" .. PLAYER_ID
		Archipelago:SetNotify({ HINTS_ID })
		Archipelago:Get({ HINTS_ID })
	end
	ScriptHost:AddOnFrameHandler("load handler", OnFrameHandler)
	MANUAL_CHECKED = true

	Tracker:FindObjectForCode("Completed Missions").AcquiredCount = 1
	local has_randomised_styles = slot_data["randomize_styles"]
	if not has_randomised_styles then
		Tracker:FindObjectForCode("Progressive Trickster").CurrentStage = 1
		Tracker:FindObjectForCode("Progressive Swordmaster").CurrentStage = 1
		Tracker:FindObjectForCode("Progressive Gunslinger").CurrentStage = 1
		Tracker:FindObjectForCode("Progressive Royalguard").CurrentStage = 1
	end
end

function onItem(index, item_id, item_name, player_number)
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("called onItem: %s, %s, %s, %s, %s", index, item_id, item_name, player_number, CUR_INDEX))
	end
	if index <= CUR_INDEX then
		return
	end
	local is_local = player_number == Archipelago.PlayerNumber
	CUR_INDEX = index
	local item = ITEM_MAPPING[item_id]
	if not item or not item[1] then
		print(string.format("onItem: could not find item mapping for id %s", item_id))
		return
	end
	for _, item_pair in pairs(item) do
		item_code = item_pair[1]
		item_type = item_pair[2]
		if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("onItem: code: %s, type %s", item_code, item_type))
		end
		local item_obj = Tracker:FindObjectForCode(item_code)
		if item_obj then
			if item_obj.Type == "toggle" then
				if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
					print("toggle")
				end
				item_obj.Active = true
			elseif item_obj.Type == "progressive" then
				if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
					print("progressive")
				end
				if item_obj.Active == true then
					item_obj.CurrentStage = item_obj.CurrentStage + 1
				else
					item_obj.Active = true
				end
			elseif item_obj.Type == "consumable" then
				if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
					print("consumable")
				end
				item_obj.AcquiredCount = item_obj.AcquiredCount + item_obj.Increment * (tonumber(item_pair[3]) or 1)
			elseif item_obj.Type == "progressive toggle" then
				if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
					print("progressive toggle")
				end
				if item_obj.Active then
					item_obj.CurrentStage = item_obj.CurrentStage + 1
				else
					item_obj.Active = true
				end
			end
			if item_code == "Purple Orb" or item_code == "Devil Trigger" then
				checkAndUpdateDevilTrigger()
			end
		else
			print(string.format("onItem: could not find object for code %s", item_code[1]))
		end
	end
end

--called when a location gets cleared
function onLocation(location_id, location_name)
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("called onLocation: %s, %s", location_id, location_name))
	end
	MANUAL_CHECKED = false
	local location_array = LOCATION_MAPPING[location_id]
	if not location_array or not location_array[1] then
		print(string.format("onLocation: could not find location mapping for id %s", location_id))
		return
	end

	for _, location in pairs(location_array) do
		local location_obj = Tracker:FindObjectForCode(location)
		if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("called onLocation: location %s, location_obj %s", location, location_obj))
		end
		if location_obj then
			if location:sub(1, 1) == "@" then
				location_obj.AvailableChestCount = location_obj.AvailableChestCount - 1
			else
				location_obj.Active = true
			end

			updateAvailableMissions(location)
		else
			print(string.format("onLocation: could not find location_object for code %s", location))
		end
	end
	MANUAL_CHECKED = true
end

function OnNotify(key, value, old_value)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onNotify: key %s, value %s, old_value %s", key, value, old_value))
    end
	if value ~= old_value and key == HINTS_ID then
		Tracker.BulkUpdate = true
		for _, hint in ipairs(value) do
			if hint.finding_player == Archipelago.PlayerNumber then
				if hint.status == 0 then
					UpdateHints(hint.location, 100 + hint.item_flags)
				else
					UpdateHints(hint.location, hint.status)
				end
			end
		end
		Tracker.BulkUpdate = false
	end
end

function OnNotifyLaunch(key, value)
	if key == HINTS_ID then
		Tracker.BulkUpdate = true
		for _, hint in ipairs(value) do
			if hint.finding_player == Archipelago.PlayerNumber then
				if hint.status == 0 then
					UpdateHints(hint.location, 100 + hint.item_flags)
				else
					UpdateHints(hint.location, hint.status)
				end
			end
		end
		Tracker.BulkUpdate = false
	end
end

function onScout(location_id, location_name, item_id, item_name, item_player)
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(
			string.format(
				"called onScout: %s, %s, %s, %s, %s",
				location_id,
				location_name,
				item_id,
				item_name,
				item_player
			)
		)
	end
	-- not implemented yet :(
end

-- called when a bounce message is received
function onBounce(json)
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("called onBounce: %s", dump_table(json)))
	end
	-- your code goes here
end

function UpdateHints(locationID, status) -->
	if Highlight then
		if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("called UpdateHints: locationID %s, status %s", locationID, status))
		end
		local location_table = LOCATION_MAPPING[locationID]
		for _, location in ipairs(location_table) do
			if location:sub(1, 1) == "@" then
				local obj = Tracker:FindObjectForCode(location)

				if obj then
					if TROLL_PLAYER and HIGHLIGHT_LEVEL[status] == Highlight.Avoid then
						obj.Highlight = HIGHLIGHT_LEVEL[30]
					else
						obj.Highlight = HIGHLIGHT_LEVEL[status]
					end
				else
					print(string.format("No object found for code: %s", location))
				end
			end
		end
	end
end

--doc
--hint layout
-- {
--     ["receiving_player"] = 1,
--     ["class"] = Hint,
--     ["finding_player"] = 1,
--     ["location"] = 67361,
--     ["found"] = false,
--     ["item_flags"] = 2, --bitflag --> 0=filler, 1=progression, 2=useful, 4=trap
--     ["status"] = 40, --bitflag --> 0=Unspecified, 10=NoPriority, 20=Avoid, 30=Priority, 40=None
--     ["entrance"] = ,
--     ["item"] = 66062,
-- }
