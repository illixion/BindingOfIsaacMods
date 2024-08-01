local unbreakableMirror = RegisterMod("Unbreakable Mirror", 1)
local game = Game()

-- this mod is dedicated to the 45 minutes of my life and 1 glorious R key run
-- that were wasted due to going into the Mirror World with Mama Mega

-- save some CPU cycles by only monitoring the mirror if currently in mirror room
function unbreakableMirror:onRoomStart()
    roomName = game:GetLevel():GetCurrentRoomDesc().Data.Name
    if roomName == "Mirror Room" then
        unbreakableMirror:AddCallback(ModCallbacks.MC_POST_UPDATE, unbreakableMirror.checkMirror)
    else
        unbreakableMirror:RemoveCallback(ModCallbacks.MC_POST_UPDATE, unbreakableMirror.checkMirror)
    end
end

function unbreakableMirror:checkMirror()
    for i = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
        local door = game:GetRoom():GetDoor(i)
        if (
            door ~= nil and
            door.OpenAnimation == "Break" and
            door:IsBusted() == true
        ) then
            -- get player's current XY
            local player = Isaac.GetPlayer(0)
            local playerX = player.Position.X
            local playerY = player.Position.Y

            -- fix mirror
            door.Busted = false
            door:SetLocked(true)

            -- prevent glass shattering sound from playing
            local sfx = SFXManager()
            sfx:Stop(SoundEffect.SOUND_MIRROR_BREAK)
            sfx:Play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.5)

            -- reload room to reset the mirror
            game:ChangeRoom(game:GetLevel():GetCurrentRoomIndex())

            -- set level state to prevent suffocation in mirror world
            game:GetLevel():SetStateFlag(LevelStateFlag.STATE_MIRROR_BROKEN, false)

            -- reset player's position
            player.Position = Vector(playerX, playerY)
        end
    end
end

unbreakableMirror:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, unbreakableMirror.onRoomStart)
