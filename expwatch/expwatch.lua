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

addon.name    = 'expwatch';
addon.author  = 'towbes';
addon.desc    = 'Hourly Exp Tracker';
addon.link    = '';
addon.version = '1.0';

require 'common';
require 'daoc';

local imgui = require 'imgui';

-- Window Variables
local window = T{
    is_checked = T{ false, },
};

-- expwatch variables..
local expwatch = T{ 
    --Regular exp
    exppointer = 0,
    lvlpointer = 0,
    startexp = 0,
    startLvl = 0,
    currentLvl = 0,
    currentExp = 0,
    --champ exp
    clexppointer = 0,
    cllvlpointer = 0,
    clstartexp = 0,
    clstartLvl = 0,
    clcurrentLvl = 0,
    clcurrentExp = 0,
    --storage variables

    player = 0,
    name = '',
    startTime = 0,
    startTotal = 0,
    is_checked = T{ false, },};

--[[
* event: load
* desc : Called when the addon is being loaded.
--]]
hook.events.register('load', 'load_cb', function ()
    -- Locate the current exp pointer..
    --Address of signature = game.dll + 0x0008F183
    local expptr = hook.pointers.add('expwatch.currentexp', 'game.dll', 'A3????????????????8CEA', 1, 0);
    if (expptr == 0) then
        error('Failed to locate required memory pointer; cannot load.');
    end
    -- Read the pointer from the opcode..
    expptr = hook.memory.read_uint32(expptr);
    if (expptr == 0) then
        error('Failed to locate required memory pointer; cannot load.');
    end
    -- Store the pointer..
    expwatch.exppointer = expptr;

    -- Locate the player level pointer..
    --Address of signature = game.dll + 0x00020AD5
    local lvlptr = hook.pointers.add('expwatch.playerlvl', 'game.dll', 'A1????????????????A493', 1, 0);
    if (lvlptr == 0) then
        error('Failed to locate required memory pointer; cannot load.');
    end
    -- Read the pointer from the opcode..
    lvlptr = hook.memory.read_uint32(lvlptr);
    if (lvlptr == 0) then
        error('Failed to locate required memory pointer; cannot load.');
    end
    -- Store the pointer..
    expwatch.lvlpointer = lvlptr;

    -- Locate the CL exp pointer..
    --Address of signature = game.dll + 0x0001B53C
    local clexppointer = hook.pointers.add('expwatch.currentexp', 'game.dll', '890D????????8B0D????????83C4', 2, 0);
    if (clexppointer == 0) then
        error('Failed to locate required memory pointer; cannot load.');
    end
    -- Read the pointer from the opcode..
    clexppointer = hook.memory.read_uint32(clexppointer);
    if (clexppointer == 0) then
        error('Failed to locate required memory pointer; cannot load.');
    end
    -- Store the pointer..
    expwatch.clexppointer = clexppointer;

    -- Locate the CL Level pointer..
    --Address of signature = game.dll + 0x0001B593
    local cllvlpointer = hook.pointers.add('expwatch.currentexp', 'game.dll', '0305????????83F8', 2, 0);
    if (cllvlpointer == 0) then
        error('Failed to locate required memory pointer; cannot load.');
    end
    -- Read the pointer from the opcode..
    cllvlpointer = hook.memory.read_uint32(cllvlpointer);
    if (cllvlpointer == 0) then
        error('Failed to locate required memory pointer; cannot load.');
    end
    -- Store the pointer..
    expwatch.cllvlpointer = cllvlpointer;

    --store start exp value
    expwatch.startexp = hook.memory.read_float(expwatch.exppointer);
    --store the level value
    expwatch.startLvl = hook.memory.read_int32(expwatch.lvlpointer);
    --total exp value
    expwatch.startTotal = expwatch.startLvl + expwatch.startexp * 0.001;

    --store start clexp value
    expwatch.clstartexp = hook.memory.read_int32(expwatch.clexppointer);
    --store the cllevel value
    expwatch.clstartLvl = hook.memory.read_int32(expwatch.cllvlpointer);
    --total clexp value
    expwatch.clstartTotal = expwatch.clstartLvl + expwatch.clstartexp * 0.001;

    --store session startTime
    expwatch.startTime = hook.time.get_tick();
end);

--[[
* Prints the addon specific help information.
*
* @param {err} err - Flag that states if this function was called due to an error.
--]]
local function print_help(err)
    err = err or false;

    local mode = daoc.chat.message_mode.help;
    if (err) then
        daoc.chat.msg(mode, 'Invalid command syntax for command: /multisend');
    else
        daoc.chat.msg(mode, 'Available commands for the move addon are:');
    end

    local help = daoc.chat.msg:compose(function (cmd, desc)
        return mode, ('  %s - %s'):fmt(cmd, desc);
    end);

    help('/exp reset', 'Reset start exp and timer');
end

--[[
* event: command
* desc : Called when the game is handling a command.
--]]
hook.events.register('command', 'command_cb', function (e)
    -- Parse the command arguments..
    local args = e.modified_command:args();
    if (#args == 0) then
        return;
    end

    -- Command: /example1
    if ((args[1]:ieq('exp') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/exp')) then
        e.blocked = true;
        -- Mark the command as handled, preventing the game from ever seeing it..
        if (#args == 1) then
            return;
        end

        -- Command: help
        if (#args == 2 and args[2]:any('help')) then
            print_help(false);
            return;
        end

        -- Command: /example2
        if ((args[2]:ieq('reset'))) then
            
            resetCounters();

            return;
        end
        -- Unknown sub-command..
        print_help(true);
        return;
    end
end);

function resetCounters ()
    --reset Champion level exp
    --reset start clexp value
    expwatch.clstartexp = hook.memory.read_int32(expwatch.clexppointer);
    --reset the cllevel value
    expwatch.clstartLvl = hook.memory.read_int32(expwatch.cllvlpointer);
    --reset clexp value
    expwatch.clstartTotal = expwatch.clstartLvl + expwatch.clstartexp * 0.001;

    --reset normal exp
    --reset start exp value
    expwatch.startexp = hook.memory.read_float(expwatch.exppointer);
    --reset the level value
    expwatch.startLvl = hook.memory.read_int32(expwatch.lvlpointer);
    --reset total exp value
    expwatch.startTotal = expwatch.startLvl + expwatch.startexp * 0.001;
    --reset session startTime
    expwatch.startTime = hook.time.get_tick();
end

--[[
* event: d3d_present
* desc : Called when the Direct3D device is presenting a scene.
--]]
hook.events.register('d3d_present', 'd3d_present_cb', function ()
    --store the player entity
    expwatch.player = daoc.entity.get(daoc.entity.get_player_index());


    if (expwatch.player ~= nil) then
        -- Render a custom example window via ImGui..
        imgui.SetNextWindowSize(T{ 350, 200, }, ImGuiCond_FirstUseEver);
        if (imgui.Begin('ExpWatch')) then
            imgui.Checkbox('Exp Type', expwatch.is_checked);
            imgui.SameLine();
            if (imgui.Button('Reset')) then
                resetCounters();
            end
            if (expwatch.is_checked[1]) then
                imgui.TextColored(T{ 0.0, 1.0, 0.0, 1.0, }, 'Champion Level Exp');
                imgui.Text(("Start level: %.03f"):fmt(expwatch.clstartTotal));
                imgui.Separator();
                local currTotal = hook.memory.read_int32(expwatch.cllvlpointer) + (hook.memory.read_int32(expwatch.clexppointer) * 0.001);
                imgui.Text(("Current level: %.03f"):fmt(currTotal));
                
                local totalExp = currTotal - expwatch.clstartTotal;
                imgui.Text(("Levels Gained: %.03f"):fmt(totalExp));
                local perHour = totalExp / (((hook.time.get_tick() - expwatch.startTime) / 1000) / 60 / 60);
                imgui.Text(("Levels per hour: %.03f"):fmt(perHour));                
            else
                imgui.TextColored(T{ 0.0, 1.0, 1.0, 1.0, }, 'Regular Exp');
                imgui.Text(("Start level: %.03f"):fmt(expwatch.startTotal));
                imgui.Separator();
                local currTotal = hook.memory.read_int32(expwatch.lvlpointer) + (hook.memory.read_float(expwatch.exppointer) * 0.001);
                imgui.Text(("Current level: %.03f"):fmt(currTotal));
                
                local totalExp = currTotal - expwatch.startTotal;
                imgui.Text(("Levels Gained: %.03f"):fmt(totalExp));
                local perHour = totalExp / (((hook.time.get_tick() - expwatch.startTime) / 1000) / 60 / 60);
                imgui.Text(("Levels per hour: %.03f"):fmt(perHour));
            end
        end
        imgui.End();
    end



end);
