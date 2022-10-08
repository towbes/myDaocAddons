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

addon.name    = 'lootmaster';
addon.author  = 'towbes';
addon.desc    = 'Addon to help with loot after raids';
addon.link    = '';
addon.version = '1.0';

require 'common';
require 'daoc';

local imgui = require 'imgui';

-- Window Variables
local window = T{
    is_checked = T{ false, },
    maxRoll = 1000,
};

local alphaNames = T{ };


--[[
* event: load
* desc : Called when the addon is being loaded.
--]]
hook.events.register('load', 'load_cb', function ()
    --[[
    Event has no arguments.
    --]]
end);

--[[
* event: unload
* desc : Called when the addon is being unloaded.
--]]
hook.events.register('unload', 'unload_cb', function ()
    --[[
    Event has no arguments.
    --]]
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
        daoc.chat.msg(mode, 'Invalid command syntax for command: /lm');
    else
        daoc.chat.msg(mode, 'Available commands for the lootmaster addon are:');
    end

    local help = daoc.chat.msg:compose(function (cmd, desc)
        return mode, ('  %s - %s'):fmt(cmd, desc);
    end);

    help('/lm max', 'Set max allowed roll value');
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
    if ((args[1]:ieq('lm') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/lm')) then
        -- Mark the command as handled, preventing the game from ever seeing it..
        e.blocked = true;
        if (#args == 1) then return; end
		-- Command: help
		if (args[2]:any('help')) then
			print_help(false);
			return;
		end

        -- Command: /inv load
        if (args[2]:ieq('max')) then
			if (#args == 2) then return; end
            window.maxRoll = tonumber(args[3]);
            daoc.chat.msg(daoc.chat.message_mode.help, ('Max roll set to %d'):fmt(window.maxRoll));
            return;
        end

		-- Unknown sub-command..
		print_help(true);

        return;
    end



end);

--[[
* event: message
* desc : Called when the game is handling a message.
--]]
hook.events.register('message', 'message_cb', function (e)
    --[[

    Event Arguments

        e.mode              - number    - [Read Only] The message mode.
        e.message           - string    - [Read Only] The message string.
        e.modified_mode     - number    - The modified message mode.
        e.modified_message  - string    - The modified message string.
        e.injected          - boolean   - [Read Only] Flag that states if the event was injected by daochook or another addon.
        e.blocked           - boolean   - Flag that states if the event has been blocked by daochook or another addon.

    --]]
	if (window.is_checked[1]) then
		if e.mode == daoc.chat.message_mode.emote and e.message:contains('a random number between') then
			
			splitString = e.message:psplit(' ', 0, false);
			--daoc.chat.msg(daoc.chat.message_mode.help, ('Name: %s , Roll: %d'):fmt(splitString[1], splitString[10]));
			--Check if the name is already there
			for k,v in ipairs(alphaNames) do
				--daoc.chat.msg(daoc.chat.message_mode.help, ('Name: %s , string: %s'):fmt(v.name, splitString[1]));
				if v.name:ieq(splitString[1]) then return end;
			end
			--if not there add the roll, check that the roll is max or under
			if tonumber(splitString[10]) <= window.maxRoll then
				alphaNames:append(T{roll = tonumber(splitString[10]), name = splitString[1]});
			end
		end
	end
end);

--[[
* event: packet_recv
* desc : Called when the game is handling a received packet.
--]]
hook.events.register('packet_recv', 'packet_recv_cb', function (e)
    --[[

    Event Arguments

        e.opcode            - number    - [Read Only] The packet opcode.
        e.unknown           - number    - [Read Only] Unknown. (Generally zero.)
        e.session_id        - number    - [Read Only] The client session id.
        e.data              - string    - [Read Only] The packet data. (As a string literal.)
        e.data_raw          - void*     - [Read Only] The packet data. (As a raw pointer, for use with FFI.)
        e.data_modified     - string    - The modified packet data. (As a string literal.)
        e.data_modified_raw - void*     - The modified packet data. (As a raw pointer, for use with FFI.)
        e.size              - number    - [Read Only] The packet size.
        e.state             - number    - [Read Only] The game state pointer.
        e.injected          - boolean   - [Read Only] Flag that states if the event was injected by daochook or another addon.
        e.blocked           - boolean   - Flag that states if the event has been blocked by daochook or another addon.

    --]]
end);

--[[
* event: packet_send
* desc : Called when the game is sending a packet.
--]]
hook.events.register('packet_send', 'packet_send_cb', function (e)
    --[[

    Event Arguments

        e.opcode            - number    - [Read Only] The packet opcode.
        e.data              - string    - [Read Only] The packet data. (As a string literal.)
        e.data_raw          - void*     - [Read Only] The packet data. (As a raw pointer, for use with FFI.)
        e.data_modified     - string    - The modified packet data. (As a string literal.)
        e.data_modified_raw - void*     - The modified packet data. (As a raw pointer, for use with FFI.)
        e.size              - number    - [Read Only] The packet size.
        e.parameter         - number    - [Read Only] The packet parameter.
        e.injected          - boolean   - [Read Only] Flag that states if the event was injected by daochook or another addon.
        e.blocked           - boolean   - Flag that states if the event has been blocked by daochook or another addon.

    --]]
end);

--[[
* event: d3d_present
* desc : Called when the Direct3D device is presenting a scene.
--]]
hook.events.register('d3d_present', 'd3d_present_cb', function ()
    --[[
    Event has no arguments.
    --]]
    -- Render a custom example window via ImGui..
    imgui.SetNextWindowSize(T{ 350, 200, }, ImGuiCond_FirstUseEver);
	if (imgui.Begin('Lootmaster')) then
		imgui.Text("Set max roll with /lm max <#>");
		imgui.Checkbox('Parse Rolls', window.is_checked);
		imgui.SameLine();
		if (imgui.Button('Reset Rolls')) then
			alphaNames:clear();
		end

		if (window.is_checked[1]) then
			imgui.TextColored(T{ 0.0, 1.0, 0.0, 1.0, }, ('Parsing Rolls - Max: %d'):fmt(window.maxRoll));
			alphaNames:sort(function (a, b)
				return (a.roll > b.roll) or (a.roll == b.roll and a.name < b.name);
			end);

			alphaNames:each(function (v,k)
				imgui.Text(("%3d - %s\n"):fmt( v.roll, v.name));
			end);
		else
			imgui.TextColored(T{ 1.0, 0.0, 0.0, 1.0, }, 'Not Parsing');
		end
	end
    imgui.End();

end);

