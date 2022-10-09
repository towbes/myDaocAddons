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
local ffi = require 'ffi';


--[[
* Entity Related Function Definitions
--]]
ffi.cdef[[
    typedef void        (__cdecl *sell_item_f)(const uint32_t slotNum);
    typedef void        (__cdecl *move_item_f)(const uint32_t toSlot, const uint32_t fromSlot, const uint32_t count);
]];

--[[
* Sells the item
--]]
daoc.items.sell_item = function (slotNum)
    --Address of signature = game.dll + 0x0002B2E3
    local ptr = hook.pointers.add('daoc.items.sellitem', 'game.dll', '558BEC83EC??833D00829900??75??568B35????????D906E8????????D946??8945??E8????????8945??6A??58E8????????6689????668B????8D75??6689????E8????????6A??6A??8BC66A', 0,0);
    if (ptr == 0) then return; end
    ffi.cast('sell_item_f', ptr)(slotNum);
end

--[[
* Moves the item
--]]
daoc.items.move_item = function (toSlot, fromSlot, count)
    --Address of signature = game.dll + 0x0002A976
    local ptr = hook.pointers.add('daoc.items.moveitem', 'game.dll', '558BEC5151833D00829900??75??566A??58E8????????6689????668B????6689', 0,0);
    if (ptr == 0) then 
        error("Failed to load move_item")
        return; 
    end
    ffi.cast('move_item_f', ptr)(toSlot, fromSlot, count);
end

-- Window Variables
local window = T{
    is_checked = T{ false, },
    minSlotBuf = { '40' },
    minSlotBufSize = 3,
    maxSlotBuf = { '79' },
    maxSlotBufSize = 3,
    findItemNameBuf = {''},
    findItemNameBufSize = 100,
    
};

local alphaItems = T{ };
local findItems = T{ };




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
    if (imgui.Begin('Inventory Helper')) then
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
            --set min and max slots
            imgui.Text("MinSlot:")
            imgui.SameLine();
            imgui.PushItemWidth(35);
            imgui.InputText("##MinSlot", window.minSlotBuf, window.minSlotBufSize);
            imgui.SameLine()
            imgui.Text("MaxSlot:")
            imgui.SameLine();
            imgui.PushItemWidth(35);
            imgui.InputText("##MaxSlot", window.maxSlotBuf, window.maxSlotBufSize);
            --look through min->max slots
            local minSlot = tonumber(window.minSlotBuf[1]);
            local maxSlot = tonumber(window.maxSlotBuf[1]);
            if minSlot == nil or maxSlot == nil then return; end
            for i = minSlot, maxSlot do
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
                imgui.Text(("Slot %d - %s\n"):fmt(v.slot, v.name));
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
                local minSlot = tonumber(window.minSlotBuf[1]);
                local maxSlot = tonumber(window.maxSlotBuf[1]);
                for i = minSlot, maxSlot do
                    daoc.items.sell_item(i);
                end
            end
            imgui.SameLine();
            if (imgui.Button('Drop')) then
                --toSlot to drop something is slot 0
                local minSlot = tonumber(window.minSlotBuf[1]);
                local maxSlot = tonumber(window.maxSlotBuf[1]);
                for i = minSlot, maxSlot do
                    daoc.items.move_item(0, i, 0);
                end
            end
            imgui.SameLine();
            if (imgui.Button('Destroy')) then
                daoc.chat.msg(daoc.chat.message_mode.help, 'Button was clicked!');
            end
        end
        if (imgui.TreeNode("Find")) then
            --clear the table
            findItems:clear();
            --set min and max slots
            imgui.Text("Item name:")
            imgui.SameLine();
            imgui.PushItemWidth(350);
            imgui.InputText("##FindName", window.findItemNameBuf, window.findItemNameBufSize);
            --look through min->max slots
            for i = 0, 249 do
                --Split based on slots, ie equipped gear, inventory, vault, house vault
                local itemTemp = daoc.items.get_item(i);
                if (itemTemp.name ~= '') then
                    findItems:append(T{slot = i, name = itemTemp.name});
                end
                --imgui.Text(("Slot %d, ItemId - %u, ItemName - %s\n"):fmt(i, itemTemp.id, itemTemp.name));
            end
            
            findItems:each(function (v,k)
                if (v.name:lower():contains(window.findItemNameBuf[1]:lower())) then
                    imgui.Text(("Slot %d - %s\n"):fmt(v.slot, v.name));
                end
            end);
        end
    end
    imgui.End();

end);

