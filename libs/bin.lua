-- BIN
-- binary reading and writing for ComputerCraft FS API
-- lib by BigBang1112
-- license: MIT

bin = {
    handle = nil
}

function bin.write_string(self, str, no_prefix)
    local h = self.handle

    if str == nil then
        h.write(0)
    else
        if #str > 255 then
            error("string longer than 255")
        end

        if not no_prefix then
            h.write(#str)
        end

        h.write(str)
    end
end

function bin.write_byte(self, n)
    self.handle.write(n)
end

function bin.write_short(self, n) ----
    local h = self.handle
    h.write(bit.band(n, 255))
    h.write(bit.band(bit.brshift(n, 8), 255))
end

function bin.read_string(self, length)
    local h = self.handle

    local len = length
    if len == nil then
        len = h.read()
    end

    if len > 255 then
        error("string longer than 255")
    end

    return h.read(len)
end

function bin.read_byte(self)
    return self.handle.read()
end

function bin.read_short(self)
    local h = self.handle
    return bit.bor(h.read(), bit.blshift(h.read(), 8))
end