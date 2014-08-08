unit urlStuff;

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils;

function resolveXMLents (buffer: string): string; // Resolve XML entities (like &amp;)
function resolveXMLent  (buffer: string): string; // Resolve a single XML entity

function stripUrlShit   (buffer: string): string; // Remove feedburner or whatever waste
function extractURLs    (buffer: string): tStringList; // Finds URLs within a string; not the best
function isValidUrl     (var buffer: string): boolean; // Doesn't do much
function urlHasTitle    (url, title: string): boolean; // Compare two strings and see if they're similar

implementation
uses kUtils;

function urlHasTitle(url, title: string): boolean;
{ This is supposed to compare the url and title and return true if there are a few
  matching words. The idea is to only show titles for urls that don't already contain
  them; however, it just always returns false. }
var u,
    t : tStringList;
    ui: dWord = 0;
    ti: dWord = 0;
    c : dWord = 0;
begin
    url   := lowerCase(url);
    title := lowerCase(title);
writeln('splitting url');
    u     := splitByType(url);
writeln('splitting title');
    t     := splitByType(title);
writeln('done. comparing');
    if (u.count > 5) and (t.count < 5) then begin
        for ui:= 0 to u.Count-1 do
            for ti:= t.Count-1 downto 0 do; { titles will usually be at the end; this may save a billionth of a second }
            if u.Strings[ui] = t.Strings[ti] then
                inc(c);
    end;
writeln('done');
    result:= c > 5;
    u.free;
    t.free
end;

function stripUrlShit(buffer: string): string;
{ I'm sure there's more to nuke }
var z: dWord;
begin
    result:= buffer;
    z:= ciPos('utm_source=feedburner', buffer);
    if z > 0 then result:= buffer[1..z-2];
    z:= ciPos('from=rss', buffer);
    if z > 0 then begin
        Delete(buffer, z, 8);
        result:= buffer;
    end;
    if result[length(buffer)] = '&' then result:= result[1..length(result)-1]
end;

function isValidUrl(var buffer: string): boolean;
var z        : dWord = 1;
    goodChars: set of char = ['#','&','0'..'9','A'..'Z','a'..'z', #128..#168];
begin
  { At least one dot or two colons should cover hostnames and IPs, both v4 and v6,
    assuming the collector doesn't do something stupid like only look for dots.
    We can't care about single-word hostnames unless we have a list somewhere to check. }
    result:= false;
    writeln(buffer);
    if (pos('.', buffer) > 0) or (countDelimiters(':', buffer) > 1) then begin
    { should do some stuff here }
    { actually I had something here but somehow all it did was make URLs with "-" as the
      second-to-last character return false, which doesn't even make sense. Anyway,
      requiring the scheme does just as well. }
        result:= true;
    end else
        result:= false
end;

function extractURLs(buffer: string): tStringList;
var z  : dWord = 1;
    y  : dWord;
    url: string;

begin
    if result = nil then
        result:= tStringList.Create;

    while z < length(buffer) do
    begin
        while (buffer[z] <> '.') and (z < length(buffer)) do
            inc(z);
        if z > 0 then begin
            y:= z;
          { Find the beginning of something that may be valid }
            while (buffer[y] in ['-'..':','=','?','A'..'Z','a'..#168]) and (y > 1) do
                dec(y);

          { Find the end }
            while (buffer[z] in ['#'..'&','(',')','+'..':','=','?','A'..'Z','_','a'..#168]) and (z < length(buffer)) do
                    inc(z);
          { We don't want them ending with '.'; do urls usually end in dots?
            Not sure about $ or ending with + }
            while not(buffer[z] in ['#','$','&','+','-','/'..':','=','?','A'..'Z','_','a'..#168]) and (z > y) do
                dec(z);

          { Some chars aren't valid at the beginning plus if we're not at [1]
            then we at least need to increment by one. }
            while not(buffer[y] in ['0'..'9','A'..'Z','a'..'z',#128..#169]) and (y < z) do
                inc(y);

            if buffer[y..z] <> '' then begin
                url:= buffer[y..z];
                if isValidUrl(url) then
                    result.Append(url);
            end;
            inc(z);
            while not(buffer[z] in[#9..#13,' ']) and (z < length(buffer)) do
                inc(z)
        end
    end
end;

function resolveXMLent(buffer: string): string;
var z: dWord = 1;

begin
    if buffer[1] = '#' then
    begin
        val(buffer[2..length(buffer)], z);
        result:= WideChar(z)
    end

    else case lowerCase(buffer) of
        'trade' : result:= '™';
        'amp'   : result:= '&';
        'gt'    : result:= '>';
        'lt'    : result:= '<';
        'quot'  : result:= '"';
        'mdash' : result:= '—';
        'middot': result:= '·';
        'ndash' : result:= '–';
        'iexcl' : result:= '¡';
        'iquest': result:= '¿';
        'copy'  : result:= '©';
        'reg'   : result:= '®';
        'curren': result:= '¤';
        'yen'   : result:= '¥';
        'brvbar': result:= '¦';
        'sect'  : result:= '§';
        'laquo' : result:= '«';
        'deg'   : result:= '°';
        'plusmn': result:= '±';
        'sup1'  : result:= '¹';
        'sup2'  : result:= '²';
        'sup3'  : result:= '³';
        'acute' : result:= '´';
        'micro' : result:= 'µ';
        'para'  : result:= '¶';
        'raquo' : result:= '»';
        'frac14': result:= '¼';
        'frac12': result:= '½';
        'frac34': result:= '¾'
    else { The rest probably don't matter; how likely are you to see them in titles? }
        result:= ''
    end
end;

function resolveXMLents(buffer: string): string;
var z: dWord = 1;
    b: string;
begin
    result:= '';
    while z < length(buffer) do
    begin
        result:= result + scanByDelimiter('&', buffer, z);
        if (buffer[z-1] = '&') and (buffer[z+1] <> ' ') then
        begin
            b:= scanByDelimiter(';', buffer, z);
            if (buffer[z-1] = ';') or (buffer[z] = ';') then
                result:= result + resolveXMLent(b)
            else result:= result + b
        end
    end
end;

end.

