local bitlib = bit32 or bit
local ffi = require("ffi")

local YOUR_NAME = "lavlua"

local ANIM_FRAMES = {
    "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"
}
local ANIM_SPEED = 0.15
local WAVE_SPEED = 0.2

pcall(ffi.cdef, [[
    typedef void* (__cdecl *InstantiateInterfaceFn_t)();
    typedef struct CInterfaceRegister {
        InstantiateInterfaceFn_t fnCreate;
        const char* szName;
        struct CInterfaceRegister* pNext;
    } CInterfaceRegister;
    typedef struct {
        const char* szName;
        void* m_pNext;
        char pad1[0x10];
        const char* szDescription;
        uint32_t nType;
        uint32_t nRegistered;
        uint32_t nFlags;
        char pad2[0x15];
        union {
            uint8_t i1; short i16; uint16_t u16; int i32; uint32_t u32;
            int64_t i64; uint64_t u64; float fl; double db; const char* sz;
        } value;
    } CConVar;
    typedef struct {
        CConVar* element;
        unsigned short prev;
        unsigned short next;
    } UtlLinkedListElement_t;
    typedef struct {
        int size;
        UtlLinkedListElement_t* data;
    } CUtlLeanVector;
    typedef struct {
        CUtlLeanVector memory;
        unsigned short iHead;
        unsigned short iTail;
        unsigned short iFirstFree;
        unsigned short nElementCount;
        unsigned short nAllocated;
        UtlLinkedListElement_t* pElements;
    } CUtlLinkedList;
    typedef struct {
        char pad[0x40];
        CUtlLinkedList listConvars;
    } IEngineCVar;
]])

local enabled = Menu.Checker("Nick Changer", false)

local MAX_NAME_LEN = 127
local OFFSETS = {
    DIRTY = 0x954,
    NAME  = 0x6F8,
    LOCAL_PLAYER_CONTROLLER = 0x22F4188,
}
local PTR_MIN = 0x10000
local PTR_MAX = 0x7FFFFFFFFFFF

local original_name     = nil
local last_name         = nil
local was_enabled       = false
local client_base       = nil
local cached_ctrl       = nil
local cvar_name_patched = false
local anim_frame        = 1
local wave_index        = 1
local last_anim_time    = 0
local last_wave_time    = 0
local last_update       = 0
local UPDATE_RATE       = 0.05

local function safe_call(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

local function trim_name(text)
    text = tostring(text or "")
    if #text > MAX_NAME_LEN then return text:sub(1, MAX_NAME_LEN) end
    return text
end

local function escape(value)
    value = tostring(value or "")
    value = value:gsub("\\", "\\\\")
    value = value:gsub('"', '\\"')
    return value
end

local function is_valid_ptr(value)
    return type(value) == "number" and value >= PTR_MIN and value <= PTR_MAX
end

local function invalidate_pointers()
    client_base = nil
    cached_ctrl = nil
end

local function find_client_base()
    if client_base then return client_base end
    local pat = safe_call(Cheat.FindPattern, "client.dll", "48 8B 05 ? ? ? ? 48 85 C0 74")
    if not pat or pat == 0 then return nil end
    local base = safe_call(function()
        local addr = tonumber(ffi.cast("uintptr_t", pat))
        addr = addr - (addr % 0x1000)
        for i = 0, 3000 do
            local try = addr - (i * 0x1000)
            local ok, mz = pcall(function() return ffi.cast("uint16_t*", try)[0] end)
            if ok and mz == 0x5A4D then return try end
        end
        return nil
    end)
    client_base = base
    return client_base
end

local function get_local_controller_ptr()
    if not Globals.IsConnected() then invalidate_pointers() return nil end
    if cached_ctrl then
        local alive = safe_call(function()
            return ffi.cast("uint8_t*", cached_ctrl + OFFSETS.NAME)[0] ~= nil
        end)
        if alive then return cached_ctrl end
        invalidate_pointers()
    end
    local base = find_client_base()
    if not base then return nil end
    local ctrl = safe_call(function()
        return tonumber(ffi.cast("uint64_t*", base + OFFSETS.LOCAL_PLAYER_CONTROLLER)[0])
    end)
    if not ctrl or ctrl == 0 or not is_valid_ptr(ctrl) then invalidate_pointers() return nil end
    cached_ctrl = ctrl
    return cached_ctrl
end

local function patch_cvar_name()
    if cvar_name_patched then return true end
    local ok = safe_call(function()
        local ci_fn = Cheat.FindExport("tier0.dll", "CreateInterface")
        if not ci_fn or ci_fn == 0 then return false end
        local rva = ffi.cast("int32_t*", ci_fn + 3)[0]
        local reg = ffi.cast("CInterfaceRegister**", ffi.cast("uintptr_t", ci_fn) + 7 + rva)[0]
        local icvar = nil
        while reg ~= nil do
            local name_ok, iface_name = pcall(function() return ffi.string(reg.szName) end)
            if name_ok and iface_name:find("VEngineCvar", 1, true) then
                icvar = ffi.cast("IEngineCVar*", reg.fnCreate())
                break
            end
            reg = reg.pNext
        end
        if not icvar then return false end
        local list = icvar.listConvars
        for i = list.iHead, list.iTail do
            local elem_ok, elem = pcall(function() return list.memory.data[i].element end)
            if elem_ok and elem ~= nil then
                local name_ok, cvar_name = pcall(function() return ffi.string(elem.szName) end)
                if name_ok and cvar_name == "name" then
                    elem.nFlags = 33408
                    return true
                end
            end
        end
        return false
    end)
    cvar_name_patched = ok == true
    return cvar_name_patched
end

local function write_display_name(text)
    local ctrl = get_local_controller_ptr()
    if not ctrl or not is_valid_ptr(ctrl) or not Globals.IsConnected() then return false end
    text = trim_name(text)
    return safe_call(function()
        local ptr = ffi.cast("uint8_t*", ctrl + OFFSETS.NAME)
        for i = 1, #text do ptr[i - 1] = text:byte(i) end
        ptr[#text] = 0
        ffi.cast("uint8_t*", ctrl + OFFSETS.DIRTY)[0] = 1
        return true
    end) == true
end

local function send_name(text)
    text = trim_name(text)
    if text == "" or text == last_name then return end
    last_name = text
    write_display_name(text)
    if patch_cvar_name() then
        pcall(CVar.ExecuteClientCmd, 'setinfo name "' .. escape(text) .. '"')
    end
end

local function read_current_name()
    return safe_call(function()
        local name_var = CVar.FindVar("name")
        return name_var and name_var:GetString() or nil
    end)
end

local function restore_original_name()
    if original_name and original_name ~= "" then send_name(original_name) end
    original_name = nil
    last_name = nil
    invalidate_pointers()
end

local function apply_wave(text, index)
    local result = ""
    for i = 1, #text do
        local ch = text:sub(i, i)
        if i == index then
            result = result .. ch:upper()
        else
            result = result .. ch:lower()
        end
    end
    return result
end

local function build_name()
    local spinner = ANIM_FRAMES[anim_frame]
    local prefix  = apply_wave(YOUR_NAME, wave_index)
    return spinner .. " " .. prefix .. " | " .. (original_name or "")
end

Cheat.RegisterCallback("OnRenderer", function()
    local ok, err = pcall(function()
        local active = enabled:GetBool()

        if not active or not Globals.IsConnected() then
            if was_enabled then restore_original_name() end
            was_enabled = false
            return
        end

        if not was_enabled then
            original_name = read_current_name() or "player"
            last_name = nil
            anim_frame = 1
            wave_index = 1
            was_enabled = true
        end

        local now = Globals.GetCurrentTime()

        if now - last_anim_time >= ANIM_SPEED then
            anim_frame = (anim_frame % #ANIM_FRAMES) + 1
            last_anim_time = now
        end

        if now - last_wave_time >= WAVE_SPEED then
            wave_index = (wave_index % #YOUR_NAME) + 1
            last_wave_time = now
        end

        if now - last_update >= UPDATE_RATE then
            send_name(build_name())
            last_update = now
        end
    end)

    if not ok then
        print("[NickChanger] " .. tostring(err))
    end
end)