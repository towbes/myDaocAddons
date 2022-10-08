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

addon.name    = 'inventory';
addon.author  = 'towbes';
addon.desc    = 'Inventory Manager';
addon.link    = '';
addon.version = '1.0';

require 'common';
require 'daoc';

local imgui = require 'imgui';

-- Window Variables
local window = T{
    is_checked = T{ false, },
    minSlotBuf = { '' },
    minSlotBufSize = 3,
    maxSlotBuf = { '' },
    maxSlotBufSize = 3,
};

local alphaItems = T{ };


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
    if ((args[1]:ieq('inv') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/inv')) then
        -- Mark the command as handled, preventing the game from ever seeing it..
        e.blocked = true;
        if (#args == 1) then return; end

        -- Command: /inv load
        if (args[2]:ieq('load')) then

            local itemTest = daoc.items.get_item(daoc.items.slot_inv_bag1_slot1);
            daoc.chat.msg(daoc.chat.message_mode.help, ('Slot %d Name: %s'):fmt(daoc.items.slot_inv_bag1_slot1, itemTest.name));
            return;
        end

        -- Command: /inv sort
        if (args[2]:ieq('sort')) then

            local itemTest = daoc.items.get_item(daoc.items.slot_inv_bag1_slot1);
            daoc.chat.msg(daoc.chat.message_mode.help, ('Slot %d Name: %s'):fmt(daoc.items.slot_inv_bag1_slot1, itemTest.name));
            return;
        end

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
    if (imgui.TreeNode("All Slots")) then
        --look through all slots
        for i = 0, 249 do
            --Split based on slots, ie equipped gear, inventory, vault, house vault
            local itemTemp = daoc.items.get_item(i);
            imgui.Text(("Slot %d, ItemId - %u, ItemName - %s\n"):fmt(i, itemTemp.id, itemTemp.name));
        end
    end
    if (imgui.TreeNode("Alpha Slots")) then
        --clear the table
        alphaItems:clear();
        --look through all slots
        for i = 0, 249 do
            --Split based on slots, ie equipped gear, inventory, vault, house vault
            local itemTemp = daoc.items.get_item(i);
            if (itemTemp.name ~= '') then
                alphaItems:append(T{slot = i, name = itemTemp.name});
            end
            --imgui.Text(("Slot %d, ItemId - %u, ItemName - %s\n"):fmt(i, itemTemp.id, itemTemp.name));
        end

        alphaItems:sort(function (a, b)
            return (a.name < b.name) or (a.name == b.name and a.slot < b.slot);
        end);

        alphaItems:each(function (v,k)
            imgui.Text(("Slot %d - ItemName - %s\n"):fmt(v.slot, v.name));
        end);
    end
    if (imgui.TreeNode("Inventory Tools")) then
        imgui.Text(("Backpack Start: %d , End: %d"):fmt(daoc.items.slot_inv_min, daoc.items.slot_inv_max));
        imgui.Text("MinSlot:")
        imgui.SameLine();
        imgui.PushItemWidth(35);
        imgui.InputText("##MinSlot", window.minSlotBuf, window.minSlotBufSize);
        imgui.SameLine()
        imgui.Text("MaxSlot:")
        imgui.SameLine();
        imgui.PushItemWidth(35);
        imgui.InputText("##MaxSlot", window.maxSlotBuf, window.maxSlotBufSize);
        if (imgui.Button('Sell')) then
            daoc.chat.msg(daoc.chat.message_mode.help, 'Button was clicked!');
        end
        imgui.SameLine();
        if (imgui.Button('Drop')) then
            daoc.chat.msg(daoc.chat.message_mode.help, 'Button was clicked!');
        end
        imgui.SameLine();
        if (imgui.Button('Destroy')) then
            daoc.chat.msg(daoc.chat.message_mode.help, 'Button was clicked!');
        end
    end
    imgui.End();

end);

