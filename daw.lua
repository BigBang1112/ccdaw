local arg = {...}

require("libs/bin")
require("libs/base64")
require("libs/ccdaw")
require("libs/essentials")

local cur_term = term.current()

local function clear_term()
    cur_term.clear()
    cur_term.setCursorPos(1, 1)
end

trackpanel_width = 13
keyboard_width = 4

local function update_monitor()
    clear_term()
    sizeX, sizeY = cur_term.getSize()
    sequence_width = sizeX - trackpanel_width - keyboard_width - 2
end

is_monitor = cur_term.setTextScale ~= nil
if is_monitor then
    cur_term.setTextScale(0.5)
end

update_monitor()

if sizeX <= 20 then
    write("Resolution of this monitor is incompatible with DAW. Please provide a 1x2 monitor or bigger.")
    return
end

stereo = false

current_version = 1

command_history = {}

devices = {
    speaker_left = {
        type = "speaker"
    },
    speaker_right = {
        type = "speaker"
    },
    speaker_mono = {
        type = "speaker"
    },
    speakers = {},
    visualizer = {
        type = "monitor"
    },
    lyrics = {
        type = "monitor"
    },
    streamer = {
        type = "computer"
    },
    log = {
        type = "monitor"
    }
}

speaker = peripheral.find("speaker");
if speaker then
    devices.speaker_mono.periph = speaker;
end

local periph_left = peripheral.wrap("left")
local periph_right = peripheral.wrap("right")

if periph_left ~= nil and periph_right ~= nil then
    if peripheral.getType(periph_left) == "speaker" and peripheral.getType(periph_right) == "speaker" then
        devices.speaker_left.periph = periph_left;
        devices.speaker_right.periph = periph_right;
        stereo = true
    end
end

--m_visualizer = nil;
--if m_visualizer ~= nil and peripheral.getType("top") == "monitor" then
--	m_visualizer.setTextScale(1)
--	m_visualizer.clear()
--end

--m_output = nil--peripheral.wrap("top")
--if m_output ~= nil and peripheral.getType("top") == "monitor" then
--	m_output.setTextScale(0.5)
--	m_output.clear()
--	m_output.setCursorPos(1,1)
--end

--c_streamer = nil--peripheral.wrap("computer_31")
--rednet.open("back")

start = os.epoch("utc")
timeline = 0
timeline_offset = 0
instrument = "Harp"
volume = 3
terminate = false
play = nil
loop = 0
delay = 0
delayBalance = 0
forcePause = false
typing = ""
period = 0
mode = "default"
lyrics_timeline = 0
key_shift = 0
selected_note = nil

project = {}
project.name = "New project"
project.version = current_version
project.author = ""
project.bpm = 120
project.scale = 1/16
project.tracks = {
    Basedrum = { volume = 1, instrument = "basedrum", chords = {} },
    Bass = { volume = 1, instrument = "bass", chords = {} },
    Bell = { volume = 1, instrument = "bell", chords = {} },
    Chime = { volume = 1, instrument = "chime", chords = {} },
    Flute = { volume = 1, instrument = "flute", chords = {} },
    Guitar = { volume = 1, instrument = "guitar", chords = {} },
    Harp = { volume = 1, instrument = "harp", chords = {} },
    Hat = { volume = 1, instrument = "hat", chords = {} },
    Pling = { volume = 1, instrument = "pling", chords = {} },
    Snare = { volume = 1, instrument = "snare", chords = {} },
    Xylophone = { volume = 1, instrument = "xylophone", chords = {} }
}
project.lyrics = {}

uiInstrument = 4

periph = {}
periph.speakers = {}
periph.speakers.left = ""
periph.speakers.right = ""
periph.speakers.mono = ""
periph.modems = {}

scroll_sequence = 0
scroll_timeline = 0
scroll_instruments = 0

clipboard_chords = {}

notes = {"F#1", "G1", "G#1", "A1", "A#1", "B1", "C2",
        "C#2", "D2", "D#2", "E2", "F2", "F#2",
        "G2", "G#2", "A2", "A#2", "B2", "C3",
        "C#3", "D3", "D#3", "E3", "F3", "F#3"}
        
instruments = {"basedrum", "bass", "bell", "chime",
        "flute", "guitar", "harp", "hat", "pling",
        "snare", "xylophone"}

major = {2, 2, 1, 2, 2, 2, 1}
minor = {2, 1, 2, 2, 1, 2, 2}

function project_has_chords(p)
    for name, track in pairs(p.tracks) do
        if next(track.chords) ~= nil then
            return true;
        end
    end

    return false;
end

function daw_load(p)
    if p ~= nil then
        table_merge(project, p);

        if p.version == nil or p.version == 0 then
            for name, track in pairs(project.tracks) do
                for time, chord in pairs(track.chords) do
                    local new_chord = {}
                    
                    for key, note in pairs(chord) do
                        new_chord[key + 1] = note;
                    end

                    project.tracks[name].chords[time] = new_chord;
                end
            end
        end
    end

    project.version = current_version
end

function daw_save()
    if filename ~= nil and fs.getFreeSpace(fs.getDir(filename)) > 0 then
        --local h = fs.open(filename, "w");
        --local song_data = textutils.serialize(project);
        --song_data = song_data:gsub('%c', ''); -- Removes new lines
        --song_data = song_data:gsub(" +"," "); -- Removes double spaces
        --song_data = song_data:gsub('%s=%s', '='); -- Removes spaces between equals
        --song_data = song_data:gsub('%[%s(%d+)%s%]', '%[%1%]'); -- Removes spaces between indexes
        --h.write(song_data);
        
        bin.handle = fs.open(filename, "wb");

        if version == nil or version == 0 then
            bin:write_string("CCSONG", true)
            bin:write_byte(project.version)
            bin:write_string(project.name)
            bin:write_string(project.author)
            bin:write_short(project.bpm)
            bin:write_byte(1/project.scale)

            bin:write_byte(table_count(project.tracks))
            for name, track in pairs(project.tracks) do
                bin:write_string(name)
                bin:write_string(track.instrument)
                if track.volume == nil then
                    bin:write_byte(1/3*255)
                else
                    bin:write_byte(track.volume/3*255)
                end
                bin:write_short(table_count(track.chords))
                for time, chord in pairs(track.chords) do
                    bin:write_short(time)
                    bin:write_byte(table_count(chord))
                    for key, note in pairs(chord) do
                        bin:write_byte(key)
                        bin:write_byte(0) -- flags
                    end
                end
            end

            bin:write_byte(table_count(project.lyrics))
            for time, part in pairs(project.lyrics) do
                bin:write_short(time)
                bin:write_string(part.text)
                if part.type == nil then
                    bin:write_byte(0)
                elseif part.type == "nv" then
                    bin:write_byte(1)
                elseif part.type == "ns" then
                    bin:write_byte(2)
                end
            end
        else
            error("version 0 file")
        end

        bin.handle.close();
    end
end

filename = arg[1];

programdir = fs.getDir(shell.getRunningProgram())

if filename ~= nil then
    if not fs.exists(filename) then
        filename = filename .. ".song";
    end

    if fs.exists(filename) then
        if fs.getSize(filename) == 0 then
            error("Empty file")
        else
            local h = fs.open(filename, "r")

            local song_data = h.readAll()
            local song_table = textutils.unserialize(song_data)

            if song_table == nil then
                h.close()

                bin.handle = fs.open(filename, "rb")
                local magic = bin:read_string(6)

                if magic ~= "CCSONG" then
                    error("Not a CCSONG or corrupted file")
                end

                song_table = {}
                song_table.version = bin:read_byte()
                song_table.name = bin:read_string()
                song_table.author = bin:read_string()
                song_table.bpm = bin:read_short()
                song_table.scale = 1/bin:read_byte()
                song_table.tracks = {}
                
                local num_tracks = bin:read_byte()
                for i=1, num_tracks do
                    local track = {}
                    local track_name = bin:read_string()
                    track.instrument = bin:read_string()
                    track.volume = bin:read_byte() / 255 * 3
                    track.chords = {}

                    local num_chords = bin:read_short()
                    for j=1, num_chords do
                        local chord = {}
                        local time = bin:read_short()
                        local num_notes = bin:read_byte()
                        for k=1, num_notes do
                            local note = {}
                            local key = bin:read_byte()
                            local flags = bin:read_byte()

                            chord[key] = note
                        end

                        track.chords[time] = chord;
                    end

                    song_table.tracks[track_name] = track
                end

                local num_lyrics_parts = bin:read_byte()

                if num_lyrics_parts ~= nil then
                    for i=1, num_lyrics_parts do
                        local part = {}
                        local time = bin:read_short()
                        part.text = bin:read_string()
                        
                        local type = bin:read_byte()
                        if type == 1 then
                            part.type = "nv"
                        elseif type == 2 then
                            part.type = "ns"
                        end

                        project.lyrics[time] = part
                    end
                end

                bin.handle.close()
            else
                h.close()
            end

            daw_load(song_table);
        end
    else
        daw_save()
    end
end

function get_delay()
    return (os.epoch("utc") - play)/1000 - timeline/4/project.bpm*60
end

function windowLoop()
    local winSizeX, winSizeY = 28, 5
    winLoop = window.create(term.current(), sizeX/2-winSizeX/2+1, sizeY/2-winSizeY/2+1, winSizeX, winSizeY, false)
    winLoop.setBackgroundColor(colors.lightBlue)
    winLoop.clear()
    winLoop.setBackgroundColor(colors.blue)
    winLoop.write("Create a loop              ")
    winLoop.setBackgroundColor(colors.red)
    winLoop.write("X")
    winLoop.setBackgroundColor(colors.lightBlue)
    winLoop.setCursorPos(3, 3)
    winLoop.write("Loop the song after this")
    winLoop.setCursorPos(3, 4)
    winLoop.write("amount of beats: ")
end

function windowAddInstrument()
    local winSizeX, winSizeY = 28, 14
    winAddInst = window.create(term.current(), sizeX/2-winSizeX/2+1, sizeY/2-winSizeY/2+1, winSizeX, winSizeY, false)
    winAddInst.setBackgroundColor(colors.lightBlue)
    winAddInst.clear()
    winAddInst.setBackgroundColor(colors.blue)
    winAddInst.write("Add an instrument          ")
    winAddInst.setBackgroundColor(colors.red)
    winAddInst.write("X")
    winAddInst.setBackgroundColor(colors.lightBlue)

    winAddInst.setCursorPos(2,13)
    winAddInst.setBackgroundColor(colors.green)
    winAddInst.write("     Add     ")

    for i,inst in pairs(instruments) do
        winAddInst.setCursorPos(17,2+i)
        winAddInst.setBackgroundColor(colors.lightGray)
        winAddInst.write(" " .. inst)
        winAddInst.write(string.rep(" ", 10-string.len(inst)))
    end
end

windowLoop()
windowAddInstrument()

function visualize_note(vol, note)
    local v = devices.visualizer.periph;
    if v ~= nil then
        local longest = 9
        local sX, sY = v.getSize()
        local c = #notes
        if note <= 7 then
            v.setBackgroundColor(colors.red)
        elseif note <= 14 then
            v.setBackgroundColor(colors.orange)
        elseif note <= 21 then
            v.setBackgroundColor(colors.yellow)
        elseif note <= 28 then
            v.setBackgroundColor(colors.lightBlue)
        end
        
        for i=sY-longest+math.floor(note/4),sY do
            v.setCursorPos((sX - c) / 2 + note, i)
            v.write(" ")
        end
        v.setBackgroundColor(colors.black)
    end
end

function daw_play()
    if play == nil then
        play = os.epoch("utc")
        timeline = timeline_offset
        if scroll_timeline > timeline_offset then
            scroll_timeline = timeline_offset
        end
    else
        if loop > 0 then
            loop = 0
        end
        timeline = timeline_offset
        play = nil
    end
end

function daw_export()
    local rh = fs.open(filename, "rb")
    local wh = fs.open(filename .. ".export", "wb")

    base64:to_base64(rh, wh)

    rh.close()
    wh.close()
end

function get_song_length()
    local length = 0

    for name, track in pairs(project.tracks) do
        for time, chord in pairs(track.chords) do
            if time > length then
                length = time
            end
        end
    end

    return length
end

function event()
    while not terminate do
        local event,p1,p2,p3,p4 = os.pullEventRaw()

        if typing == "" then
            if event == "mouse_scroll" then
                local dir = p1
                local x = p2
                local y = p3

                if mode == "default" then
                    if x >= 15 and y >= 4 then
                        scroll_sequence = clamp(scroll_sequence + dir, 0, 10)
                    end
                elseif mode == "lyrics" then
                    scroll_timeline = scroll_timeline + dir
                end
            elseif event == "mouse_click" then
                local num = p1
                local x = p2
                local y = p3

                if mode == "default" then
                    local counter = 0

                    if x <= 11 then
                        for name,track in pairs(project.tracks) do
                            if y == uiInstrument+counter then
                                instrument = name
                            end
                            counter = counter + 1
                        end
                    end

                    if x >= 18 and x <= sizeX-2 and y == 3 then -- begin stamp
                        local new_offset = x - 18 + scroll_timeline
                        if new_offset >= 0 and new_offset % 4 == 0 then
                            timeline_offset = new_offset
                            if play == nil then
                                timeline = timeline_offset
                            end
                        end
                    end
                    if x >= 18 and x <= sizeX-2 and y >= 4 and y <= sizeY-1 and project.tracks[instrument] ~= nil then -- piano roll
                        local key = 34 - 5 - y - scroll_sequence
                        local time = x - 17 + scroll_timeline

                        local chords = project.tracks[instrument].chords

                        if time > 0 and time <= 65535 then -- file format limitation
                            if chords == nil then
                                chords = {}
                            end

                            if chords[time] == nil then
                                chords[time] = {}
                            end

                            if chords[time][key] ~= nil then
                                if num == 1 then
                                    chords[time][key] = nil
                                    local count = 0
                                    for key, note in pairs(chords[time]) do
                                        count = count + 1
                                    end
                                    if count == 0 then
                                        chords[time] = nil
                                    end
                                elseif num == 2 then
                                    if selected_note == chords[time][key] then
                                        selected_note = nil
                                    else
                                        selected_note = chords[time][key]
                                    end
                                end
                            elseif num == 1 then
                                local note = {}

                                local track = project.tracks[instrument]
                                track.chords[time][key] = note

                                local track_volume = 1
                                if track.volume ~= nil then
                                    track_volume = track.volume
                                end

                                local s_mono = devices.speaker_mono.periph;

                                if track.sound ~= nil then
                                    if stereo then
                                        if devices.speaker_left.periph ~= nil then
                                            devices.speaker_left.periph.playSound(track.sound, volume*track_volume*1, 2 ^ ((key-1 - 12) / 12)) -- 1 in volume means default volume
                                        end
                                        if devices.speaker_right.periph ~= nil then
                                            devices.speaker_right.periph.playSound(track.sound, volume*track_volume.volume*1, 2 ^ ((key-1 - 12) / 12))
                                        end
                                    elseif s_mono ~= nil then
                                        s_mono.playSound(track.sound, volume*track_volume*1, 2 ^ ((key-1 - 12) / 12))
                                    end
                                end
                                if track.instrument ~= nil then
                                    if stereo then
                                        if devices.speaker_left.periph ~= nil then
                                            devices.speaker_left.periph.playNote(track.instrument, volume*track_volume*1, key-1+key_shift)
                                        end
                                        if devices.speaker_right.periph ~= nil then
                                            devices.speaker_right.periph.playNote(track.instrument, volume*track_volume*1, key-1+key_shift)
                                        end
                                    elseif s_mono ~= nil then
                                        s_mono.playNote(track.instrument, volume*track_volume*1, key-1+key_shift)
                                    end

                                    if devices.visualizer.periph ~= nil then
                                        visualize_note(1, key+key_shift)
                                    end
                                end
                            end
                        end
                        
                        daw_save()
                    end

                    if y >= 4 and y <= 12 then
                        if x == sizeX then
                            scroll_timeline = scroll_timeline + 4 -- when click on next 4 beats
                        elseif x == sizeX-1 then
                            scroll_timeline = scroll_timeline - 4 -- when click on previous 4 beats
                        end
                    end
                end
                if mode == "lyrics" then
                    if y >= 4 and y <= sizeY-1 then
                        local i = y - 4 + scroll_timeline
                        if x == 1 then
                            if i >= 0 then
                                timeline_offset = i
                                if play == nil then
                                    timeline = timeline_offset
                                end
                            end
                        elseif x >= 2 and x <= 3 then
                            if project.lyrics == nil then
                                project.lyrics = {}
                            end
                            if project.lyrics[i+1] == nil then
                                project.lyrics[i+1] = {}
                            end

                            local part = project.lyrics[i+1]

                            if part.type == nil then
                                part.type = "nv" -- New verse
                            elseif part.type == "nv" then
                                part.type = "ns" -- New stanza
                            else
                                part.type = nil
                            end

                            if part.type == nil and (part.text == nil or part.text == "") then
                                project.lyrics[i+1] = nil
                            end

                            daw_save()
                        elseif x >= 5 and x <= sizeX - 3 then
                            lyrics_timeline = i+1
                            typing = "lyrics"
                        end
                    end
                end
                if x >= 28 and x <= 30 and y == 2 then -- when click on BPM
                    typing = "bpm"
                end
                if num == 1 and x >= 8 and x <= 11 and y == 2 then -- when click on Play
                    daw_play()
                end

                if x >= sizeX - 1 and x <= sizeX then
                    if y == sizeY-2 then
                        if mode == "default" then
                            if scroll_sequence > 0 then
                                scroll_sequence = scroll_sequence - 1
                            end
                        elseif mode == "lyrics" then
                            scroll_timeline = scroll_timeline - 4
                        end
                    elseif y == sizeY-1 then
                        if mode == "default" then
                            if scroll_sequence < #notes - 15 then
                                scroll_sequence = scroll_sequence + 1
                            end
                        elseif mode == "lyrics" then
                            scroll_timeline = scroll_timeline + 4
                        end
                    end
                end

                if x >= 32 and x <= 38 and y == 2 then -- when click on Lyrics
                    if mode == "default" then
                        if project.lyrics == nil then
                            project.lyrics = {}
                        end
                        mode = "lyrics"
                    elseif mode == "lyrics" then
                        mode = "default"
                    end
                end

                if num == 2 then
                    if x >= 8 and x <= 11 and y == 2 then -- when right click on Play ala Loop
                        if play == nil then
                            winLoop.setVisible(true)
                            typing = "beats"
                        end
                    end
                end
            elseif event == "key" then
                local key_name = keys.getName(p1)
                local held = p2

                if not held then
                    if key_name == "space" then
                        daw_play()
                    elseif key_name == "enter" then -- Enter
                        typing = "console"
                    elseif key_name == "w" then -- W
                        timeline_offset = 0
                        scroll_timeline = 0
                        timeline = 0
                    elseif key_name == "v" then -- V
                        scroll_timeline = timeline_offset
                    end
                end

                if mode == "default" then
                    if key_name == "left" then
                        scroll_timeline = scroll_timeline - 4
                    elseif key_name == "right" then
                        scroll_timeline = scroll_timeline + 4
                    elseif key_name == "up" then
                        scroll_sequence = clamp(scroll_sequence - 1, 0, 10)
                    elseif key_name == "down" then
                        scroll_sequence = clamp(scroll_sequence + 1, 0, 10)
                    end
                elseif mode == "lyrics" then
                    if key_name == "up" then
                        scroll_timeline = scroll_timeline - 1
                    elseif key_name == "down" then
                        scroll_timeline = scroll_timeline + 1
                    end
                end
            elseif event == "terminate" then
                clear_term();
                if filename == nil and project_has_chords(project) then
                    filename = "temp.song"
                    daw_save()
                    print("No file name specified.\nSong has been saved as temp.song");
                end
                terminate = true
            elseif event == "monitor_resize" then
                update_monitor()
            end
        end
    end
end

function audio()
    while not terminate do
        if play ~= nil then
            ccdaw:play_stamp()
        end

        sleep(0.05)
    end
end

local function console_autocomplete(text)
    local autocomplete = {}

    if text == "" then
        return autocomplete
    end

    local commands = {
        "w",
        "tl", "tl offset",
        "key",
        "copy",
        "shift",
        "device",
        "lyrics",
        "lyrics print",
        "name",
        "author",
        "e"
    }

    local periphs = peripheral.getNames()

    for name, device in pairs(devices) do
        table.insert(commands, "device " .. name)

        for i, periph in pairs(periphs) do
            if peripheral.getType(periph) == device.type then
                table.insert(commands, "device " .. name .. " " .. periph)
            end
        end
    end

    for i, periph in pairs(periphs) do
        if peripheral.getType(periph) == "printer" then
            table.insert(commands, "lyrics print " .. periph)
        end
    end

    for i, command in pairs(commands) do
        if text == command then
            return autocomplete
        end
    end

    for i,command in pairs(commands) do
        if command:sub(1, #text) == text and split(command:sub(#text+1), " ")[1] == command:sub(#text+1) then
            local compl = command:sub(#text+1)
            if compl ~= "" then
                table.insert(autocomplete, compl)
            end
        end
    end

    return autocomplete;
end

local function write_console_line(text)
    term.setCursorPos(3, sizeY-2)
    write(text)

    local t = os.startTimer(2)
    while true do
        local event,p1 = os.pullEvent()
        if (event == "timer" and t == p1) or event == "key" then
            break
        end
    end
end

function render()
    while not terminate do
        while typing == "bpm" do
            term.setCursorPos(27, 2)
            local newBpm = read(nil, nil, nil, tostring(project.bpm))
            if newBpm ~= "" and tonumber(newBpm) ~= nil then
                project.bpm = clamp(tonumber(newBpm), 1, 999)
            end
            typing = ""
        end

        while typing == "beats" do
            winLoop.setCursorPos(20, 4)
            local prevBg = term.getBackgroundColor()
            term.setBackgroundColor(colors.lightBlue)
            local beats = read(nil, nil, nil, "32")
            term.getBackgroundColor(prevBg)
            winLoop.setVisible(false)
            if tonumber(beats) ~= nil and tonumber(beats) < 9999 then
                loop = tonumber(beats)
                play = os.epoch("utc")
                timeline = 0
            else
                loop = 0
            end
            typing = ""
        end

        while typing == "lyrics" do
            term.setCursorPos(5, lyrics_timeline-scroll_timeline+3)

            local default = ""
            if project.lyrics ~= nil and project.lyrics[lyrics_timeline] ~= nil then
                default = project.lyrics[lyrics_timeline].text
            end

            local part = project.lyrics[lyrics_timeline]
            local text = read(nil, nil, nil, default)
            if text ~= nil and text ~= "" then
                if part == nil then
                    project.lyrics[lyrics_timeline] = {}
                end
                project.lyrics[lyrics_timeline].text = text
            elseif part ~= nil then
                project.lyrics[lyrics_timeline].text = nil

                if part.type == nil then
                    project.lyrics[lyrics_timeline] = nil
                end
            end
            daw_save()
            typing = ""
        end

        while typing == "console" do
            term.setCursorPos(3, sizeY-2)
            term.getBackgroundColor()
            for i=1,sizeX-4 do
                term.write(" ")
            end
            term.setCursorPos(3, sizeY-2)
            term.write(">")
            local cmd = read(nil, command_history, console_autocomplete)
            table.insert(command_history, cmd);
            local c = split(cmd, " ")
            if c[1] == "w" then
                timeline_offset = 0
                scroll_timeline = 0
                timeline = 0
            elseif c[1] == "tl" then -- tl
                if c[2] == "offset" then -- tl offset
                    local new_offset = tonumber(c[3]) -- tl offset [n]
                    if new_offset ~= nil then
                        timeline_offset = new_offset
                        scroll_timeline = new_offset
                    else
                        write_console_line("?tl offset [n]")
                    end
                else
                    write_console_line("?tl offset")
                end
            elseif c[1] == "key" then
                if c[2] ~= nil then -- key [n]
                    local n = tonumber(c[2])
                    if n ~= nil then
                        key_shift = n
                    end
                else
                    write_console_line("?key [n]")
                end
            elseif c[1] == "repeat" then -- repeat
                if c[2] ~= nil then -- repeat [n]
                    local n = tonumber(c[2])
                    if n ~= nil then
                        for i=1, n do
                            local chord = project.tracks[instrument].chords[timeline_offset+i]
                            if chord ~= nil then
                                if project.tracks[instrument].chords[timeline_offset+i+n] == nil then
                                    project.tracks[instrument].chords[timeline_offset+i+n] = {}
                                end
                                for key, note in pairs(chord) do
                                    local repeat_note = {}
                                    if note.vol ~= nil then
                                        repeat_note.vol = note.vol
                                    end
                                    if note.pan ~= nil then
                                        repeat_note.pan = note.pan
                                    end

                                    project.tracks[instrument].chords[timeline_offset+i+n][key] = repeat_note
                                end
                            end
                        end
                        daw_save()
                    end
                else
                    write_console_line("?copy [n]")
                end
            elseif c[1] == "copy" then -- copy
                if c[2] ~= nil then -- copy [n]
                    local n = tonumber(c[2])
                    if n ~= nil then
                        clipboard_chords = {}
                        for i=1, n do
                            local chord = project.tracks[instrument].chords[timeline_offset+i]
                            if chord ~= nil then
                                for key, note in pairs(chord) do
                                    local copy_note = {}
                                    if note.vol ~= nil then
                                        copy_note.vol = note.vol
                                    end
                                    if note.pan ~= nil then
                                        copy_note.pan = note.pan
                                    end

                                    if clipboard_chords[i] == nil then
                                        clipboard_chords[i] = {}
                                    end

                                    clipboard_chords[i][key] = note
                                end
                            end
                        end
                    end

                    write_console_line("Copied to clipboard.")
                else
                    write_console_line("?copy [n]")
                end
            elseif c[1] == "paste" then -- paste
                if clipboard_chords ~= nil then
                    for time, chord in pairs(clipboard_chords) do
                        for key, note in pairs(chord) do
                            if project.tracks[instrument].chords[timeline_offset+time] == nil then
                                project.tracks[instrument].chords[timeline_offset+time] = {}
                            end

                            project.tracks[instrument].chords[timeline_offset+time][key] = note
                        end
                    end
                    write_console_line("Pasted.")
                else
                    write_console_line("Nothing to paste.")
                end
            elseif c[1] == "shift" then -- shift
                if c[2] ~= nil then -- shift [n]
                    local n = tonumber(c[2])
                    if n ~= nil then
                        if c[3] ~= nil then -- shift [n] [k]
                            local k = tonumber(c[3])
                            if k ~= nil then
                                for i=0, k do
                                    local chord = project.tracks[instrument].chords[timeline_offset+i]
                                    if chord ~= nil then
                                        local copy_chord = {}
                                        for key, note in pairs(chord) do
                                            local copy_note = {}
                                            if note.vol ~= nil then
                                                copy_note.vol = note.vol
                                            end
                                            if note.pan ~= nil then
                                                copy_note.pan = note.pan
                                            end

                                            local f = 0
                                            
                                            if key+n < 0 then
                                                f = math.floor((key+n)/-12)+1
                                            end

                                            if key+n > 24 then
                                                f = math.floor((key+n)/-12)+1
                                            end

                                            copy_chord[key+n+f*12] = copy_note
                                        end

                                        project.tracks[instrument].chords[timeline_offset+i] = copy_chord;
                                    end
                                end
                                daw_save()
                            else
                                write_console_line("?shift "..n.." [k]")
                            end
                        else
                            for time, chord in pairs(project.tracks[instrument].chords) do
                                if chord ~= nil then
                                    local copy_chord = {}
                                    for key, note in pairs(chord) do
                                        local copy_note = {}
                                        if note.vol ~= nil then
                                            copy_note.vol = note.vol
                                        end
                                        if note.pan ~= nil then
                                            copy_note.pan = note.pan
                                        end

                                        local f = 0
                                        
                                        if key+n < 0 then
                                            f = math.floor((key+n)/-12)+1
                                        end

                                        if key+n > 24 then
                                            f = math.floor((key+n)/-12)+1
                                        end

                                        copy_chord[key+n+f*12] = copy_note
                                    end

                                    project.tracks[instrument].chords[time] = copy_chord;
                                end
                            end
                        end
                    else
                        write_console_line("?shift [n] [k]")
                    end
                else
                    write_console_line("?shift [n] [k]")
                end
            elseif c[1] == "device" then -- device
                if c[2] ~= nil then -- device [device]
                    local device = c[2]
                    if device ~= nil and device ~= "" then
                        if devices[device] ~= nil then
                            local device_info = devices[device]
                            if device_info.type ~= nil then
                                if c[3] ~= nil then -- device [device] [periph_to_attach]
                                    local periph_to_attach = c[3]
                                    if peripheral.isPresent(periph_to_attach) then
                                        local periph = peripheral.wrap(periph_to_attach)
                                        local periph_name = peripheral.getName(periph)

                                        if peripheral.getType(periph) == device_info.type then
                                            device_info.periph = periph
                                            write("Peripheral '" .. periph_name .. "' has been assigned for device '".. device .."'.")
                                        else
                                            write_console_line("Peripheral '" .. periph_name .. "' isn't of type '" .. device_info.type .. "' required for device '".. device .."'.")
                                        end
                                    else
                                        write_console_line("Peripheral '" .. periph_name .. "' with a name '" .. periph_to_attach .. "' wasn't found.")
                                    end
                                else
                                    if device_info.periph ~= nil then
                                        local periph_name = peripheral.getName(device_info.periph)
                                        write_console_line("Device '" .. device .. "' is attached to '" .. periph_name .. "'.")
                                    else
                                        write_console_line("Device '" .. device .. "' isn't attached to a '" .. device_info.type .. "' peripheral.")
                                    end
                                end
                            else
                                write_console_line("Device '" .. device .. "' is a multidevice.")
                            end
                        else
                            write_console_line("Device '" .. device .. "' is unknown.")
                        end
                    end
                else
                    write_console_line("?device [device]")
                end
            elseif c[1] == "lyrics" then -- lyrics
                if c[2] == nil then
                    if project.lyrics == nil then project.lyrics = {} end
                    mode = "lyrics"
                elseif c[2] == "print" then
                    if c[3] == nil then
                        write_console_line("?lyrics print [printer]")
                    else
                        local printer_name = c[3]
                        local printer = peripheral.wrap(printer_name)

                        if project.lyrics ~= nil and table_count(project.lyrics) > 0 then
                            local start = printer.newPage()
                            if start then
                                local page_num = 1
                                for i = 0, get_song_length() do
                                    if page_num > 1 then
                                        printer.setPageTitle(project.name .. ": Page " .. page_num)
                                    else
                                        printer.setPageTitle(project.name)
                                    end

                                    if project.lyrics[i] ~= nil then
                                        local part = project.lyrics[i]
                                        local w, h = printer.getPageSize()
                                        local x, y = printer.getCursorPos()

                                        if x + #part.text > w then
                                            printer.setCursorPos(1, y + 1)
                                        end

                                        if part.type == "nv" then
                                            printer.setCursorPos(1, y + 1)
                                        elseif part.type == "ns" then
                                            printer.setCursorPos(1, y + 2)
                                        end

                                        x, y = printer.getCursorPos()

                                        if y > h then
                                            printer.setPageTitle(project.name .. ": Page " .. page_num)
                                            printer.endPage()
                                            printer.newPage()
                                            page_num = page_num + 1
                                        end

                                        printer.write(part.text .. " ")
                                    end
                                end

                                printer.endPage()

                                write_console_line("Lyrics printed.")
                            else
                                write_console_line("Lyrics can't be printed.")
                            end
                        else
                            write_console_line("The song has no lyrics to print.")
                        end
                    end
                end
            elseif c[1] == "name" then
                if c[2] == nil then
                    write_console_line("?name [full song name]")
                else
                    table.remove(c, 1)
                    project.name = table.concat(c, " ")
                    write_console_line("Name has been set to " .. project.name)
                    daw_save()
                end
            elseif c[1] == "author" then
                if c[2] == nil then
                    write_console_line("?author [name]")
                else
                    table.remove(c, 1)
                    project.author = table.concat(c, " ")
                    write_console_line("Author has been set to " .. project.author)
                    daw_save()
                end
            elseif c[1] == "export" then
                daw_export()
            elseif c[1] == "scale" then
                local n = tonumber(c[2])
                if n ~= nil then
                    if is_monitor then
                        cur_term.setTextScale(n)
                        update_monitor()
                        write_console_line("Monitor scale has been set to " .. n)
                    else
                        write_console_line("DAW is not running on a monitor.")
                    end
                end
            end
            typing = ""
        end

        if devices.visualizer.periph ~= nil then
            devices.visualizer.periph.scroll(-1)
        end

        term.setCursorPos(3, 2)
        term.write("DAW")

        term.setCursorPos(8, 2)
        if loop ~= 0 then
            term.setBackgroundColor(colors.orange)
            term.write("Loop")
        elseif play == nil then
            term.setBackgroundColor(colors.green)
            term.write("Play")
        else
            term.setBackgroundColor(colors.red)
            term.write("Stop")
        end
        term.setBackgroundColor(colors.black)

        term.setCursorPos(15, 2)
        local seconds = timeline/4*60/project.bpm
        if seconds == 0 then
            term.write("0:00:00.00")
        else
            term.write(format_second_time(seconds))
        end

        term.setCursorPos(27, 1)
        if play ~= nil then
            --term.write(delay)
        end

        term.setCursorPos(27, 2)
        term.write(project.bpm)

        --term.setCursorPos(1, 4)
        --term.setBackgroundColor(colors.blue)
        --term.write("             ")
        --term.setCursorPos(3, 4)
        --term.write("Save song")
        --term.setBackgroundColor(colors.black)
        
        term.setCursorPos(32, 2)
        if mode == "default" then
            term.setBackgroundColor(colors.red)
        elseif mode == "lyrics" then
            term.setBackgroundColor(colors.green)
        end
        term.write("Lyrics")
        term.setBackgroundColor(colors.black)
        
        term.setCursorPos(39, 2)
        term.setBackgroundColor(colors.red)
        term.write("Peripherals")
        term.setBackgroundColor(colors.black)

        if mode == "default" then
            term.setCursorPos(2, uiInstrument)

            local counter = 0
            for name,track in pairs(project.tracks) do
                if name == instrument then
                    term.setBackgroundColor(colors.red)
                else
                    term.setBackgroundColor(colors.gray)
                end

                term.setCursorPos(1,uiInstrument+counter)
                term.write("           ")
                term.setCursorPos(2,uiInstrument+counter)
                term.write(name)

                counter = counter + 1
            end

            for i = 1, sizeY-counter-4 do
                term.setBackgroundColor(colors.lightGray)
                term.setCursorPos(1,uiInstrument+counter+i-1)
                term.write("           ")
            end
        end

        term.setBackgroundColor(colors.black)
        term.setCursorPos(18, 3)
        for i = 0, sequence_width do
            term.write(" ")
        end

        if mode == "default" then
            if timeline-scroll_timeline >= 0 and timeline-scroll_timeline < sequence_width then
                term.setCursorPos(18+timeline-scroll_timeline-1, 3)
                if play ~= nil and timeline ~= timeline_offset then
                    term.setTextColor(colors.green)
                    term.write("v")
                end
            end
            if timeline_offset-scroll_timeline >= 0 and timeline_offset-scroll_timeline < sequence_width then
                term.setCursorPos(18+timeline_offset-scroll_timeline, 3)
                term.setTextColor(colors.white)
                term.write("v")
            end

            local pressed_keys = {}
            
            if play ~= nil and project.tracks[instrument].chords ~= nil then
                local chord = project.tracks[instrument].chords[timeline];
                if chord ~= nil then
                    for i=1,25 do
                        if chord[i] ~= nil then
                            pressed_keys[i] = true;
                        end
                    end
                end
            end

            for i=1,25 do
                local line = 5+24-i
                if line > 0 and line <= sizeY-1 then
                    local note = notes[i-scroll_sequence]
                    term.setCursorPos(14, line)
                    
                    if string.match(note, "#") then
                        if pressed_keys[i-scroll_sequence] then
                            term.setBackgroundColor(colors.gray)
                        else
                            term.setBackgroundColor(colors.black)
                        end

                        term.setTextColor(colors.lightGray)
                    else
                        if pressed_keys[i-scroll_sequence] then
                            term.setBackgroundColor(colors.lightGray)
                        else
                            term.setBackgroundColor(colors.white)
                        end

                        term.setTextColor(colors.gray)
                    end
                    
                    term.write(note)
                    if string.len(note) == 2 then
                        term.write(" ")
                    end

                    if pressed_keys[i-scroll_sequence] and string.len(note) == 2 then
                        term.setBackgroundColor(colors.lightGray)
                    else
                        term.setBackgroundColor(colors.white)
                    end
                    term.write(" ")

                    term.setTextColor(colors.white)
                    
                    for j = 1, sequence_width do
                        if play ~= nil and timeline == j + scroll_timeline then
                            term.setBackgroundColor(colors.green)
                        else
                            if (j - 1 + scroll_timeline) % 4 == 0 then
                                term.setBackgroundColor(colors.lightGray)
                            else
                                term.setBackgroundColor(colors.gray)
                            end
                        end

                        if project.tracks[instrument] == nil or project.tracks[instrument].chords == nil or project.tracks[instrument].chords[j+scroll_timeline] == nil then
                            if play ~= nil and timeline == j+scroll_timeline then
                                term.setBackgroundColor(colors.green)
                            end
                            term.write("_")
                        else
                            local chord = project.tracks[instrument].chords[j+scroll_timeline]
                            local exists = false
                            for key, note in pairs(chord) do
                                if key == (i-scroll_sequence) then
                                    if chord[key] == selected_note then
                                        term.setBackgroundColor(colors.blue)
                                    else
                                        if play ~= nil and timeline == j+scroll_timeline then
                                            term.setBackgroundColor(colors.green)
                                        else
                                            term.setBackgroundColor(colors.red)
                                        end
                                    end
                                    term.write("#")
                                    exists = true
                                end
                            end
                            if not exists then
                                term.write("_")
                            end
                        end
                    end
                    
                    term.setBackgroundColor(colors.black)
                    
                    if i % 2 == 0 then
                    
                    else
                        
                    end
                end
            end

            for i=1,9 do
                term.setCursorPos(sizeX-1, 3+i)
                term.setBackgroundColor(colors.blue)
                if i == 5 then
                    term.blit("<>", "00", "9b")
                else
                    term.blit("  ", "00", "9b")
                end
            end
        elseif mode == "lyrics" then
            for i = 1, sizeY-4 do
                term.setCursorPos(1, i+3)
                term.setBackgroundColor(colors.black)
                if i-1+scroll_timeline == timeline_offset then
                    term.write(">")
                else
                    term.write(" ")
                end
                if project.lyrics == nil or project.lyrics[i+scroll_timeline] == nil or project.lyrics[i+scroll_timeline].type == nil then
                    term.setBackgroundColor(colors.red)
                    term.write("NV")
                elseif project.lyrics[i+scroll_timeline].type == "nv" then
                    term.setBackgroundColor(colors.green)
                    term.write("NV")
                elseif project.lyrics[i+scroll_timeline].type == "ns" then
                    term.setBackgroundColor(colors.blue)
                    term.write("NS")
                end
                
                if i-1+scroll_timeline == timeline then
                    term.setBackgroundColor(colors.green)
                elseif project.tracks[instrument] ~= nil and project.tracks[instrument].chords[i+scroll_timeline] ~= nil then
                    term.setBackgroundColor(colors.brown)
                else
                    term.setBackgroundColor(colors.black)
                end

                term.write(" ")

                local part = project.lyrics[i+scroll_timeline]
                local count = 0
                if part ~= nil and part.text ~= nil then
                    term.write(part.text)
                    count = #part.text
                end
                for j = count + 1, sizeX-7 do
                    term.write(".")
                end

                term.write(" ")
            end
        end

        term.setCursorPos(sizeX-1, sizeY-2)
        term.setBackgroundColor(colors.cyan)
        term.write(" ^")
        term.setCursorPos(sizeX-1, sizeY-1)
        term.setBackgroundColor(colors.blue)
        term.write(" v")

        term.setCursorPos(18, sizeY)
        term.setBackgroundColor(colors.black)
        term.write("                                ")
        term.setCursorPos(18, sizeY)
        term.write(round2((scroll_timeline)/4/project.bpm*60, 2))

        local timeMid = round2((scroll_timeline+sequence_width/2)/4/project.bpm*60, 2)
        term.setCursorPos((sizeX-2-sequence_width/2)-(string.len(timeMid)/2), sizeY)
        term.write(timeMid)

        local timeEnd = round2((scroll_timeline+sequence_width)/4/project.bpm*60, 2)
        term.setCursorPos(sizeX-2-string.len(timeEnd)+1, sizeY)
        term.write(timeEnd)

        winLoop.redraw()
        winAddInst.redraw()

        sleep(0.05)
    end
    
    --clear_term()
end

parallel.waitForAll(event, audio, render);