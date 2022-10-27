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

addon.name    = 'scparser';
addon.author  = 'towbes';
addon.desc    = 'Parse and craft spellcraft template text files';
addon.link    = '';
addon.version = '1.0';

require 'common';
require 'daoc';

local imgui     = require 'imgui';
local settings  = require 'settings';
local json = require('json');
local ffi = require('ffi');
--[[
* Inventory Related Function Definitions
--]]
ffi.cdef[[
    typedef void        (__cdecl *sell_item_f)(const uint32_t slotNum);
    typedef void        (__cdecl *move_item_f)(const uint32_t toSlot, const uint32_t fromSlot, const uint32_t count);
    typedef void        (__cdecl *use_slot_f)(const uint32_t slotNum, const uint32_t useType);
	typedef void        (__cdecl *buy_item_f)(const uint32_t slotNum);
	typedef void		(__cdecl *interact_f)(const uint32_t objId);

	//Credit to atom0s for reversing this structure
	typedef struct {
		uint32_t    model;
		uint32_t    unknown; // Set to 0 when read from packet.
		uint32_t    cost;
		uint32_t    level;
		uint32_t    value1;
		uint32_t    spd_abs;
		uint32_t    dpsaf_or_hand;
		uint32_t    damage_and_type;
		uint32_t    value2;
		uint32_t    can_use_flag;
		char        name_[64];
	} merchantitem_t;

	typedef struct {
        merchantitem_t      items[150];         // The array of items
    } merchantlist_t;
	
    typedef struct {
        char        name_[64];          // The craft name.
		uint32_t	level_mod;			// actual level = level_mod * 0x100 + level
		uint32_t    level;              // The craft level. [ie. Unique id if used.]
		uint32_t	index;				//index in TDL?
		char		unknown1[24];
		uint32_t	unknownIndex;
		char		unknown[64];		// unknown for now
	} craft_t;

	typedef struct {
        craft_t      crafts[15];         // The array of crafts.
    } craftlevels_t;
]];

--[[
* Helpers for merchantitem_t
--]]
ffi.metatype('merchantitem_t', T{
    __index = function (self, k)
        return switch(k, {
            ['name']            = function () return ffi.string(self.name_); end,
            [switch.default]    = function () return nil; end
        });
    end,
    __newindex = function (self, k, v)
        error('read-only type');
    end,
    __tostring = function (self)
        return ffi.string(self.name_);
    end,
});

--[[
* Returns a craft by its array slot.
--]]
daoc.items.get_merchantitem = function (slotId)
    if (slotId < 0 or slotId > 149) then
        return nil;
    end

    local ptr = hook.pointers.get('game.ptr.merchant_list');
    if (ptr == 0) then return nil; end
	ptr = hook.memory.read_uint32(ptr);
    if (ptr == 0) then return nil; end

    return ffi.cast('merchantitem_t*', ptr + (slotId * ffi.sizeof('merchantitem_t')));
end

--[[
* Returns slot id for an item by name
--]]
daoc.items.get_merchant_slot = function (itemName)
	if (itemName == nil or itemName == '') then
		return nil;
	end
	for i=0, 150 do
		local item = daoc.items.get_merchantitem(i);
		if (item ~= nil) then
			if (item.name:contains(itemName)) then
				return i;
			end
		end
	end
	return nil;
end

--[[
* Helpers for craft_t
--]]
ffi.metatype('craft_t', T{
    __index = function (self, k)
        return switch(k, {
            ['name']            = function () return ffi.string(self.name_); end,
            [switch.default]    = function () return nil; end
        });
    end,
    __newindex = function (self, k, v)
        error('read-only type');
    end,
    __tostring = function (self)
        return ffi.string(self.name_);
    end,
});

--[[
* Returns a craft by its array slot.
--]]
daoc.items.get_craft = function (slotId)
    if (slotId < 0 or slotId > 13) then
        return nil;
    end

    local ptr = hook.pointers.get('game.ptr.craft_levels');
    if (ptr == 0) then return nil; end
	ptr = hook.memory.read_uint32(ptr);
    if (ptr == 0) then return nil; end

    return ffi.cast('craft_t*', ptr + (slotId * ffi.sizeof('craft_t')));
end

--[[
* Returns current level of a craft searching by string name
--]]
daoc.items.get_craft_level = function (craftName)
	if (craftName == nil or craftName == '') then
		return nil;
	end
	for i=0, 15 do
		local craft = daoc.items.get_craft(i);
		if (craft ~= nil) then
			if (craft.name:contains(craftName)) then
				return craft.level_mod * 0x100 + craft.level;
			end
		end

	end
	return nil;
end


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

--[[
* Buys item from merchant
--]]
daoc.items.buy_item = function (slotNum)
    ffi.cast('buy_item_f', hook.pointers.get('daoc.items.buyitem'))(slotNum);
end

--[[
* Interact with an object
--]]
daoc.items.interact = function (objId)
    ffi.cast('interact_f', hook.pointers.get('daoc.items.interact'))(objId);
end

--[[
* Default Settings Blocks
--]]

-- Used with the default alias, 'settings'..
local default_settings = T{
    gem_list_str = T{ 'Hello world.', },
    craft_list = T { },
    realm_id = T { },
};

--Master Recipe list
local masterRecipe = T { };

--spellcraft recipe list
local spellcraftRecipes = T{};
local matList = T {};

--combo box for type of report
local selectedCraft = T { 0 };

-- Load both settings blocks..
local scparser = settings.load(default_settings); -- Uses 'settings' alias by default..

--[[
* Event invoked when a settings table has been changed within the settings library.
*
* Note: This callback only affects the default 'settings' table.
--]]
settings.register('settings', 'settings_update', function (e)
    -- Update the local copy of the 'settings' settings table..
    scparser = e;

    -- Ensure settings are saved to disk when changed..
    settings.save();
end);


--[[
* event: unload
* desc : Called when the addon is being unloaded.
--]]
hook.events.register('unload', 'unload_cb', function ()

	settings.save();
end);

--[[
* event: unload
* desc : Called when the addon is being unloaded.
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

    --Buy item pointer
	--Address of signature = game.dll + 0x0002AFBE
    local ptr = hook.pointers.add('daoc.items.buyitem', 'game.dll', '558BEC83EC??833D28980401??7E??68????????68????????E8????????5959C9C3833D00829900??75??83FF', 0,0);
    if (ptr == 0) then
        error('Failed to locate buy item function pointer.');
    end

    --Interact pointer
	--Address of signature = game.dll + 0x0002AE06 0x42ae06
    local ptr = hook.pointers.add('daoc.items.interact', 'game.dll', '558BEC83EC??833D28980401??7E??68????????68????????E8????????5959C9C3833D00829900??75??56', 0,0);
    if (ptr == 0) then
        error('Failed to locate interact function pointer.');
    end

    --Start of craftlevel array
	--Address of signature = game.dll + 0x0001F495
	--"B9????????8039??74??8B41"
    ptr = hook.pointers.add('game.ptr.craft_levels', 'game.dll', 'B9????????8039??74??8B41', 1,0);
    if (ptr == 0) then
        error('Failed to locate craft levels pointer.');
    end

	--Start of merchant array
	--Address of signature = game.dll + 0x0001C16B
    ptr = hook.pointers.add('game.ptr.merchant_list', 'game.dll', 'BE????????03FE3845', 1,0);
    if (ptr == 0) then
        error('Failed to locate merchant list pointer.');
    end

	--load in the recipe list
    local f = io.open(addon.path .. '/data/edenrecipes.json', 'rb');
    if (f == nil) then
        error('Failed to load spell list file. (/data/edenrecipes.json)');
    end

    -- Read the full file contents..
    local c = f:read("*all");
    f:close();

    -- Parse the spell json data..
    masterRecipe = T(json.decode(c) or {});

    masterRecipe:each(function (v, k)
        --daoc.chat.msg(daoc.chat.message_mode.help, ('%s'):fmt(k));
        v:each(function (_, kk)
            if (_['profession'] == 'Spellcraft') then
                spellcraftRecipes:append(_);
            end
        end);
    end);


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

    -- Command: /inv
    if ((args[1]:ieq('sctest') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/sctest')) then
        -- Mark the command as handled, preventing the game from ever seeing it..
        e.blocked = true;
        -- Find all valid recipes for realm
        

        --daoc.chat.msg(daoc.chat.message_mode.help, ('%s'):fmt(masterRecipe["Albion"][2886]["profession"]));
        daoc.chat.msg(daoc.chat.message_mode.help, ('%s'):fmt(spellcraftRecipes:len()));
        return;
    end
end);

--[[
* event: d3d_present
* desc : Called when the Direct3D device is presenting a scene.
--]]
hook.events.register('d3d_present', 'd3d_present_cb', function ()
    imgui.SetNextWindowSize({ 500, 500, });
    if (imgui.Begin('SC Parser')) then
        -- Show the current settings library information..
        imgui.Text(('     Name: %s'):fmt(settings.name));
        imgui.Text(('Logged In: %s'):fmt(tostring(settings.logged_in)));
        imgui.NewLine();
        imgui.Separator();
        imgui.TextColored({ 1.0, 1.0, 0.0, 1.0 }, 'Paste the zenkraft report or list of gems separated by newline (\\n)\n\nGem vendor window must be open to buy mats');
        imgui.NewLine();

        if (imgui.BeginTabBar('##settings_tabbar', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton)) then
            --[[
            * Tab: 'settings'
            *
            * Demostrates the usage of the default configuration alias 'settings'.
            --]]
            if (imgui.BeginTabItem('settings', nil)) then
                imgui.TextColored({ 0.0, 0.8, 1.0, 1.0 }, 'Type of report:');
                imgui.SameLine();
				local report_type = { selectedCraft[1] };
				if (imgui.Combo('##selCraft', report_type, 'Zenkraft\0Plain Gem List\0\0')) then
					selectedCraft[1] = report_type[1];
				end

                if (imgui.Button('Parse', { 55, 20 })) then
                    scparser.craft_list:clear();
                    settings.save();
                    parseList();
                end
                imgui.SameLine();
                if (imgui.Button('Buy Mats', { 75, 20 })) then

                end
                imgui.SameLine();
                if (imgui.Button('Craft Gems', { 85, 20 })) then

                end
                imgui.SameLine();
                if (imgui.Button('Reset', { 55, 20 })) then
                    settings.reset();
                end
                imgui.InputTextMultiline('##str_val1', scparser.gem_list_str, 10384, { -1, imgui.GetTextLineHeight() * 20, }, ImGuiInputTextFlags_AllowTabInput);


                imgui.EndTabItem();
            end

            imgui.EndTabBar();
        end
    end
    imgui.End();
end);

function parseList()
    if selectedCraft[1] == 0 then
        parseZenList()
    else
        parseGemList();
    end
end

function parseGemList()
    
    local gems = scparser.str_val3[1]:psplit('\n');
    for i = 1, gems:len() do
        daoc.chat.msg(daoc.chat.message_mode.help, ('gem: %s'):fmt(gems[i]));
    end
end

function parseZenList()
    daoc.chat.msg(daoc.chat.message_mode.help, ('Parse zen list'));
    --split into table of each line
    local gems = scparser.gem_list_str[1]:psplit('\n');
    local matLines = T {};
    for i = 1, gems:len() do
        --for each line, look for [] 
        --daoc.chat.msg(daoc.chat.message_mode.help, ('check: %s'):fmt(gems[i]));
        if (gems[i]:contains('[')) then
            --daoc.chat.msg(daoc.chat.message_mode.help, ('add: %s'):fmt(gems[i]));
            matLines:append(gems[i])
        end
    end

    --parse out the gem info
    for x = 1, matLines:len() do
        
        local line = matLines[x];
        local gem = line:psplit('%[');
        gem = gem[2]:psplit(']')
        gem = gem[1]:replace('(', '', 1);
        gem = gem:replace(')', '', 1);
        scparser.craft_list:append(gem);
    end

    for x = 1, scparser.craft_list:len() do
        --Get base material in first index, rest of name in second index
        local basemat = scparser.craft_list[x]:psplit(' ', 1, false);
        local category = scparser.craft_list[x]:replace(basemat[1]..' ', '', 1);
        --lookup the materials
        daoc.chat.msg(daoc.chat.message_mode.help, ('%s %s'):fmt(basemat[1], category));
        matList = get_materials('Spellcraft', basemat[1], category);

        matList:each(function (v, k)
            --daoc.chat.msg(daoc.chat.message_mode.help, ('%s'):fmt(k));
            --daoc.chat.msg(daoc.chat.message_mode.help, ('%d %s %s'):fmt(v['count'], v['base_material_name'], v['name']));
        end);
        
        daoc.chat.msg(daoc.chat.message_mode.help, ('id: %d'):fmt(get_craftid('Spellcraft', basemat[1], category)));
    end
end

function get_craftid(craftName, baseMat, category)
    local craftid = 0;

    masterRecipe:each(function (v, k)
        --daoc.chat.msg(daoc.chat.message_mode.help, ('%s'):fmt(k));
        v:each(function (_, kk)
            if (_['profession'] == craftName) then
                if (_['base_material_name']:ieq(baseMat) and _['category']:ieq(category)) then
                    --daoc.chat.msg(daoc.chat.message_mode.help, ('%s'):fmt(v['category']));
                    craftid = _['id'];
                end
            end
        end);
    end);

    return craftid;
end

function get_materials(craftName, baseMat, category)
    local matTable;

    masterRecipe:each(function (v, k)
        --daoc.chat.msg(daoc.chat.message_mode.help, ('%s'):fmt(k));
        v:each(function (_, kk)
            if (_['profession'] == craftName) then
                if (_['base_material_name']:ieq(baseMat) and _['category']:ieq(category)) then
                    --daoc.chat.msg(daoc.chat.message_mode.help, ('%s'):fmt(v['category']));
                    matTable = _['materials'];
                end
            end
        end);
    end);

    return matTable;
end

function checkMats()

	if scparser.isCrafting[1] then


		for i=1, matList:len() do
			local matname = matList[i].base_material_name .. ' ' .. matList[i].name;
			--if the matname ends in an s, remove it
			if matname:endswith('s') then
				daoc.chat.msg(daoc.chat.message_mode.help, ('remove s'));
				matname = matname:sub(1, -2);
			end
			--trim whitespace
			matname = matname:clean();
			local matval = matList[i].count;
			daoc.chat.msg(daoc.chat.message_mode.help, ('buy %s %s'):fmt(matval, matname));
			while matval >= 100 do
				if (buyMats(matname, 100)) then
					matval = matval - 100;
				else
					return;
				end
			end
			if matval > 0 and matval < 100 then
				if not buyMats(matname, matval) then
					return;
				end
			end
			coroutine.sleep(1);
		end

		--doCraft();
	end

end

function buyMats(matName, count)
	local slotNum = 0;
	if matName:len() > 0 then
		slotNum = daoc.items.get_merchant_slot(matName);
	end

	if slotNum ~= nil then
		--daoc.chat.msg(daoc.chat.message_mode.help, ('buy %d %s from slot %d'):fmt(count, itemName, slotNum));
		buyItem(slotNum, count)
		return true;
	else
		daoc.chat.msg(daoc.chat.message_mode.help, ('No %s in merchant list'):fmt(matName));
		return false;
	end
	return false;
end