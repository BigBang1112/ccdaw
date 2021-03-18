-- BIN
-- binary reading and writing for ComputerCraft FS API
-- lib by BigBang1112
-- license: MIT

bin = {
    handle = nil
}

bin.write_string = function (self, str, no_prefix)
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

        for i = 1, #str do
            local c = str:sub(i,i)
            h.write(string.byte(c))
        end
    end
end

bin.write_byte = function (self, n)
    self.handle.write(n)
end

bin.write_short = function (self, n) ----
    local h = self.handle
    h.write(bit.band(n, 255))
    h.write(bit.band(bit.brshift(n, 8), 255))
end

bin.read_string = function (self, length)
    local h = self.handle

    local len = length
    if len == nil then
        len = h.read()
    end

    if len > 255 then
        error("string longer than 255")
    end

    local chars = {}
    for i = 1, len do
        table.insert(chars, string.char(h.read()))
    end
    return table.concat(chars)
end

bin.read_byte = function (self)
    return self.handle.read()
end

bin.read_short = function (self)
    local h = self.handle
    return bit.bor(h.read(), bit.blshift(h.read(), 8))
end