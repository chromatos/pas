{ License: wtfpl; see /copying or the Internet }

{ eval unit for string processing functions }

unit unit_strings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, functiondict, parameters;

type

  { kUnit_strings }

  kUnit_strings = class(kfunction_list)
    function str_pos       (params: kParameterList): kSeries;
    function str_len       (params: kParameterList): kSeries;
    function str_reverse   (params: kParameterList): kSeries;
    function str_delete    (params: kParameterList): kSeries;
    function str_join      (params: kParameterList): kSeries;
    function str_lower_case(params: kParameterList): kSeries;
    function str_upper_case(params: kParameterList): kSeries;
    function str_padleft   (params: kParameterList): kSeries;
    function str_padright  (params: kParameterList): kSeries;
    function str_substr    (params: kParameterList): kSeries;

    constructor create;
  end;

implementation
uses
  strutils, kUtils;

{ kUnit_strings }

constructor kUnit_strings.create;
begin
  inherited;
  Add('pos'      , @str_pos);
  Add('len'      , @str_len);
  Add('reverse'  , @str_reverse);
  Add('delete'   , @str_delete);
  Add('join'     , @str_join);
  Add('lowercase', @str_lower_case);
  Add('padleft'  , @str_padleft);
  Add('padright' , @str_padright);
  Add('substr'   , @str_substr);
end;

function kUnit_strings.str_pos(params: kParameterList): kSeries;
var
  z: integer;
  y: string;
begin
  params.resolve_vars(0);
  result:= kSeries.create;
  if params.count > 1 then
  begin
    y:= params.merge2string(1);
    for z:= 0 to params[0].count-1 do
      result.append(IntToStr(Pos(params[0][z], y)))
  end;
end;

function kUnit_strings.str_len(params: kParameterList): kSeries;
var
  z: integer;
  y: kSeries;
begin
  params.resolve_vars(0);
  y:= params.merge(0);
  result:= kSeries.create;
  if params.count > 0 then
    for z:= 0 to y.count-1 do
      result.append(IntToStr(Length(y[z])))
end;

function kUnit_strings.str_reverse(params: kParameterList): kSeries;
var
  z: integer;
begin
  params.resolve_vars(0);
  result:= params.merge(0);

  if result.count > 0 then
    for z:= 0 to result.count-1 do
      result[z]:= ReverseString(result[z])
end;

function kUnit_strings.str_delete(params: kParameterList): kSeries;
var
  z: integer;
  y: integer;
begin
  params.resolve_vars(0);
  result:= params.merge(0);
  if result.Values.Count > 1 then
    for z:= 0 to result.Values.Count-1 do
      for y:= 0 to params[0].count-1 do
      result[z]:= ReplaceStr(result[z], params[0][y], '')
end;

function kUnit_strings.str_join(params: kParameterList): kSeries;
var
  z: integer;
  y: kSeries;
begin
  params.resolve_vars(0);
  result:= kSeries.create;
  if params.count > 1 then
  begin
    y:= params.merge(1);

    result.set_value(y[0]);
    if y.count > 1 then
      for z:= 0 to y.Values.Count-1 do
        result.Values[0]:= result.Values[0] + params[0][0] + y[z]
  end
  else
  result.set_err('join'+err_param)
end;

function kUnit_strings.str_lower_case(params: kParameterList): kSeries;
var
  z: integer;
begin
  params.resolve_vars(0);
  result:= params.merge(0);
  if result.count > 0 then
    for z:= 0 to Result.Values.Count-1 do
      result.Values[z]:= LowerCase(result.Values[z])
end;

function kUnit_strings.str_upper_case(params: kParameterList): kSeries;
var
  z: integer;
  b: string;
begin
  params.resolve_vars(0);
  result:= params.merge(0);

  if result.count > 0 then
    for z:= 0 to Result.Values.Count-1 do
    begin
      b:= UpperCase(result.Values[z]);
      result.Values[z]:= b
    end;
end;

function kUnit_strings.str_padleft(params: kParameterList): kSeries;
{ padleft(padding, length, strings) }
var
  z: integer;
  y: integer;
  p: string;
  b: string;
begin
  if params.count > 2 then
  begin
    params.resolve_vars(0);
    result:= params.merge(2);
    p:= params[0][0];
    y:= StrToIntDef(params[1][0], 0);
    if result.count > 0 then
      for z:= 0 to Result.Values.Count-1 do
      begin
        b:= result.Values[z];
        b:= str_pad(b, p, y, false);
        result.Values[z]:= b
      end
  end
  else
    result.set_err('padleft'+err_param)
end;

function kUnit_strings.str_padright(params: kParameterList): kSeries;
{ padright(padding, length, strings) }
var
  z: integer;
  y: integer;
  p: string;
begin
  if params.count > 2 then
  begin
    params.resolve_vars(0);
    result:= params.merge(2);
    p:= params[0][0];
    y:= StrToIntDef(params[1][0], 0);
    if result.count > 0 then
      for z:= 0 to Result.Values.Count-1 do
        result.Values[z]:= str_pad(result.Values[z], p, y, true)
  end
  else
    result.set_err('padright'+err_param)
end;

function kUnit_strings.str_substr(params: kParameterList): kSeries;
var
  z: integer;
  y,
  x: integer;
  b: string;
begin
  if params.count > 2 then
  begin
    params.resolve_vars(0);
    x:= StrToIntDef(params[0][0], 1);
    y:= abs(StrToIntDef(params[1][0], 1));
    result:= params.merge(2);

    if result.count > 0 then
    begin
      if x = 0 then x:= 1;
      if x > 0 then
        for z:= 0 to Result.Values.Count-1 do
        begin
          b:= Copy(result.Values[z], x, y);
          result.Values[z]:= b
        end
      else
      if x < 0 then
      begin
        for z:= 0 to Result.Values.Count-1 do begin
          b:= Copy(result.Values[z], length(result.Values[z])+x-y+2, y);
          result.Values[z]:= b
        end
      end
    end
  end
  else
    result.set_err('substr'+err_param)
end;

end.

