unit stringUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, evaluator;

procedure load(dictionary: kfunctionDict);

implementation
uses
    strutils;

function val(meta: p_metaParam; parameters: k_parameterList): string;
var
  z: integer;
begin
  result:= '';
  if parameters.Count > 0 then
    for z:= 0 to parameters.Count-1 do
      result+= meta^.parser^.storage[parameters[z]]
end;

function reverse(meta: p_metaParam; parameters: k_parameterList): string;
var
  z: integer;
begin
  if parameters.Count > 0 then
    for z:= 0 to parameters.Count-1 do
      result:= ReverseString(parameters[z]);
end;

function join(meta: p_metaParam; parameters: k_parameterList): string;
var
    z: integer;
begin
    if parameters.Count > 2 then
    begin
        result:= parameters[1];
        for z:= 2 to parameters.count -1 do
            result+= parameters[0] + parameters[z]
    end
    else
    if parameters.Count = 2 then
        result:= parameters[1]
    else
        result:= ''
end;

function concatenate(meta: p_metaParam; parameters: k_parameterList): string;
var
    z: integer;
begin
    result:= '';
    if parameters.Count > 0 then
        result:= parameters.cat
end;

procedure load(dictionary: kfunctionDict);
begin
    with dictionary do
    begin
        namespace:= 'strings';
        Add('join', @join);
        Add('cat', @concatenate);
    end;
end;

end.
