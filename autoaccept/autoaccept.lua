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

addon.name    = 'autoaccept';
addon.author  = 'towbes';
addon.desc    = 'Auto accept party invites';
addon.link    = '';
addon.version = '1.0';

local ffi = require 'ffi';

require 'common';
require 'daoc';

local settings = require 'settings';
local imgui = require 'imgui';

--[[
* Default Settings Blocks
--]]

-- Used with the default alias, 'settings'..
local default_settings = T{
    accept = T{ '', },
    deny = T{ '', },
	showMenu = false,
};

-- Load both settings blocks..
local cfg1 = settings.load(default_settings); -- Uses 'settings' alias by default..

--[[
* event: load
* desc : Called when the addon is being loaded.
--]]
hook.events.register('load', 'load_cb', function ()
    daoc.chat.msg(daoc.chat.message_mode.alliance, ('Autoaccept: toggle menu with /aa menu'));
    cfg1.showMenu = false;
end);

--[[
* Event invoked when a settings table has been changed within the settings library.
*
* Note: This callback only affects the default 'settings' table.
--]]
settings.register('settings', 'settings_update', function (e)
    -- Update the local copy of the 'settings' settings table..
    cfg1 = e;

    -- Ensure settings are saved to disk when changed..
    settings.save();
end);

--[[
* event: packet_recv
* desc : Called when the game is handling a received packet.
--]]
hook.events.register('packet_recv', 'packet_recv_cb', function (e)
    -- OpCode: Message
    if (e.opcode == 0x81) then
		
        -- Cast the raw packet pointer to a byte array via FFI..
        local packet = ffi.cast('uint8_t*', e.data_modified_raw);
		if (packet[1] == 0x02) then
			--dialog string starts at 0x0C or index 12
			--parts = e.data:psplit(' ', 0, true);
			--for k,v in ipairs(parts) do
			--	print(v);
			--end
			if (checkAccept(e.data) == true) then
				e.blocked = true;
				local sendpacket = {0x00};
				daoc.game.send_packet(0x98, sendpacket, 0);
            elseif (checkDeny(e.data) == true) then
                e.blocked = true;
            end
		end
		if (packet[1] == 0x18) then
			--dialog string starts at 0x0C or index 12
			--parts = e.data:psplit(' ', 0, true);
			--for k,v in ipairs(parts) do
			--	print(v);
			--end
			if (checkAccept(e.data) == true) then
				e.blocked = true;
				local sendpacket = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x01};
				daoc.game.send_packet(0x82, sendpacket, 0);
            elseif (checkDeny(e.data) == true) then
                e.blocked = true;
            end
		end
    end
end);

function checkAccept (invite)
    --First check accept list
	local charNames = cfg1.accept[1]:psplit(',');
	for k,v in ipairs(charNames) do
		if not v:empty() and invite:contains(v) then
			return true;
		end
	end
	return false;
end

function checkDeny (invite)
    --First check accept list
	local charNames = cfg1.deny[1]:psplit(',');
	for k,v in ipairs(charNames) do
		if not v:empty() and invite:contains(v) then
			return true;
		end
	end
	return false;
end

--[[
* event: d3d_present
* desc : Called when the Direct3D device is presenting a scene.
--]]
hook.events.register('d3d_present', 'd3d_present_cb', function ()
    imgui.SetNextWindowSize({ 500, 500, });
    if (cfg1.showMenu and imgui.Begin('Autoaccept Addon')) then
        -- Show the current settings library information..
        imgui.Text(('     Name: %s'):fmt(settings.name));
        imgui.Text(('Logged In: %s'):fmt(tostring(settings.logged_in)));
        imgui.NewLine();
        imgui.Separator();

        if (imgui.BeginTabBar('##settings_tabbar', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton)) then
            --[[
            * Tab: 'settings'
            *
            * Demostrates the usage of the default configuration alias 'settings'.
            --]]
            if (imgui.BeginTabItem('AutoAccept', nil)) then
                imgui.TextColored({ 0.0, 0.8, 1.0, 1.0 }, 'Modify the \'autoaccept\' configuration.');
                imgui.TextColored({ 0.0, 0.8, 1.0, 1.0 }, 'Toggle Menu with /aa menu');

                if (imgui.Button('Load', { 55, 20 })) then
                    daoc.chat.msg(daoc.chat.message_mode.help, ('Autoaccept Settings Loaded'));
                    cfg1 = settings.load(default_settings);
                end
                imgui.SameLine();
                if (imgui.Button('Save', { 55, 20 })) then
                    daoc.chat.msg(daoc.chat.message_mode.help, ('Autoaccept Settings Saved'));
                    settings.save();
                end
                imgui.SameLine();
                if (imgui.Button('Reload', { 55, 20 })) then
                    daoc.chat.msg(daoc.chat.message_mode.help, ('Autoaccept Settings Reloaded'));
                    settings.reload();
                end
                imgui.SameLine();
                if (imgui.Button('Reset', { 55, 20 })) then
                    daoc.chat.msg(daoc.chat.message_mode.help, ('Autoaccept Settings Reset'));
                    settings.reset();
                end
				imgui.Text('Comma separated, no space (eg: Char1,Char2,Char3');
				imgui.InputText('Accept List', cfg1.accept, 255);
				imgui.InputText('Deny List', cfg1.deny, 255);
                imgui.EndTabItem();
            end

            imgui.EndTabBar();
        end
    end
    imgui.End();
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
        daoc.chat.msg(mode, 'Invalid command syntax for autoaccept addon');
    else
        daoc.chat.msg(mode, 'Available commands for the autoaccept addon are:');
    end

    local help = daoc.chat.msg:compose(function (cmd, desc)
        return mode, ('  %s - %s'):fmt(cmd, desc);
    end);

    help('/aa menu', 'Toggles the gui menu');
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



    -- Command: /aa
    if ((args[1]:ieq('aa') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/aa')) then
        -- Mark the command as handled, preventing the game from ever seeing it..
        e.blocked = true;
        if (#args == 1) then return; end

        -- Command: /aa menu
        if (args[2]:ieq('menu')) then
			if (cfg1.showMenu) then
				cfg1.showMenu = false;
			else
				cfg1.showMenu = true;
            end
           	return;
        end

		-- Unknown sub-command..
		print_help(true);
        return;
    end

end);