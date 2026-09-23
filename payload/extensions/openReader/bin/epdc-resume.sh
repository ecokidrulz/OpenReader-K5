#!/bin/sh

LUAJIT="/mnt/us/koreader/luajit"
WINDOW="${1:-10}"

[ -x "$LUAJIT" ] || exit 0

case "$WINDOW" in
    ''|*[!0-9]*)
        echo "EPDC: invalid retry window '$WINDOW'"
        exit 1
        ;;
esac

"$LUAJIT" - "$WINDOW" <<'LUA'
local ffi = require("ffi")

ffi.cdef[[
int open(const char *pathname, int flags);
int close(int fd);
int ioctl(int fd, unsigned long request, void *arg);
unsigned int sleep(unsigned int seconds);
]]

local C = ffi.C

local O_RDWR = 2
local MXCFB_GET_PAUSE  = 0x40044634
local MXCFB_SET_RESUME = 0x40044635

local window = tonumber(arg[1]) or 10

local function check_and_resume()
    local fd = C.open("/dev/fb0", O_RDWR)

    if fd < 0 then
        return false, "open /dev/fb0 failed"
    end

    local value = ffi.new("uint32_t[1]", 0)
    local rc = C.ioctl(fd, MXCFB_GET_PAUSE, value)

    if rc ~= 0 then
        C.close(fd)
        return false, "GET_PAUSE failed"
    end

    local paused = tonumber(value[0])

    if paused == 1 then
        value[0] = 0
        rc = C.ioctl(fd, MXCFB_SET_RESUME, value)

        if rc ~= 0 then
            C.close(fd)
            return false, "SET_RESUME failed"
        end

        print("EPDC: resumed paused framebuffer")
    end

    C.close(fd)
    return true
end

-- Check immediately, then once per second for the requested window.
for second = 0, window do
    local ok, err = check_and_resume()

    if not ok then
        print("EPDC: " .. err)
    end

    if second < window then
        C.sleep(1)
    end
end

os.exit(0)
LUA
