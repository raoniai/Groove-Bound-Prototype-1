-- Zero-dependency test runner. Runs headless under plain LuaJIT (the same
-- runtime LÖVE embeds): luajit tests/run.lua [pattern]
--
-- Test files live in tests/unit/*_test.lua and return a table of
-- { ["test name"] = function() ... end }. Assertion helpers are in
-- tests/helpers.lua. Exit code 0 = all green, 1 = failures.

-- Make requires resolve from the game root regardless of CWD.
local root = arg[0]:match("^(.*)/tests/run%.lua$") or "."
package.path = table.concat({
  root .. "/?.lua",
  root .. "/?/init.lua",
  package.path,
}, ";")

local pattern = arg[1]

-- Discover test files.
local function list_test_files()
  local files = {}
  local pipe = io.popen('ls "' .. root .. '/tests/unit/" 2>/dev/null')
  if pipe then
    for line in pipe:lines() do
      if line:match("_test%.lua$") then
        files[#files + 1] = line:gsub("%.lua$", "")
      end
    end
    pipe:close()
  end
  table.sort(files)
  return files
end

local total, failed = 0, 0
local failures = {}

for _, file in ipairs(list_test_files()) do
  local suite = require("tests.unit." .. file)
  local names = {}
  for name in pairs(suite) do
    names[#names + 1] = name
  end
  table.sort(names)

  for _, name in ipairs(names) do
    if not pattern or name:find(pattern, 1, true) or file:find(pattern, 1, true) then
      total = total + 1
      local ok, err = xpcall(suite[name], debug.traceback)
      if ok then
        io.write(".")
      else
        io.write("F")
        failed = failed + 1
        failures[#failures + 1] = string.format("%s :: %s\n%s", file, name, err)
      end
    end
  end
end

print()
for _, f in ipairs(failures) do
  print("\nFAIL: " .. f)
end
print(string.format("\n%d tests, %d failures", total, failed))
os.exit(failed == 0 and 0 or 1)
