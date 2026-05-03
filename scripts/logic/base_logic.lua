-- this is the file to put all your custom logic functions into.
-- if you dont want to use the json based logic you can switch to a graph-based logic method.
-- the needed functions for that are in `/scripts/logic/graph_logic/logic_main.lua`.

-- function <name> (<parameters if needed>)
--     <actual code>
--     <indentations are just for readability>
-- end
--
function has(item, amount)
	local count = Tracker:ProviderCountForCode(item)
	amount = tonumber(amount)
	if not amount then
		return count > 0
	else
		return count >= amount
	end
end

function notHas(item)
    return not has(item)
end

ADDED_DT_ORBS = false
function checkAndUpdateDevilTrigger()
	local is_dt_mode = SLOT_DATA["devil_trigger_mode"]
	local is_purple_mode = SLOT_DATA["purple_orb_mode"]
	if is_purple_mode and not is_dt_mode then
		Tracker:FindObjectForCode("Devil Trigger").Active = tonumber(Tracker:ProviderCountForCode("Purple Orb")) >= 3
	elseif not is_purple_mode and has("Devil Trigger") and ADDED_DT_ORBS then
		Tracker:FindObjectForCode("Purple Orb").AcquiredCount = Tracker:FindObjectForCode("Purple Orb").AcquiredCount
			+ 3
		ADDED_DT_ORBS = true
	end
end

COMPLETED_LOCATIONS = {}
function activateMissionAssignment(mission_idx)
	local slot = getCurrentSlot(mission_idx)
	Tracker:FindObjectForCode("m" .. slot .. "_assignment").CurrentStage = MISSION_ASSIGNMENTS[tonumber(mission_idx)]
    Tracker:FindObjectForCode("Assignment Slot #" .. slot).Active = true

end

function updateAvailableMissions(location)
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print("[DEBUG] updateAvailableMap called | Location: " .. tostring(location))
	end
	if not COMPLETED_LOCATIONS[location] and string.find(location, "Mission Completion$") then
		if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print("[DEBUG] updateAvailableMap adds location to completed missions: " .. tostring(location))
		end
		local item_obj = Tracker:FindObjectForCode("Completed Missions")
		item_obj.AcquiredCount = item_obj.AcquiredCount + item_obj.Increment
		COMPLETED_LOCATIONS[location] = true

		local current_mission_idx = item_obj.AcquiredCount + 1
		local current_mission = MISSION_ASSIGNMENTS[current_mission_idx]
		if current_mission then
			activateMissionAssignment(current_mission_idx, current_mission)
			updateMap(current_mission, 0)
		end
	end
end

function reverseMapping(input_table)
	local reversed = {}
	for k, v in pairs(input_table) do
		-- We set the value as the key, and the key as the value
		reversed[v] = k
	end
	return reversed
end

function getCurrentSlot(i)
	local idx = tonumber(i)
	local slot = ""

	if idx < 10 and idx > 0 then
		slot = "0" .. idx
	else
		slot = "" .. idx
	end

	return slot
end

function getActiveMissionIdx(mission_slot)
	local idx = tonumber(mission_slot)
	for i = 1, 20 do
		local slot = getCurrentSlot(i)
		local m = Tracker:FindObjectForCode("m" .. slot .. "_assignment")
		if m.CurrentStage == idx then
			return slot
		end
	end
	return nil
end

function hasMission(mission_idx)
	local m_idx = getActiveMissionIdx(mission_idx)
	return m_idx ~= nil and Tracker:FindObjectForCode("Assignment Slot #" .. m_idx).Active
end

function notHasMission(mission_idx)
	return not hasMission(mission_idx)
end

ADJUDICATOR_MAP = {
	[1] = 3,
	[2] = 5,
	[3] = 6,
	[4] = 7,
	[5] = 8,
	[6] = 9,
	[7] = 11,
	[8] = 13,
	[9] = 14,
	[10] = 17,
}

ADJUDICATOR_BASE_WEAPON_MAP = {
	[1] = "Rebellion",
	[2] = "Cerberus",
	[3] = "Agni and Rudra",
	[4] = "Rebellion",
	[5] = "Cerberus",
	[6] = "Nevan",
	[7] = "Agni and Rudra",
	[8] = "Nevan",
	[9] = "Beowulf",
	[10] = "Beowulf",
}

function hasRequiredWeapon(adjudicator_idx)
	adjudicator_idx = tonumber(adjudicator_idx)
	local map_idx = ADJUDICATOR_MAP[adjudicator_idx]
	local adjudicator_name = "Mission #" .. map_idx .. " - Combat Adjudicator #" .. adjudicator_idx
	local adjudicators = SLOT_DATA["adjudicators"]
	if adjudicators ~= nil then
		local adjudicator = adjudicators[adjudicator_name]
		local required_weapon = adjudicator["weapon"]
		return Tracker:FindObjectForCode(required_weapon).Active
	else
		local required_weapon = ADJUDICATOR_BASE_WEAPON_MAP[adjudicator_idx]
		return Tracker:FindObjectForCode(required_weapon).Active
	end
end

function notHasRequiredWeapon(idx)
    return not hasRequiredWeapon(idx)
end

function hasRequiredDifficulty()
	local required_difficulty = SLOT_DATA["mission_clear_difficulty"]
	if required_difficulty == nil then
		return true
	end

	for difficulty, _ in pairs(AVAILABLE_DIFFICULTIES) do
		if difficulty >= required_difficulty then
			return true
		end
	end
	return false
end

function hasRequiredSSDifficulty()
	if SLOT_DATA["enabled_ss_rank"] and SLOT_DATA["check_ss_difficulty"] then
		local required_difficulty = SLOT_DATA["mission_clear_difficulty"]
		if required_difficulty == nil then
			return true
		end

		for difficulty, _ in pairs(AVAILABLE_DIFFICULTIES) do
			if difficulty >= required_difficulty then
				return true
			end
		end
	end
	return false
end

function hasAirhike()
	return has("Rebellion - Airhike") or has("Agni and Rudra - Airhike") or has("Beowulf - Airhike")
end

function notHasAirhike()
    return not hasAirhike()
end

function hasAirraid()
	return has("Nevan") and has("Nevan - Airraid") and has("Devil Trigger")
end

function hasShopEnabled(name)
	if name == "Orb" then
		return SLOT_DATA["shop_orb_checks"]
	end

	return false
end

function SB()
	if has("show_oom_available") or has("show_oom_on") then
		return AccessibilityLevel.SequenceBreak
	else
		return AccessibilityLevel.None
	end
end

function updateMap(mission_id, room_id)
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print("[DEBUG] updateMap called | Mission ID: " .. tostring(mission_id) .. " | Room ID: " .. tostring(room_id))
	end
	if has("auto_tab_on_mission") then
		local tabs = TAB_MAPPING[mission_id][0]
		if tabs then
			print("[DEBUG] Found " .. #tabs .. " tab(s) to activate")
			for _, tab in ipairs(tabs) do
				print("[DEBUG] Activating tab: " .. tostring(tab))
				Tracker:UiHint("ActivateTab", tab)
			end
		end
	elseif has("auto_tab_on_room") then
		local tabs = TAB_MAPPING[mission_id][room_id]
		if tabs then
			for _, tab in ipairs(tabs) do
				Tracker:UiHint("ActivateTab", tab)
			end
		end
	end
end
