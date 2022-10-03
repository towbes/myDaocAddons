--[[
* Addons - Copyright (c) 2021 Ashita Development Team
* Contact: https://www.ashitaxi.com/
* Contact: https://discord.gg/Ashita
*
* This file is part of Ashita.
*
* Ashita is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Ashita is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with Ashita.  If not, see <https://www.gnu.org/licenses/>.
--]]

addon.name      = 'timestamp';
addon.author    = 'atom0s - daochook port by towbes';
addon.version   = '1.0';
addon.desc      = 'Adds a timestamp to chat messages.';
addon.link      = 'https://atom0s.com';

require('common');
require('daoc');

-- Default Settings
local default_settings = T{
    format = '[%H:%M:%S]';
};

-- Timestamp Variables
local timestamp = T{
--    settings = settings.load(default_settings),
    settings = default_settings;
};

--[[
* Registers a callback for the settings to monitor for character switches.
--]]
--settings.register('settings', 'settings_update', function (s)
--    if (s ~= nil) then
--        timestamp.settings = s;
--    end
--
--    settings.save();
--end);

--[[
* event: message
* desc : Called when the game is handling a message.
--]]
hook.events.register('message', 'message_cb', function (e)

    -- Prepare needed variables..
    local fmt = timestamp.settings.format;

    local msg = e.message
    e.modified_message = os.date(fmt, os.time()) .. ' ' .. e.modified_message:replace('@@', '');
end);