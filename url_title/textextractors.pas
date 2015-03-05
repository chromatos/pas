{ Warning: Complete mess ahead!
  This is what happens when you refactor while refactoring.
  The fact this actually works makes me feel like I might be responsible for slashd.

  Some day, I intend to make this OO so each scraper can be assigned as required.
  It's kind of silly for each one to have its own code to assemble the titles, summaries
  and colors.

  License: wtfpl (See 'copying' file or the Internet)
}

unit textExtractors;

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils, tanks;


type
    kFileProperty   = (isText, isXMLish);
    kFileProperties = set of kFileProperty;
    kRequestResult  = (isOK, isTooRedirectish, isNotFound, isNothing);
    kTitleType      = (isTitle, isSummary, isFirstLine, isSNsummary);

    kSiteType       = (siWhatever, siSoyMain, siSoyComment, siSoyArticle, siSoyPoll, siSoySub, siYouTube, siPedia, siPipeArticle, siPipeComment);
    kSiteFlags      = set of (sfTMBdev, sfDev, sfJournal, sfSubmission);
    kSite           = record
                          site : kSiteType;
                          flags: kSiteFlags;
                      end;

    kpageInfo       = record
        url,
        title,
        description,
        content,
        mimetype    : string;
        refreshed,
        last_emitted: TDate;
        redirects   : word;
        cached      : boolean;
    end;

    kPageList = array of kpageInfo;

    tColor          = (clNone, clBlack, clBlue, clGreen, clRed, clBrown, clMagenta, clOrange, clYellow, clLtGreen, clCyan, clLtCyan, clLtBlue,clLtMagenta,clLtGray,clGray,clWhite);

procedure getSoylentComment   (flags: kSiteFlags; var info: kpageInfo);
procedure getSoylentArticle   (flags: kSiteFlags; var info: kpageInfo);
procedure getSoylentPoll      (flags: kSiteFlags; var info: kpageInfo);
procedure getSoylentSubmission(flags: kSiteFlags; var info: kpageInfo);

procedure getPipedotArticle   (flags: kSiteFlags; var info: kpageInfo);
procedure getPipedotComment   (flags: kSiteFlags; var info: kpageInfo);

procedure getWikiTextia       (anchor: string; var info: kpageInfo);
procedure getYouTubeDiz       (var info: kpageInfo);

procedure getExcerpt          (size: dWord; var info: kpageInfo);
procedure getXMLtitle         (var info: kpageInfo);

function stripHTML            (buffer: string): string;
function stripBlockQuotes     (buffer: string): string;

function detectSite           (url: string): kSite;

function mIRCcolor            (color: tColor): string;

function tank2pageInfo        (buffer: string): kpageInfo;
function pageInfo2tank        (page: kpageInfo): string;


var iCantStrings: tStringList;

function iCant(): string;


implementation
uses strutils, kUtils, urlStuff;
const
    nothing_Error = 'nothing for you to see here';

function iCant(): string;
var z: dWord;
begin
    result:= iCantStrings.Strings[Random(iCantStrings.Count-1)]
end;


function cleanHTMLForIRC(buffer: string): string;
begin
    result:= trim(resolveXMLents(stripHTML(stripSomeControls(buffer))))
end;

function mIRCcolor(color: tColor): string;
{ We pad all the color codes because the protocol was designed by a tard }
begin
    case color of
        clNone     : result:= #15;
        clWhite    : result:= #3'00';
        clBlack    : result:= #3'01';
        clBlue     : result:= #3'02';
        clGreen    : result:= #3'03';
        clRed      : result:= #3'04';
        clBrown    : result:= #3'05';
        clMagenta  : result:= #3'06';
        clOrange   : result:= #3'07';
        clYellow   : result:= #3'08';
        clLtGreen  : result:= #3'09';
        clCyan     : result:= #3'10';
        clLtCyan   : result:= #3'11';
        clLtBlue   : result:= #3'12';
        clLtMagenta: result:= #3'13';
        clGray     : result:= #3'14';
        clLtGray   : result:= #3'15'
    end
end;

function tank2pageInfo(buffer: string): kpageInfo;
var z: integer;
    y: kKeyValues;
begin
    y:= tanks2keyvalues(buffer);
    for z:= 0 to high(y) do
        case y[z].key of
            'title'    : result.title       := y[z].value;
            'diz'      : result.description := y[z].value;
            'refreshed': result.refreshed   := StrToDateTime(y[z].value);
            'spoken'   : result.last_emitted:= StrToDateTime(y[z].value);
            'redirects': result.redirects   := StrToInt(y[z].value)
        end
end;

function pageInfo2tank(page: kpageInfo): string;
begin
    result:= keyvalue2tanks('title', page.title)
           + keyvalue2tanks('diz', page.description)
           + keyvalue2tanks('refreshed', DateTimeToStr(page.refreshed))
           + keyvalue2tanks('spoken', DateTimeToStr(page.last_emitted))
           + keyvalue2tanks('redirects', IntToStr(page.redirects));
end;

function detectSite(url: string): kSite;
var z: integer = 0;
    y: string;
    x: string;
begin
    result.flags:=[];
    z:= PosEx(':', url, 1) + 3;

    x:= lowerCase(url);
    y:= ExtractSubstr(x, z, ['/']);
    if (pos('soylentnews.org', y) > 0) or (pos('tmbvm.ddns.net', y) > 0) then begin
        if pos('dev.s', y) > 0 then result.flags:= [sfDev];
        if pos('wiki.s', y) > 0 then
            result.site:= siPedia
        else if pos('comments.pl', x) > 0 then
            result.site:= siSoyComment
        else if (pos('article.pl', x) > 0) then
            result.site:= siSoyArticle
        else if ((pos('journal', x) > 0) and (x[length(x)] in ['0'..'9'])) then begin
            result.site:= siSoyArticle;
            result.flags+= [sfJournal]
        end else
        if (pos('submit.pl?op=viewsub', x) > 0) then
            result.site:= siSoySub
        else
        if (pos('pollbooth.pl?', x) > 0) and (pos('aid=', x) > 0) then
            result.site:= siSoyPoll
        else
            result.site:= siSoyMain;
        if pos('tmbvm.ddns.net', y) > 0 then //for TMB's dev instance
            result.flags+= [sfTMBdev];
    end
    else if pos('pipedot.org', y) > 0 then begin
        if pos('/comment/', x) > 0 then
            result.site:= siPipeComment
        else if pos('/story/', x) > 0 then
            result.site:= siPipeArticle
        else result.site:= siWhatever
    end
    else if (pos('wikipedia.org', y) > 0) or (pos('wiktionary.org', y) > 0)
         or (pos('wikia.', y) > 0) or (pos('wiki.', y) > 0) then
        result.site:= siPedia
    else if pos('youtube.com', y) > 0 then
        result.site:= siYouTube
    else result.site:= siWhatever
end;

procedure getExcerpt(size: dWord; var info: kpageInfo);
{ This is for text files or whatever. Might fancy it up later. }
var z: dWord = 0;
    l: dWord;
begin
    l:= length(info.content);
    info.title:='Text';
    while (byte(info.content[z]) < 33) and (z < l) do
        inc(z);
    if (z + size) < l then
        info.description:= info.content[z..z+size]
    else info.description:= info.content[z..l]
end;

{ and of course, these should be split into includes; oh well }

procedure getSoylentArticle(flags: kSiteFlags; var info: kpageInfo);
var z    : integer = 0;
    y    : integer = 0;
    title: string;

begin
{ Title }
    z:= Pos('<div class="article"', info.content);
    if z < 1 then begin
        z:= Pos('<div id="journal', info.content);
    end;

    z:= PosEx('<h3', info.content, z);
    z:= PosEx('>', info.content, z) + 1;
    title:= resolveXMLents(stripHTML(extract_subStr(info.content, z, '</h3')));

    y:= z;
{ Comment count }
    z:= PosEx('<!-- start template: ID 154', info.content, z);
    if z > 0 then begin
        z:= PosEx('value="-1"', info.content, z);
        z:= PosEx(':', info.content, z) + 2;
        title += ' ' + mIRCcolor(clRed) + '(' + ExtractSubstr(info.content, z, [' ']) + ' comments)'
    end;

{ Summary }
    z:= y;
    extract_subStr(info.content, z, 'div class="intro"');
    z:= PosEx('>', info.content, z) + 1;

    info.description:= clip_text(cleanHTMLForIRC(extract_subStr(info.content, z, '</div')), 180);

    if (TextPos('close', title) = 1) or (TextPos('error', title) = 1) or (TextPos('log in', title) = 1) then
        if TextPos(nothing_error, info.content) > 0 then begin
            info.title:= iCant();
            exit
        end;

    info.title:= 'SN ';
    if sfDev     in flags then info.title+= '(dev) ';
    if sfTMBDev  in flags then info.title+= '(TMB dev) ';
    if sfJournal in flags then info.title+= 'journal '
    else info.title+= 'article: '+mIRCcolor(clNone);

    info.title+= reduce_white_space(title)
end;

procedure getSoylentSubmission(flags: kSiteFlags; var info: kpageInfo);
var z      : integer = 0;
    title,
    summary: string;
    who    : string;
begin
    { Title }
    z:= PosEx('<div class="article">', info.content, 1);
    if z < 1 then begin
        z:= PosEx('<div id="journal', info.content, 1);
        if z < 1 then
            exit;
    end;

    z:= PosEx('<h3', info.content, z);
    z:= PosEx('>', info.content, z) + 1;

    title:= cleanHTMLForIRC(extract_subStr(info.content, z, '</h3'));

  { Submitter }
    z:= PosEx('<div class="det', info.content, z);
    z:= PosEx('<b', info.content, z);
    z:= PosEx('>', info.content, z) + 1;

    who:= trim(resolveXMLents(stripHTML(extract_subStr(info.content, z, '<'))));


    { Summary }

    z:= PosEx('<p class="byline">', info.content, z);
    z:= PosEx('writes', info.content, z);
    z:= PosEx(':', info.content, z) + 1;

    info.description:= cleanHTMLForIRC(extract_subStr(info.content, z, '</div'));

    if (TextPos('close', title) = 1) or (TextPos('error', title) = 1) or (TextPos('log in', title) = 1) then
        if TextPos(nothing_error, info.content) > 0 then begin
            info.title:= iCant();
            exit
        end;

    info.title:= mIRCcolor(clRed) + 'SN ';
    if sfDev    in flags then info.title+= '(dev) ';
    if sfTMBDev in flags then info.title+= '(TMB dev) ';

    info.title+= reduce_white_space('Submission by ' + who + ': ' + mIRCcolor(clNone) + title)
end;


procedure getWikiTextia(anchor: string; var info: kpageInfo);
var z      : integer = 0;
begin
    info.title:= 'Wiki: ' + mIRCcolor(clNone);
    z:= PosEx('id="firstHeading"', info.content, 1);
    if z < 1 then
        z:= PosEx('id="section_0"', info.content, z);
    if z > 1 then begin
        z:= PosEx('>', info.content, z) + 1;

        info.title+= cleanHTMLForIRC(extract_subStr(info.content, z, '</h1'))
    end else
        getXMLtitle(info);

    if anchor = '' then begin
        z:= PosEx('mw-content-text', info.content, z);
        z:= PosEx('>', info.content, z) + 1;
    end else begin
        z:= TextPos('id="' + anchor, info.content);
        if z > 0 then begin
            z:= PosEx('</span', info.content, z);
            z:= PosEx('>', info.content, z) + 1;
        end
    end;

    info.description:= reduce_white_space(cleanHTMLForIRC(extract_subStr(info.content, z, '</p')))
end;

procedure getYouTubeDiz(var info: kpageInfo);
var z: integer = 0;
    y: integer;
begin
  { This is broken and is very similar to the xml scraper which is good enough for now. }
    z:= PosEx('meta name="title"', info.content, 1);
    z:= PosEx('c', info.content, z);
    z:= PosEx('"', info.content, z) + 1;

    info.title:= ExtractSubstr(info.content, z, ['"']);

    z:= PosEx('meta name="description"', info.content, z) + 1;

    z:= PosEx('c', info.content, z);
    z:= PosEx('"', info.content, z) + 1;

    info.title:= resolveXMLents(ExtractSubstr(info.content, z, ['"']))
end;

procedure getSoylentComment(flags: kSiteFlags; var info: kpageInfo);
var z: integer = 0;

begin
    z:= pos('<div id="comment_top', info.content);
    if z > 0 then begin
      { Find the user name/id }
        z:= PosEx('<div class="de', info.content, z);
        z:= PosEx('by', info.content, z) + 2;

        info.title:= 'SN ';
        if sfDev    in flags then info.title+= '(dev) ';
        if sfTMBDev in flags then info.title+= '(TMB dev) ';
        info.title+= 'comment by ' + trim(stripHTML(stripSomeControls(extract_subStr(info.content, z, '<span'))));
      { Find the comment }
        z:= PosEx('<div id="comment_', info.content, z);
        z:= PosEx('>', info.content, z) + 1;

        info.description:= reduce_white_space(stripBlockQuotes(cleanHTMLForIRC(extract_subStr(info.content, z, '</div>'))))
    end
end;

procedure getSoylentPoll(flags: kSiteFlags; var info: kpageInfo);
var Z       : integer = 0;
    comments: string;
    title   : string;
    votes   : string;
begin
  { Find the title }
    z:= PosEx('<div id="pollBooth">', info.content, 1);
    z:= PosEx('class="title"',info.content, z);
    z:= PosEx('>', info.content, z) + 1;

    title:= stripHTML(stripSomeControls(extract_subStr(info.content, z, '</div')));

    if (TextPos('close', title) = 1) or (TextPos('error', title) = 1) or (TextPos('log in', title) = 1) then
        if TextPos(nothing_error, info.content) > 0 then begin
            info.title:= iCant();
            exit
        end;

  { Find the vote count, even though we're putting it before the horse—I mean title }
    z:= PosEx('class="totalVotes"', info.content, z);
    z:= PosEx('>', info.content, z) + 1;

    votes:= trim(extract_subStr(info.content, z, '</b'));
    if votes[length(votes)] = '.' then votes:= votes[1..length(votes)-1];

  { Find the comment count }
    z:= PosEx('<select id="thresh', info.content, z);
    z:= PosEx('-1', info.content, z);
    z:= PosEx(':', info.content, z) + 2;

    comments:= ExtractSubstr(info.content, z, ['<']);

    info.title:= 'SN Poll ';
    if sfDev    in flags then info.title+= '(dev)';
    if sfTMBDev in flags then info.title+= '(TMB dev)';

    info.description:= reduce_white_space(title + ' (' + comments + '; ' + votes + ')');
end;

procedure getPipedotArticle(flags: kSiteFlags; var info: kpageInfo);
var z       : integer = 0;
    title,
    summary,
    comments: string;
begin
    z    := Pos('<article class="story', info.content);
    z    := PosEx('>', info.content, z) + 1;
    title:= resolveXMLents(stripHTML(stripSomeControls(extract_subStr(info.content, z, '</h1>'))));
    z    := PosEx('<div', info.content, z);
    z    := PosEx('>', info.content, z) + 1;

    info.description:= cleanHTMLForIRC(extract_subStr(info.content, z, '</div'));

    z:= PosEx('<footer>', info.content, z);
    z:= PosEx('<b>', info.content, z) + 3;

    comments  := stripSomeControls(extract_subStr(info.content, z, '</b>'));
    info.title:= reduce_white_space('Pipedot Article: ' + title + ' (' + comments + ' comments) ');
end;

procedure getPipedotComment(flags: kSiteFlags; var info: kpageInfo);
var z      : integer = 0;
    title,
    summary,
    score,
    who    : string;
begin
   { title }
     z:= Pos('<article class="comment', info.content);
     z:= PosEx('<h1', info.content, z);
     z:= PosEx('>', info.content, z) + 1;

     title:= cleanHTMLForIRC(ExtractSubstr(info.content, z, ['(']));
   { score }
     dec(z);
     score:= cleanHTMLForIRC(extract_subStr(info.content, z, '</h1'));
   { user name }
     z:= PosEx('<h3>', info.content, z);
     z:= PosEx('href', info.content, z);
     z:= PosEx('>', info.content, z) + 1;

     who:= cleanHTMLForIRC(ExtractSubstr(info.content, z, ['@']));
   { summary }
     extract_subStr(info.content, z, '<div');
     z:= PosEx('>', info.content, z) + 1;

     info.description:= cleanHTMLForIRC(extract_subStr(info.content, z, '<footer>'));

     info.title:= reduce_white_space('Pipedot Comment by ' + who + ': '
                                    + title + ' ' + score);
end;

procedure getXMLtitle(var info: kpageInfo);
{ For generic XML/HTML pages (including feeds) }
var z: integer = 0;
begin
    z:= TextPos('<title', info.content);
    if z > 0 then
    begin
        z:= PosEx('>', info.content, z) + 1;

        info.title:= cleanHTMLForIRC(extract_subStr(info.content, z, '</'));

        z:= TextPos('="og:description"',info.content);
        if z > 0 then
        begin
            while (info.content[z] <> '<') and (z > 1) do
                dec(z);
            extract_subStr(info.content, z, 'content="');
            z:= PosEx('"', info.content, z) + 1;

            info.description:= ': ' + cleanHTMLForIRC(ExtractSubstr(info.content, z, ['"']))
        end else
        begin
            z:= TextPos('name="description"',info.content);
            if z > 0 then
            begin
                while (info.content[z] <> '<') and (z > 1) do
                    dec(z);
                extract_subStr(info.content, z, 'content="');
                z:= PosEx('"', info.content, z) + 1;

                info.description:= cleanHTMLForIRC(ExtractSubstr(info.content, z, ['"']))
            end
        end
    end
end;

function stripHTML(buffer: string): string;
var z: integer = 1;
    y: string;
begin
    result:= '';
    while z < length(buffer) do begin
        if buffer[z] <> '<' then
            result+= ExtractSubstr(buffer, z, ['<']);
        y:= ExtractSubstr(buffer, z, ['>']);
        if (length(y) > 1) and ((y[1..2] = 'br') or (y[1..2] = '/p')) then
            result+= ' '
    end
end;

function stripBlockQuotes(buffer: string): string;
{ This is for comments, although sometimes people put their replies within; tough shit }
var z: integer = 1;
    y: integer;
begin
    while (z > 0) and (z < length(buffer)) do begin
        z:= PosEx('<', buffer, z);
        if z > 0 then begin
            y:= z;
            if TextPos('blockquote', ExtractSubstr(buffer, z, ['>'])) > 0 then begin
                z:= PosEx('</blockquote', buffer, z);
                z:= PosEx('>', buffer, z) + 1;

                delete(buffer, y, z - y);
                z:= y
            end
        end
    end;
    result:= buffer
end;

end.

