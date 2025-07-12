

local gui = LibStub("AceGUI-3.0")
local reg = LibStub("AceConfigRegistry-3.0")
local dialog = LibStub("AceConfigDialog-3.0")

local addon = LibStub("AceAddon-3.0"):NewAddon("DailyGrind", "AceEvent-3.0", "AceConsole-3.0")

local questieDb = QuestieLoader:ImportModule("QuestieDB");
local questieTrackerUtils = QuestieLoader:ImportModule("TrackerUtils");

local old_CloseSpecialWindows

function addon:OpenFrame()
	if not old_CloseSpecialWindows then
		old_CloseSpecialWindows = CloseSpecialWindows
		CloseSpecialWindows = function()
			local found = old_CloseSpecialWindows()
			if self.frame then
				self.frame:Hide()
				return true
			end
			return found
		end
	end
	
	local frame = self.frame
	if not frame then
		frame = self:CreateMainFrame()
	end
	
	frame:Show()
end

function addon:CreateMainFrame()
	local frame = gui:Create("Frame")
	frame:ReleaseChildren()
	frame:SetTitle("Daily Grind")
	frame:SetLayout("Fill")
	frame:SetCallback("OnClose", function()
		gui:Release(frame)
		self.frame = nil
	end)
	
	local data = self:BuildData();
	
	local tree = gui:Create("TreeGroup")
	tree:SetTree(data)
	frame:AddChild(tree)
end

local function getZoneName(zoneId)
	local zoneName = "Unknown"
	if zoneId then
		zoneName = questieTrackerUtils:GetZoneNameByID(zoneId)
		if not zoneName then
			zoneName = questieTrackerUtils:GetCategoryNameByID(zoneId)
		end
	end
	return zoneName
end

function addon:BuildData()
	local dataByZone = {};
	local zoneNameList = {};
	
	for _, questId in ipairs(addon.quests) do
		local zoneName, item
		local questInfo = questieDb.GetQuest(questId)
		if questInfo then
			zoneName = getZoneName(questInfo.zoneOrSort)
			item = { text = questInfo.name, value = questId }
		else
			zoneName = "Unknown"
			item = { text = "Unknown quest " .. questId, value = questId }
		end
		
		local array = dataByZone[zoneName]
		if array == nil then
			array = {}
			dataByZone[zoneName] = array
			table.insert(zoneNameList, zoneName)
		end
		table.insert(array, item)
	end
	
	table.sort(zoneNameList)
	
	local resultData = {}
	for _, zoneName in ipairs(zoneNameList) do
		local zoneQuests = dataByZone[zoneName]
		table.sort(zoneQuests, function(a,b) return a.text < b.text end)
		
		local header = { text = zoneName, children = zoneQuests }
		table.insert(resultData, header)
	end
	DAILY_GRIND_RESULT_DATA = resultData
	return resultData
end

function addon:UpdateActiveQuests()
	-- todo
end

function addon:OnInitialize()
	self:RegisterChatCommand("daily", "OpenFrame")
	self:RegisterEvent("QUEST_ACCEPTED", "UpdateActiveQuests")
	self:RegisterEvent("QUEST_REMOVED", "UpdateActiveQuests")
	self:RegisterEvent("QUEST_TURNED_IN", "UpdateActiveQuests")
end





--
-- IsQuestCompletable
-- QuestIsDaily QuestIsWeekly
-- C_QuestLog.GetAllCompletedQuestIDs
-- C_QuestLog.GetMaxNumQuests
-- C_QuestLog.GetMaxNumQuestsCanAccept
-- C_QuestLog.GetQuestIDForLogIndex
-- C_QuestLog.GetHeaderIndexForQuest
-- C_QuestLog.GetInfo (details but active only)
-- numShownEntries, numQuests = C_QuestLog.GetNumQuestLogEntries()
--
-- /run for a,b in pairs(LibStub("AceAddon-3.0"):GetAddon("DailyGrind").quests) do print(b,C_QuestLog.IsQuestFlaggedCompleted(b)) end
-- /run for a,b in pairs(LibStub("AceAddon-3.0"):GetAddon("DailyGrind").quests) do if C_QuestLog.IsQuestFlaggedCompleted(b) then print(b) end end
--
-- C_QuestLog.GetQuestInfo(29211) (title)
-- C_QuestLog.IsQuestFlaggedCompleted(29211)
-- C_QuestLog.GetDistanceSqToQuest
-- 
-- /dump QuestieLoader:ImportModule("QuestieDB")
-- /dump QuestieLoader:ImportModule("QuestieDB").GetQuest(29211)
-- /dump QuestieLoader:ImportModule("QuestieDB").GetQuest(29211).zoneOrSort

--    local sortedQuestIds, questDetails = TrackerUtils:GetSortedQuestIds()
--            local zoneName = questDetails[questId].zoneName
--			TrackerUtils:GetZoneNameByID

--  /dump QuestieLoader:ImportModule("TrackerUtils").GetZoneNameByID(-379)
-- /dump QuestieLoader:ImportModule("TrackerUtils"):GetCategoryNameByID(-379)


