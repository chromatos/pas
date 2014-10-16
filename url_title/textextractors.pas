{ Warning: Complete mess ahead!
  This is what happens when you refactor while refactoring.
  The fact this actually works makes me feel like I might be responsible for slashd.

  Some day, I intend to make this OO so each scraper can be assigned as required.
  It's kind of silly for each one to have its own code to assemble the titles, summaries
  and colors.
}

unit textExtractors;

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils, kUtils, urlStuff;


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

    tColor          = (clNone, clBlack, clBlue, clGreen, clRed, clBrown, clMagenta, clOrange, clYellow, clLtGreen, clCyan, clLtCyan, clLtBlue,clLtMagenta,clLtGray,clGray,clWhite);

function getSoylentComment   (buffer: string; flags: kSiteFlags): string;
function getSoylentArticle   (buffer: string; flags: kSiteFlags): string;
function getSoylentPoll      (buffer: string; flags: kSiteFlags): string;
function getSoylentSubmission(buffer: string; flags: kSiteFlags): string;

function getPipedotArticle   (buffer: string; flags: kSiteFlags): string;
function getPipedotComment   (buffer: string; flags: kSiteFlags): string;

function getWikiTextia       (buffer: string; anchor: string): string;
function getYouTubeDiz       (buffer: string): string;


function getExcerpt          (buffer: string; size: dWord): string;
function getXMLtitle         (buffer: string): string;
function stripHTML           (buffer: string): string;
function stripBlockQuotes    (buffer: string): string;

function detectSite          (url: string): kSite;

function mIRCcolor           (color: tColor): string;

implementation

const
    nothing_Error = 'nothing for you to see here';
var iCantStrings: tStringList;

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
        clLtGray   : result:= #3'15';

    end
end;

function detectSite(url: string): kSite;
var z: dWord = 1;
    y: string;
    x: string;
begin
    result.flags:=[];
    findNext(':', url, z);
    inc(z, 3);
    x:= lowerCase(url);
    y:= scanByDelimiter('/', x, z);
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

function getExcerpt(buffer: string; size: dWord): string;
{ This is for text files or whatever. Might fancy it up later. }
var z: dWord = 1;
    l: dWord;
begin
    l:= length(buffer);
    while (byte(buffer[z]) < 33) and (z < l) do
        inc(z);
    if (z + size) < l then
        result:= buffer[z..z+size]
    else result:= buffer[z..l]
end;

{ and of course, these should be split into includes; oh well }

function getSoylentArticle(buffer: string; flags: kSiteFlags): string;
var z      : dWord = 1;
    y      : dWord = 0;
    title,
    summary: string;

begin
    { Title }
    scanToWord('<div class="article">', buffer, z);
    if z < 2 then begin // This is stupid; wtf? It should be zero but it's returning one. wtf?!
        z:= 1;
        scanToWord('<div id="journal', buffer, z);
        z:= 1
    end;

    scanToWord('<h3', buffer, z);
    findNext('>', buffer, z);
    inc(z);
    title+= resolveXMLents(stripHTML(scanToWord('</h3', buffer, z)));

    y:= z;
    { Comment count }
    scanToWord('<!-- start template: ID 154', buffer, z);
    if z > 0 then begin
        scanToWord('value="-1"', buffer, z);
        findNext(':', buffer, z);
        inc(z, 2);
        title += ' ' + mIRCcolor(clRed) + '(' + scanToWord(' ', buffer, z) + ' comments)'
    end;

    { Summary }
    z:= y;
    scanToWord('div class="intro"', buffer, z);
    findNext('>', buffer, z);
    inc(z);
    summary:= clipText(cleanHTMLForIRC(scanToWord('</div', buffer, z)), 180);

    if (ciPos('close', title) = 1) or (ciPos('error', title) = 1) or (ciPos('log in', title) = 1) then
        if ciPos(nothing_error, buffer) > 0 then begin
            result:= iCant();
            exit
        end;

    result:= mIRCcolor(clRed) + 'SN ';
    if sfDev in flags then result+= '(dev) ';
    if sfTMBDev in flags then result+= '(TMB dev) ';
    if sfJournal in flags then result+= 'journal '
    else result+= 'article ';


    result+= reduceWhiteSpace(mIRCcolor(clGreen) + title + mIRCcolor(clNone));// + ': ' + summary);
end;

function getSoylentSubmission(buffer: string; flags: kSiteFlags): string;
var z      : dWord = 1;
    title,
    summary: string;
    who    : string;
begin
    { Title }
    scanToWord('<div class="article">', buffer, z);
    if z < 2 then begin // This is stupid; wtf? It should be zero but it's returning one. wtf?!
        z:= 1;
        scanToWord('<div id="journal', buffer, z);
        z:= 1
    end;

    scanToWord('<h3', buffer, z);
    findNext('>', buffer, z);
    inc(z);
    title+= cleanHTMLForIRC(scanToWord('</h3', buffer, z));

  { Submitter }
    scanToWord('<div class="det', buffer, z);
    scanToWord('<b', buffer, z);
    findNext('>', buffer, z);
    inc(z);
    who:= trim(resolveXMLents(stripHTML(scanToWord('</b', buffer, z))));


    { Summary }

    scanToWord('<p class="byline">', buffer, z);
    scanToWord('writes', buffer, z);
    findNext(':', buffer, z);
    inc(z);
    summary:= clipText(cleanHTMLForIRC(scanToWord('</div', buffer, z)), 180);

    if (ciPos('close', title) = 1) or (ciPos('error', title) = 1) or (ciPos('log in', title) = 1) then
        if ciPos(nothing_error, buffer) > 0 then begin
            result:= iCant();
            exit
        end;

    result:= mIRCcolor(clRed) + 'SN ';
    if sfDev in flags then result+= '(dev) ';
    if sfTMBDev in flags then result+= '(TMB dev) ';

    result+= 'Submission by ' + who + ' ' + mIRCcolor(clGreen) + title + mIRCcolor(clNone);// + ': ' + summary;
    result:= reduceWhiteSpace(result)
end;


function getWikiTextia(buffer: string; anchor: string): string;
var z      : dWord = 1;
    title,
    summary: string;
begin
    scanToWord('id="firstHeading"', buffer, z);
    if z < 1 then
        scanToWord('id="section_0"', buffer, z);
    if z > 1 then begin
        findNext('>', buffer, z);
        inc(z);
        title:= clipText(cleanHTMLForIRC(scanToWord('</h1', buffer, z)), 69)
    end else
        title:= getXMLtitle(buffer);

    if anchor = '' then begin
        scanToWord('mw-content-text', buffer, z);
        findNext('>', buffer, z);
        inc(z)
    end else begin
        z:= ciPos('id="' + anchor, buffer);
        if z > 0 then begin
            scanToWord('</span', buffer, z);
            findNext('>', buffer, z);
            inc(z)
        end
    end;
//    inc(z);
    summary:= clipText(reduceWhiteSpace(cleanHTMLForIRC(scanToWord('</p', buffer, z))), 420);

    result := mIRCcolor(clRed) + 'Wiki: ' + mIRCcolor(clGreen) + title {+ ':'} + mIRCcolor(clNone);// + ' ' + summary
end;

function getYouTubeDiz(buffer: string): string;
var z: dWord = 1;
    y: dWord;
begin
  { This is broken and is very similar to the xml scraper which is good enough anyway. }
    scanToWord('meta name="title"', buffer, z);
    findNext('c', buffer, z);
    findNext('"', buffer, z);
    inc(z);
    result:= scanToWord('"', buffer, z);

    scanToWord('meta name="description"', buffer, z);
    inc(z, 22);
    findNext('c', buffer, z);
    findNext('"', buffer, z);
    inc(z);
    result+= ': ' + scanToWord('"', buffer, z);
    result:= resolveXMLents(result)
end;

function getSoylentComment(buffer: string; flags: kSiteFlags): string;
var z: dWord = 1;

begin
    z:= pos('<div id="comment_top', buffer);
    if z > 0 then begin
      { Find the user name/id }
        scanToWord('<div class="de', buffer, z);
        scanToWord('by', buffer, z);
        inc(z, 2);
        result:= mIRCcolor(clRed) + 'SN ';
        if sfDev in flags then result+= '(dev) ';
        if sfTMBDev in flags then result+= '(TMB dev) ';
        result+= 'comment by ' + trim(stripHTML(stripSomeControls(scanToWord('<span', buffer, z))));// + ':' + mIRCcolor(clNone);
      { Find the comment }
{        scanToWord('<div id="comment_', buffer, z);
        findNext  ('>', buffer, z);
        inc       (z);
        result+= ' ' + clipText(cleanHTMLForIRC(scanToWord('</div>', buffer, z)))), 180);
}
        result:= reduceWhiteSpace(stripBlockQuotes(result))
    end;
end;

function getSoylentPoll(buffer: string; flags: kSiteFlags): string;
var Z       : dWord = 1;
    comments: string;
    title   : string;
    votes   : string;
begin
  { Find the title }
    scanToWord('<div id="pollBooth">', buffer, z);
    scanToWord('class="title"',buffer, z);
    findNext('>', buffer, z);
    inc(z);
    title:= stripHTML(stripSomeControls(scanToWord('</div', buffer, z)));

    if (ciPos('close', title) = 1) or (ciPos('error', title) = 1) or (ciPos('log in', title) = 1) then
        if ciPos(nothing_error, buffer) > 0 then begin
            result:= iCant();
            exit
        end;

  { Find the vote count, even though we're putting it before the horse—I mean title }
    scanToWord('class="totalVotes"', buffer, z);
    findNext('>', buffer, z);
    inc(z);
    votes:= scanToWord('</b', buffer, z);
    if votes[length(votes)] = '.' then votes:= votes[1..length(votes)-1];

  { Find the comment count }
    scanToWord('<select id="thresh', buffer, z);
    scanToWord('-1', buffer, z);
    findNext(':', buffer, z);
    inc(z, 2);
    comments:= scanToWord('<', buffer, z);

    result:= mIRCcolor(clRed) + 'SN Poll ';
    if sfDev in flags then result+= '(dev) ';
    if sfTMBDev in flags then result+= '(TMB dev) ';
    result+= mIRCcolor(clNone) + ': ' + reduceWhiteSpace(title + ' (' + comments + '; ' + votes + ')');
end;

function getPipedotArticle(buffer: string; flags: kSiteFlags): string;
var z       : dWord = 1;
    title,
    summary,
    comments: string;
begin
    scanToWord('<article class="story', buffer, z);
    findNext('>', buffer, z);
    inc(z);
    title:= resolveXMLents(stripHTML(stripSomeControls(scanToWord('</h1>', buffer, z))));
    scanToWord('<div', buffer, z);
    findNext('>', buffer, z);
    inc(z);
//    summary:= clipText(cleanHTMLForIRC(scanToWord('</div', buffer, z)), 180);

    scanToWord('<footer>', buffer, z);
    scanToWord('<b>', buffer, z);
    inc(z, 2);
    comments:= stripSomeControls(scanToWord('</b>', buffer, z));
    result:= reduceWhiteSpace(mIRCcolor(clBlue) + 'Pipedot Article: ' + mIRCcolor(clGreen) + title + mIRCcolor(clBlue) + ' (' + comments + ' comments) ');// + mIRCcolor(clNone) + summary);
end;

function getPipedotComment(buffer: string; flags: kSiteFlags): string;
var z      : dWord = 1;
    title,
    summary,
    score,
    who    : string;
begin
   { title }
     scanToWord('<article class="comment', buffer, z);
     scanToWord('<h1', buffer, z);
     findNext('>', buffer, z);
     inc(z);
     title:= cleanHTMLForIRC(scanToWord('(', buffer, z));
   { score }
     dec(z);
     score:= cleanHTMLForIRC(scanToWord('</h1', buffer, z));
   { user name }
     scanToWord('<h3>', buffer, z);
     scanToWord('href', buffer, z);
     findNext('>', buffer, z);
     inc(Z);
     who:= cleanHTMLForIRC(scanToWord('@', buffer, z));
   { summary }
{     scanToWord('<div', buffer, z);
     findNext('>', buffer, z);
     inc(z);
     summary:= clipText(cleanHTMLForIRC(scanToWord('<footer>', buffer, z)), 180);
}
     result := reduceWhiteSpace(mIRCcolor(clBlue) + 'Pipedot Comment by ' + who + ': ' + mIRCcolor(clGreen) + title + ' ' + mIRCcolor(clBlue) + score);// + mIRCcolor(clNone) + ' ' + summary);
end;

function getXMLtitle(buffer: string): string;
{ For generic XML/HTML pages (including feeds) }
var z: dWord = 1;
begin
    z:= ciPos('<title', buffer);
    if z > 0 then begin
        findNext('>', buffer, z);
        inc(z);
        result:= mIRCcolor(clGreen) + clipText(cleanHTMLForIRC(scanToWord('</title', buffer, z)), 120) + mIRCcolor(clNone);
{
        z:= ciPos('="og:description"',buffer);
        if z > 0 then begin
            while (buffer[z] <> '<') and (z > 1) do
                dec(z);
            scanToWord('content="', buffer, z);
            findNext('"', buffer, z);
            inc(z);
            result+= ': ' + clipText(cleanHTMLForIRC(scanToWord('"', buffer, z)), 180);
        end else begin
        z:= ciPos('name="description"',buffer);
        if z > 0 then begin
                while (buffer[z] <> '<') and (z > 1) do
                    dec(z);
                scanToWord('content="', buffer, z);
                findNext('"', buffer, z);
                inc(z);
                result+= ': ' + clipText(cleanHTMLForIRC(scanToWord('"', buffer, z)), 180);
            end;
        end;
}
    end else
        result:= '';
end;

function stripHTML(buffer: string): string;
var z: dWord = 1;
    y: string;
begin
    result:= '';
    while z < length(buffer) do begin
        if buffer[z] <> '<' then
            result+= scanByDelimiter('<', buffer, z);
        y:= scanByDelimiter('>', buffer, z);
        if (length(y) > 1) and ((y[1..2] = 'br') or (y[1..2] = '/p')) then
            result+= ' '
    end
end;

function stripBlockQuotes(buffer: string): string;
{ This is for comments, although sometimes people put their replies within; tough shit }
var z: dWord = 1;
    y: dWord;
begin
    while z < length(buffer) do begin
        findNext('<', buffer, z);
        y:= z;
        if ciPos('blockquote', scanByDelimiter('>', buffer, z)) > 0 then begin
            scanToWord('</blockquote', buffer, z);
            findNext('>', buffer, z);
            inc(z);
            delete(buffer, y, z - y);
            z:= y
        end;
    end;
    result:= buffer
end;

initialization
    iCantStrings:= tStringList.create;
    iCantStrings.Append('I can''t!');
    iCantStrings.Append('It won''t let me');
    iCantStrings.Append('It''s no good; I can''t do it!');
    iCantStrings.Append('');
    iCantStrings.Append('');


finalization
    iCantStrings.free;



end.

