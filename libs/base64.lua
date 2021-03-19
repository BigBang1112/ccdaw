-- base64
-- from/to stream conversion of base64 for ComputerCraft FS API
-- lib by BigBang1112
-- license: MIT

base64 = {
    table = {
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P",
        "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e", "f",
        "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v",
        "w", "x", "y", "z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "+", "/"
    }
}

-- to_base64(in_handle, out_handle)
-- args:
--   in_handle:
--   out_handle:
function base64.to_base64(self, in_handle, out_handle)
    local num = nil
    repeat
        num = nil
        local num_size = 4 -- byte size
        for i = 1, 3 do
            local byte = in_handle.read()
            if byte == nil then
                if i ~= 1 then
                    num_size = i
                end
                break
            else
                if num == nil then
                    num = byte
                else
                    num = bit.bor(num, bit.blshift(byte, 8 * (i - 1)))
                end
            end
        end
        if num ~= nil then
            for i = 1, num_size do
                local index = bit.band(bit.brshift(num, 6 * (i - 1)), 63) 
                local byte = string.byte(self.table[index + 1])
                out_handle.write(byte)
            end
        end
    until num == nil
end

function base64.from_base64(self, in_handle, out_handle)
    local indicies = nil
    repeat
        indicies = {}
        for i = 1, 4 do
            local byte = in_handle.read()
            if byte == nil then
                break
            else
                local char = string.char(byte)
                local index = 0
                for i, c in pairs(self.table) do
                    if char == c then
                        indicies[i] = c
                        break
                    end
                end
            end
        end
        if #indicies > 0 then
            local num = 0
            for i = 1, #indicies do
                local index = indicies[i]
                num = bit.bor(num, bit.blshift(index, 6 * (i - 1)))
            end
            for i = 1, #indicies do
                local byte = bit.band(bit.brshift(num, 8 * (i - 1)), 255)
                out_handle.write(byte)
            end
        end
    until #indicies < 4
end