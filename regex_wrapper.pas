{ A quick wrapper for the regex unit so we don't have to bother with using its
  class for random regex sprinklings, most especially because url_title4 is
  mostly functional at the moment.

  License: wtfpl (See 'copying' file or the Internet)
}

unit regex_wrapper;

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils;

function match(aRegex: string; subStrings: tStringList): integer;
function match(aRegex: string; const subString: string; out matchPos: integer; var offset: integer): boolean;

function replace(aRegex: string; const source, newStr: string; out destination: string): integer;
function replace(aRegex: string; source: tStringList; const newStr: string; count: integer): tStringList;

implementation
uses regex;

function match(aRegex: string; subStrings: tStringList): integer;
var z: integer = 0;
    y: integer = 1;
    x: integer = 1;
    r: TRegexEngine;
    a: boolean = false;
begin
    r:= TRegexEngine.Create(aRegex);

    while (not a) and (z < subStrings.Count) do begin
        a:= r.MatchString(subStrings.strings[z], y, x);
        inc(z)
    end;
    if a then
        result:= z - 1
    else
        result:= -1;
    r.Free // although it does seem like classes are freed when they go out of scope
end;

function match(aRegex: string; const subString: string; out matchPos: integer; var offset: integer): boolean;
var r: TRegexEngine;
begin
    r     := TRegexEngine.Create(aRegex);
    result:= r.MatchString(subString, matchPos, offset);
    r.free
end;

function replace(aRegex: string; const source, newStr: string; out destination: string): integer;
var r: TRegexEngine;
begin
    r     := TRegexEngine.Create(aRegex);
    result:= r.ReplaceAllString(source, newStr, destination);
    r.Free
end;

function replace(aRegex: string; source: tStringList; const newStr: string; count: integer): tStringList;
var z: integer;
    b: string;
begin
    count := 0;
    result:= tStringList.Create;
    for z:= 0 to source.Count-1 do
    begin
        count+= replace(aRegex, source.Strings[z], newStr, b);
        result.Append(b)
    end
end;

end.

