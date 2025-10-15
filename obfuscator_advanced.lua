--[[
obfuscator_advanced.lua
Author: 0xXrer (2025)
A fully mathematical obfuscator for Luau/Lua 5.4
--]]

local math, string, table = math, string, table
math.randomseed(os.time() % 2^31)
local function rnd(a,b) return math.random(a,b) end
local function wrap(e) return "("..e..")" end

----------------------------------------------------------
-- Basic formulas
----------------------------------------------------------
local generators = {}

-- Generator 1: linear congruence solution expression
generators[#generators+1] = function(target)
    local a = rnd(3,97); local b = rnd(0,499); local m = rnd(97,997)
    local need = ((target - b) % m)
    local k = 0
    for i=0,m-1 do if (a * i) % m == need then k = i; break end end
    return string.format("((%d*%d+%d)%% %d + %d - %d)", a, k, b, m, (target - ((a*k + b) % m)), 0)
end

-- Generator 2: represent the number in a random base as sum of base^p terms
generators[#generators+1] = function(target)
    local base = rnd(2,7)
    local coeffs, rem = {}, target
    for i=0,5 do coeffs[i+1]=rem%base; rem=math.floor(rem/base) end
    local parts = {}
    for i=1,#coeffs do
        if coeffs[i]~=0 then
            local p=i-1
            if p==0 then parts[#parts+1]=tostring(coeffs[i])
            else parts[#parts+1]=string.format("%d*%d^%d",coeffs[i],base,p) end
        end
    end
    return "("..table.concat(parts," + ")..")"
end

-- Generator 3: use a sine-based expression and floor to approximate the target
generators[#generators+1] = function(target)
    local A=rnd(20,180); local B=rnd(1,12); local C=rnd(0,120)
    local phase=string.format("%.6f", math.random()/5 + 0.01)
    local expr=string.format("((math.floor(%d*(math.sin(%s*%d)+1)+%d)))",A,phase,B,C)
    return string.format("(%s - %d)", expr, (math.floor(A*1.5+C)-target))
end

-- Generator 4: use exp and floor with a scaling factor
generators[#generators+1] = function(target)
    local s=rnd(2,40); local shift=rnd(0,30)
    local approx=(target+shift)/s
    local x=math.log(math.max(1,approx))
    return string.format("(math.floor(math.exp(%f)*%d)-%d)",x,s,shift)
end

-- Generator 5: use log and floor to reconstruct the target through exp/log trick
generators[#generators+1] = function(target)
    local s=rnd(1,40); local shift=rnd(0,40)
    local val=target+shift; local x=math.exp(val/s)
    return string.format("(math.floor(math.log(%f)*%d)-%d)",x,s,shift)
end

-- Generator 6: sum of factorial numbers (greedy) to build the target
generators[#generators+1] = function(target)
    local parts,rem,i={},target,1
    while rem>0 and i<8 do
        local f=1; for j=1,i do f=f*j end
        if f<=rem then parts[#parts+1]=tostring(f); rem=rem-f end
        i=i+1
    end
    if #parts>0 then return "("..table.concat(parts," + ")..")" else return tostring(target) end
end

----------------------------------------------------------
-- Additional noise generators (no recursion)
----------------------------------------------------------
for i=1,12 do
    generators[#generators+1] = function(target)
        local g1=generators[rnd(1,6)](target+rnd(0,5))
        local g2=generators[rnd(1,6)](rnd(1,20))
        local g3=generators[rnd(1,6)](rnd(0,10))
        return "("..g1.." + "..g2.." - "..g3..")"
    end
end

----------------------------------------------------------
-- Protection depth
----------------------------------------------------------
local MAX_DEPTH=3
local function build_complex_expr_for(target,depth)
    depth=(depth or 0)
    if depth>MAX_DEPTH then
        local g=generators[rnd(1,6)]
        return "tonumber("..g(target)..")"
    end
    local parts,n={},rnd(3,5)
    for i=1,n do
        local g=generators[rnd(1,#generators)]
        parts[#parts+1]=g(target+rnd(-2,2))
    end
    return "tonumber(("..table.concat(parts," + ").."))"
end

----------------------------------------------------------
-- Simple XOR encryption with math-based KDF
----------------------------------------------------------
local function math_kdf(pass)
    local s=0
    for i=1,#pass do s=s+string.byte(pass,i)*(i%7+1) end
    local x=s
    for i=1,6 do
        x=math.floor((math.abs(math.sin(x+i*0.1234567))+0.5)*1e6)%2147483647
        x=(x+math.floor(math.exp((x%10)+1)))%2147483647
    end
    return x
end

local function make_prng(seed)
    local m,a,c=2147483647,1103515245,12345
    local state=seed%m
    return function() state=(a*state+c)%m; return state%256 end
end

local function xor_encrypt_bytes(str,pass)
    local seed=math_kdf(pass or "")
    local prng=make_prng(seed)
    local out={}
    for i=1,#str do
        local b=string.byte(str,i)
        out[#out+1]=(b ~ prng())
    end
    return out
end

----------------------------------------------------------
-- Main obfuscation
----------------------------------------------------------
local function obfuscate_source(src, password)
    local string_map,sid={},0
    local function process_string(inner)
        sid=sid+1
        local key="__S"..sid.."__"
        local bytes
        if password then
            -- If a password is provided, encrypt the string bytes
            bytes=xor_encrypt_bytes(inner,password)
            string_map[key]={enc=true,data=bytes}
        else
            -- Otherwise store raw byte values
            bytes={}
            for i=1,#inner do bytes[#bytes+1]=string.byte(inner,i) end
            string_map[key]={enc=false,data=bytes}
        end
        return key
    end

    -- Replace double-quoted strings
    src=src:gsub('"(.-)"',process_string)
    -- Replace single-quoted strings
    src=src:gsub("'(.-)'",process_string)
    -- Replace numeric literals (word boundaries) with generated expressions
    src=src:gsub("(%f[^%w]%d+%f[^%w])",function(num)
        local n=tonumber(num)
        if not n or n>2^24 then return num end
        return build_complex_expr_for(n)
    end)

    -- For each stored string, build expressions for each byte and replace placeholders
    for key,v in pairs(string_map) do
        local exprs={}
        for _,byte in ipairs(v.data) do
            exprs[#exprs+1]=build_complex_expr_for(byte)
        end
        local arr="{"..table.concat(exprs,",").."}"
        arr=arr:gsub("%%","%%%%") -- ⚠️ escape '%' for gsub replacement

        if v.enc then
            -- For encrypted strings build a runtime decryption call with the KDF value
            local pass_expr="tonumber("..build_complex_expr_for(math_kdf(password)%2147483647)..")"
            pass_expr=pass_expr:gsub("%%","%%%%")
            local repl="(bytes_to_string(decrypt_bytes("..arr..","..pass_expr..")))"
            src=src:gsub(key,repl)
        else
            -- For plain strings replace with string.char(byte expressions)
            local repl="(string.char("..table.concat(exprs,",").."))"
            src=src:gsub(key,repl)
        end
    end

    -- Runtime block injected on top of the obfuscated code
    local runtime=[[
-- Runtime block
local math,string,table=math,string,table
local function math_kdf(p)local s=0 for i=1,#p do s=s+string.byte(p,i)*(i%7+1) end local x=s for i=1,6 do x=math.floor((math.abs(math.sin(x+i*0.1234567))+0.5)*1e6)%2147483647 x=(x+math.floor(math.exp((x%10)+1)))%2147483647 end return x end
local function make_prng(s)local m=2147483647 local a=1103515245 local c=12345 local st=s%m return function()st=(a*st+c)%m return st%256 end end
local function decrypt_bytes(arr,p)local seed=math_kdf(p or "")local pr=make_prng(seed)local o={}for i=1,#arr do local k=pr()o[i]=(arr[i]~k)end return o end
local function bytes_to_string(arr)local t={}for i=1,#arr do t[i]=string.char(arr[i])end return table.concat(t)end
]]

    return runtime.."\n"..src
end

----------------------------------------------------------
-- Demonstration (without files)
----------------------------------------------------------
local PASSWORD="super_secure_math"

local source = [[
print("hi")
print('test123')
print(42)
]]

local result = obfuscate_source(source, PASSWORD)
print("\n========= 🔒 OBFUSCATED CODE =========\n")
print(result)
print("\n==========================================\n")
