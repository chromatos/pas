program url_title;
{$mode objfpc}{$H+}

uses
    Classes, SysUtils, unix, kUtils, urlStuff, textExtractors;

function isSafe(buffer: string): boolean;
begin
    buffer:= lowerCase(buffer);
    result:= false;
    if Pos('//localhost', buffer) > 0 then exit else
    if Pos('//127.', buffer) > 0 then exit else
    if Pos('//192.168', buffer) > 0 then exit else
    if Pos('//10.', buffer) > 0 then exit else
    if Pos('//0.', buffer) > 0 then exit else
    if Pos('//255.', buffer) > 0 then exit else
    if Pos('kidd', buffer) > 0 then exit else
    result:= true
end;

function doRequest(var uri: string; baseName: string; out props: kFileProperties; out buffer: string): kRequestResult;
const
    uaString = 'monopoly/1 (Mozilla Gecko Netscape lynx links2 Firefox IE safari konqueror opera chrome googlebot bingbot)';
var aFile : tStringList;
    z     : dWord;
    redirs: byte = 0;
    urls  : tStringList;
    final : boolean = false;
begin
    urls  := tStringList.Create;
    aFile := tStringList.Create;
    props := [];
    result:= isOK;

    while (not final) and (redirs < 6) do begin
        uri:= stripUrlShit(uri);
        if not isSafe(uri) then begin
            result:= isNothing;
            exit
        end;
        fpSystem('curl -A "' + uaString + '" -k -s -D ' + baseName + '.head "' + uri + '" > ' + baseName + '.body');
        if not (FileExists(baseName + '.head') and FileExists(baseName + '.body')) then begin
            result:= isNotFound;
            break
        end;

        aFile.LoadFromFile(baseName + '.head');
        if aFile.Count = 0 then begin
            result:= isNothing;
            exit
        end;
        z:= 0;
        while z < aFile.Count do begin
            if ciPos('http/', aFile.Strings[z]) > 0 then begin
                if Pos ('30', aFile.Strings[z]) > 0 then
                    inc(redirs)
                else
                    final:= true
            end;
            if ciPos('location', aFile.Strings[z]) > 0 then
                uri:= aFile.Strings[z][Pos(':', aFile.Strings[z])+2..length(aFile.Strings[z])];
            if ciPos('content-type', aFile.Strings[z]) > 0 then begin
                if ciPos('text', aFile.Strings[z]) > 0 then props+= [isText];
                if (ciPos('xml', aFile.Strings[z]) > 0) or (ciPos('html', aFile.Strings[z]) > 0) then props+= [isXMLish];
            end;
            inc(z)
        end
    end;

    if props <= [isText, isXMLish] then begin
        aFile.LoadFromFile(baseName + '.body');
        buffer:= aFile.Text;
    end;

    urls.free;
    aFile.free;
    if not final then
        result:= isTooRedirectish

end;

procedure doThings(aFile: string);
var z     : dWord;
    buffer: string;
    oldUri       : string          = '';
    title        : string          = '';
    content      : string          = '';
    lines        : tStringList;
    theSite      : kSite;
    fileProps    : kFileProperties;
    requestResult: kRequestResult;
begin
  { A little hackishness. This was the only way loading files would work before
    I figured out files don't work well in global space. I'm not going to change
    it now, at least until total rewrite. }

  { Oh yeah, the real hack is curl --> files --> here instead of using pipes or
    learning SSL. }
    lines:= TStringList.Create;
    lines.LoadFromFile(aFile);
    if FileExists(aFile) then DeleteFile(aFile);
    buffer:= lines.text;
    lines.Clear;

    lines:= extractURLs(buffer);
    if lines.count > 0 then
        for z:= 0 to lines.count-1 do begin
            buffer := lines.Strings[z];
            if (ciPos('http:/', buffer) > 0) or (ciPos('https:/', buffer) > 0) then begin
                oldUri := buffer;
                requestResult:= doRequest(buffer, aFile, fileProps, content);
                if FileExists(aFile + '.head') then DeleteFile(aFile + '.head');
                if FileExists(aFile + '.body') then DeleteFile(aFile + '.body');
                theSite:= detectSite(buffer);

              { File hacks are done; everything else is just string passing.
                It's still terrible because there's a lot of lowerCase() calling,
                which should be replaced with a record of two strings or something. }

                if (requestResult = isOK) and (content <> '') then begin
                    if isXMLish in fileProps then begin
                        case theSite.site of
                            siWhatever,
                            siPedia,
                            siSoyMain,
                            siYouTube    : title:= getXMLtitle(content);
                            siSoyArticle : title:= getSoylentArticle(content, theSite.flags);
                            siSoyComment : title:= getSoylentComment(content, theSite.flags);
                            siSoyPoll    : title:= getSoylentPoll(content, theSite.flags);
                            siSoySub     : title:= getSoylentSubmission(content, theSite.flags);

                            siPipeArticle: title:= getPipedotArticle(content, theSite.flags);
                            siPipeComment: title:= getPipedotComment(content, theSite.flags);

//                            siPedia      : title:= getWikiTextia(content); // Broken for mobile pages

//                            siYouTube    : title:= getYouTubeDiz(content); // Broken; the XML one is good enough

                        end;
                    end else if isText in fileProps then begin
                        title:= getExcerpt(content, 32);
                    end else
                        ; // do stuff
{                    if urlHasTitle(oldUri, title) then
                        title:= '';} // Broken because urlHasTitle() always returns false

                    if buffer <> oldUri then title+= ' ( '+stripControls(buffer)+' )';
                end;
            end;
            { ':'#9 allows the IRC bot to skip error messages, even though they should be
              going to stdErr, anyway. Apparently I'm doin' it wrong in KVIrc. }
            if title <> '' then
                writeln(':', #9, title);
        end
end;


begin

{ Have to put everything into a function otherwise all kinds of errors pop up,
  especially around files. I assume it's due to the way globals are stored
  but I'm not going to check. }

{ The reason for using a file is so I don't have to escape the strings
  (and I don't recall) if thee's a way in KVIrc to pipe stuff into stdIn on processes. }

doThings(paramStr(1));

end.

