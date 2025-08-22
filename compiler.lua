

local js = require "js"
local document = js.global.document
local JSON = js.global.JSON
local encodeURIComponent = js.global.encodeURIComponent

local function ms_to_timestamp(ms)
  -- formats 742 -> 00:00.742
  local seconds = ms / 1000.0
  local total = math.floor(seconds)
  local millis = math.floor((seconds - total) * 1000 + 0.5)
  local minutes = math.floor(total / 60)
  local sec = total % 60
  return string.format("%02d:%02d.%03d", minutes, sec, millis)
end

local function collect_notes(data)
  local notes = {}
  local sections = data.notes
  if not sections then return notes end
  local len = sections.length or 0
  for i = 0, len - 1 do
    local sec = sections[i]
    if sec and sec.sectionNotes then
      local arr = sec.sectionNotes
      local nlen = arr.length or 0
      for j = 0, nlen - 1 do
        local n = arr[j]
        -- n is a JS array: [time, lane, length, ...]
        local t = tonumber(n[0]) or 0
        local lane = tonumber(n[1]) or 0
        local hold = tonumber(n[2]) or 0
        notes[#notes+1] = { time = t, lane = lane, length = hold }
      end
    end
  end
  table.sort(notes, function(a,b) return a.time < b.time end)
  return notes
end

local function compile_text(jsonText)
  local ok, parsed = pcall(function() return JSON:parse(jsonText) end)
  if not ok then
    return "! JSON parse error: check your input"
  end
  local out = {}
  out[#out+1] = "FNF Arrow Chart → Scratch Compiler Output"
  out[#out+1] = string.rep("=", 40)

  local notes = collect_notes(parsed)
  out[#out+1] = ("Total Notes: %d\n"):format(#notes)

  for i = 1, #notes do
    local n = notes[i]
    local ts = ms_to_timestamp(n.time)
    if n.length > 0 then
      out[#out+1] = ("[%s] Lane %d HOLD (%dms)"):format(ts, n.lane, n.length)
    else
      out[#out+1] = ("[%s] Lane %d TAP"):format(ts, n.lane)
    end
  end
  return table.concat(out, "\n")
end

-- Hook up UI
local jsonIn = document:getElementById("jsonIn")
local txtOut = document:getElementById("txtOut")
local btnCompile = document:getElementById("compile")
local btnDownload = document:getElementById("downloadTxt")

-- Expose small helpers to JS (index.html binds buttons as fallback)
js.global.__luaCompile = function()
  local input = tostring(jsonIn.value or "")
  txtOut.value = compile_text(input)
end

js.global.__luaDownload = function()
  local text = tostring(txtOut.value or "")
  if #text == 0 then return end
  local url = "data:text/plain;charset=utf-8," .. tostring(encodeURIComponent(text))
  local a = document:createElement("a")
  a.href = url
  a.download = "fnf-chart.txt"
  document.body:appendChild(a)
  a:click()
  a:remove()
end

-- Also bind directly from Lua to ensure buttons work even if JS fallback removed
if btnCompile then btnCompile:addEventListener("click", js.global.__luaCompile) end
if btnDownload then btnDownload:addEventListener("click", js.global.__luaDownload) end
