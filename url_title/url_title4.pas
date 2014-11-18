{ Page title-grabbing script with much hackishness.

  License: wtfpl (See 'copying' file or the Internet)
}

unit url_title4;
{$mode objfpc}{$H+}

interface
uses
    Classes, SysUtils, unix, kUtils, urlStuff, textExtractors, hives;

type kSomeFlags = set of (gtHttp, gtHttps, gtFtp, gtGopher);


function getTitles(buffer: string; someFlags: kSomeFlags): kPageList;
function pageIsUp (uri: string): boolean;

var hive_cluster: kHive_cluster; // This is probably an ill-advised way to do get
                                 // things done. The purpose is to have the robot's
                                 // hive cluster available here since we're not
                                 // using classes here for whatever reason.

                                 // Anyhow, this should NOT be constructed locally;
                                 // just set it to the bot's instance.

implementation
uses dateutils, regexpr;

function isSafe(buffer: string): boolean;
var z: integer = 0;
    y: tStringList;
    x: boolean = false;
begin
    y:= kList_hive(hive_cluster.Find('.titles.ignore')).content;
    if y.count = 0 then
    begin
        result:= true;
        exit
    end;
    buffer:= lowerCase(buffer);

    while (z < y.count) and (not x) do
    begin
        x:= regexpr.ExecRegExpr(y.Strings[z], buffer);
        inc(z)
    end;
    if x then
        writeln('Ignoring ', buffer);

    result:= not x
end;

//function doRequest(var uri: string; baseName: string; out props: kFileProperties; out buffer: string; out contentType: string; out redirects: byte): kRequestResult;
function doRequest(var aSite: kpageInfo; baseName: string; out props: kFileProperties): kRequestResult;
//const
//    uaString = 'Mozilla/5.0 (netctl; X11; Linux x86_64; rv:24.7) Gecko/20140911 Firefox/24.7';
var aFile   : tStringList;
    z       : dWord;
    final   : boolean = false;
begin
    aFile := tStringList.Create;
    aSite.redirects:= 0;
    props := [];
    result:= isOK;

    while (not final) and (aSite.redirects < 6) do begin
        aSite.url:= stripUrlShit(aSite.url);
        if not isSafe(aSite.url) then begin
            result:= isNothing;
            exit
        end;
        fpSystem('curl -m 8 -x "http://10.10.9.254:3128" -A "' + hive_cluster.content['.config/user_agent', cp_No_touch]
               + '" -k -s -D ' + baseName + '.head "' + aSite.url + '" > ' + baseName + '.body');
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
                    inc(aSite.redirects)
                else
                    final:= true
            end;
            if TextPos('location', aFile.Strings[z]) > 0 then
                aSite.url:= aFile.Strings[z][Pos(':', aFile.Strings[z])+2..length(aFile.Strings[z])];
            if TextPos('content-type', aFile.Strings[z]) > 0 then begin
                aSite.mimetype:= aFile.Strings[z];
                if TextPos('text', aSite.mimetype) > 0 then props+= [isText];
                if (TextPos('xml', aSite.mimetype) > 0) or (TextPos('html', aSite.mimetype) > 0) then props+= [isXMLish];
            end;
            inc(z)
        end
    end;
    aFile.free;

    if props <= [isText, isXMLish] then
        aSite.content:= file2string(baseName + '.body');

    if not final then
        result:= isTooRedirectish
end;

function pageIsUp(uri: string): boolean;
var baseName : string = '/tmp/.sitecheck.ask';
    props    : kFileProperties;
    aSite    : kpageInfo;
    theResult: kRequestResult;
begin
    aSite.url:= uri;
    theResult:= doRequest(aSite, baseName, props);
    result   := pos('GMT by cella (squid/', aSite.content) < 2
end;


procedure fillTitle(var aPage: kpageInfo; var someFlags: kSomeFlags);
const
    a = '/tmp/titlebot.';
var z            : dWord;
    y            : dWord;
    x            : dWord = 0;
    oldUri       : string          = '';
    content      : string          = '';
    aFile        : string          = '';
    lines        : tStringList;
    theSite      : kSite;
    fileProps    : kFileProperties;
    requestResult: kRequestResult;
    hasTheTitle  : boolean;
    cache        : kHive_ancestor;
    ignorables   : tStringList;
begin
  { A little hackishness. This was the only way loading files would work before
    I figured out files don't work well in global space. I'm not going to change
    it now, at least until total rewrite. }

  { Oh yeah, the real hack is curl --> files --> here instead of using pipes or
    learning to https. }

    aFile := a + '.' + intToStr(random(65535));

    if ((gtHttp in someFlags) and (TextPos('http:/', aPage.url) = 1)) or ((gtHttps in someFlags) and (TextPos('https:/', aPage.url) = 1)) then
    begin
        oldUri := aPage.url;
        writeln('Requesting: ', aPage.url);
        requestResult:= doRequest(aPage, aFile, fileProps);
        if FileExists(aFile + '.head') then DeleteFile(aFile + '.head');
        if FileExists(aFile + '.body') then DeleteFile(aFile + '.body');
        theSite:= detectSite(aPage.url);

      { File hacks are done; everything else is just string passing.
        It's still terrible because there's a lot of lowerCase() calling,
        which should be replaced with a record of two strings or something. }

        if (requestResult = isOK) and (aPage.content <> '') then
        begin
            if isXMLish in fileProps then
            begin
                case theSite.site of
                    siWhatever,
                    siSoyMain,
                    siYouTube    : getXMLtitle(aPage);
                    siSoyArticle : getSoylentArticle(theSite.flags, aPage);
                    siSoyComment : getSoylentComment(theSite.flags, aPage);
                    siSoyPoll    : getSoylentPoll(theSite.flags, aPage);
                    siSoySub     : getSoylentSubmission(theSite.flags, aPage);

                    siPipeArticle: getPipedotArticle(theSite.flags, aPage);
                    siPipeComment: getPipedotComment(theSite.flags, aPage);

                    siPedia      : begin
                                       y:= pos('#', aPage.url);
                                       if y = 0 then
                                           getWikiTextia('', aPage)
                                       else
                                           getWikiTextia(aPage.url[y+1..length(aPage.url)], aPage); // Broken for mobile pages
                                       end;

//                  siYouTube    : getYouTubeDiz(content, aPage); // Broken; the XML one is good enough
                end;
            end;
        end{ else if isText in fileProps then begin
             aPage.mimetype:= contentType;
             end else}
             ; // do stuff

        hasTheTitle:= (theSite.site = siWhatever) and urlHasTitle(oldUri, aPage.title);

        if aPage.url <> oldUri then aPage.title+= ' ( '+stripSomeControls(aPage.url)+' )';
    end;

    if ((not hasTheTitle) or (aPage.redirects > 0)) and (aPage.title <> '') then
    begin
        aPage.title    := stripSomeControls(aPage.title);
        aPage.refreshed:= now;
        writeln(aPage.title);
    end
end;

function getTitles(buffer: string; someFlags: kSomeFlags): kPageList;
const
    a = '/tmp/titlebot.';
var z            : dWord;
    y            : dWord;
    x            : dWord = 0;
    oldUri       : string          = '';
    content      : string          = '';
    aFile        : string          = '';
    lines        : tStringList;
    theSite      : kSite;
    aPage        : kpageInfo;
    fileProps    : kFileProperties;
    requestResult: kRequestResult;
    hasTheTitle  : boolean;
    cache        : kHive_ancestor;
    cache_timeout: dWord = 20;
    emit_timeout : dWord = 10;
    ignorables   : tStringList;
begin
    oldUri:= hive_cluster.content['.config/title.cache.timeout', cp_No_touch];
    if oldUri <> '' then
        cache_timeout:= strToInt(oldUri);

    oldUri:= hive_cluster.content['.config/title.emit.timeout', cp_No_touch];
    if oldUri <> '' then
        emit_timeout:= strToInt(oldUri);

  { Oh yeah, the real hack is curl --> files --> here instead of using pipes or
    learning to https. }
    lines:= TStringList.Create;

    aFile := a + '.' + intToStr(random(65535));
    lines.clear;
    lines := extractURLs(buffer[z+1..length(buffer)]);
    setLength(result, lines.Count);
    if lines.count > 0 then
    begin
        cache     := hive_cluster.select_hive('.titles.cache');

        for z:= 0 to lines.count-1 do
        begin
            aPage.url        := lines.Strings[z];
            aPage.cached     := false;
            aPage.title      := '';
            aPage.description:= '';
            aPage.redirects  := 0;

          { Check for cache }
            oldUri:= cache.items[aPage.url]; // variable_reuse++ # for naughtiness
            if oldUri <> '' then
            begin
                aPage:= tank2pageInfo(oldUri);
                if MinutesBetween(aPage.last_emitted, now) < emit_timeout then // keep from amplifying
                    writeln('Too soon! (', lines[z], ')')           // repetitive-link flood
                else
                begin
                    if MinutesBetween(aPage.refreshed, now) > cache_timeout then // refresh cache
                    begin
                        fillTitle(aPage, someFlags);
                        aPage.cached:= false;
                    end
                    else
                    begin
                        aPage.cached:= true;
                        writeln('Cache was recent for ', aPage.url)
                    end;

                    aPage.last_emitted:= now;
                    if aPage.title <> '' then
                    begin
                        cache.items[aPage.url]:= pageInfo2tank(aPage);
                        result[x]:= aPage;
                        inc(x)
                    end
                end
            end
            else
            begin
                fillTitle(aPage, someFlags);
                aPage.cached:= false;
                if aPage.title <> '' then
                begin
                    aPage.last_emitted:= now;
                    cache.items[aPage.url]:= pageInfo2tank(aPage);
                    result[x]:= aPage;
                    inc(x)
                end
            end
        end;
    setLength(result, x)
    end
end

;end. // the compiler suddenly needs a semicolon here

