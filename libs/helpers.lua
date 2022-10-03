require 'common';


--[[
* Returns the current number of allocated and in-use entities.
--]]
decode_level = function (encLevel)
	if (encLevel == 0) then return 0; end
	--//unencode level: ((*(uint32_t*)(tempPtr + 0x60) ^ 0xCB96)/74) - 23
	--Had to change this to 24 for some reason because it was showing 50 as 51
	local decLevel = (bit.bxor((encLevel + 0x60), 0xCB96) / 74) - 24
    return decLevel;
end