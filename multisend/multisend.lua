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
	typedef struct 
	{
		uint8_t			active;
		//multisend_type	type;
		//uint32_t		param;
		uint32_t		sender_process_id;
		uint8_t			command[248];
	} MMF_ICommand_Single;
	//
	typedef struct 
	{
		uint32_t				ProcessID;
		uint32_t				Position;
		MMF_ICommand_Single		Command[100];
	} MMF_ICommand;
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
		MMF_ICommand			Command;
		//MMF_IFollow				Follow;
	} MMF_Global;

]];

-- Shared Memory Variables
local shared    = T{ };
shared.map      = nil;
shared.view     = nil;
shared.mem      = nil;

--Global variables for Command Position
local s_position = 0;

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

	--Set the current command position
	s_position = shared.mem.Command.Position;

	daoc.chat.msg(daoc.chat.message_mode.help, ('Initial s_pos %d'):fmt(s_position));

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

    if ((args[1]:any('ms') and e.imode == daoc.chat.input_mode.slash) or args[1]:any('/ms')) then
        e.blocked = true;

		if (#args == 1) then return; end

		-- Command: send
		if ((args[2]:any('send'))) then

			if (args[3] == nil) then return; end

			if (shared.mem == nil) then
				daoc.chat.msg(daoc.chat.message_mode.help, ('%s shm fail'):fmt(args[2]));
				return;
			end

			local procId = C.GetProcessId(C.GetCurrentProcess());

			local command = args[3];
			if (#args > 3) then
				for i=4, #args do
					command = command:append(" ");
					command = command:append(args[i]);
				end
			end

			SendCommand(command);

			--for i=0, 100 do
			--	if (shared.mem.Name.Names[i].Active == 1) then
			--		if (shared.mem.Name.Names[i].Process ~= procId) then
			--		shared.mem.Name.Names[i].Active = 1;
			--		shared.mem.Name.Names[i].Process = procId;
			--		end
			--	end
			--end
			return;
		end

		-- Command: write
		if ((args[2]:any('write'))) then

			if (shared.mem == nil) then
				daoc.chat.msg(daoc.chat.message_mode.help, ('%s shm fail'):fmt(args[2]));
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
		end
		-- Command: read
		if ((args[2]:any('read'))) then

			if (shared.mem == nil) then
				daoc.chat.msg(daoc.chat.message_mode.help, ('%s shm fail'):fmt(args[2]));
				return;
			end

			for i=0, 100 do
				if (shared.mem.Name.Names[i].Active == 1) then
					daoc.chat.msg(daoc.chat.message_mode.help, ('Char %d: %d'):fmt(i, shared.mem.Name.Names[i].Process));
				end
			end
			return;
		end

		-- Command: clear
		if ((args[2]:any('clear'))) then

			if (shared.mem == nil) then
				daoc.chat.msg(daoc.chat.message_mode.help, ('%s shm fail'):fmt(args[2]));
				return;
			end

			--Set everything inactive
			for i=0, 100 do
				shared.mem.Name.Names[i].Active = 0;
				shared.mem.Name.Names[i].Process = 0;
			end

			return;
		end
        return;
    end



end);

--[[
* event: d3d_present
* desc : Called when the Direct3D device is presenting a scene.
--]]
hook.events.register('d3d_present', 'd3d_present_cb', function ()


	--Check for command, executes every frame
	ReadCommand();
end);


--[[
* function: ReadCommand
* desc : Loop for receiving commands
--]]
function ReadCommand ()

	local procId = C.GetProcessId(C.GetCurrentProcess());

	if (shared.mem.Command.Command[s_position].active == 1) then
		--If this process is sender, don't execute the command -- need to update to support sending to all
		if (shared.mem.Command.Command[s_position].sender_process_id ~= procId) then
			daoc.chat.msg(daoc.chat.message_mode.help, ('Reading command: %s'):fmt(ffi.string(shared.mem.Command.Command[s_position].command)));
			daoc.chat.exec(daoc.chat.command_mode.typed, daoc.chat.input_mode.normal, ffi.string(shared.mem.Command.Command[s_position].command));
		end
		s_position = s_position + 1;
		if (s_position == 100) then s_position = 0; end
		return true;
	end

	return false;
end

--[[
* function: Send
* desc : Send Command to target process
--]]
function SendCommand (cmd)
	local procId = C.GetProcessId(C.GetCurrentProcess());
	local NextPosition = shared.mem.Command.Position + 1;
	if (NextPosition == 100) then NextPosition = 0; end

	--Set the next position to false
	shared.mem.Command.Command[NextPosition].active = false;

	--Reset the current position
	shared.mem.Command.Command[shared.mem.Command.Position].command = "";

	--Set the current command
	shared.mem.Command.Command[shared.mem.Command.Position].sender_process_id = procId;
	shared.mem.Command.Command[shared.mem.Command.Position].command = cmd;
	shared.mem.Command.Command[shared.mem.Command.Position].active = true;
	daoc.chat.msg(daoc.chat.message_mode.help, ('active:%s Spos: %d command %s'):fmt(tostring(shared.mem.Command.Command[shared.mem.Command.Position].active),shared.mem.Command.Position, cmd));
	--Move the position + 1
	shared.mem.Command.Position = NextPosition;
end