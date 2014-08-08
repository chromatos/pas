{ This is a small hunk of string processing crap
  License: wtfpl (See 'copying' file or the Internet)
}

{ This is in dire need of rewriting. Several functions are nearly the same and
  some have dumb names. I'll get to it. }

{$mode objfpc}{$h+}
unit kUtils;

interface
uses classes, sysUtils;

type
    kStrings = array of string;

function  splitByType      (yourString: string; skipWhiteSpace: boolean = true;
                            alphaNum: boolean = true): tStringList;

function  split            (delimiter: char; yourString: string): tStringList; // These are unnecessary because
function  join             (delimiter: char; stringList: tStringList): string; // we're using tStringList now.
function  split            (delimiter: char; yourString: string): kStrings;

function  splitBySequence  (sequence, buffer: string): tStringList;

function  scanByDelimiter  (delimiter: char; buffer: string; var position: dWord): string;
function  scanToWord       (aWord: string; buffer: string; var position: dWord; ignoreCase: boolean = true): string;
procedure findNext         (delimiter: char; buffer: string; var position: dWord);

function  wordPresent      (yourWord, buffer: string; caseSensitive: boolean = false): boolean;
function  findWord         (yourWord, buffer: string; caseSensitive: boolean = false): dWord;
function  wordPresent      (yourWord: string; strings: tStringList; caseSensitive: boolean = false): boolean; overload;
function  findWord         (yourWord: string; strings: tStringList; caseSensitive: boolean = false): dWord; overload;

function  countDelimiters  (delimiter: char; yourString: string): dWord;
function  ciPos            (subString, buffer: string): dWord; // case-insensitive Pos()

function  isNumeric        (buffer: string): boolean;

function  stripControls    (buffer: string): string;
function  stripSomeControls(buffer: string): string;
function  reduceWhiteSpace (buffer: string): string;
function  clipText         (buffer: string; newLength: word): string;

function  reverse          (buffer: string): string;

function  readFile         (fileName: string): string;

implementation

function readFile(fileName: string): string;
var x: tFileStream;
begin
    if FileExists(fileName) then begin
        x:= TFileStream.create(fileName, fmOpenRead);
        setLength(result, x.Size);
        x.Read(result[1], x.Size);
        x.Free
    end else
        result:= ''
end;

function countDelimiters(delimiter: char; yourString: string): dWord;
var z: dWord = 0;
begin
    result:= 0;
    while z < length(yourString) do begin
        inc(z);
        if yourString[z] = delimiter then
            inc(result)
    end
end;

function  ciPos(subString, buffer: string): dWord;
var a,
    b: string;
begin
    a:= lowercase(subString);
    b:= lowercase(buffer);
    result:= pos(a, b)
end;


function stripControls(buffer: string): string;
var z: dWord = 1;
    y: dWord = 1;
begin
    if buffer <> '' then begin
        setLength(result, length(buffer));
        for z:= 1 to length(buffer) do
            if byte(buffer[z]) > 31 then
            begin
                result[y]:= buffer[z];
                inc(y)
            end else
            if buffer[z] in [#9,#10,#13] then
            begin
                result[y]:= ' ';
                inc(y)
            end;
        setLength(result, y-1)
    end
end;

function  stripSomeControls(buffer: string): string;
var z: dWord = 1;
    y: dWord = 1;
begin
    if buffer <> '' then begin
        setLength(result, length(buffer));
        for z:= 1 to length(buffer) do
            if not(buffer[z] in [#0, #9..#13]) then { #0 doesn't matter but some
                                                      people think null-terminated
                                                      strings are reasonable. }
            begin
                result[y]:= buffer[z];
                inc(y)
            end;
        setLength(result, y-1)
    end
end;

function split(delimiter: char; yourString: string): kStrings;
var z,
    y,
    aIndex: integer;
begin
    z     := 0;
    y     := 1;
    setLength(result, 64);

    while z <= length(yourString) do begin
        inc(z);
        if yourString[z] in [delimiter] then inc(y)
    end;
    if y > 1 then begin
        z:= 0;
        y:= 1;
    while z <= length(yourString) do begin
        inc(z);
            if yourString[z] in [delimiter] then begin
                if length(split) = aIndex then setLength(split, aIndex+8);
                split[aIndex]:= yourString[y..z-1];
                inc(aIndex);
                inc(z);
                y:= z
            end else
            if z = length(yourString) then
                split[aIndex]:= yourString[y..z]
        end
    end;
    setLength(split, aIndex)
end;


function split(delimiter: char; yourString: string): tStringList;
var z,
    y: integer;
begin
    z:= 0;
    y:= 1;

    while z <= length(yourString) do begin
        inc(z);
        if yourString[z] in [delimiter] then inc(y)
    end;
    if y > 1 then begin
        if split = nil then
            split:= tStringList.Create;
        z:= 0;
        y:= 1;
    while z <= length(yourString) do begin
        inc(z);
            if yourString[z] in [delimiter] then begin
                split.Append(yourString[y..z-1]);
                inc(z);
                y:= z
            end else
            if z = length(yourString) then
                split.Append(yourString[y..z])
        end
    end
end;


function splitByType(yourString: string; skipWhiteSpace: boolean = true;
                     alphaNum: boolean = true): tStringList;
{ Automatically finds substrings by type (letters, symbols) and separates
  them into a nice array.

  Set skipWhiteSpace = false if you want it to appear in the array.
  Set alphaNum   = true to consider mixed letters and numbers as one item. }
var numbers : set of char = ['0'..'9'];
    letters : set of char = ['A'..'Z','a'..'z'];
    whitey  : set of char = [#9..#13,' '];
    symbols : set of char = ['!'..'/',':'..'@','['..'`','{'..'~'];
    charType: set of char;
    z,
    y       : integer;
    x       : dWord = 0;
begin
    z:= 1;
    splitByType:= tStringList.Create;

    if alphaNum then begin
        Numbers:= Numbers + Letters;
        Letters:= Numbers
    end;
    while (z < length(yourString)) do begin
        case yourString[z] of
            '0'..'1'         : charType:= numbers;
            'A'..'Z','a'..'z': charType:= letters;
            #9..#13,' '      : charType:= whitey;
            '!'..'/',':'..'@',
            '['..'`','{'..'~': charType:= symbols;
        end;
        y:= z;
        while (yourString[z] in charType) and (z <= length(yourString)) do
            inc(z);
        if skipWhiteSpace and (charType = whitey) then
            continue;

        splitByType.Append(yourString[y..z-1]);
        inc(x)
    end
end;


function wordsList(yourString: string): tStringList;
{ I don't recall the utility of this function. May throw it out. }
var z,
    y         : integer;
    allowables: set of char;
begin
    allowables:= ['A'..'Z','a'..'z','+','''','-'];
    z     := 0;
    y     := 1;

    if length(yourString) > 1 then begin
        if wordsList = nil then
            wordsList:= tStringList.create;
        z:= 0;
        y:= 1;
        while z <= length(yourString) do begin
            inc(z);
            if not(yourString[z] in allowables) then begin
                wordsList.Append(yourString[y..z-1]);
                while (z< length(yourString)) and (not(yourString[z] in allowables)) do
                    inc(z);

                y:= z
            end
        end
    end
end;

procedure findNext(delimiter: char; buffer: string; var position: dWord);
var z: dWord;
begin
    z:= position;
    while (buffer[position] <> delimiter) and (position < length(buffer)) do
        inc(position);
    if (position = length(buffer)) and (buffer[position] <> delimiter) then
        position:= z // If we don't find what we're looking for then just put
                     // it back and walk away, whistling nonchalantly.
end;

function scanByDelimiter(delimiter: char; buffer: string; var position: dWord): string;
{ Returns the portion of a string from Position to the next delimiter.
  The position of the character following the space is returned in Position
  for Looping. }
var endPos: dWord;
begin
    if position < length(buffer) then begin
        endPos:= position;
        while (endPos < length(buffer)) and (buffer[endPos] <> delimiter) do
            inc(endPos);
//            findNext(delimiter, buffer, endPos);

        if (endPos > position) then
        begin
            if endPos = length(buffer) then
                inc(endPos);
            scanByDelimiter:= buffer[position..endPos-1]
        end

        else if (endPos = position) then // I suppose I could take out this check, assuming
            scanByDelimiter:= buffer[position..endPos]; // the difference won't become negative
        position:= endPos + 1
    end
end;

function scanToWord(aWord: string; buffer: string; var position: dWord; ignoreCase: boolean = true): string;
var z: dWord;
    a,
    b: string;
begin
    z:= position;
    if ignoreCase then begin
        a:= lowercase(aWord);
        b:= lowercase(buffer[z..length(buffer)]);
    end else begin
        a:= aWord;
        b:= buffer[z..length(buffer)]
    end;
    inc(z, pos(a, b));

    result  := buffer[position..z-2];
    position:= z;
end;

function splitBySequence(sequence, buffer: string): tStringList;
var z: dWord = 1;
    y: dWord = 0;
begin
    if splitBySequence = nil then splitBySequence:= tStringList.create;

    while y < length(sequence) do begin
        splitBySequence.Append(scanByDelimiter(sequence[y+1], buffer, z));
        inc(y)
    end;
    splitBySequence.Append(buffer[z..length(buffer)])
end;

function findWord(yourWord, buffer: string; caseSensitive: boolean = false): dWord;
{ Checks for the presence of a whole word and returns its position
  or 0 if not found. Strings are 1-indexed so we don't need to waste half
  the range by using a signed int. }
var a, b: string;
    z   : dWord;
begin
    findWord:= 0;

    if caseSensitive then begin
        a:= yourWord;
        b:= buffer
    end else
    begin
        a:= lowerCase(yourWord);
        b:= lowerCase(buffer)
    end;

    z:= 1;
    while z < length(b) do begin
        while (b[z] <> a[1]) and (z < length(b)) do
            inc(z);
{       Nested IFs may be more optimal. The Interwebz says this could be
        bad for branch prediction. }
        if ((b[z] = a[1]) and (z < length(b)) and (b[z+1] = a[2]))
            and(b[z..z+length(a)-1] = a)
            and(((z = 1) or (not(b[z-1] in ['0'..'9','A'..'Z','a'..'z'])))
                 and((z+length(a) = length(b)+1)
                    or(not(b[z+length(a)] in ['0'..'9','A'..'Z','a'..'z']))
                 ))
            then begin
                findWord:= z;
                exit
            end;
        inc(z)
    end;
end;

function wordPresent(yourWord, buffer: string; caseSensitive: boolean = false): boolean;
{ Checks for the presence of a whole word }
begin
    if findWord(yourWord, buffer, caseSensitive) > 0 then
        wordPresent:= true
    else
      wordPresent:= false
end;

function findWord(yourWord: string; strings: tStringList; caseSensitive: boolean = false): dWord;
var
    z: dWord = 0;
begin
    while (z < strings.Count) and (not(wordPresent(yourWord, strings.Strings[z], caseSensitive))) do
        inc(z);
    if z < strings.count then
        findWord:= z
    else
        findWord:= high(dWord)
end;

function wordPresent(yourWord: string; strings: tStringList; caseSensitive: boolean = false): boolean;
begin
    if findWord(yourWord, strings, caseSensitive) < high(dWord) then
        wordPresent:= true
    else
        wordPresent:= false
end;

function isNumeric(buffer: string): boolean;
{ I thought this existed in the RTL but I can't find it. This is only smart
  enough to handle unsigned ints because that's all we need at the moment. }
var z: dWord = 1;
begin
    while (z < length(buffer)) and (buffer[z] in [' ', '0'..'9']) do
        inc(z);

    if buffer[z] in [' ', '0'..'9'] then
        isNumeric:= true
    else
        isNumeric:= false
end;

function join(delimiter: char; stringList: tStringList): string;
{ This is similar to using DelimitedText but we append, otherwise we should
  probably just call delimitedText or just use it instead. Whatever. }
var z: dWord;
begin
    join:= stringList.Strings[0];
    if stringList.Count > 1 then
        for z:= 1 to stringList.Count-1 do
            join:= join + delimiter + stringList.Strings[z]
end;

function reduceWhiteSpace(buffer: string): string;
var z: dWord = 1;
    y: dWord;
begin
    result:= '';
    while z < length(buffer) do begin
        y:= z;
        while (not(buffer[z] in [#9, #10, #13, ' '])) and (z < length(buffer)) do
            inc(z);
        if (buffer[z] in [#9, #10, #13, ' ']) then begin
            result+= buffer[y..z-1] + ' ';
            while (buffer[z] in [#9, #10, #13, ' ']) and (z < length(buffer)) do
                inc(z)
        end
        else if z = length(buffer) then
            result+= buffer[y..z]
    end;
end;

function clipText(buffer: string; newLength: word): string;
begin
    if length(buffer) > newLength then
        result:= buffer[1..newLength-3] + '...'
    else
        result:= buffer
end;

function reverse(buffer: string): string;
var z: dWord = 1;
    l: dWord;
begin
    l:= length(buffer);
    setLength(result, l);
    for z:= 1 to l do
        result[l-z+1]:= buffer[z]
end;

end.

