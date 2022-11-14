--[[
* daochook - Copyright (c) 2022 atom0s [atom0s@live.com]
* Contact: https://www.atom0s.com/
* Contact: https://discord.gg/UmXNvjq
* Contact: https://github.com/atom0s
*
* This file is part of daochook.
*
* daochook is free software: you can redistribute it and/or modify
* it under the terms of the GNU Affero General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* daochook is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Affero General Public License for more details.
*
* You should have received a copy of the GNU Affero General Public License
* along with daochook.  If not, see <https://www.gnu.org/licenses/>.
--]]

addon.name    = 'dpsmeter';
addon.author  = 'towbes';
addon.desc    = 'DPS Meter for daoc';
addon.link    = '';
addon.version = '1.0';

require 'common';
require 'daoc';

local imgui = require 'imgui';

-- Window Variables
local meter = T{
    is_checked = T{ true, },
    current_dmg = 0,
    total_dmg = 0,
    current_target = '',
    targets = T {''},
    past_fights = T {0},
    durations = T {1},
    in_combat = T{ false, },
};

--pause time to flag combat
local tick_holder = hook.time.tick();
local tick_interval = 4000;
local combat_start = 1;
local combat_end = 2;

local combatMessages = T {
    daoc.chat.message_mode.spell,
    daoc.chat.message_mode.you_hit,
    daoc.chat.message_mode.you_were_hit,
    daoc.chat.message_mode.skill,
    daoc.chat.message_mode.others_combat,
    daoc.chat.message_mode.damage_add,
    daoc.chat.message_mode.spell_resisted,
    daoc.chat.message_mode.damaged,
    daoc.chat.message_mode.missed,
}

local badStartMessages = T {
    'You target',
    'You examine',
    'You must wait',
    'That target is too far away',
    'Your target is not in view',
}

-- Prepare the logs output folder..
local path = ('%s\\addons\\dpsmeter\\logs'):fmt(hook.get_hook_path());
hook.fs.create_dir(path);

-- Prepare the output file name based on the current date information..
local time = hook.time.get_local_time();
local file = ('%s\\damagelog_%02d.%02d.%02d.log'):fmt(path, time['day'], time['month'], time['year']);
daoc.chat.msg(daoc.chat.message_mode.help, ('[DPS Meter] Logs will save to:\n%s'):fmt(file));

--[[
* Writes the given string to the current packet log file.
--]]
local function log(str)
    local f = io.open(file, 'a');
    if (f == nil) then
        return;
    end

    f:write(str);
    f:flush();
    f:close();
end

--[[
* event: message
* desc : Called when the game is handling a message.
--]]
hook.events.register('message', 'message_cb', function (e)
    -- Look for combat messages
    log(('mode: %d, msg %s\n'):fmt(e.mode, e.message));
    if (meter.is_checked[1] and combatMessages:contains(e.mode)) then
        --we're still fighting so reset the timer
        tick_holder = hook.time.tick();

        --check for combat messages indicating a failure, dont' start the timer
        for i = 1, badStartMessages:len() do
            if e.message:contains(badStartMessages[i]) then
                return;
            end
        end

        
        if (meter.is_checked[1] and (e.mode == daoc.chat.message_mode.you_hit or e.mode == daoc.chat.message_mode.you_miss or e.mode == daoc.chat.message_mode.spell_resisted)) then

            
            --start the timer on hit/miss instead of just cast
            if (meter.in_combat[1] == false) then
                meter.in_combat[1] = true;
                combat_start = hook.time.tick();
            end
            -- Add a timestamp to each message..
            local time = hook.time.get_local_time();
            --log(('%02i:%02i | %s\n'):fmt(time['hh'], time['mm'], e.message));
            log_you_hit(e.message);
            
        end 

    end
    if (e.mode == daoc.chat.message_mode.player_died) then
        --If something died, set the combat end to that so that we always catch the last thing that died before timeout
        combat_end = hook.time.tick();
    end

end);


--[[
* event: d3d_present
* desc : Called when the Direct3D device is presenting a scene.
--]]
hook.events.register('d3d_present', 'd3d_present_cb', function ()
    -- Render a custom example window via ImGui..
    imgui.SetNextWindowSize(T{ 350, 200, }, ImGuiCond_FirstUseEver);
    if (imgui.Begin('DPS Meter')) then
        imgui.Text('Tracks your damage');
        imgui.Checkbox('Check Me', meter.is_checked);

        if (meter.is_checked[1]) then
            imgui.TextColored(T{ 0.0, 1.0, 0.0, 1.0, }, 'Logging!');
        else
            imgui.TextColored(T{ 1.0, 0.0, 0.0, 1.0, }, 'Not Logging');
        end

        imgui.Text(('Total damage done: %d'):fmt(meter.total_dmg));
        imgui.Separator();
        imgui.Text(('Current target: %s'):fmt(meter.current_target));
        --If combat end hasn't been set (default is 2), then use tick time to get dps
        if (combat_end == 2) then
            imgui.Text(('Current dps: %d'):fmt(meter.current_dmg / ((hook.time.tick() - combat_start) / 1000)));
        else
            --otherwise use the combat end time
            imgui.Text(('Current dps: %d'):fmt(meter.current_dmg / ((hook.time.tick() - combat_start) / 1000)));
        end
        
        imgui.Separator();
        imgui.Text(('Prev fight target: %s'):fmt(meter.targets[1]));
        imgui.Text(('Prev fight damage: %d'):fmt(meter.past_fights[1]));
        imgui.Text(('Prev fight time: %ds'):fmt(meter.durations[1] / 1000));
        imgui.Text(('Prev fight dps: %d'):fmt(meter.past_fights[1] / (meter.durations[1] / 1000)));


        if (meter.in_combat[1]) then
            imgui.TextColored(T{ 0.0, 1.0, 0.0, 1.0, }, 'FIGHTING!');
        else
            imgui.TextColored(T{ 1.0, 0.0, 0.0, 1.0, }, 'Waiting');
        end
    end
    imgui.End();
end);

--[[
* event: d3d_present_tick
* desc : Used to determine when combat starts/ends
--]]
hook.events.register('d3d_present', 'd3d_present_tick', function ()
    -- Render a custom example window via ImGui..
    if (hook.time.tick() >= (tick_holder + tick_interval) ) then	

        --if we were in combat, log it
        if (meter.in_combat[1]) then
            --we timed out of combat so reset combat stats
            --Reset in combat flag
            meter.in_combat[1] = false;
            --log the target
            table.insert(meter.targets, 1, meter.current_target);
            meter.current_target = '';
            --Calculate the time of battle
            local fight_time = combat_end - combat_start;
            table.insert(meter.durations, 1, fight_time);
            --save and reset current dmg
            table.insert(meter.past_fights, 1, meter.current_dmg);
            meter.current_dmg = 0;

            combat_end = 2;
        end


        tick_holder = hook.time.tick();
        
    end
end);

function log_you_hit(msg)
    if msg == nil then
        return
    end
    local dmg = 0;
    local target = ''
    --if eden
    --melee attack
    if (msg:startswith('You attack')) then
        --You attack the villainous youth with your Exceptional Avernal Maligned Hammer and hit for 100 damage! (Damage Modifier: 2786)
        local tarsplit = msg:psplit('You attack');
        daoc.chat.msg(daoc.chat.message_mode.help, ('tarsplit: %s'):fmt(tarsplit[2]));
        if (tarsplit[2]:contains(' the')) then
            tarsplit[2] = tarsplit[2]:replace(' the', '');
        end

        if tarsplit[2] ~= nil then
            target = tarsplit[2]:psplit('with your');
            target = target[1]:clean();
            local dmgsplit = tarsplit[2]:psplit('hit for ');
            daoc.chat.msg(daoc.chat.message_mode.help, ('dmgsplit: %s'):fmt(dmgsplit[2]));
            if dmgsplit[2] ~= nil then
                local dmgsplit2 = dmgsplit[2]:psplit(' damage!');
                dmg = tonumber(dmgsplit2[1]);
            end
            
        end
    elseif (msg:startswith('You hit')) then
        --You hit the villainous youth for 204 damage!
        local tarsplit = msg:psplit('You hit the ');
        --daoc.chat.msg(daoc.chat.message_mode.help, ('tarsplit: %s'):fmt(tarsplit[2]));

        if tarsplit[2] ~= nil then
            target = tarsplit[2]:psplit('for');
            target = target[1]:clean();
            local dmgsplit = tarsplit[2]:psplit('for ');
            --daoc.chat.msg(daoc.chat.message_mode.help, ('dmgsplit: %s'):fmt(dmgsplit[2]));
            if dmgsplit[2] ~= nil then
                local dmgsplit2 = dmgsplit[2]:psplit(' damage!');
                --if there is a (-xx) resist message, remove it
                if (dmgsplit2[1]:contains('(')) then
                    dmgsplit2 = dmgsplit2[1]:psplit(' %(');
                end
                --daoc.chat.msg(daoc.chat.message_mode.help, ('dmgsplit: %s'):fmt(dmgsplit2[1]));
                dmg = tonumber(dmgsplit2[1]:clean());
            end
        end     
    end

    --daoc.chat.msg(daoc.chat.message_mode.help, ('Target: x%sx'):fmt(target));
    --daoc.chat.msg(daoc.chat.message_mode.help, ('damage: %d'):fmt(dmg));

    --if no current target, set one
    if meter.current_target:empty() then
        meter.current_target = target;
    end
    if dmg ~= nil then
        meter.current_dmg = meter.current_dmg + dmg;
        meter.total_dmg = meter.total_dmg + dmg;
    end
    
end