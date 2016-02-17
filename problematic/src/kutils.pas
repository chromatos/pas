{ License: wtfpl; see /copying or the Internet }

{ Miscellaneous utility functions }

unit kUtils;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  keyval = record
    key,
    val: string;
  end;

  tCharSet = set of char;

function  ExtractUp2delimiter(const S: string; var Pos: Integer; const Delims: TSysCharSet): string;
procedure SkipSubStr(buffer: string; aSet: tCharSet; var position: longint);

function  strings2string(strings: TStrings): string;
function  str_pad(buffer, pad: string; size: integer; right: boolean): string;

function  fill(aString: string; count: integer): string;

function  hex2string(buffer: string): string;
function  unescape(buffer: string): string;
function  ExtractQuoteStr(buffer: string; var position: longint): string;
function  extract_number(buffer: string; var position: longint): string;

implementation
uses
  strutils;

procedure SkipSubStr(buffer: string; aSet: tCharSet; var position: longint);
var
  l: longint;
begin
  l:= length(buffer);
  while (position < l) and (buffer[position] in aSet) do
    inc(position)
end;

function ExtractUp2delimiter(const S: string; var Pos: Integer; const Delims: TSysCharSet): string;
{ This is ExtractSubStr without stepping over the delimiters }
var
  i,l: Integer;

begin
  i:=Pos;
  l:=Length(S);
  while (i<=l) and not (S[i] in Delims) do
    inc(i);
  Result:=Copy(S,Pos,i-Pos);
  Pos:=i;
end;


function fill(aString: string; count: integer): string;
var
  pl: integer;
begin
  pl:= length(aString);
  result:= DupeString(aString, count div pl) + LeftStr(aString, count mod pl);
end;

function strings2string(strings: TStrings): string;
var
  z: integer;
  l: integer;
begin
  l:= strings.Count;
  result:= '';
  if l > 0 then
  begin
    dec(l);
    for z:= 0 to l do
      result+= strings[z]
  end
end;


function str_pad(buffer, pad: string; size: integer; right: boolean): string;
var
  bl: integer;
  pl: integer;
  s : integer;
begin
  bl:= length(buffer);
  pl:= size - bl;
  s := abs(size);
  if (bl > 0) and (pl > 0) and (bl < s) then
  begin
    if right then
      result:= buffer + fill(pad, pl)
    else
      result:= fill(pad, pl) + buffer
  end
  else
    result:= buffer
end;


function hex2string(buffer: string): string;
var
  l,
  z: integer;
  b: string;
begin
result:= buffer
{  l:= length(buffer);

  if odd(l) then
    b:= '0' + buffer
  else
    b:= buffer;

  z:= 1;
  while (z+1 < l) do
  begin
    result+= char(dec2hex(b[z..z+1]));
    inc(z, 2)
  end; }
end;

function unescape(buffer: string): string;
var
  l,
  m,
  z: integer;
begin
  l:= length(buffer);
  z:= 1;
  result:= '';
  while z < l do
  begin
    result+= ExtractSubstr(buffer, z, ['\']);
    if z < l-1 then
    begin
      inc(z);
      case buffer[z] of
        'a': result+= #7;
        'b': result+= #8;
        'f': result+= #12;
        'n': result+= #10;
        'r': result+= #13;
        't': result+= #9;
        'v': result+= #11;
        'x': begin
               inc(z);
               m:= z;
               while (z < l) and (buffer[z] in ['0'..'9','A'..'F','a'..'f']) do
                 inc(z);
               if z-1 > m then
                   result:= hex2String(buffer[m..z-1]);
             end
      end
    end
  end
end;

function ExtractQuoteStr(buffer: string; var position: longint): string;
var
  l: longint;
  s: longint;
  d: boolean = false;
begin
  l:= length(buffer);

  //if buffer[position] = '"' then
    s:= position+1;

  while (position < l) and (not d) do
  begin
    inc(position);
    if buffer[position] in ['"'] then
      begin
        d:= true
      end
    else
    if buffer[position] in ['\'] then
      inc(position)
  end;
  if d and (position > s) then
    result:= buffer[s..position-1];
  inc(position);
end;

function extract_number(buffer: string; var position: longint): string;
var
  l: longInt;
  y: longint;
begin
  l:= length(buffer);
  y:= position;

  if (position + 2 < l) and (buffer[position+1] in ['b', 'x']) then
  begin
    inc(position);
    if (buffer[position] = 'x') then
    begin
      inc(position);
      while (position <= l) and (buffer[position] in ['0'..'9','A'..'F','a'..'f']) do
        inc(position);
    end
    else
    if (buffer[position] = 'b') then
    begin
      inc(position);
      while (position <= l) and (buffer[position] in ['0', '1']) do
        inc(position)
    end;
  end
  else
    while (position <= l) and (buffer[position] in ['0'..'9']) do
      inc(position);
  if position > y then
    result:= buffer[y..position-1]
  else
    result:= buffer[y]
end;


end.
