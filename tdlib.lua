-----------------------------------------------------------
--  Bindings for TDLib
-----------------------------------------------------------

--[[ LICENSE
  The MIT License (MIT)

  luajit-tdlib - TDLib bindings for LuaJIT

  Copyright (c) 2020 Playermet

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
]]

local ffi = require 'ffi'

local mod = {} -- Lua module namespace
local aux = {} -- Auxiliary utils

local args -- Arguments for binding
local clib -- C library namespace

local is_luajit = pcall(require, 'jit')


local load_clib, bind_clib -- Forward declaration

local function init(mod, name_or_args)
  if clib ~= nil then
    return mod
  end

  if type(name_or_args) == 'table' then
    args = name_or_args
    args.name = args.name or args[1]
  elseif type(name_or_args) == 'string' then
    args = {}
    args.name = name_or_args
  end

  clib = load_clib()
  bind_clib()

  return mod
end

function load_clib()
  if args.clib ~= nil then
    return args.clib
  end

  if type(args.name) == 'string' then
    if type(args.path) == 'string' then
      return ffi.load(package.searchpath(args.name, args.path))
    else
      return ffi.load(args.name)
    end
  end

  -- If no library or name is provided, we just
  -- assume that the appropriate SQLite libraries
  -- are statically linked to the calling program
  return ffi.C
end

function bind_clib()
  -----------------------------------------------------------
  --  Namespaces
  -----------------------------------------------------------
  local const = {} -- Table for contants
  local funcs = {} -- Table for functions
  local types = {} -- Table for types
  local cbs   = {} -- Table for callbacks

  mod.const = const
  mod.funcs = funcs
  mod.types = types
  mod.cbs   = cbs
  mod.clib  = clib

  -- Access to funcs from module namespace by default
  aux.set_mt_method(mod, '__index', funcs)


  -----------------------------------------------------------
  --  Constants
  -----------------------------------------------------------
  -- For C pointers comparison
  if not is_luajit then
    const.NULL = ffi.C.NULL
  end


  -----------------------------------------------------------
  --  Types
  -----------------------------------------------------------
  ffi.cdef [[
    typedef struct td_client td_client;
  ]]

  local td_client_mt = aux.class()


  -----------------------------------------------------------
  --  Functions
  -----------------------------------------------------------
  ffi.cdef [[
    td_client * td_json_client_create ();
	void td_json_client_send (td_client *client, const char *request);
	const char * td_json_client_receive (td_client *client, double timeout);
	const char * td_json_client_execute (td_client *client, const char *request);
	void td_json_client_destroy (td_client *client);
  ]]

  function funcs.client_create()
    return clib.td_json_client_create()
  end

  function funcs.client_send(client, request)
    clib.td_json_client_send(client, request)
  end

  function funcs.client_receive(client, timeout)
    return aux.string_or_nil(clib.td_json_client_receive(client, timeout))
  end

  function funcs.client_execute(client, request)
    return aux.string_or_nil(clib.td_json_client_execute(client, request))
  end

  function funcs.client_destroy(client)
    clib.td_json_client_destroy(client)
  end


  -----------------------------------------------------------
  --  Extended Functions
  -----------------------------------------------------------
  td_client_mt.send    = funcs.client_send
  td_client_mt.receive = funcs.client_receive
  td_client_mt.execute = funcs.client_execute
  td_client_mt.destroy = funcs.client_destroy

  -----------------------------------------------------------
  --  Finalize types metatables
  -----------------------------------------------------------
  ffi.metatype('td_client', td_client_mt)
end

-----------------------------------------------------------
--  Auxiliary
-----------------------------------------------------------
function aux.class()
  local class = {}
  class.__index = class
  return class
end

function aux.set_mt_method(t,k,v)
  local mt = getmetatable(t)
  if mt then
    mt[k] = v
  else
    setmetatable(t, { [k] = v })
  end
end

if is_luajit then
  -- LuaJIT way to compare with NULL
  function aux.is_null(ptr)
    return ptr == nil
  end
else
  -- LuaFFI way to compare with NULL
  function aux.is_null(ptr)
    return ptr == ffi.C.NULL
  end
end

function aux.string_or_nil(cstr)
  if not aux.is_null(cstr) then
    return ffi.string(cstr)
  end
  return nil
end


return setmetatable(mod, { __call = init })
