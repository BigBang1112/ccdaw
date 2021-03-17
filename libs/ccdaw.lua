ccdaw = {
    previous = 1
}

ccdaw.play_stamp = function (self)
    local time = os.epoch("utc") - play
    local beat = time/1000/60*project.bpm
    local current = beat % (project.scale*4)

    delay = get_delay()
    
    if self.previous > current then
        local stream_packet = {}
        local line = ""

        for name, track in pairs(project.tracks) do
            local track_volume = 1
            if track.volume ~= nil then
                track_volume = track.volume
            end

            if track.chords ~= nil then
                local chord = track.chords[timeline+1]
                if chord ~= nil then
                    for key, note in pairs(chord) do
                        local note_vol = 1
                        if note.vol ~= nil then
                            note_vol = note.vol
                        end

                        local s_mono = devices.speaker_mono.periph;

                        if track.sound ~= nil then
                            if stereo then
                                if devices.speaker_left.periph ~= nil then
                                    devices.speaker_left.periph.playSound(track.sound, volume*track_volume*note_vol, 2 ^ ((key-1 - 12) / 12))
                                end
                                if devices.speaker_right.periph ~= nil then
                                    devices.speaker_right.periph.playSound(track.sound, volume*track_volume*note_vol, 2 ^ ((key-1 - 12) / 12))
                                end
                            elseif s_mono ~= nil then
                                s_mono.playSound(track.sound, volume*track_volume*note_vol, 2 ^ ((key-1 - 12) / 12))
                            end
                        end
                        if track.instrument ~= nil then
                            if stereo then
                                if devices.speaker_left.periph ~= nil then
                                    devices.speaker_left.periph.playNote(track.instrument, volume*track_volume*note_vol, key-1+key_shift)
                                end
                                if devices.speaker_right.periph ~= nil then
                                    devices.speaker_right.periph.playNote(track.instrument, volume*track_volume*note_vol, key-1+key_shift)
                                end
                            elseif s_mono ~= nil then
                                s_mono.playNote(track.instrument, volume*track_volume*note_vol, key-1+key_shift)
                            end

                            visualize_note(note_vol, key+key_shift)
                        end
                    end
                    
                    if track.sound ~= nil then

                    elseif track.instrument ~= nil then
                        local inst = {}
                        inst.ins = track.instrument
                        inst.notes = {}

                        line = line .. track.instrument:sub(0, 3) .. ":"

                        for key, note in pairs(chord) do
                            if notes[key] ~= nil then
                                line = line .. " " .. notes[key]
                            end
                            inst.notes[key] = note
                        end

                        line = line .. "; "

                        table.insert(stream_packet, inst)
                    end
                end
            end
        end

        if project.lyrics ~= nil then
            local part = project.lyrics[timeline]
            if part ~= nil then
                local l = devices.lyrics.periph;
                if l ~= nil then
                    local x, y = l.getCursorPos()
                    if part.type == nil and x > 1 then
                        l.setCursorPos(x + 1, y)
                    elseif part.type == "nv" then
                        l.setCursorPos(1, y + 1)
                    elseif part.type == "ns" then
                        l.setCursorPos(1, y + 2)
                    end
                    l.write(part.text)
                end
            end
        end
        
        if line ~= "" then
            if devices.lyrics.periph then
                local prev_term = term.current()
                term.redirect(devices.lyrics.periph)
                --print(stream_packet)
                term.redirect(prev_term)
            end
            if devices.streamer.periph then
                rednet.send(devices.streamer.periph.getID(), textutils.serialize(stream_packet), os.date("%d.%m.%Y %H:%M:%S"))
            end
        end
        
        timeline = timeline + 1

        if mode == "default" then
            if timeline - scroll_timeline > sequence_width - 4 then
                scroll_timeline = scroll_timeline + 4
            end
        elseif mode == "lyrics" then
            while timeline - scroll_timeline > sizeY-6 do
                scroll_timeline = scroll_timeline + 1
            end
        end

        if loop > 0 and timeline-timeline_offset >= loop then
            timeline = timeline_offset
        end
    end
    self.previous = current
end