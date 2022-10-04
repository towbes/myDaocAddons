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

	DWORD GetProcessId(
		HANDLE Process
	);

	HANDLE GetCurrentProcess();
    
	typedef const char* LPCSTR;

    typedef struct _LPSECURITY_ATTRIBUTES {
        DWORD  nLength;
        LPVOID lpSecurityDescriptor;
        BOOL   bInheritHandle;
	} LPSECURITY_ATTRIBUTES, *PSECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;

	HANDLE CreateFileMappingA(
	HANDLE				  hFile,
	HANDLE lpFileMappingAttributes,
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

	BOOL FlushViewOfFile(
  		LPCVOID lpBaseAddress,
  		SIZE_T  dwNumberOfBytesToFlush
	);

	enum {
        FILE_MAP_ALL_ACCESS     = 0x0000F001F,
        FILE_MAP_READ           = 0x000000004,
        FILE_MAP_WRITE          = 0x000000002,
        FILE_MAP_COPY           = 0x000000001,
    };

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

	//// Data struct to be shared between processes
	//typedef struct {
	//	UINT32 test;
	//} MMF_Global;
//
	////enum multisend_type
	////{
	////	all, //Param irrelevant
	////	others, //Param = sender's process ID
	////	alliance, //Param = sender's server id
	////	party, //Param = sender's server id
	////	group, //Param = group id
	////	single //Param = process id of target
	////};
	//
	typedef struct
	{
		uint32_t Process;
		uint8_t Name[64];
		uint8_t Active;
	} MMF_Name_Single;
	
	typedef struct
	{
		uint32_t				ProcessID;
		MMF_Name_Single			Names[100];
	} MMF_Name;
	//
	//typedef struct 
	//{
	//	uint8_t			active;
	//	//multisend_type	type;
	//	uint32_t		param;
	//	uint32_t		sender_process_id;
	//	uint8_t			command[248];
	//} MMF_ICommand_Single;
	//
	//typedef struct 
	//{
	//	uint32_t				ProcessID;
	//	uint32_t				Position;
	//	MMF_ICommand_Single		Command[100];
	//} MMF_ICommand;
	//
	//typedef struct 
	//{
	//	uint32_t				target_process_id;
	//	uint16_t				lastzone;
	//	uint16_t				zone;
	//	float					position_x;
	//	float					position_z;
	//	uint32_t				idle_count;
	//} MMF_IFollow;
	
	typedef struct 	{
		MMF_Name				Name;
		//MMF_ICommand			Command;
		//MMF_IFollow				Follow;
	} MMF_Global;

]];

-- Shared Memory Variables
local shared    = T{ };
shared.map      = nil;
shared.view     = nil;
shared.mem      = nil;


--[[
* event: load
* desc : Called when the addon is being loaded.
--]]
hook.events.register('load', 'load_cb', function ()
    shared.map = C.CreateFileMappingA(ffi.cast('HANDLE', -1), nil, C.PAGE_READWRITE, 0, ffi.sizeof('MMF_Global'), 'daoc_sharedmem');
    if (shared.map == nil) then
        error('Failed to create required file mapping.');
    end

    shared.view = C.MapViewOfFile(shared.map, C.FILE_MAP_ALL_ACCESS, 0, 0, 0);
    if (shared.view == nil) then
        C.CloseHandle(shared.map);
        shared.map = nil;
        error('Failed to create map view.');
    end

    shared.mem = ffi.cast('MMF_Global*', shared.view);

	--Check if we already have an active process
	local procId = C.GetProcessId(C.GetCurrentProcess());
    --Check if this process already has our procId
	for i=0, 100 do
		if (shared.mem.Name.Names[i].Active == 1) then
			if (shared.mem.Name.Names[i].Process == procId) then
				return;
			end
		end
	end
	--Otherwise set our procId to first inactive
	for i=0, 100 do
		if (shared.mem.Name.Names[i].Active == 0) then
			shared.mem.Name.Names[i].Active = 1;
			shared.mem.Name.Names[i].Process = procId;
			return;
		end
	end

end);

--[[
* event: unload
* desc : Called when the addon is being unloaded.
--]]
hook.events.register('unload', 'unload_cb', function ()

	local procId = C.GetProcessId(C.GetCurrentProcess());
    --Set our process to inactive
	for i=0, 100 do
		if (shared.mem.Name.Names[i].Active == 1) then
			if (shared.mem.Name.Names[i].Process == procId) then
				shared.mem.Name.Names[i].Active = 0;
				shared.mem.Name.Names[i].Process = 0;
			end
			return;
		end
	end
	
	
	shared.mem = nil;

    if (shared.view ~= nil) then
        C.UnmapViewOfFile(shared.view);
		shared.view = nil;
    end
    if (shared.map ~= nil) then
        C.CloseHandle(shared.map);
        shared.map = nil;
    end
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

		if (shared.mem == nil) then
			return;
		end

		local procId = C.GetProcessId(C.GetCurrentProcess());
		daoc.chat.msg(daoc.chat.message_mode.help, ('ProcID: %d'):fmt(procId));
		--shared.mem.Name.ProcessID = procId;
		--shared.mem.Name.Names[0].Process = procId;

		for i=0, 100 do
			if (shared.mem.Name.Names[i].Active == 0) then
				shared.mem.Name.Names[i].Active = 1;
				shared.mem.Name.Names[i].Process = procId;
				
				return;
			end
		end
        return;
    end

    -- Command: /maximize, /minimize
    if ((args[1]:any('read') and e.imode == daoc.chat.input_mode.slash) or args[1]:any('/read')) then
        e.blocked = true;

        if (shared.mem == nil) then
            return;
        end

		for i=0, 100 do
			if (shared.mem.Name.Names[i].Active == 1) then
				daoc.chat.msg(daoc.chat.message_mode.help, ('Char %d: %d'):fmt(i, shared.mem.Name.Names[i].Process));
			end
		end
        return;
    end

	-- Command: /maximize, /minimize
	if ((args[1]:any('clear') and e.imode == daoc.chat.input_mode.slash) or args[1]:any('/clear')) then
		e.blocked = true;

		if (shared.mem == nil) then
			return;
		end

		--Set everything inactive
		for i=0, 100 do
			shared.mem.Name.Names[i].Active = 0;
			shared.mem.Name.Names[i].Process = 0;
		end

		return;
	end

end);
