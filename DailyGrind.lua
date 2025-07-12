

local gui = LibStub("AceGUI-3.0")
local reg = LibStub("AceConfigRegistry-3.0")
local dialog = LibStub("AceConfigDialog-3.0")

local addon = LibStub("AceAddon-3.0"):NewAddon("DailyGrind", "AceEvent-3.0", "AceConsole-3.0")

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
	
	local data = { 
      { 
        value = "A",
        text = "Alpha",
      },
      {
        value = "B",
        text = "Bravo",
        children = {
          { 
            value = "C", 
            text = "Charlie",
          },
          {
            value = "D",	
            text = "Delta",
            children = { 
              { 
                value = "E",
                text = "Echo"
              } 
            }
          }
        }
      },
      { 
        value = "F", 
        text = "Foxtrot",
        disabled = true,
      }
    }
	
	local tree = gui:Create("TreeGroup")
	tree:SetTree(data)
	frame:AddChild(tree)
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
