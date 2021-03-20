repo = "ccdaw"
author = "BigBang1112"

github_trees = "https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1"
github_raw = "https://raw.githubusercontent.com/%s/%s/%s/%s"

local function has_element(t, x)
    for i, e in pairs(t) do
        if e == x then
            return true;
        end
    end

    return false;
end

local function starts_with(str, start)
    return str:sub(1, #start) == start;
end

local function ends_with(str, ending)
    return ending == "" or str:sub(-#ending) == ending
end

local files_to_ignore = {".gitignore"};

install_all_songs = true;
install_dir = "";
program_root_dir = "ccdaw";
branch = "main";

if fs.exists(string.format("%s/%s/%s", install_dir, program_root_dir, branch)) then
    local command = string.format("rm %s/%s/%s", install_dir, program_root_dir, branch);
    print("CCDAW branch '" .. branch .. "' is already installed. Please delete the installation with the command '" .. command .. "', if you want to reinstall the program.");
    print("Reinstaller coming soon.");
    return;
end

shell.run("clear");

print("Fetching the official repository files...");

print("");

local request = http.get(string.format(github_trees, author, repo, branch));
local response, response_message = request.getResponseCode();
local headers = request.getResponseHeaders();
if response == 200 then
    local result_json = request.readAll();
    request.close();

    local result = textutils.unserializeJSON(result_json);
    
    if headers["X-RateLimit-Reset"] ~= nil then
        local remaining = headers["X-RateLimit-Remaining"];
        local reset = os.date("%X", tonumber(headers["X-RateLimit-Reset"]));
        local limit = headers["X-RateLimit-Limit"];

        print("GITHUB API LIMITATION NOTE");
        print("You can use this installer " .. remaining .. " more times.");
        print("Countdown will be reset to " .. limit .. " after " .. reset .. ".");

        print("");
    end

    for i, blob in pairs(result.tree) do
        if blob.type == "blob" and not has_element(files_to_ignore, blob.path) then
            if install_all_songs or (not install_all_songs and not starts_with(blob.path, "songs/")) then
                print("Downloading " .. blob.path .. "...");

                local is_binary = ends_with(blob.path, ".song");

                local content = http.get(string.format(github_raw, author, repo, branch, blob.path), nil, is_binary).readAll();
                if not content then
                    error("Downloading " .. blob.path .. " failed.");
                end

                local file = string.format("%s/%s/%s/%s", install_dir, program_root_dir, branch, blob.path)

                if content == "" then
                    print("Skipping " .. blob.path .. " (empty file)");
                elseif is_binary then
                    local h = fs.open(file, "wb")
                    for i = 1, #content do
                        h.write(string.byte(content, i))
                    end
                    h.close()
                else
                    local h = fs.open(file, "w");
                    h.write(content);
                    h.close();
                end
            end
        end
    end

    print("");

    local daw_path = string.format("%s/%s/%s/daw.lua", install_dir, program_root_dir, branch);

    print("Creating program shortcuts...");

    local daw_shortcut_file = "daw.lua";

    if fs.exists(daw_shortcut_file) then
        print("File '" .. daw_shortcut_file .. "' already exists. Skipping for safety.");

        print("");
    
        print("Done!");
    
        sleep(1);
    else
        local h_daw = fs.open(daw_shortcut_file, "w");
        h_daw.write("args = {...};\n")
        h_daw.write(string.format("shell.run(\"%s\", table.concat(args, \" \"));", daw_path))
        h_daw.close();

        print("");
    
        print("Done!");
    
        sleep(1);

        shell.run(daw_shortcut_file);
    end
else
    request.close();
end