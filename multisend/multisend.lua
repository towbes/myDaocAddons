addon.name    = 'multisend';
addon.author  = 'towbes - original from thorny';
addon.desc    = 'Window helper to adjust position, size, border, etc.';
addon.link    = 'https://github.com/ThornyFFXI/Multisend';
addon.version = '1.0';

require 'common';
require 'win32types';
require 'daoc';

local ffi   = require 'ffi';
local C     = ffi.C;

--[[
* FFI Definitions
--]]
ffi.cdef[[

	HANDLE CreateFileMappingA(
	HANDLE				  hFile,
	LPSECURITY_ATTRIBUTES lpFileMappingAttributes,
	DWORD                 flProtect,
	DWORD                 dwMaximumSizeHigh,
	DWORD                 dwMaximumSizeLow,
	LPCSTR                lpName
	);

	LPVOID MapViewOfFile(
		HANDLE hFileMappingObject,
		DWORD  dwDesiredAccess,
		DWORD  dwFileOffsetHigh,
		DWORD  dwFileOffsetLow,
		SIZE_T dwNumberOfBytesToMap
	);

	BOOL UnmapViewOfFile(
  		LPCVOID lpBaseAddress
	);

	BOOL CloseHandle(
		HANDLE hObject
	);

    enum {
        PAGE_EXECUTE_READ      	= 0x20,
        PAGE_EXECUTE_READWRITE 	= 0x40,
        PAGE_EXECUTE_WRITECOPY 	= 0x80,
        PAGE_READONLY    		= 0x02,
        PAGE_READWRITE      	= 0x04,
		PAGE_WRITECOPY			= 0x08,
    };

    enum {
        SEC_COMMIT = 0x8000000,
        SEC_IMAGE     = 0x1000000,
        SEC_IMAGE_NO_EXECUTE = 0x11000000,
		SEC_LARGE_PAGES = 0x80000000,
		SEC_NOCACHE = 0x10000000,
		SEC_RESERVE = 0x4000000,
		SEC_WRITECOMBINE = 0x40000000,
    };



	// Data struct to be shared between processes
	typedef struct _TSharedData {
		UINT32 test;
	} TSharedData, *TSharedData;

]];

local hMap;
local hShm;

INVALID_HANDLE_VALUE = ffi.cast("HANDLE",ffi.cast("LONG_PTR",-1));
local FILE_MAP_ALL_ACCESS = 0xf001f

--[[
* event: load
* desc : Called when the addon is being loaded.
--]]
hook.events.register('load', 'load_cb', function ()
	--create LPSECURITY_ATTRIBUTES holder
	local lpAtt = ffi.new('LPSECURITY_ATTRIBUTES');

    -- Obtain the shm handle..
	hMap = ffi.cast('HANDLE', C.CreateFileMappingA(
		INVALID_HANDLE_VALUE, lpAtt, C.PAGE_READWRITE, 0, 1, ffi.cast('LPCSTR', 'luashm')
	));


	--if (hMap == nil) then
	--	return;
	--end

	hShm = ffi.cast('HANDLE', C.MapViewOfFile(hMap, FILE_MAP_ALL_ACCESS, 0, 0, 0));

	hShm = ffi.new("TSharedData");

end);

--[[
* event: unload
* desc : Called when the addon is being unloaded.
--]]
hook.events.register('unload', 'unload_cb', function ()

	C.UnmapViewOfFile(hShm);
	C.CloseHandle(hMap);

end);

--[[
* event: command
* desc : Called when the game is handling a command.
--]]
hook.events.register('command', 'command_cb', function (e)
    -- Parse the command arguments..
    local args = e.modified_command:args();
    if (#args == 0) then return; end



    -- Command: /maximize, /minimize
    if ((args[1]:any('write') and e.imode == daoc.chat.input_mode.slash) or args[1]:any('/write')) then
        e.blocked = true;

        hook.tasks.oncef(1, function ()
            hShm.test = hShm.test +1;
        end);

        return;
    end

    -- Command: /maximize, /minimize
    if ((args[1]:any('read') and e.imode == daoc.chat.input_mode.slash) or args[1]:any('/read')) then
        e.blocked = true;

        hook.tasks.oncef(1, function ()
            msg = ("#: %d"):fmt(hShm.test);
			daoc.chat.msg(daoc.chat.message_mode.help, msg)
        end);

        return;
    end

end);
