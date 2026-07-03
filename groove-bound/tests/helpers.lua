-- Assertion helpers for the test suite.

local H = {}

function H.eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%sexpected %s, got %s",
      msg and (msg .. ": ") or "", tostring(expected), tostring(actual)), 2)
  end
end

function H.near(actual, expected, tolerance, msg)
  tolerance = tolerance or 1e-9
  if math.abs(actual - expected) > tolerance then
    error(string.format("%sexpected %s ± %s, got %s",
      msg and (msg .. ": ") or "", tostring(expected), tostring(tolerance), tostring(actual)), 2)
  end
end

function H.is_true(value, msg)
  if value ~= true then
    error((msg and (msg .. ": ") or "") .. "expected true, got " .. tostring(value), 2)
  end
end

function H.is_false(value, msg)
  if value ~= false then
    error((msg and (msg .. ": ") or "") .. "expected false, got " .. tostring(value), 2)
  end
end

function H.is_nil(value, msg)
  if value ~= nil then
    error((msg and (msg .. ": ") or "") .. "expected nil, got " .. tostring(value), 2)
  end
end

function H.errors(fn, msg)
  local ok, err = pcall(fn)
  if ok then
    error((msg and (msg .. ": ") or "") .. "expected an error, got none", 2)
  end
  return err
end

-- Deep table equality (for JSON round-trips etc.).
function H.deep_eq(actual, expected, path)
  path = path or "value"
  if type(expected) ~= "table" or type(actual) ~= "table" then
    if actual ~= expected then
      error(string.format("%s: expected %s, got %s", path, tostring(expected), tostring(actual)), 2)
    end
    return
  end
  for k, v in pairs(expected) do
    H.deep_eq(actual[k], v, path .. "." .. tostring(k))
  end
  for k in pairs(actual) do
    if expected[k] == nil then
      error(string.format("%s.%s: unexpected key", path, tostring(k)), 2)
    end
  end
end

return H
