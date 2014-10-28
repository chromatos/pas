{ Page title-grabbing script with much hackishness.

  License: wtfpl (See 'copying' file or the Internet)
}

unit url_title4;
{$mode objfpc}{$H+}

interface
uses
    Classes, SysUtils, unix, kUtils, urlStuff, textExtractors;

type kSomeFlags = set of (gtHttp, gtHttps, gtFtp, gtGopher);

     k_title_cache_item = record
         url,
         title  : string;
         expires,
         seen   : tDateTime; // For people like EF who paste a link several times
     end;

     kTitleCache = class(tFpList);

function getTitles(buffer: string; someFlags: kSomeFlags): tStringList;
function pageIsUp (uri: string): boolean;
function loadNaughties: dWord;

var naughtyList: tStringList;

implementation

function loadNaughties: dWord;
begin
    if FileExists('/usr/local/etc/titlebot.ignores') then begin
        naughtyList.LoadFromFile('/usr/local/etc/titlebot.ignores');
        result:= naughtyList.Count;
        writeLn(#9'Ignore list: loaded ', naughtyList.Count, ' strings')
    end
end;

function isSafe(buffer: string): boolean;
begin
    buffer:= lowerCase(buffer);
//    result:= false;
    result:= not contains_any_strings(naughtyList, buffer, true) //then exit else
{    if Pos('//localhost', buffer) > 0 then exit else
    if Pos('//127.', buffer) > 0 then exit else
    if Pos('//192.168', buffer) > 0 then exit else
    if Pos('//10.', buffer) > 0 then exit else
    if Pos('//0.', buffer) > 0 then exit else
    if Pos('//255.', buffer) > 0 then exit else
    if Pos('example.com', buffer) > 0 then exit else
    if Pos('kidd', buffer) > 0 then exit else // Anything else? Don't need to be party v& again}
//    result:= true
end;

function doRequest(var uri: string; baseName: string; out props: kFileProperties; out buffer: string; out contentType: string; out redirects: byte): kRequestResult;
const
    uaString = 'Mozilla/5.0 (monopoly 2; X11; Linux x86_64; rv:24.7) Gecko/20140911 Firefox/24.7';
var aFile   : tStringList;
    z       : dWord;
    redirs  : byte = 0;
    urls    : tStringList;
    final   : boolean = false;
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
        fpSystem('curl -m 8 -x "http://10.10.9.254:3128" -A "' + uaString + '" -k -s -D ' + baseName + '.head "' + uri + '" > ' + baseName + '.body');
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
            if TextPos('http/', aFile.Strings[z]) > 0 then begin
                if Pos ('30', aFile.Strings[z]) > 0 then
                    inc(redirs)
                else
                    final:= true
            end;
            if TextPos('location', aFile.Strings[z]) > 0 then
                uri:= aFile.Strings[z][Pos(':', aFile.Strings[z])+2..length(aFile.Strings[z])];
            if TextPos('content-type', aFile.Strings[z]) > 0 then begin
                contentType:= aFile.Strings[z];
                if TextPos('text', contentType) > 0 then props+= [isText];
                if (TextPos('xml', contentType) > 0) or (TextPos('html', contentType) > 0) then props+= [isXMLish];
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
        result:= isTooRedirectish;
    redirects:= redirs; // maybe just need one variable. Oh well.

end;

function pageIsUp(uri: string): boolean;
var baseName : string = '/tmp/.sitecheck.ask';
    props    : kFileProperties;
    buffer   : string;
    cType    : string;
    redirects: byte = 0;
    theResult: kRequestResult;
begin
    theResult:= doRequest(uri, baseName, props, buffer, cType, redirects);
    result:= pos('GMT by cella (squid/', buffer) < 2
end;


function getTitles(buffer: string; someFlags: kSomeFlags): tStringList;
const
    a = '/tmp/titlebot.';
var z            : dWord;
    y            : dWord;
    oldUri       : string          = '';
    title        : string          = '';
    content      : string          = '';
    aFile        : string          = '';
    contentType  : string          = '';
    redirects    : byte;
//    user,
//    channel,
    message      : string;
    lines        : tStringList;
    theSite      : kSite;
    fileProps    : kFileProperties;
    requestResult: kRequestResult;
    DoABarrelRoll: boolean = true;
    hasTheTitle  : boolean;
begin
  { A little hackishness. This was the only way loading files would work before
    I figured out files don't work well in global space. I'm not going to change
    it now, at least until total rewrite. }

  { Oh yeah, the real hack is curl --> files --> here instead of using pipes or
    learning to https. }
    lines := TStringList.Create;

    aFile := a + '.' + intToStr(random(65535));
    lines.clear;
    lines := extractURLs(buffer[z+1..length(buffer)]);
    result:= tStringList.Create;
    if lines.count > 0 then
        for z:= 0 to lines.count-1 do begin
            buffer := lines.Strings[z];
            title  := '';
            if ((gtHttp in someFlags) and (TextPos('http:/', buffer) > 0)) or ((gtHttps in someFlags) and (TextPos('https:/', buffer) > 0)) then begin
                writeln(#9'url: ', buffer);
                oldUri := buffer;
                writeln('Requesting: ', buffer);
                requestResult:= doRequest(buffer, aFile, fileProps, content, contentType, redirects);
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
                            siSoyMain,
                            siYouTube    : title:= getXMLtitle(content);
                            siSoyArticle : title:= getSoylentArticle(content, theSite.flags);
                            siSoyComment : title:= getSoylentComment(content, theSite.flags);
                            siSoyPoll    : title:= getSoylentPoll(content, theSite.flags);
                            siSoySub     : title:= getSoylentSubmission(content, theSite.flags);

                            siPipeArticle: title:= getPipedotArticle(content, theSite.flags);
                            siPipeComment: title:= getPipedotComment(content, theSite.flags);

                            siPedia      : begin
                                               y:= pos('#', buffer);
                                               if y = 0 then
                                                   title:= getWikiTextia(content, '')
                                               else
                                                   title:= getWikiTextia(content, buffer[y+1..length(buffer)]); // Broken for mobile pages
                                           end;

//                            siYouTube    : title:= getYouTubeDiz(content); // Broken; the XML one is good enough
                            end;

                        end;
                    end else if isText in fileProps then begin
                        title:= contentType;
                    end else
                        ; // do stuff

                    hasTheTitle:= (theSite.site = siWhatever) and urlHasTitle(oldUri, title);

                    if buffer <> oldUri then title+= ' ( '+stripSomeControls(buffer)+' )';
                end;
                { ':'#9 allows the IRC bot to skip error messages, even though they should be
                  going to stdErr, anyway. Apparently I was doin' it wrong in KVIrc. }
                if ((not hasTheTitle) or (redirects > 0)) and (title <> '') then
                    result.Append(stripSomeControls(title))
            end
        end;

initialization

naughtyList:= TStringList.create;
loadNaughties

;end. // the compiler suddenly needs a semicolon here

