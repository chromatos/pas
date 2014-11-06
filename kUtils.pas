{ This is a small hunk of string processing crap

  License: wtfpl (See 'copying' file or the Internet)
}


{$mode objfpc}{$h+}
unit kUtils;

interface
uses classes, sysUtils;

type
    kKeyValue = record
        key,
        value: string;
    end;

    kStrings   = array of string;
    kKeyValues = array of kKeyValue;
    kCharSet   = set of char;

function  splitByType         (yourString: string; skipWhiteSpace: boolean = true;
                               alphaNum: boolean = true): tStringList;

function  split               (delimiter: char; yourString: string): tStringList; // These are unnecessary because
function  join_stringList     (delimiter: char; stringList: tStringList): string; // we're using tStringList now.
function  split2array         (delimiter: char; yourString: string): kStrings;

function  split_by_sequence   (sequence, buffer: string): tStringList;

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

function  reduce_white_space  (buffer: string): string; // Reduces consecutive whitespace characters

function  clip_text           (buffer: string; newLength: dWord): string;

function  delete_range        (buffer, from_what, to_what: string): string; // Remove a substring bounded by inclusive substrings

function  reverse             (buffer: string): string;

function  file2string         (fileName: string): string;
procedure string2File         (filename, buffer: string; append: boolean = false);

function  string2KeyValue     (buffer: string): kKeyValue;
function  keyValue2String     (kv: kKeyValue): string;

function  string2KeyValues    (buffer: string):kKeyValues ;
function  keyValues2String    (keyvalues: kKeyValues): string;

implementation
uses strutils;

{ Disk i/o }

function file2string(fileName: string): string;
var x: TFileStream;
begin
    if FileExists(fileName) then
    begin
        x:= TFileStream.Create(fileName, fmOpenRead);
        setLength(result, x.Size);
        x.Read(result[1], x.Size);
        x.Free
    end else
        result:= ''
end;

procedure string2File(filename, buffer: string; append: boolean = false);
var x: tFileStream;
begin
    if FileExists(filename) then
    begin
        if append then
            x:= TFileStream.create(fileName, fmAppend)
        else begin
            x     := TFileStream.create(fileName, fmOpenWrite);
            x.Size:= 0
        end
    end
    else
        x:= TFileStream.create(fileName, fmCreate);

    x.WriteBuffer(buffer[1], length(buffer));
    x.Free
end;


function count_delimiters(delimiter: char; yourString: string): dWord;
var z: dWord = 0;
begin
    result:= 0;
    while z < length(yourString) do
    begin
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
    if buffer <> '' then
    begin
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
    while z < length(buffer) do
    begin
        if buffer[z] in theSet then
        begin
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
    if z > position then
    begin
        result  := buffer[position..z-1];
        position:= z + length(subString)
    end else
    begin
        result  := buffer[position..length(buffer)];
        position:= length(buffer)
    end
end;

function find_word(yourWord, buffer: string; caseSensitive: boolean = false): dWord;
{ Checks for the presence of a whole word and returns its position
  or 0 if not found. Strings are 1-indexed so we don't need to waste half
  the range by using a signed int plus that's how Pos() works. }
var a, b: string;
    z   : dWord;
begin
    find_word:= 0;

    if caseSensitive then
    begin
        a:= yourWord;
        b:= buffer
    end else
    begin
        a:= lowerCase(yourWord);
        b:= lowerCase(buffer)
    end;

    z:= 1;
    while z < length(b) do
    begin
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
            then
            begin
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

    if caseSensitive then
    begin
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
    while z < length(buffer) do
    begin
        y:= z;
        while (not(buffer[z] in [#9, #10, #13, ' '])) and (z < length(buffer)) do
            inc(z);
        if (buffer[z] in [#9, #10, #13, ' ']) then
        begin
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

function delete_range(buffer, from_what, to_what: string): string;
{ Find a range within a string bounded by substrings and delete them, including the bounds.
  Leave a substring empty to align the range and string ends. }
var z,
    y: integer;
begin
    if from_what <> '' then
        z:= Pos(from_what, buffer)
    else
        z:= 1;

    if z > 0 then begin
        if to_what <> '' then
        begin
            y:= PosEx(to_what, buffer, z + length(from_what));
            if y = 0 then
                y:= length(buffer);
        end else
            y:= length(buffer);
        Delete(buffer, z, y-z)
    end
end;


{ String splitting }

function split2array(delimiter: char; yourString: string): kStrings;
var z,
    y,
    aIndex: integer;
begin
    z     := 0;
    y     := 1;
    setLength(result, 64);

    while z <= length(yourString) do
    begin
        inc(z);
        if yourString[z] in [delimiter] then inc(y)
    end;
    if y > 1 then
    begin
        z:= 0;
        y:= 1;
    while z <= length(yourString) do
    begin
        inc(z);
            if yourString[z] in [delimiter] then
            begin
                if length(result) = aIndex then setLength(result, aIndex+8);
                result[aIndex]:= yourString[y..z-1];
                inc(aIndex);
                inc(z);
                y:= z
            end else
            if z = length(yourString) then
                result[aIndex]:= yourString[y..z]
        end
    end;
    setLength(result, aIndex)
end;


function split(delimiter: char; yourString: string): tStringList;
var z,
    y: integer;
begin
    z:= 0;
    y:= 1;

    while z <= length(yourString) do
    begin
        inc(z);
        if yourString[z] in [delimiter] then inc(y)
    end;
    if y > 1 then
    begin
        if split = nil then
            split:= tStringList.Create;
        z:= 0;
        y:= 1;
    while z <= length(yourString) do
    begin
        inc(z);
            if yourString[z] in [delimiter] then
            begin
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

    if alphaNum then
    begin
        Numbers:= Numbers + Letters;
        Letters:= Numbers
    end;
    while (z < length(yourString)) do
    begin
        case yourString[z] of
            '0'..'1'         : charType:= numbers;
            'A'..'Z','a'..'z': charType:= letters;
            #9..#13,' '      : charType:= whitey;
            '!'..'/',':'..'@',
            '['..'`','{'..'~': charType:= symbols;
            else
                herp:= true;
        end;
        if not herp then
        begin
            y:= z;
            while (yourString[z] in charType) and (z <= length(yourString)) do
                inc(z);
            if skipWhiteSpace and (charType = whitey) then
                continue;

            splitByType.Append(yourString[y..z-1]);
            inc(x)
        end else
        begin
            inc(z);
            herp:= false
        end
    end
end;

function split_by_sequence(sequence, buffer: string): tStringList;
var z: integer = 1;
    y: integer = 0;
    l: dWord;
begin
    split_by_sequence:= tStringList.create;

    l:= length(sequence);
    for y:= 1 to l do
        split_by_sequence.Append(ExtractSubstr(buffer, z, [sequence[y]]));

    split_by_sequence.Append(buffer[z..length(buffer)])
end;

function string2KeyValue(buffer: string): kKeyValue;
var z: integer;
begin
    z:= pos(':', buffer);
    if (z > 1) and (z < length(buffer)) then begin
        result.key  := buffer[1..z-1];
        result.value:= buffer[z+1..length(buffer)]
    end
end;

function keyValue2String(kv: kKeyValue): string;
begin
    result:= kv.key + ':' + kv.value
end;

function string2KeyValues(buffer: string): kKeyValues;
var z: integer = 0;
    x: kStrings;
begin
    x:= split2array(';', buffer);
    setLength(result, length(x));
    for z:= 0 to high(x) do
        result[z]:= string2KeyValue(x[z])
end;


{ String joining }

function keyValues2String(keyvalues: kKeyValues): string;
var z: integer = 0;
    l: integer;
begin
    l:= high(keyvalues);
    if l > 0 then
    begin
        for z:= 0 to l do
            result+= keyValue2String(keyvalues[z]) + ';';
        setLength(result, length(result)-1) // hehe
    end
end;

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

    if length(yourString) > 1 then
    begin
        result:= tStringList.create;
        z     := 0;
        y     := 1;
        while z <= length(yourString) do
        begin
            inc(z);
            if not(yourString[z] in allowables) then
            begin
                result.Append(yourString[y..z-1]);
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

