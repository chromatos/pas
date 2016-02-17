{ License: wtfpl; see /copying or the Internet }

{ A function dictionary class }

unit fdictionary;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs, strutils, parameterStuff;

type

    eFunction = class(exception);

    p_metaParam = ^k_metaParam;

    k_metaParam = record
      parser: kEvaluator;
    end;


    kfunction  = function (meta: p_metaParam; parameters: k_parameterList): string;
    kfunctionO = function (meta: p_metaParam; parameters: k_parameterList): string of object;

    { kfunctionDict }

    kfunctionDict = class
        namespace: string;
          storage: TFPHashList;

        function  Get(Index: string): kfunction; {$ifdef CCLASSESINLINE}inline;{$endif}
        procedure Put(Index: string; Item: kfunction); {$ifdef CCLASSESINLINE}inline;{$endif}

        function  Add(const AName: shortstring; Item: kfunction): integer;
        property  Items[Index: string]: kfunction read Get write Put; default;

        constructor create;
        destructor  destroy;

    end;


implementation

{ kfunctionDict }

function kfunctionDict.Add(const AName: shortstring; Item: kfunction): integer;
begin
    result:= storage.Add(AName, Item)
end;

constructor kfunctionDict.create;
begin
    inherited;
    storage:= TFPHashList.Create
end;

destructor kfunctionDict.destroy;
begin
    inherited
end;

function kfunctionDict.Get(Index: string): kfunction;
var
  y: pointer;
begin
    y:= storage.Find(Index);
    if y <> nil then
      result:= kfunction(y)
    else
      ;//raise eFunction.create()
end;

procedure kfunctionDict.Put(Index: string; Item: kfunction);
var
    z: pointer;
begin
    z:= storage.Find(index);
    z:= Item
end;


end.

