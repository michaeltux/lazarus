unit uLuaCmdXpl;

{$mode delphi}

interface

uses
  Classes, SysUtils, Lua;

function XplCommand(luaState : TLuaState) : integer;
function XplCommandBegin(luaState : TLuaState) : integer;
function XplCommandEnd(luaState : TLuaState) : integer;
function GetXplVariable(luaState : TLuaState) : integer;
function SetXplVariable(luaState : TLuaState) : integer;
function XplDrawText(luaState : TLuaState) : integer;
function XplVarChange(luaState : TLuaState) : integer;
function UnregisterXplVarChange(luaState : TLuaState) : integer;


implementation

uses
  uGlobals, uXplCommon, variants, uXplMessages;

function XplCommand(luaState : TLuaState) : integer;
var arg : PAnsiChar;
begin
     //reads the first parameter passed to Increment as an integer
     arg := lua_tostring(luaState, 1);

     //print
     Glb.XplControl.ExecuteCommand(arg);

     //clears current Lua stack
     Lua_Pop(luaState, Lua_GetTop(luaState));

     //Result : number of results to give back to Lua
     Result := 0;
end;

function XplCommandBegin(luaState: TLuaState): integer;
var arg : PAnsiChar;
begin
     arg := lua_tostring(luaState, 1);
     Glb.XplControl.ExecuteCommandBegin(arg);
     Result := 0;
end;

function XplCommandEnd(luaState: TLuaState): integer;
var arg : PAnsiChar;
begin
     arg := lua_tostring(luaState, 1);
     Glb.XplControl.ExecuteCommandEnd(arg);
     Result := 0;
end;

function GetXplVariable(luaState: TLuaState): integer;
var arg : PAnsiChar;
  lRes: TXplValue;
  lMessage: String;
  lNumOfParams: Integer;
  lIndex: Integer;
begin
  lNumOfParams:=lua_gettop(luaState);
  if (lNumOfParams < 1) then
    raise LmcException.Create('Wrong number of parameters. Provide at least name.');
  arg := lua_tostring(luaState, 1);
  if (lNumOfParams = 2) then
  begin
    lIndex := lua_tointeger(luaState, 2);
    lRes := Glb.XplControl.GetXplVariable(arg, lIndex);
  end
  else
    lRes := Glb.XplControl.GetXplVariable(arg);
  if (lRes = nil) then
  begin
   lMessage:='No value returned from Xplane';
   lua_pushstring(luaState, PChar(lMessage));
   Result := 1;
  end else
  begin
   if (lRes.ValueType = vtString) then
   begin
     lMessage:=lRes.StringValue;
     lua_pushstring(luaState, PChar(lMessage));
   end
   else if (lRes.ValueType = vtInteger) then lua_pushinteger(luaState, lRes.IntValue)
   else if (lRes.ValueType = vtDouble) then lua_pushnumber(luaState, lRes.DoubleValue)
   else
     begin
       lMessage:='Unexpected type returned from XPL with value ' + lRes.ToString;
       lua_pushstring(luaState, PChar(lMessage))
     end;
   Result := 1;
   Glb.XplControl.XplVarProcessed;
  end;
end;

function SetXplVariable(luaState: TLuaState): integer;
var arg : PAnsiChar;
  lVal: TXplValue;
  lNumOfParams: Integer;
  lIndex: Integer;
begin
  lNumOfParams:=lua_gettop(luaState);
  if (lNumOfParams < 2) then
    raise LmcException.Create('Wrong number of parameters. Provide at least name and value.');
  arg := lua_tostring(luaState, 1);
  if (lua_isnumber(luaState, 2) = 0) then lVal := TXplValue.Create(lua_tonumber(luaState, 2))
  else if (lua_isstring(luaState, 2) <> 0) then lVal := TXplValue.Create(lua_tostring(luaState, 2))
  else
  begin
    raise Exception.Create('Unexpected variable type');
  end;
  if (lNumOfParams = 3) then
  begin
    lIndex := lua_tointeger(luaState, 3);
    Glb.DebugLogFmt('Setting variable %s[%d] to %s', [arg, lIndex, lVal.ToString], cLoggerXpl);
    Glb.XplControl.SetXplVariable(arg, lVal, lIndex);
  end else begin
    Glb.DebugLog('Setting variable ' + arg + ' to ' + lVal.ToString, cLoggerXpl);
    Glb.XplControl.SetXplVariable(arg, lVal);
  end;
  Result := 0;
end;

function XplDrawText(luaState: TLuaState): integer;
var
  lText : PAnsiChar;
  lNumOfParams: Integer;
  lPos: Single;
  lSec: Integer;
begin
  lNumOfParams:=lua_gettop(luaState);
  lText := lua_tostring(luaState, 1);
  if (lNumOfParams > 1) then
    lPos := lua_tonumber(luaState, 2)
  else
    lPos := 0.3;
  if (lNumOfParams > 2) then
    lSec := lua_tointeger(luaState, 3)
  else
    lSec := 5;
  Glb.XplControl.DrawText(lText, lPos, lSec);
  Result := 0;
end;

function XplVarChange(luaState: TLuaState): integer;
var
  lVarName : PAnsiChar;
  lIntervalMs : Integer;
  lHandlerRef: Integer;
  lNumOfParams: Integer;
begin
  //Glb.LuaEngine.StackDump(luaState);
  lNumOfParams:=lua_gettop(luaState);
  if (lNumOfParams < 2) then
    raise LmcException.Create('Wrong number of parameters. Provide at least name and handler.');
  if (lNumOfParams = 3) then
  begin
    if (lua_isnumber(luaState, -1) = 1) then
    begin
      lIntervalMs:=Trunc(lua_tonumber(luaState, -1));
      lua_settop(luaState, 2);
    end
    else
      raise LmcException.Create('3rd parameter is supposed to be a number.');
  end
  else
    lIntervalMs:=0;
  lHandlerRef := luaL_ref(luaState, LUA_REGISTRYINDEX);
  Glb.DebugLog(Format('Got function reference with key %d', [lHandlerRef]), cLoggerLua);
  lVarName := lua_tostring(luaState, 1);
  Glb.XplControl.SetVariableHook(lVarName, lHandlerRef, lIntervalMs);
  Result := 0;
end;

function UnregisterXplVarChange(luaState: TLuaState): integer;
var
  lVarName : PAnsiChar;
  lNumOfParams: Integer;
begin
  //Glb.LuaEngine.StackDump(luaState);
  lNumOfParams:=lua_gettop(luaState);
  if (lNumOfParams <> 1) then
    raise LmcException.Create('Wrong number of parameters. Provide name.');
  if (lua_isstring(luaState, -1) = 1) then
  begin
    lVarName := lua_tostring(luaState, 1);
  end
  else
    raise LmcException.Create('1st parameter is supposed to be a string.');
  Glb.XplControl.UnhookVariable(lVarName);
  Result := 0;
end;

end.

