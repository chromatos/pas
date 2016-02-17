{ License: wtfpl; see /copying or the Internet }

{ Provides a dictionary/associative array ancestor class }
unit dictionary;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs;

type

    kdOptions = (kdo_sorted, kdo_caseSensitive);
    kdOptionSet = set of kdOptions;

    { kDictionary_ancestor }

    kDictionary_ancestor = class
    private
      Fname: string;
      procedure Setname(AValue: string);
    public
      options : kdOptionSet;
      function  Get(key: shortstring): string;virtual;abstract;
      procedure Put(key: shortstring; value: string);virtual;abstract;

      function  Add(const key: shortstring; value: string): integer;virtual;abstract;
      function  Del(const key: shortstring): boolean; virtual; abstract;
      procedure clear; virtual;abstract;

      function  to_json: string;virtual;abstract;
      function  to_json(from_key, to_key: string): string;virtual;abstract;
      procedure from_json(buffer: string);virtual;abstract;

      property  Items[key: shortstring]: string read Get write Put; default;
      property  name: string read Fname write Setname;
    end;

    { kDictionary_List }

{    kDictionary_List = class(kDictionary_ancestor)
//    private
//      function  Get(key: shortstring): kDictionary_ancestor;
//      procedure Put(key: shortstring; AValue: kDictionary_ancestor);
//    public
      storage : TFPHashList;

      function  Get(key: shortstring): kDictionary_ancestor;override;
      procedure Put(key: shortstring; child: kDictionary_ancestor);virtual;

      function  Add(const key: shortstring; value: kDictionary_ancestor): integer;virtual;
      function  Del(const key: shortstring): boolean; virtual;
      procedure clear; virtual;

      function  to_json: string;virtual;
      function  to_json(from_key, to_key: string): string;virtual;
      procedure from_json(buffer: string);virtual;

      property  Items[child: shortstring]: kDictionary_ancestor read Get write Put;default;

      property  key: string read fname write fname;

      constructor create;
      destructor  destroy;
    end;
}
    { kNumbered_List }

    kNumbered_List = class(kDictionary_ancestor)
        storage : TStringList;

        function  Get(key: shortstring): string;virtual;
        procedure Put(key: shortstring; value: string);virtual;

        function  Add(const key: shortstring; value: string): integer;virtual;
        function  Del(const key: shortstring): boolean; virtual;
        procedure clear; virtual;

        function  to_json: string;virtual;
        function  to_json(from_key, to_key: string): string;virtual;
        procedure from_json(buffer: string);virtual;

        property  name: string read fname write fname;

        constructor create;
        destructor  destroy;
    end;

    kDictionary = class(kDictionary_ancestor)
    private
        procedure Setname(AValue: string);
    public
        storage: TFPStringHashTable;

        function  Get(key: shortstring): string;override;
        procedure Put(key: shortstring; value: string);override;

        function  Add(const key: shortstring; value: string): integer;override;
        function  Del(const key: shortstring): boolean; override;
        procedure clear; override;

        function  to_json: string;override;
        function  to_json(from_key, to_key: string): string;override;
        procedure from_json(buffer: string);override;

        property  name: string read Fname write Setname ;

        constructor create;
        destructor  destroy;
    end;

implementation

function is_numeric(buffer: string): boolean;
var
    z: integer = 1;
begin
    if length(buffer) > 0 then
        while (buffer[z] in ['-',' ','0'..'9']) and (z < length(buffer)) do
            inc(z);
    result:= z >= length(buffer)
end;

{ kDictionary_List }
{
function kDictionary_List.Get(name: shortstring): kDictionary_ancestor;
begin

end;

procedure kDictionary_List.Put(name: shortstring; AValue: kDictionary_ancestor);
begin

end;

function kDictionary_List.Get(name: string): kDictionary_ancestor;
begin

end;

procedure kDictionary_List.Put(name: string; child: kDictionary_ancestor);
begin

end;

function kDictionary_List.Add(const name: shortstring;
  child: kDictionary_ancestor): integer;
begin
  result:= storage.Add(name, @child);
end;

function kDictionary_List.Del(const name: shortstring): boolean;
var
  z: integer;
begin
  z:= storage.FindIndexOf(name);
  if z >= 0 then
  begin
    kDictionary_ancestor(storage[z]).Free;
    storage.Delete(z);
    result:= true
  end
  else
    result:= false
end;

procedure kDictionary_List.clear;
var
  z: integer;
begin
  if storage.Count > 0 then
    for z:= 0 to storage.Count-1 do
      kDictionary_ancestor(storage[z]).Free;
  storage.Clear
end;

function kDictionary_List.to_json: string;
begin

end;

function kDictionary_List.to_json(from_key, to_key: string): string;
begin

end;

procedure kDictionary_List.from_json(buffer: string);
begin

end;

constructor kDictionary_List.create;
begin
  inherited;
  storage:= TFPHashList.Create
end;

destructor kDictionary_List.destroy;
begin
  clear;
  storage.Free;
  inherited
end;
}
{ kDictionary_ancestor }

procedure kDictionary_ancestor.Setname(AValue: string);
begin
  if Fname=AValue then Exit;
  Fname:=AValue;
end;

{ kDictionary }

procedure kDictionary.Setname(AValue: string);
begin
  if Fname=AValue then Exit;
  Fname:=AValue;
end;

function kDictionary.Get(key: shortstring): string;
begin
    result:= storage[key]
end;

procedure kDictionary.Put(key: shortstring; value: string);
begin
    storage[key]:= value
end;

function kDictionary.Add(const key: shortstring; value: string): integer;
begin
    storage.Add(key, value)
end;

function kDictionary.Del(const key: shortstring): boolean;
begin
    storage.Delete(key)
end;

procedure kDictionary.clear;
begin
    storage.Clear
end;

function kDictionary.to_json: string;
begin

end;

function kDictionary.to_json(from_key, to_key: string): string;
begin

end;

procedure kDictionary.from_json(buffer: string);
begin

end;

constructor kDictionary.create;
begin
    storage:= TFPStringHashTable.Create;
end;

destructor kDictionary.destroy;
begin
    storage.Free
end;

{ kDictionary_ancestor }



{ kNumbered_List }

function kNumbered_List.Get(key: shortstring): string;
var
    z: integer;
begin
    if is_numeric(key) then
    begin
        z:= StrToIntDef(key, 0);
        if z < 0 then
            z:= storage.Count - z;
        if z < storage.Count then
            result:= storage[z]
        else
            result:= ''
    end
end;

procedure kNumbered_List.Put(key: shortstring; value: string);
var
    z: integer;
begin
    z:= StrToIntDef(key, -1);

    if (z < storage.Count) and (z >= 0) then
        storage[z]:= value
    else
        storage.Append(value)
end;

function kNumbered_List.Add(const key: shortstring; value: string): integer;
begin
    result:= storage.Add(value)
end;

function kNumbered_List.Del(const key: shortstring): boolean;
var
    z: integer;
begin
    if is_numeric(key) then
    begin
        z:= StrToIntDef(key, 0);
        if z < 0 then
            z:= storage.Count - z;
        if z < storage.Count then
            storage.Delete(z)
    end
end;

procedure kNumbered_List.clear;
begin
    storage.Clear
end;

function kNumbered_List.to_json: string;
begin
    result:='{'+fname+':['+storage.CommaText+']}'
end;

function kNumbered_List.to_json(from_key, to_key: string): string;
var
    z: integer;
begin
    result:= '{'+fname+':[';
    if storage.Find(from_key, z) then
    begin
        result+= '"'+storage[z]+'"';
        while z < storage.Count do
        begin
            inc(z);
            result+= ',"'+storage[z]+'"'
        end;
        result+=']}'
    end
end;

procedure kNumbered_List.from_json(buffer: string);
begin

end;

constructor kNumbered_List.create;
begin
    inherited;
    storage:= TStringList.Create
end;

destructor kNumbered_List.destroy;
begin
    storage.Free;
    inherited
end;

end.

