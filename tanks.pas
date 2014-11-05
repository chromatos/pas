{ Unit that stores buffers without any kind of escapement.

  Really, they're just strings prefixed with a length indicator and wrapped with
  braces to keep their teeth straight. There's also an option to calculate,
  embed and verify checksums.

  Options are wrapped in square brackets and semicolon-separated:
          {[option2:value;option2;value]length:content}

  Examples:
      {17:Example buffer}
        ^ Buffer length ^ decorative only because we already know where it ends

      {[sha1:b3e687ba81093b2ee9abd135e4655697fb7819e4]19:This one has a sha1}


  License: wtfpl (See 'copying' file or the Internet)
}

unit tanks;

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils, kUtils;

type
    kSerial_options = set of (so_md5, so_sha1);

    eChecksum_mismatch = class(Exception);


function tank          (buffer: string; options: kSerial_options): string;
function tank          (strings: tStringList; options: kSerial_options): string;

function detank        (buffer: string): string;
function detank        (buffer: string; var offset: integer): string;
function detank2list   (buffer: string): tStringList;

function tank2keyvalue(buffer: string): kKeyValue;
function tank2keyvalue(buffer: string; var offset: integer): kKeyValue;
function keyvalue2tanks(kv: kKeyValue): string;
function keyvalue2tanks(key, value: string): string;

function keyvalues2tanks(keyvals: kKeyValues): string;
function tanks2keyvalues(buffer: string): kKeyValues;

implementation
uses
    sha1, md5, strutils;

const // Would be better to do whatever's required for internationalizing them
    e_missing = 'Improper stream: missing ';
    e_short   = 'Stream is too short';

function tank(buffer: string; options: kSerial_options): string;
var o: string = '';

begin
    if so_sha1 in options then
        o:= 'sha1:' + SHA1Print(SHA1String(buffer));
    if so_md5 in options then begin
        if o <> '' then
            o+= ';';
        o+= 'md5:' + MD5Print(MD5String(buffer));
    end;
    if o <> '' then
        o:= '[' + o + ']';
    result:= '{'
           + o
           + IntToStr(length(buffer))
           + ':'
           + buffer
           + '}'
end;

function tank(strings: tStringList; options: kSerial_options): string;
var z: integer;
begin
    result:= '';
    for z:=0 to strings.Count-1 do
        result+= tank(strings.Strings[z], options)
end;

function detank(buffer: string; var offset: integer): string;
var z              : integer;
    y              : integer = 0;
    expected_length: integer = 0;
    l              : integer;
    options        : string  = '';
begin
    l:= length(buffer);

    if l < offset + 4 then
        raise EStreamError.Create(e_short);

    z:= offset;
    z:= PosEx('{', buffer, z);

    if buffer[z] = '{' then
    begin
        z:= PosSetEx(['0'..'9', '['], buffer, z);

        if z < 1 then
            raise EStreamError.create(e_short);
        if (buffer[z] = '[') then
        begin
            inc(z);
            options:= ExtractSubstr(buffer, z, [']']);

            while (not(buffer[z] in ['0'..'9'])) and (z < l) do // Pick up the slack
                inc(z)
        end;

        if buffer[z] in ['0'..'9'] then
        begin
            y:= z;
            while (buffer[z] in ['0'..'9']) and (z < l) do
               inc(z);

            expected_length:= StrToInt(buffer[y..z-1]);

            while (not(buffer[z] in [':'])) and (z < l) do
                inc(z);
            if buffer[z] in [':'] then
                inc(z);

            if l - z >= expected_length then             // Don't want to go out of bounds, plus
            begin                                        // we need one char for the final '}'
                result:= buffer[z..z+expected_length-1];
                inc(z, expected_length);
                if options <> '' then
                begin
                    y:= 1;
                    while y < length(options) do
                        case ExtractSubstr(options, y, [':']) of
                            'md5' : if ExtractSubstr(options, y, [';', ']']) <> MD5Print(MD5String(result)) then
                                        raise eChecksum_mismatch.Create('md5 mismatch');

                            'sha1': if ExtractSubstr(options, y, [';', ']']) <> SHA1Print(SHA1String(result)) then
                                        raise eChecksum_mismatch.Create('sha1 mismatch');
                        end
                end
            end
            else
                raise EStreamError.Create('The stream lied about its size: Expected '
                                         +intToStr(expected_length)
                                         +' bytes but it was actually '
                                         +intToStr(l - z));
        end else
            raise EStreamError.Create(e_missing + 'length indicator: ' + buffer[z-1..z+1]);


        while (not(buffer[z] in ['}'])) and (z < l) do
            inc(z);
        if buffer[z] in ['}'] then
            inc(z)
        else
            raise EStreamError.Create(e_missing + '''}''');

        offset:= z
    end else
        raise EStreamError.Create(e_missing + '''{''');
end;

function detank(buffer: string): string;
var z: integer = 1;
begin
    result:= detank(buffer, z)
end;

function detank2list(buffer: string): tStringList;
var z: integer = 1;
    l: integer;
    b: string;
begin
    l:= length(buffer);
    result:= tStringList.Create;
    while z < l do begin
        b:= detank(buffer, z);

        if b <> '' then
            result.Append(b)
    end
end;

function tank2keyvalue(buffer: string): kKeyValue;
var z: integer = 1;
    b: string;
begin
    b:= detank(buffer);
    result.key  := detank(b, z);
    result.value:= detank(b, z)
end;

function tank2keyvalue(buffer: string; var offset: integer): kKeyValue;
var z: integer = 1;
    b: string;
begin
    b:= detank(buffer, offset);
    result.key  := detank(b, z);
    result.value:= detank(b, z)
end;

function keyvalue2tanks(kv: kKeyValue): string;
begin
    result:= tank(tank(kv.key, []) + tank(kv.value, []), [])
end;

function keyvalue2tanks(key, value: string): string;
begin
    result:= tank(tank(key, []) + tank(value, []), [])
end;

function keyvalues2tanks(keyvals: kKeyValues): string;
var z: integer = 0;
begin
    for z:= 0 to high(keyvals) do
        result+= keyvalue2tanks(keyvals[z]);
    result:= tank(result, [])
end;

function tanks2keyvalues(buffer: string): kKeyValues;
var z : integer = 1;
    y : integer = 0;
    l : integer = 0;
    rl: integer = 8;
    b : string;
begin
    b:= buffer;//b:=detank(buffer);
    l:= length(b);
    setLength(result, rl);

    while z < l do begin
        result[y]:= tank2keyvalue(b, z);
        inc(y);
        if y = rl then
        begin
            inc(rl, 8);
            setLength(result, rl)
        end;
    end;
    setLength(result, y - 1)
end;

end.



