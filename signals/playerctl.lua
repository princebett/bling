-- Provides:
-- bling::playerctl::status
--      playing (boolean)
-- bling::playerctl::album
--      album_art (string)
-- bling::playerctl::title
--      stdout (string)
-- bling::playerctl::info
--      interval_sec (number)
--      length_sec (number)
--
local awful = require("awful")
local beautiful = require("beautiful")

local update_interval = beautiful.playerctl_album_update_interval or 5
local interval_status = beautiful.playerctl_position_update_interval or 1

local function emit_player_status()
    local status_cmd = "playerctl status"
    awful.widget.watch(status_cmd, interval_status, function(_, stdout)
        local playing = false
        if stdout:find("Playing") then
            playing = true
        else
            playing = false
        end
        awesome.emit_signal("bling::playerctl::status", playing)
    end)
end

local function emit_player_info()
    local art_script = [[
sh -c '

tmp_dir="$XDG_CACHE_HOME/awesome/"

if [ -z ${XDG_CACHE_HOME} ]; then
    tmp_dir="$HOME/.cache/awesome/"
fi

tmp_cover_path=${tmp_dir}"cover.png"

if [ ! -d $tmp_dir  ]; then
    mkdir -p $tmp_dir
fi

link="$(playerctl metadata mpris:artUrl | sed -e 's/open.spotify.com/i.scdn.co/g')"

curl -s "$link" --output $tmp_cover_path

echo $tmp_cover_path
']]

    local song_title_cmd = "playerctl metadata title"
    local song_title = "No Song Playing"

    awful.widget.watch(song_title_cmd, update_interval, function(_, stdout)
        if not (song_title == stdout) then
            awful.spawn.easy_async_with_shell(art_script, function(out)
                local album_path = out:gsub('%\n', '')
                awesome.emit_signal("bling::playerctl::album", album_path)
            end)
            song_title = stdout
        end
        awesome.emit_signal("bling::playerctl::title", stdout)
    end)

    local prog_cmd = "playerctl position"
    local length_cmd = "playerctl metadata mpris:length"

    awful.widget.watch(prog_cmd, interval_status, function(_, interval)
        awful.spawn.easy_async_with_shell(length_cmd, function(length)
            local length_sec = tonumber(length) -- in microseconds
            local interval_sec = tonumber(interval) -- in seconds
            if length_sec and interval_sec then
                if interval_sec >= 0 and length_sec > 0 then
                    awesome.emit_signal("bling::playerctl::position",
                                        interval_sec, length_sec / 1000000)
                end
            end
        end)
    end)

end

-- Emit info
-- emit_player_status()
-- emit_player_info()

local enable = function()
    emit_player_status()
    emit_player_info()
end

return {enable = enable}
