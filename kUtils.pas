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
    kCharSet = set of char;

function  splitByType         (yourString: string; skipWhiteSpace: boolean = true;
                               alphaNum: boolean = true): tStringList;

function  split               (delimiter: char; yourString: string): tStringList; // These are unnecessary because
function  join_stringList     (delimiter: char; stringList: tStringList): string; // we're using tStringList now.
function  split               (delimiter: char; yourString: string): kStrings;

function  split_by_sequence   (sequence, buffer: string): tStringList;
{
procedure find_next_char      (delimiter: char; buffer: string; var position: dWord; overstep: boolean = false);
function  get_to_next_char    (delimiter: char; buffer: string; var position: dWord; overstep: boolean = false): string;
function  find_next_set       (delimiter: kCharSet; buffer: string; var position: dWord): string;
function  find_next_string    (aWord: string; buffer: string; var position: dWord; ignoreCase: boolean = true): string;
}

function  extract_subStr      (buffer: string; var position: integer; subString: string): string;
function  word_is_present     (yourWord, buffer: string; caseSensitive: boolean = false): boolean;
function  find_word           (yourWord, buffer: string; caseSensitive: boolean = false): dWord;
function  word_is_present     (yourWord: string; strings: tStringList; caseSensitive: boolean = false): boolean; overload;
function  find_word           (yourWord: string; strings: tStringList; caseSensitive: boolean = false): dWord; overload;

function  contains_any_strings(subStrings: tStringList; buffer: string; caseSensitive: boolean = false): boolean;
function  count_words         (subStrings: tStringList; buffer: string; caseSensitive: boolean = false): dWord;

function  count_delimiters    (delimiter: char; yourString: string): dWord;
function  TextPos             (subString, buffer: string): dWord; // case-insensitive Pos()

function  string_is_numeric   (buffer: string): boolean;

function  stripSomeControls   (buffer: string): string;
function  strip_set           (theSet: kCharSet; buffer: string): string;

function  reduce_white_space  (buffer: string): string;

function  clip_text           (buffer: string; newLength: dWord): string;

function  reverse             (buffer: string): string;

function  file2string         (fileName: string): string;
procedure string2File         (filename, buffer: string; append: boolean = false);

implementation
uses strutils;

{ Disk i/o }

function file2string(fileName: string): string;
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

procedure string2File(filename, buffer: string; append: boolean = false);
var x: tFileStream;
begin
    if append and FileExists(filename) then
        x:= TFileStream.create(fileName, fmAppend)
    else
        x:= TFileStream.create(fileName, fmOpenWrite);
    x.WriteBuffer(buffer[1], length(buffer));
    x.Free
end;

function count_delimiters(delimiter: char; yourString: string): dWord;
var z: dWord = 0;
begin
    result:= 0;
    while z < length(yourString) do begin
        inc(z);
        if yourString[z] = delimiter then
            inc(result)
    end
end;

function TextPos(subString, buffer: string): dWord;
var a,
    b: string;
begin
    a:= lowercase(subString);
    b:= lowercase(buffer);
    result:= pos(a, b)
end;


{ Stripping }

function stripSomeControls(buffer: string): string;
var z: dWord = 1;
    y: dWord = 1;
begin
    if buffer <> '' then begin
        setLength(result, length(buffer));
        for z:= 1 to length(buffer) do
            if not(buffer[z] in [#9..#13]) then
            begin
                result[y]:= buffer[z];
                inc(y)
            end;
        setLength(result, y-1)
    end
end;

function strip_set(theSet: kCharSet; buffer: string): string;
var z: dWord = 1;
    y: dWord;
begin
    while z < length(buffer) do begin
        if buffer[z] in theSet then begin
            y:= z;
            while (buffer[z] in theSet) and (z < length(buffer)) do
                inc(z);
            if buffer[z] in theSet then
                inc(z);
            result += buffer[y..z-1]
        end else
            while not(buffer[z] in theSet) and (z < length(buffer)) do
                inc(z)
    end
end;


{ Searching }

function extract_subStr(buffer: string; var position: integer; subString: string): string;
var z: integer;
begin
    z:= PosEx(subString, buffer, position);
    if z > 0 then begin
        result  := buffer[position..z-1];
        position:= z + length(subString)
    end else begin
        result  := buffer[position..length(buffer)];
        position:= length(buffer)
    end
end;

procedure find_next_char(delimiter: char; buffer: string; var position: dWord; overstep: boolean = false);
{ Look for the next delimiter, with an offset }
var z: dWord;
begin
{    z:= position;

{    while (buffer[position] <> delimiter) and (position < length(buffer)) do
        inc(position);

    if (position = length(buffer)) and (buffer[position] <> delimiter) then
        position:= z // If we don't find what we're looking for then just put
                      // it back and walk away, whistling nonchalantly.
    else }
    z:= pos(delimiter, buffer[position..length(buffer)]);
    if z > 0 then begin
        if overstep and (z < length(buffer)) then
            inc(z, position)
        else
            inc(z, position-1)
    end;}
    position:= PosEx(delimiter, buffer, position);
    if overstep and (position > 0) then
        inc(position)
end;

function get_to_next_char(delimiter: char; buffer: string; var position: dWord; overstep: boolean = false): string;
{ Returns the portion of a string from Position to the next delimiter.
  The position of the character following the delimiter is returned in Position
  for Looping. }
var z: dWord;
begin
{    if position < length(buffer) then begin
        z:= position;
        while (z < length(buffer)) and (buffer[z] <> delimiter) do
            inc(z);
//            get_to_next_char(delimiter, buffer, z);

        if (z > position) then
        begin
            if z = length(buffer) then
                inc(z);
            get_to_next_char:= buffer[position..z-1]
        end

        else if (z = position) then // I suppose I could take out this check, assuming
            get_to_next_char:= buffer[position..z]; // the difference won't become negative
        position:= z + 1
    end}
    get_to_next_char(delimiter, buffer, z, overstep);
    if z > 0 then
        result:= buffer[position..z-1]
    else
        result:= '';
    position:= z
end;

function find_next_set(delimiter: kCharSet; buffer: string; var position: dWord): string;
{ Returns the portion of a string from Position to the next delimiter.
  The position of the character following the space is returned in Position
  for Looping. }
var z: dWord;
begin
{    if position < length(buffer) then begin
        endPos:= position;
        while (endPos < length(buffer)) and (not(buffer[endPos] in delimiter)) do
            inc(endPos);
//            find_next(delimiter, buffer, endPos);

        if (endPos > position) then
        begin
            if endPos = length(buffer) then
                inc(endPos);
            find_next:= buffer[position..endPos-1]
        end

        else if (endPos = position) then // I suppose I could take out this check, assuming
            find_next:= buffer[position..endPos]; // the difference won't become negative
        position:= endPos + 1
    end
}
    z:= PosSetEx(delimiter, buffer, position);
    if z > 0 then begin
        result:= buffer[position..z-1];
        inc(z)
    end else
        result:= '';
    position:= z
end;


function find_next_string(aWord: string; buffer: string; var position: dWord; ignoreCase: boolean = true): string;
{ An optionally case-insensitive Pos() with offset }
var z: dWord;
    a,
    b: string;
begin
    if position < length(buffer) then begin
        z:= position;
        if ignoreCase then
            z:= PosEx(lowercase(aWord), lowercase(buffer), position)
        else
            z:= PosEx(aWord, buffer, position);

        if z > 0 then
            result:= buffer[position..z-1]
        else
            result:= buffer[position..length(buffer)];
        position:= z
    end else
        result:= ''
end;


function find_word(yourWord, buffer: string; caseSensitive: boolean = false): dWord;
{ Checks for the presence of a whole word and returns its position
  or 0 if not found. Strings are 1-indexed so we don't need to waste half
  the range by using a signed int plus that's how Pos() works. }
var a, b: string;
    z   : dWord;
begin
    find_word:= 0;

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
{       Nested IFs may be more optimal; the Interwebz says this could be
        bad for branch prediction. But it looks so obtuse and coooool! }
        if ((b[z] = a[1]) and (z < length(b)) and (b[z+1] = a[2]))
            and(b[z..z+length(a)-1] = a)
            and(((z = 1) or (not(b[z-1] in ['0'..'9','A'..'Z','a'..'z'])))
                 and((z+length(a) = length(b)+1)
                    or(not(b[z+length(a)] in ['0'..'9','A'..'Z','a'..'z']))
                 ))
            then begin
                find_word:= z;
                exit
            end;
        inc(z)
    end;
end;

function find_word(yourWord: string; strings: tStringList; caseSensitive: boolean = false): dWord;
{ Similar to above but returns an index in a stringlist }
var
    z: dWord = 0;
begin
    while (z < strings.Count) and (not(word_is_present(yourWord, strings.Strings[z], caseSensitive))) do
        inc(z);
    if z < strings.count then
        find_word:= z
    else
        find_word:= high(dWord)
end;

function word_is_present(yourWord, buffer: string; caseSensitive: boolean = false): boolean;
{ Checks for the presence of a whole word within a string.
  It's find_word: boolean edition }
begin
    if find_word(yourWord, buffer, caseSensitive) > 0 then
        word_is_present:= true
    else
      word_is_present:= false
end;

function word_is_present(yourWord: string; strings: tStringList; caseSensitive: boolean = false): boolean;
{ Checks for the presence of a whole word within a stringlist }
begin
    if find_word(yourWord, strings, caseSensitive) < high(dWord) then
        word_is_present:= true
    else
        word_is_present:= false
end;

function contains_any_strings(subStrings: tStringList; buffer: string; caseSensitive: boolean = false): boolean;
{ Checks for at least one word in the buffer }
var z: dWord = 0;
    y: boolean = false;
    x: string;
begin
    if caseSensitive then
        x:= buffer
    else
        x:= LowerCase(buffer);

    while (z < subStrings.Count) and (not y) do
    begin
        y:= pos(subStrings.Strings[z], buffer) > 0;
//??        if y then writeln(#9'ignored string: ', subStrings.Strings[z]);
        inc(z)
    end;
    result:= y
end;

function count_words(subStrings: tStringList; buffer: string; caseSensitive: boolean = false): dWord;
{ Counts substrings in the buffer }
var z: dWord = 0;
    y: string;
begin
    result:= 0;

    if caseSensitive then begin
        while z < subStrings.Count do
        begin
            if pos(subStrings.Strings[z], buffer) > 0 then
                inc(result);
            inc(z)
        end
    end
    else begin
        y:= LowerCase(buffer);
        while z < subStrings.Count do
        begin
            if pos(LowerCase(subStrings.Strings[z]), y) > 0 then
                inc(result);
            inc(z)
        end
    end
end;


{ String typechecking }

function string_is_numeric(buffer: string): boolean;
{ I thought this existed in the RTL but I can't find it. This is only smart
  enough to handle unsigned ints because that's all we need at the moment. }
var z: dWord = 1;
begin
    while (z < length(buffer)) and (buffer[z] in [' ', '0'..'9']) do
        inc(z);

    if buffer[z] in [' ', '0'..'9'] then
        string_is_numeric:= true
    else
        string_is_numeric:= false
end;


{ String cleanup and prettifying }

function reduce_white_space(buffer: string): string;
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

function clip_text(buffer: string; newLength: dWord): string;
begin
    if length(buffer) > newLength then
        result:= buffer[1..newLength-3] + '...'
    else
        result:= buffer
end;


{ String splitting }

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
    herp    : boolean = false;
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
            else
                herp:= true;
        end;
        if not herp then begin
            y:= z;
            while (yourString[z] in charType) and (z <= length(yourString)) do
                inc(z);
            if skipWhiteSpace and (charType = whitey) then
                continue;

            splitByType.Append(yourString[y..z-1]);
            inc(x)
        end else begin
            inc(z);
            herp:= false
        end
    end
end;

function split_by_sequence(sequence, buffer: string): tStringList;
var z: dWord = 1;
    y: dWord = 0;
    l: dWord;
begin
    split_by_sequence:= tStringList.create;

    l:= length(sequence);
    for y:= 1 to l do
        split_by_sequence.Append(get_to_next_char(sequence[y], buffer, z));

    split_by_sequence.Append(buffer[z..length(buffer)])
end;


{ String joining }

function join_stringList(delimiter: char; stringList: tStringList): string;
{ This is similar to using stringList.DelimitedText but we append, otherwise we
  should probably just call delimitedText or just use it instead. Whatever. }
var z: dWord;
begin
    join_stringList:= stringList.Strings[0];
    if stringList.Count > 1 then
        for z:= 1 to stringList.Count-1 do
            join_stringList:= join_stringList + delimiter + stringList.Strings[z]
end;


{ Steal underpants; ?; Profit! }

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


{ Miscellaneous }

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

