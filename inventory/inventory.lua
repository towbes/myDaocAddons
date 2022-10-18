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
* Inventory Related Function Definitions
--]]
ffi.cdef[[
    typedef void        (__cdecl *sell_item_f)(const uint32_t slotNum);
    typedef void        (__cdecl *move_item_f)(const uint32_t toSlot, const uint32_t fromSlot, const uint32_t count);
    typedef void        (__cdecl *use_slot_f)(const uint32_t slotNum, const uint32_t useType);
]];

--Pointer variables
local sellPtr = 0;
local movePtr = 0;

--flags
local TaskList = T { }; --stores tasks to be completed in separate present callback
local processingTask = false;


--[[
* Sells the item
--]]
daoc.items.sell_item = function (slotNum)
    ffi.cast('sell_item_f', hook.pointers.get('daoc.items.sellitem'))(slotNum);
end

--[[
* Moves the item
--]]
daoc.items.move_item = function (toSlot, fromSlot, count)
    ffi.cast('move_item_f', hook.pointers.get('daoc.items.moveitem'))(toSlot, fromSlot, count);
end

--[[
* Uses the slot
--]]
daoc.items.use_slot = function (slotNum, useType)
    ffi.cast('use_slot_f', hook.pointers.get('daoc.items.useslot'))(slotNum, useType);
end

-- inventory Variables
local inventory = T{
    find_is_checked = T{ false, },
    minSlotBuf = { '40' },
    minSlotBufSize = 4,
    maxSlotBuf = { '79' },
    maxSlotBufSize = 4,
    findItemNameBuf = {''},
    findItemNameBufSize = 100,
    sortDelay = 0.25,
    
};

--Items tables for sort / find
local alphaItems = T{ };
local findItems = T{ };
local sortItems = T{ };
local sortedIndex = T{ };

--Combo box for sort type
local sortType = T{0};

--Utility and required level(bonus level) logging variables for Eden
local utilTable = T { };
local bonusTable = T { };
local utilTasks = T { };    
local utilCurSlot = 0; --stores current slot so packet knows where to log the utility
local utilCheck = T { false, }; --gui checkbox
local procUtilTask = false;
local logUtil = true;

--do a check every 1000ms
local tick_holder = hook.time.tick();
local tick_interval = 500;

--[[
* event: load
* desc : Called when the addon is being loaded.
--]]
hook.events.register('load', 'load_cb', function ()
    --Sell item pointer
    --Address of signature = game.dll + 0x0002B2E3
    local ptr = hook.pointers.add('daoc.items.sellitem', 'game.dll', '558BEC83EC??833D00829900??75??568B35????????D906E8????????D946??8945??E8????????8945??6A??58E8????????6689????668B????8D75??6689????E8????????6A??6A??8BC66A', 0,0);
    if (ptr == 0) then
        error('Failed to locate sell item function pointer.');
    end

    --Move item pointer
    --Address of signature = game.dll + 0x0002A976
    ptr = hook.pointers.add('daoc.items.moveitem', 'game.dll', '558BEC5151833D00829900??75??566A??58E8????????6689????668B????6689', 0,0);
    if (ptr == 0) then
        error('Failed to locate move item function pointer.');
    end

    --Use Slot
    --Address of signature = game.dll + 0x0002B6F5
    ptr = hook.pointers.add('daoc.items.useslot', 'game.dll', '558BEC83EC??833D00829900??0F85????????D905????????576A??33C0598D7D??F3??8B0D????????5FD941??DAE9DFE0F6C4??7B??804DFB??5333DB3859??5674??D905????????D941??DAE9DFE0F6C4??7B??804DFB??A1????????????????53E8????????84C05974??A1????????????????3BC375??804DFB??A1????????????????53E8????????84C05974??804DFB??D905????????D905????????DAE9DFE0F6C4??7B??E8????????84C074??804DFB??A1????????????????53E8????????84C05974??804DFB??A1????????????????6689????8B08894D??8B48??894D??8B48??8B40??8945??8A45??8845??8A45??8D75??894D??8845??E8????????536A??8BC66A??50E8????????83C4??5E5BC9C3558BEC51', 0,0);
    if (ptr == 0) then
        error('Failed to locate use slot function pointer.');
    end

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
        daoc.chat.msg(mode, 'Invalid command syntax for inventory addon');
    else
        daoc.chat.msg(mode, 'Available commands for the inventory addon are:');
    end

    local help = daoc.chat.msg:compose(function (cmd, desc)
        return mode, ('  %s - %s'):fmt(cmd, desc);
    end);

    help('/sell <minSlot> <maxSlot>', 'Sell items between slots (must be between 40 and 79)');
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

    -- Command: /inv
    if ((args[1]:ieq('inventory') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/inventory')) then
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
		-- Unknown sub-command..
		print_help(true);
        return;
    end

    -- Command: /sell <minSlot> <maxSlot>
    if ((args[1]:ieq('sell') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/sell')) then
        -- Mark the command as handled, preventing the game from ever seeing it..
        e.blocked = true;
        if (#args < 3) then return; end

        local minSlot = tonumber(args[2]);
        local maxSlot = tonumber(args[3]);

        if minSlot < 40 or minSlot > 79 then return; end
        if maxSlot < 40 or maxSlot > 79 then return; end

        for i = minSlot, maxSlot do
            daoc.items.sell_item(i);
        end

		-- Unknown sub-command..
		print_help(true);
        return;
    end

end);

--[[
* event: packet_recv
* desc : Called when the game is handling a received packet.
--]]
hook.events.register('packet_recv', 'packet_recv_cb', function (e)
    if (e.opcode == 0xC4) then
        -- Cast the raw packet pointer to a byte array via FFI..
        local packet = ffi.cast('uint8_t*', e.data_modified_raw);
        --Find the string 'Total Utility:' and get right most index
        local utilStart = e.data:rfind('Total Utility: ', 0, e.data:len());
        if utilStart ~= nil then
            local strLen = packet[utilStart - 2];
            utilStart = e.data:sub(utilStart, utilStart + strLen - 1);
            local utilSplit = utilStart:psplit('Utility: ', 0, false);
            --Check for required level
            
            local lvlStart = e.data:rfind('Required player', 0, e.data:len());
            local reqlvl = 0;
            local lvlSplit = '';
            if lvlStart ~= nil then
                local lvlStrLen = packet[lvlStart - 2];
                
                lvlStart = e.data:sub(lvlStart, lvlStart + lvlStrLen - 1);
                lvlSplit = lvlStart:psplit('level: ', 0, false);
                reqlvl = tonumber(lvlSplit[2]);
            end
            daoc.chat.msg(daoc.chat.message_mode.help, ('ItemUtil: %.03f, ReqLvl: %d'):fmt(tonumber(utilSplit[2]), reqlvl));
            if utilCheck[1] then
                utilTable[utilCurSlot] = tonumber(utilSplit[2]);
                bonusTable[utilCurSlot] = reqlvl;
                e.blocked = true;
            end
        else
            if utilCheck[1] then
                utilTable[utilCurSlot] = 0;
                bonusTable[utilCurSlot] = 0;
                e.blocked = true;
            end
            daoc.chat.msg(daoc.chat.message_mode.help, ('Pattern not found'));
        end
    end
end);

--[[
* event: d3d_present_2 for sort
* desc : Called when the Direct3D device is presenting a scene.
--]]
hook.events.register('d3d_present', 'd3d_present_2', function ()
    --[[
    Event has no arguments.
    --]]
    if (TaskList:length() > 0 and processingTask == false) then
        processingTask = true;
        --daoc.chat.msg(daoc.chat.message_mode.help, ('Task: %s, size %d'):fmt(TaskList[1].name, TaskList:length()));
        if (TaskList[1].name:ieq('Sort')) then
            Sort(TaskList[1].minSlot, TaskList[1].maxSlot);
        end
        table.remove(TaskList, 1);
        --daoc.chat.msg(daoc.chat.message_mode.help, ('Tasklist size: %d'):fmt(TaskList:length()));
        processingTask = false;
    end

    if (hook.time.tick() >= (tick_holder + tick_interval) ) then	
		
		tick_holder = hook.time.tick();
        if (utilTasks:length() > 0 and procUtilTask == false) then
            procUtilTask = true;
            
            GetUtil(utilTasks[1].slot);
            table.remove(utilTasks, 1);
            --daoc.chat.msg(daoc.chat.message_mode.help, ('Tasklist size: %d'):fmt(TaskList:length()));
            procUtilTask = false;
        end
    end



end);
--[[
* event: d3d_present_1 for imgui
* desc : Called when the Direct3D device is presenting a scene.
--]]
hook.events.register('d3d_present', 'd3d_present_1', function ()
    --[[
    Event has no arguments.
    --]]
    -- Render a custom example inventory via ImGui..
    imgui.SetNextWindowSize(T{ 350, 200, }, ImGuiCond_FirstUseEver);
    if (imgui.Begin('Inventory Helper')) then
        if (imgui.TreeNode("All Slots")) then
            --look through all slots
            for i = 0, 249 do
                --Split based on slots, ie equipped gear, inventory, vault, house vault
                local itemTemp = daoc.items.get_item(i);
                imgui.Text(("Slot %d, ItemId - %u, ItemName - %s\n"):fmt(i, itemTemp.id, itemTemp.name));
            end
            imgui.TreePop()
        end
        if (imgui.TreeNode("Sorted Slots")) then
            --clear the table
            alphaItems:clear();
            --set min and max slots
            imgui.Text("MinSlot:")
            imgui.SameLine();
            imgui.PushItemWidth(35);
            imgui.InputText("##MinSlot", inventory.minSlotBuf, inventory.minSlotBufSize);
            imgui.SameLine()
            imgui.Text("MaxSlot:")
            imgui.SameLine();
            imgui.PushItemWidth(35);
            imgui.InputText("##MaxSlot", inventory.maxSlotBuf, inventory.maxSlotBufSize);
            --look through min->max slots
            local minSlot = tonumber(inventory.minSlotBuf[1]);
            local maxSlot = tonumber(inventory.maxSlotBuf[1]);
            if minSlot == nil or maxSlot == nil then return; end
            for i = minSlot, maxSlot do
                --Split based on slots, ie equipped gear, inventory, vault, house vault
                local itemTemp = daoc.items.get_item(i);
                if (not itemTemp.name:empty()) then
                    alphaItems:append(T{slot = i, name = itemTemp.name, quality = itemTemp.quality, bonus_level = itemTemp.bonus_level});
                end
                --imgui.Text(("Slot %d, ItemId - %u, ItemName - %s\n"):fmt(i, itemTemp.id, itemTemp.name));
            end

            --select the sort type
            imgui.SameLine();
            imgui.PushItemWidth(100);
            --imgui.Combo('sortType', 0, 'sortType');
            local overlay_pos = { sortType[1] };
            if (imgui.Combo('##sortType', overlay_pos, 'Alpha\0Quality\0Bonus Level\0\0')) then
                sortType[1] = overlay_pos[1];
            end
            
            --sort items based on type
            --Alpha
            if sortType[1] == 0 then
                alphaItems:sort(function (a, b)
                    return (a.name:lower() < b.name:lower()) or (a.name:lower() == b.name:lower() and a.slot < b.slot);
                end);
            --quality
            elseif sortType[1] == 1 then
                alphaItems:sort(function (a, b)
                    return (a.quality > b.quality) or (a.quality == b.quality and a.bonus_level > b.bonus_level) or (a.quality == b.quality and a.bonus_level == b.bonus_level and a.name:lower() < b.name:lower()) or (a.quality == b.quality and a.bonus_level == b.bonus_level and a.name:lower() == b.name:lower() and a.slot < b.slot);
                end);
            --bonus level
            elseif sortType[1] == 2 then
                alphaItems:sort(function (a, b)
                    return (a.bonus_level > b.bonus_level) or  (a.bonus_level == b.bonus_level and a.quality > b.quality) or (a.bonus_level == b.bonus_level and a.quality == b.quality and a.name:lower() < b.name:lower()) or (a.bonus_level == b.bonus_level and a.quality == b.quality and a.name:lower() == b.name:lower() and a.slot < b.slot);
                end);              
            --something went wrong
            else
                return;
            end

            alphaItems:each(function (v,k)
                imgui.Text(("Slot %d - %s, Qua: %d, Blvl: %d\n"):fmt(v.slot, v.name, v.quality, v.bonus_level));
            end);
            imgui.TreePop()
        end
        if (imgui.TreeNode("Inventory Tools")) then
            imgui.Text(("Backpack Start: %d , End: %d"):fmt(daoc.items.slots.vault_min, daoc.items.slots.vault_max));
            imgui.Text("MinSlot:")
            imgui.SameLine();
            imgui.PushItemWidth(35);
            imgui.InputText("##MinSlot", inventory.minSlotBuf, inventory.minSlotBufSize);
            imgui.SameLine()
            imgui.Text("MaxSlot:")
            imgui.SameLine();
            imgui.PushItemWidth(35);
            imgui.InputText("##MaxSlot", inventory.maxSlotBuf, inventory.maxSlotBufSize);
            local minSlot = tonumber(inventory.minSlotBuf[1]);
            local maxSlot = tonumber(inventory.maxSlotBuf[1]);
            if minSlot == nil then minSlot = 40; end;
            if maxSlot == nil then maxSlot = 79; end;
            if (imgui.Button('Sell')) then
                for i = minSlot, maxSlot do
                    local item = daoc.items.get_item(i)
                    if (item ~= nil and item.name:len() > 0) then
                        daoc.items.sell_item(i);
                    end
                end
            end
            imgui.SameLine();
            if (imgui.Button('Drop')) then
                for i = minSlot, maxSlot do
                    local item = daoc.items.get_item(i)
                    if (item ~= nil and item.name:len() > 0) then
                        daoc.items.move_item(0, i, 0);
                    end
                end
            end
            imgui.SameLine();
            if (imgui.Button('Destroy')) then
                daoc.chat.msg(daoc.chat.message_mode.help, 'Button was clicked!');
            end
            if (imgui.Button('Use Min Slot')) then
                local item = daoc.items.get_item(inventory.minSlotBuf[1])
                if (item ~= nil and item.name:len() > 0) then
                    daoc.items.use_slot(tonumber(inventory.minSlotBuf[1]), 1);
                end
            end
            
            for i = minSlot, maxSlot do
                --Split based on slots, ie equipped gear, inventory, vault, house vault
                local itemTemp = daoc.items.get_item(i);
                imgui.Text(("Slot %d, ItemId - %u, ItemName - %s\n"):fmt(i, itemTemp.id, itemTemp.name));
            end
            imgui.TreePop()
        end
        if (imgui.TreeNode("Find")) then
            --clear the table
            findItems:clear();
            --set min and max slots
            imgui.Text("Item name:")
            imgui.SameLine();
            imgui.PushItemWidth(350);
            imgui.InputText("##FindName", inventory.findItemNameBuf, inventory.findItemNameBufSize);
            --set min and max slots
            imgui.Text("MinSlot:")
            imgui.SameLine();
            imgui.PushItemWidth(35);
            imgui.InputText("##MinSlot", inventory.minSlotBuf, inventory.minSlotBufSize);
            imgui.SameLine()
            imgui.Text("MaxSlot:")
            imgui.SameLine();
            imgui.PushItemWidth(35);
            imgui.InputText("##MaxSlot", inventory.maxSlotBuf, inventory.maxSlotBufSize);
            imgui.SameLine();
            imgui.Checkbox('Alpha Order', inventory.find_is_checked);
            --look through min->max slots
            local minSlot = tonumber(inventory.minSlotBuf[1]);
            local maxSlot = tonumber(inventory.maxSlotBuf[1]);
            if minSlot == nil or maxSlot == nil then return; end
            for i = minSlot, maxSlot do
                --Split based on slots, ie equipped gear, inventory, vault, house vault
                local itemTemp = daoc.items.get_item(i);
                if (not itemTemp.name:empty()) then
                    findItems:append(T{slot = i, name = itemTemp.name});
                end
                --imgui.Text(("Slot %d, ItemId - %u, ItemName - %s\n"):fmt(i, itemTemp.id, itemTemp.name));
            end
            
            if (inventory.find_is_checked) then
                findItems:sort(function (a, b)
                    return (a.name:lower() < b.name:lower()) or (a.name:lower() == b.name:lower() and a.slot < b.slot);
                end);
            end

            findItems:each(function (v,k)
                if (v.name:lower():contains(inventory.findItemNameBuf[1]:lower())) then
                    imgui.Text(("Slot %d - %s\n"):fmt(v.slot, v.name));
                end
            end);
            imgui.TreePop()
        end
        if (imgui.TreeNode("Sort")) then
            imgui.Text(("Vault Start: %d , End: %d"):fmt(daoc.items.slots.vault_min, daoc.items.slots.vault_max));
            imgui.Text(("HouseVault Start: %d , End: %d"):fmt(daoc.items.slots.player_merchant_min, daoc.items.slots.player_merchant_max));
            --clear the table
            sortItems:clear();
            --set min and max slots
            imgui.Text("MinSlot:")
            imgui.SameLine();
            imgui.PushItemWidth(35);
            imgui.InputText("##MinSlot", inventory.minSlotBuf, inventory.minSlotBufSize);
            imgui.SameLine()
            imgui.Text("MaxSlot:")
            imgui.SameLine();
            imgui.PushItemWidth(35);
            imgui.InputText("##MaxSlot", inventory.maxSlotBuf, inventory.maxSlotBufSize);

            --look through min->max slots
            local minSlot = tonumber(inventory.minSlotBuf[1]);
            local maxSlot = tonumber(inventory.maxSlotBuf[1]);
            if minSlot == nil or maxSlot == nil then return; end
            if (minSlot < 0) then minSlot = 0 end;
            if (maxSlot > 250) then maxSlot = 250 end;

            for i = minSlot, maxSlot do
                --Split based on slots, ie equipped gear, inventory, vault, house vault
                local itemTemp = daoc.items.get_item(i);
                if (not itemTemp.name:empty()) then
                    sortItems:append(T{slot = i, name = itemTemp.name, quality = itemTemp.quality, bonus_level = bonusTable[i] or itemTemp.bonus_level, utility = utilTable[i] or 0});
                    --if utilCheck[1] and utilTable[i] == nil then
                    --    utilTasks:append(T{slot = i})
                    --end
                end
                --imgui.Text(("Slot %d, ItemId - %u, ItemName - %s\n"):fmt(i, itemTemp.id, itemTemp.name));
            end

            --select the sort type
            imgui.SameLine();
            imgui.PushItemWidth(100);
            --imgui.Combo('sortType', 0, 'sortType');
            local overlay_pos = { sortType[1] };
            if (imgui.Combo('##sortType', overlay_pos, 'Alpha\0Quality\0Bonus Level\0Utility\0')) then
                sortType[1] = overlay_pos[1];
            end
            
            --sort items based on type
            --Alpha
            if sortType[1] == 0 then
                sortItems:sort(function (a, b)
                    return (a.name:lower() < b.name:lower()) or (a.name:lower() == b.name:lower() and a.slot < b.slot);
                end);
            --quality
            elseif sortType[1] == 1 then
                sortItems:sort(function (a, b)
                    return (a.quality > b.quality) or (a.quality == b.quality and a.bonus_level > b.bonus_level) or (a.quality == b.quality and a.bonus_level == b.bonus_level and a.name:lower() < b.name:lower()) or (a.quality == b.quality and a.bonus_level == b.bonus_level and a.name:lower() == b.name:lower() and a.slot < b.slot);
                end);
            --bonus level
            elseif sortType[1] == 2 then
                sortItems:sort(function (a, b)
                    return (a.bonus_level > b.bonus_level) or  (a.bonus_level == b.bonus_level and a.quality > b.quality) or (a.bonus_level == b.bonus_level and a.quality == b.quality and a.name:lower() < b.name:lower()) or (a.bonus_level == b.bonus_level and a.quality == b.quality and a.name:lower() == b.name:lower() and a.slot < b.slot);
                end);
            --utility
            elseif sortType[1] == 3 then
                sortItems:sort(function (a, b)
                    return (a.utility > b.utility) or (a.utility == b.utility and a.quality > b.quality) or (a.utility == b.utility and a.quality == b.quality and a.name:lower() < b.name:lower()) or (a.utility == b.utility and a.quality == b.quality and a.name:lower() == b.name:lower() and a.slot < b.slot);
                end);
            --something went wrong
            else
                return;
            end
            imgui.SameLine();
            --use slots 48 and 49 for sorting
            if (imgui.Button('Sort')) then
                sortedIndex:clear();
                sortItems:each(function (v,k)
                    if (not v.name:empty()) then
                        sortedIndex:append(v.slot);
                        --daoc.chat.msg(daoc.chat.message_mode.help, ('Slot %d - %s'):fmt(v.slot, v.name));
                    end
                end);           
                local tempSort = T {name = 'Sort', minSlot = minSlot, maxSlot = maxSlot};   
                TaskList:append(tempSort);
                --daoc.chat.msg(daoc.chat.message_mode.help, ('Task added %s'):fmt(TaskList[1].name));
            end
            imgui.SameLine();
            imgui.Checkbox('Log Util', utilCheck);
            imgui.SameLine();
            if (imgui.Button('Get Util')) then
                for i = minSlot, maxSlot do
                    --Split based on slots, ie equipped gear, inventory, vault, house vault
                    local itemTemp = daoc.items.get_item(i);
                    if (not itemTemp.name:empty()) then
                        if utilCheck[1] and utilTable[i] == nil then
                            utilTasks:append(T{slot = i})
                        end
                    end
                    --imgui.Text(("Slot %d, ItemId - %u, ItemName - %s\n"):fmt(i, itemTemp.id, itemTemp.name));
                end
            end
            if (imgui.BeginTable('##find_items_list2', 5, bit.bor(ImGuiTableFlags_RowBg, ImGuiTableFlags_BordersH, ImGuiTableFlags_BordersV, ImGuiTableFlags_ContextMenuInBody, ImGuiTableFlags_ScrollX, ImGuiTableFlags_ScrollY, ImGuiTableFlags_SizingFixedFit))) then
                imgui.TableSetupColumn('Slot', ImGuiTableColumnFlags_WidthFixed, 35.0, 0);
                imgui.TableSetupColumn('Qual', ImGuiTableColumnFlags_WidthFixed, 55.0, 0);
                imgui.TableSetupColumn('BLvl', ImGuiTableColumnFlags_WidthFixed, 55.0, 0);
                imgui.TableSetupColumn('Util', ImGuiTableColumnFlags_WidthFixed, 55.0, 0);
                imgui.TableSetupColumn('Name', ImGuiTableColumnFlags_WidthStretch, 0, 0);
                imgui.TableSetupScrollFreeze(0, 1);
                imgui.TableHeadersRow();
                for x=1, sortItems:len() do
                    imgui.PushID(x);
                    imgui.TableNextRow();
                    imgui.TableSetColumnIndex(0);
                    imgui.Text(('%d'):fmt(sortItems[x].slot));
                    imgui.TableNextColumn();
                    imgui.Text(tostring(sortItems[x].quality));
                    imgui.TableNextColumn();
                    imgui.Text(tostring(sortItems[x].bonus_level));
                    imgui.TableNextColumn();
                    imgui.Text(tostring(sortItems[x].utility));
                    imgui.TableNextColumn();
                    imgui.Text(tostring(sortItems[x].name):gsub('%%', '%%%%'));
                    imgui.PopID();
                end
                imgui.EndTable();
            end
            --sortItems:each(function (v,k)
            --    if (not v.name:empty()) then
            --        local util = 0;
            --        if utilTable:containskey(v.slot) then 
            --            util = utilTable[v.slot];
            --        end
            --        imgui.Text(("Slot %d - %s, Qua: %d, Blvl: %d, Util: %.02f\n"):fmt(v.slot, v.name, v.quality, v.bonus_level, util));
            --    end
            --end);
            imgui.TreePop()
        end

    end
    imgui.End();

end);   

--[[
* function: Sort
* desc : Sort items in the game
--]]
function Sort(minSlot, maxSlot)
    daoc.chat.msg(daoc.chat.message_mode.help, 'Starting sort');
    --Return if arguments weren't passed properly
    if minSlot == nil or maxSlot == nil then return; end

    --if the first slotNum of alpha items does not equal the min Slot Num, move items
    for i=1, sortItems:length() do
        --if (sortItems[i].slot ~= i + (minSlot - 1)) then
            --clear out the util table entry if it exists
            --if utilTable:containskey(i + (minSlot - 1)) then
            --    utilTable[i + (minSlot - 1)] = nil;
            --end
            --if utilTable:containskey(sortItems[i].slot) then
            --    utilTable[sortItems[i].slot] = nil;
            --end
            daoc.items.move_item(i + (minSlot - 1), sortItems[i].slot, 0);
            --sleep to prevent spam
            coroutine.sleep(inventory.sortDelay);
        --end
    end
    utilTable:clear();
    bonusTable:clear();
    daoc.chat.msg(daoc.chat.message_mode.help, 'Sorting finished!');
end

function next_empty_slot(minSlot, maxSlot)
    for i = minSlot, maxSlot do
        --Split based on slots, ie equipped gear, inventory, vault, house vault
        local itemTemp = daoc.items.get_item(i);
        if (itemTemp.name:empty()) then
            return i;
        end
    end
    return nil;
end

--[[
* function: GetUtil
* desc : Get total utility value on an item for Eden
--]]
function GetUtil(slot)
    --Set curslot so when we receive packet it sets the right
    utilCurSlot = slot;
    --packet opcode 0xD8
    --00 01 19 00 00 00 00 [slot] 00 00 00 00
    local sendpacket = {0x00, 0x01, 0x19, 0x00, 0x00, 0x00, 0x00, slot, 0x00, 0x00, 0x00, 0x00};
    daoc.game.send_packet(0xD8, sendpacket, 0);
    
end