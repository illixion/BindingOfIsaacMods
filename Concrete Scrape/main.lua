local CSWS = RegisterMod("Concrete Scrape", 1)
local json = require("json")
local game = Game()
local sfx = SFXManager()

local persistentData = {}
local defaultConfig = {
    configVersion = 1,
    volume = 0.5,
    activationSpeed = 0.6,
    pitchAdjust = true
}
local sfxId = Isaac.GetSoundIdByName("Concrete Scrape Loop")
local currentlyPlaying = false

function CSWS:onUpdate(player)
    -- hot reload fix
    if persistentData["configVersion"] == nil then
        CSWS:loadConfiguration()
    end

    -- only enable when speed is low
    if player.MoveSpeed <= persistentData["activationSpeed"] then
        local velocity = player.Velocity:Length()

        -- ensure speed is within a range
        if (not ((velocity >= 0.5) and (velocity <= 4.42))) then
            -- stop sound
            sfx:Stop(sfxId)
            currentlyPlaying = false
            return
        end

        local pitch = 1
        if persistentData["pitchAdjust"] then
            -- calculate pitch based on player's velocity, limit to values between 0.8 and 1
            pitch = math.max(math.min(velocity / 2, 1), 0.8)
        end

        -- if sound is already playing, adjust pitch
        if currentlyPlaying then
            sfx:AdjustPitch(sfxId, pitch)
        else
            -- play sound
            sfx:Play(sfxId, persistentData["volume"], 0, true, pitch)
            currentlyPlaying = true
        end
    else
        -- if playing, stop sound
        if currentlyPlaying then
            sfx:Stop(sfxId)
            currentlyPlaying = false
        end
    end
end

-- Mod Config Menu Settings
if ModConfigMenu then
    local modSettings = "Concrete Scrape"

    -- avoid duplicating settings
    ModConfigMenu.RemoveCategory(modSettings)

    ModConfigMenu.UpdateCategory(modSettings, {
		Info = {"Concrete Scrape",}
	})

    ------ Title
    ModConfigMenu.AddText(modSettings, "Settings", function() return "Concrete Scrape" end)
	ModConfigMenu.AddSpace(modSettings, "Settings")

    ------ Settings

    -- Volume
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return persistentData["volume"] * 100
			end,
			Minimum = 0,
			Maximum = 100,
			Display = function()
				return "Volume: " .. persistentData["volume"] * 100 .. "%"
			end,
			OnChange = function(currentNum)
                persistentData["volume"] = currentNum / 100
                CSWS:SaveData(json.encode(persistentData))
			end,
			Info = {"Volume", "Default: 50%"}
	})
    -- Activation Speed
    ModConfigMenu.AddSetting(modSettings, "Settings",
        {
            Type = ModConfigMenu.OptionType.NUMBER,
            CurrentSetting = function()
                return persistentData["activationSpeed"] * 100
            end,
            Minimum = 0,
            Maximum = 100,
            Display = function()
                return "Activation Speed: " .. persistentData["activationSpeed"]
            end,
            OnChange = function(currentNum)
                persistentData["activationSpeed"] = currentNum / 100
                CSWS:SaveData(json.encode(persistentData))
            end,
            Info = {"Only play sound if speed is below this value", "Default: 0.7"}
    })
    -- Pitch adjust
    ModConfigMenu.AddSetting(modSettings, "Settings",
        {
            Type = ModConfigMenu.OptionType.BOOLEAN,
            CurrentSetting = function()
                return persistentData["pitchAdjust"]
            end,
			Display = function()
				local onOff = "No"
				if persistentData["pitchAdjust"] then
					onOff = "Yes"
				end
				return 'Adjust pitch: ' .. onOff
			end,
            OnChange = function(currentBool)
                persistentData["pitchAdjust"] = currentBool
                CSWS:SaveData(json.encode(persistentData))
            end,
            Info = {"Sound will change pitch based on player velocity", "Default: yes"}
    })
end

-- Mod Config Menu save/load
function CSWS:onGameStart()
    CSWS:loadConfiguration()
end

function CSWS:loadConfiguration()
    if (CSWS:HasData()) then
        persistentData = json.decode(CSWS:LoadData())
    else
        persistentData = defaultConfig
    end

    -- upgrade config if necessary
    if (persistentData["configVersion"] == nil or persistentData["configVersion"] ~= defaultConfig["configVersion"]) then
        print("[CSWS+] Upgrading config to v" .. defaultConfig["configVersion"])
        persistentData["configVersion"] = defaultConfig["configVersion"]
        -- iterate over persistentData and add missing keys
        for key, value in pairs(defaultConfig) do
            if (persistentData[key] == nil) then
                persistentData[key] = value
            end
        end
    end

    CSWS:SaveData(json.encode(persistentData))
end

function CSWS:onGameEnd()
    -- ensure sound is stopped
    sfx:Stop(sfxId)
    currentlyPlaying = false
end

CSWS:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, CSWS.onGameStart)
CSWS:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, CSWS.onUpdate)
