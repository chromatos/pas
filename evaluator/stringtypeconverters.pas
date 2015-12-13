unit stringtypeconverters;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, evaluator;

type
    kFloatList = array of extended;
    kIntList   = array of Int64;

function hasFloats(parameters: k_parameterList): boolean;

function parameters2floats(list: k_parameterList): kFloatList;
function floats2parameters(list: kFloatList): k_parameterList;

function parameters2ints(list: k_parameterList): kIntList;
function ints2parameters(list: kIntList): k_parameterList;

function array2parameters(list: array of string): k_parameterList;

implementation

function hasFloats(parameters: k_parameterList): boolean;
var
    z: integer = 0;
begin
    if parameters.count > 0 then
        while (z < parameters.Count) and (pos('.', parameters.Strings[z]) = 0) do
            inc(z);
    result:= z < parameters.count
end;

function parameters2floats(list: k_parameterList): kFloatList;
var
    z: integer;
begin
    SetLength(result, list.count);
    for z:= 0 to list.count - 1 do
        result[z]:= StrToFloatDef(list.Strings[z], 0)
end;

function floats2parameters(list: kFloatList): k_parameterList;
var
    z: integer;
begin
    result:= k_parameterList.Create;
    for z:= 0 to high(list) do
        result.AddVal(FloatToStr(list[z]))
end;

function parameters2ints(list: k_parameterList): kIntList;
var
    z: integer;
begin
    SetLength(result, list.count);
    for z:= 0 to list.count - 1 do
        result[z]:= StrToInt64Def(list.Strings[z], 0)
end;

function ints2parameters(list: kIntList): k_parameterList;
var
    z: integer;
begin
    result:= k_parameterList.Create;
    for z:= 0 to high(list) do
        result.AddVal(IntToStr(list[z]))
end;

function array2parameters(list: array of string): k_parameterList;
var
    z: integer;
begin
    result:= k_parameterList.create;
    if length(list) > 0 then
        for z:= 0 to high(list) do
            result.AddVal(list[z]);
end;


end.
