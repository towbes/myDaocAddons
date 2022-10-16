addon.name    = 'buttonmaster';
addon.author  = 'towbes';
addon.desc    = 'imgui Buttons Page';
addon.link    = '';
addon.version = '1.0';

require 'common';
require 'daoc';

local settings = require 'settings';
local LIP = require('lib/LIP')
local utils = require('lib/ed/utils')

local imgui = require 'imgui';

-- Window Variables
local window = T{
    is_checked = T{ false, },
};

-- helpers
local time = hook.time.get_local_time()
local Output = function(msg) print(('\aw[%02i:%02i] [\aoButton Master\aw] ::\a-t %s'):fmt(time['hh'], time['mm'], msg)); end

local SaveSettings = function() 
    LIP.save(settings_path, settings) 
end

-- globals
local CharConfig = 'Char_Config'
local DefaultSets = { 'Primary', 'Movement' }
local openGUI = true
local shouldDrawGUI = true
local initialRun = false
--local tmpButton = { ButtonKey = {Label = { name='Label', buf = '', bufsize = 100 }, 
--                                 Cmd1 = {name='Cmd1', buf = '', bufsize = 100},
--                                 Cmd2 = {name='Cmd2', buf = '', bufsize = 100},
--                                 Cmd3 = {name='Cmd3', buf = '', bufsize = 100},
--                                 Cmd4 = {name='Cmd4', buf = '', bufsize = 100},
--                                 Cmd5 = {name='Cmd5', buf = '', bufsize = 100}, }}
local tmpButton = { }
--Used to store the edit button input text buffers
local editBufs = { T {''}, T {''}, T {''}, T {''}, T {''}, T {''} };
--Used to store the create new tab text buffer
local createBuf = { T {''} };
local editSetBuf = { T {''} };
local btnColor = {}
local txtColor = {}
local lastWindowHeight = 0
local lastWindowWidth = 0
local buttons = {}
local editPopupName
local editTabPopup = "edit_tab_popup"
local name

-- binds
local BindBtn = function() 
    openGUI = not openGUI
end

local GetButtonBySetIndex = function(Set, Index)
    return settings[settings[Set][Index]] or { Unassigned = true, Label = tostring(Index) }
end

local GetButtonSectionKeyBySetIndex = function(Set, Index)
    local key = settings[Set][Index]

    -- if the key doesn't exist, get the current button counter and add 1
    if key == nil then
        key = 'Button_' .. tonumber(settings['Global']['ButtonCount']+1)
    end
    return key
end

local DrawButtonTooltip = function(Button)
    -- hover tooltip
    if Button.Unassigned == nil and imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.Text(Button.Label)
        imgui.EndTooltip()
    end
end

local RecalculateVisibleButtons = function()
    local btnSize = (settings['Global']['ButtonSize'] or 6) * 10
    lastWindowWidth = imgui.GetWindowSize()
    lastWindowHeight = imgui.GetWindowHeight()
    local rows = math.floor(lastWindowHeight / (btnSize + 5))
    local cols = math.floor(lastWindowWidth / (btnSize + 5))
    local count = 100
    if rows * cols < 100 then count = rows * cols end
    buttons = {}
    for i = 1, count do buttons[i] = i end
end

local DrawTabContextMenu = function()
    local openPopup = false
    
    local max = 1
    local unassigned = {}
    local keys = {}
    for k, v in ipairs(settings[CharConfig]) do 
        keys[v] = true 
        max = k + 1
    end
    for k, v in pairs(settings['Sets']) do 
        if keys[v] == nil then unassigned[k] = v end
    end

    if imgui.BeginPopupContextItem() then
        if getTableSize(unassigned) > 0 then
            if imgui.BeginMenu("Add Set") then
                for k, v in pairs(unassigned) do
                    if imgui.MenuItem(v) then
                        settings[CharConfig][max] = v
                        SaveSettings()
                        break
                    end
                end
                imgui.EndMenu()
            end
        end

        if imgui.BeginMenu("Remove Set") then
            for i, v in ipairs(settings[CharConfig]) do
                if imgui.MenuItem(v) then
                    settings[CharConfig][i] = nil
                    SaveSettings()
                    break
                end
            end
            imgui.EndMenu()
        end

        if imgui.MenuItem("Create New") then
            openPopup = true
        end

        if imgui.BeginMenu("Font Scale") then
            if imgui.MenuItem("Tiny") then settings['Global']['Font'] = 0.8 end
            if imgui.MenuItem("Small") then settings['Global']['Font'] = 0.9 end
            if imgui.MenuItem("Normal") then settings['Global']['Font'] = 1.0 end
            if imgui.MenuItem("Large") then settings['Global']['Font'] = 1.1 end
            imgui.EndMenu()
        end

        imgui.EndPopup()
    end

    if openPopup and imgui.IsPopupOpen(editTabPopup) == false then
        imgui.OpenPopup(editTabPopup)
        openPopup = false
    end
end

local DrawCreateTab = function()
    if imgui.BeginPopup(editTabPopup) then
        imgui.Text("New Button Set:")
        imgui.InputText("##edit", createBuf, 255)
        if imgui.Button("Save") then
            name = createBuf[1]
            if name ~= nil and name:len() > 0 then
                settings[CharConfig][getTableSize(settings[CharConfig])+1] = name -- update the character button set name
                settings['Sets'][getTableSize(settings['Sets'])+1] = name
                settings['Set_'..name] = {}
                SaveSettings()
            else
                Output("\arError Saving Set: Name cannot be empty.\ax")
            end
            imgui.CloseCurrentPopup() 
        end
        imgui.EndPopup()
    end
end

local DrawContextMenu = function(Set, Index)
    local openPopup = false
    local ButtonKey = GetButtonSectionKeyBySetIndex(Set, Index)
    local Button = GetButtonBySetIndex(Set, Index)

    local unassigned = {}
    local keys = {}
    for k, v in pairs(settings[Set]) do keys[v] = true end
    for k, v in pairs(settings) do 
        if k:find("^(Button_)") and keys[k] == nil then
            unassigned[k] = v
        end
    end

    if imgui.BeginPopupContextItem() then
        editPopupName = "edit_button_popup|"..Index

        -- only list hotkeys that aren't already assigned to the button set
        if getTableSize(unassigned) > 0 then
            if imgui.BeginMenu("Assign Hotkey") then
                for k, v in pairs(unassigned) do
                    if imgui.MenuItem(v.Label) then
                        settings[Set][Index] = k
                        SaveSettings()
                        break
                    end
                end
                imgui.EndMenu()
            end
        end

        -- only show create new for unassigned buttons
        if Button.Unassigned == true then
            if imgui.MenuItem("Create New") then
                openPopup = true
            end
        end

        -- only show edit & unassign for assigned buttons
        if Button.Unassigned == nil then
            if imgui.MenuItem("Edit") then
                openPopup = true
            end
            if imgui.MenuItem("Unassign") then
               settings[Set][Index] = nil
               SaveSettings()
            end
        end

        imgui.EndPopup()
    end

    if openPopup and imgui.IsPopupOpen(editPopupName) == false then
        imgui.OpenPopup(editPopupName)
        openPopup = false
    end
end

local HandleEdit = function(Set, Index, Key, Prop, buf)
    
    local selected = imgui.InputText(Prop, buf, 255)
    if selected then
        -- if theres no value, nil the key so we don't save empty command lines
        if tostring(buf[1]):len() > 0 then 
            tmpButton[Key][Prop] = buf[1]
        else
            tmpButton[Key][Prop] = nil
        end
    end
end

local DrawEditButtonPopup = function(Set, Index)
    local ButtonKey = GetButtonSectionKeyBySetIndex(Set, Index)
    local Button = GetButtonBySetIndex(Set, Index)

    if imgui.BeginPopup("edit_button_popup|"..Index) then
        -- shallow copy original button incase we want to reset (close)
        if tmpButton[ButtonKey] == nil then
            tmpButton[ButtonKey] = shallowcopy(Button)
            if tmpButton[ButtonKey] ~= nil then
                editBufs[1][1] = tmpButton[ButtonKey].Label;
                editBufs[2][1] = tmpButton[ButtonKey].Cmd1;
                editBufs[3][1] = tmpButton[ButtonKey].Cmd2;
                editBufs[4][1] = tmpButton[ButtonKey].Cmd3;
                editBufs[5][1] = tmpButton[ButtonKey].Cmd4;
                editBufs[6][1] = tmpButton[ButtonKey].Cmd5;
            end
            
        end
        
        -- color pickers
        if Button.ButtonColorRGB ~= nil then
            local tColors = split(Button.ButtonColorRGB, ",")
            for i, v in ipairs(tColors) do btnColor[i] = tonumber(v/255) end
        end
        local col, used = imgui.ColorEdit3("Button Color", btnColor, NoInputs)
        if used then 
            btnColor = shallowcopy(col)
            tmpButton[ButtonKey].ButtonColorRGB = string.format("%d,%d,%d", math.floor(col[1]*255), math.floor(col[2]*255), math.floor(col[3]*255))
        end
        imgui.SameLine()
        if Button.TextColorRGB ~= nil then
            local tColors = split(Button.TextColorRGB, ",")
            for i, v in ipairs(tColors) do txtColor[i] = tonumber(v/255) end
        end
        col, used = imgui.ColorEdit3("Text Color", txtColor, imNoInputs)
        if used then 
            txtColor = shallowcopy(col)
            tmpButton[ButtonKey].TextColorRGB = string.format("%d,%d,%d", math.floor(col[1]*255), math.floor(col[2]*255), math.floor(col[3]*255))
        end

        -- color reset
        imgui.SameLine()
        if imgui.Button("Reset") then
            btnColor, txtColor = {}, {}
            settings[ButtonKey].ButtonColorRGB = nil
            settings[ButtonKey].TextColorRGB = nil
            SaveSettings()
            imgui.CloseCurrentPopup()
        end

        HandleEdit(Set, Index, ButtonKey, 'Label', editBufs[1])
        HandleEdit(Set, Index, ButtonKey, 'Cmd1', editBufs[2])
        HandleEdit(Set, Index, ButtonKey, 'Cmd2', editBufs[3])
        HandleEdit(Set, Index, ButtonKey, 'Cmd3', editBufs[4])
        HandleEdit(Set, Index, ButtonKey, 'Cmd4', editBufs[5])
        HandleEdit(Set, Index, ButtonKey, 'Cmd5', editBufs[6])

        -- save button
        if imgui.Button("Save") then
            -- make sure the button label isn't nil/empty/spaces
            --tmpButton[ButtonKey].Label:gsub("%s+",""):len() > 0
            if tmpButton[ButtonKey].Label ~= nil and tmpButton[ButtonKey].Label:clean():len() > 0 then
                settings[Set][Index] = ButtonKey            -- add the button key for this button set index
                settings[ButtonKey] = shallowcopy(tmpButton[ButtonKey])  -- store the tmp button into the settings table
                settings[ButtonKey].Unassigned = nil        -- clear the unassigned flag
                -- if we're saving this, update the button counter
                settings['Global']['ButtonCount'] = settings['Global']['ButtonCount'] + 1
                SaveSettings()
            else
                tmpButton[ButtonKey] = nil
                Output("\arSave failed.  Button Label cannot be empty.")
            end
            imgui.CloseCurrentPopup()
        end
        
        imgui.SameLine()

        -- close button
        local closeClick = imgui.Button("Close") 
        if imgui.IsItemHovered() then
            imgui.BeginTooltip()
            imgui.Text("Close edit dialog without saving")
            imgui.EndTooltip()
        end
        if closeClick then 
            tmpButton[ButtonKey] = shallowcopy(Button)
            imgui.CloseCurrentPopup() 
        end

        imgui.SameLine()

        local clearClick = imgui.Button("Clear") 
        if imgui.IsItemHovered() then
            imgui.BeginTooltip()
            imgui.Text("Clear hotbutton fields")
            imgui.EndTooltip()
        end
        if clearClick then
            tmpButton[ButtonKey] = nil -- clear the buffer
            settings[Set][Index] = nil -- clear the button set index
        end

        -- imgui.SameLine()

        -- local deleteClick = imgui.Button("Delete")
        -- if imgui.IsItemHovered() then
        --     imgui.BeginTooltip()
        --     imgui.Text("No going back - this will destroy the hotbutton!")
        --     imgui.EndTooltip()
        -- end
        -- if deleteClick then
        --     settings[ButtonKey] = nil
        --     tmpButton[ButtonKey] = nil
        --     settings[Set][Index] = nil
        --     SaveSettings()
        --     imgui.CloseCurrentPopup()
        -- end

        imgui.EndPopup()
    end
end

local DrawButtons = function(Set)
    if imgui.GetWindowSize() ~= lastWindowWidth or imgui.GetWindowHeight() ~= lastWindowHeight then
        RecalculateVisibleButtons()
    end

    -- global button configs
    local btnSize = (settings['Global']['ButtonSize'] or 6) * 10
    local cols = math.floor(imgui.GetWindowSize() / (btnSize + 5))

    for i, ButtonIndex in ipairs(buttons) do
        local ButtonSectionKey = GetButtonSectionKeyBySetIndex(Set, ButtonIndex)
        local Button = GetButtonBySetIndex(Set, ButtonIndex)

        -- push button styles if configured
        if Button.ButtonColorRGB ~= nil then
            local Colors = split(Button.ButtonColorRGB, ",")
            imgui.PushStyleColor(0, {tonumber(Colors[1]/255), tonumber(Colors[2]/255), tonumber(Colors[3]/255)})
        end
        if Button.TextColorRGB ~= nil then
            local Colors = split(Button.TextColorRGB, ",")
            imgui.PushStyleColor(0, {tonumber(Colors[1]/255), tonumber(Colors[2]/255), tonumber(Colors[3]/255)})
        end

        imgui.SetWindowFontScale(settings['Global']['Font'] or 1)
        local clicked = imgui.Button(Button.Label:gsub(" ", "\n"), {btnSize, btnSize})
        imgui.SetWindowFontScale(1)
        
        -- pop button styles as necessary
        if Button.ButtonColorRGB ~= nil then imgui.PopStyleColor() end
        if Button.TextColorRGB ~= nil then imgui.PopStyleColor() end


        if clicked then
            for k, cmd in orderedPairs(Button) do
                if k:find('^(Cmd%d)') then
                    if cmd:find('^/') then
                        --print(cmd);
                        daoc.chat.exec(daoc.chat.command_mode.typed, daoc.chat.input_mode.normal, cmd);
                    else
                        Output('\arInvalid command: \ax'..cmd)
                    end
                end
            end
        else
            -- setup drag and drop
            if imgui.BeginDragDropSource() then
                imgui.SetDragDropPayload("BTN", ButtonIndex)
                imgui.Button(Button.Label, btnSize, btnSize)
                imgui.EndDragDropSource()
            end
            if imgui.BeginDragDropTarget() then
                local payload = imgui.AcceptDragDropPayload("BTN")
                if payload ~= nil then
                    local num = payload.Data;
                    -- swap the keys in the button set
                    settings[Set][num], settings[Set][ButtonIndex] = settings[Set][ButtonIndex], settings[Set][num]
                    SaveSettings()
                end
                imgui.EndDragDropTarget()
            end

            -- render button pieces
            DrawButtonTooltip(Button)
            DrawContextMenu(Set, ButtonIndex)
            DrawEditButtonPopup(Set, ButtonIndex)
        end

        -- button grid
        if i % cols ~= 0 then imgui.SameLine() end
    end
end

local DrawTabs = function()
    local Set
    imgui.Button("Settings") 
    imgui.SameLine()
    DrawTabContextMenu()
    DrawCreateTab()
    
    if imgui.BeginTabBar("Tabs") then
        for i, set in ipairs(settings[CharConfig]) do
            if imgui.BeginTabItem(set) then
                Set = 'Set_'..set

                -- tab edit popup
                if imgui.BeginPopupContextItem() then
                    imgui.Text("Edit Name:")
                    --editSetBuf[1] = set
                    imgui.InputText("##edit", editSetBuf, 255)
                    if imgui.Button("Save") then
                        name = editSetBuf[1];
                        settings[CharConfig][i] = name -- update the character button set name
                        settings['Set_'..name], settings[Set] = settings[Set], nil -- move the old button set to the new name
                        Set = 'Set_'..name -- update set to the new name so the button render doesn't fail
                        SaveSettings()
                        imgui.CloseCurrentPopup() 
                    end
                    imgui.EndPopup()
                end

                DrawButtons(Set)
                imgui.EndTabItem()
            end
        end
        imgui.EndTabBar();
    end
end

local ButtonGUI = function()
    --if not openGUI then return end
    --openGUI, shouldDrawGUI = imgui.Begin('Button Master', openGUI, NoFocusOnAppearing)
    --if openGUI and shouldDrawGUI then
    --    if initialRun then 
    imgui.Begin('Button Master', openGUI, NoFocusOnAppearing);
    imgui.SetNextWindowSize(T{280, 318}, ImGuiCond_FirstUseEver); 
            --initialRun = false
        --end
    DrawTabs()
    imgui.End()
end

local LoadSettings = function() 
    config_dir = settings.settings_path();
    settings_file = 'settings.ini'
    settings_path = config_dir..settings_file

    if file_exists(settings_path) then
        settings = LIP.load(settings_path)
    else
        settings = {
            Global = {
                ButtonSize = 6,
                ButtonCount = 4,
            },
            Sets = { 'Primary', 'Movement' },
            Set_Primary = { 'Button_1', 'Button_2', 'Button_3' },
            Set_Movement = { 'Button_4' },
            Button_1 = {
                Label = 'Burn (all)',
                Cmd1 = '/bcaa //burn',
                Cmd2 = '/timed 500 /bcaa //burn'
            },
            Button_2 = {
                Label = 'Pause (all)',
                Cmd1 = '/bcaa //multi ; /twist off ; /mqp on'
            },
            Button_3 = {
                Label = 'Unpause (all)',
                Cmd1 = '/bcaa //mqp off'
            },
            Button_4 = {
                Label = 'Nav Target (bca)',
                Cmd1 = '/bca //nav id ${Target.ID}'
            },
            [CharConfig] = DefaultSets
        }
        SaveSettings()
    end

    -- if this character doesn't have the sections in the ini, create them
    if settings[CharConfig] == nil then 
        settings[CharConfig] = DefaultSets 
        initialRun = true
        SaveSettings()
    end
end


--[[
* event: load
* desc : Called when the addon is being loaded.
--]]
hook.events.register('load', 'load_cb', function ()
    
    LoadSettings()
    Output('\ayButton Master by (\a-to_O\ay) Special.Ed (\a-to_O\ay) - \atLoaded '..settings_file)

end);

--[[
* event: d3d_present
* desc : Called when the Direct3D device is presenting a scene.
--]]
hook.events.register('d3d_present', 'd3d_present_cb', function ()
    -- Render a custom example window via imgui..
    ButtonGUI();
end);
