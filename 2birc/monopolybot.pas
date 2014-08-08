{ A useless 2bIRC-based robot.
  License: WTFPL (see /copying)
}

program monopolybot;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, process, baseunix, CustApp, tubeyIRC, kUtils, url_title4;

const
    root       = '/home/toobee/';
    logFile    = root + '/monopo.log';
    sourceLink = 'https://github.com/chromatos/pas/tree/master/2birc';

type
    kBotMode = (bmStopped, bmRunning, bmRestarting);

  { tMonopolyBot }

    tMonopolyBot = class(TCustomApplication)
        bot       : kIRCclient;
//        proc: TProcess;

        procedure   doCommand    (message: kIrcMessage);
        procedure   handleInvite (message: kIrcMessage);
        procedure   handleMessage(message: kIrcMessage);
        procedure   handleKick   (message: kIrcMessage);
        procedure   handleJoin   (message: kIrcMessage);
        procedure   handleConnect;
        procedure   handleSocket (message: string; x: boolean);
        procedure   switchTitles (active: boolean);
        procedure   showTitles   (message: kIrcMessage);
//        procedure   titleCallBack;

      protected
        procedure   DoRun;override;
      public
        logger    : tFileStream;
        mode      : kBotMode;
        constructor Create(TheOwner: TComponent); override;
        destructor  Destroy; override;
        procedure   WriteHelp; virtual;
      private
        doTitles  : boolean;
    end;

var
    reboot     : boolean = false;
{ tMonopolyBot }

procedure tMonopolyBot.handleJoin(message: kIrcMessage);
begin
  { Sometimes this raises an exception but it seems to be ignored now I guess.
    Either way, no automatic bacon. We'll disable for now; can always manually bacon up.}
{    if (message.user.nick = bot.me.nick) and (message.channel = '##') then
        bot.say('##', 'bacon++')
    else}
        // Should centralize the 'authentication' sometime
        if (message.user.host = '0::1') or (message.user.nick = 'crutchy') or (ciPos('Soylent/Staff/', message.user.host) = 1) then
            bot.setMode(message.channel, '+v', message.user.nick);
end;

procedure tMonopolyBot.showTitles(message: kIrcMessage);
var buffer: string;
    z     : dWord;
    x     : tStringList;
    flags : kSomeFlags;
begin
  { We don't want to ejaculate titles whenever someone seds or .topics or something.
    Also aqu4 has $title so we want to ignore that, too, although we could detect
    what it's doing first. }

    flags:= [gtHttps, gtHttp];
//    if (ciPos('#soylent', message.channel) = 0) and(message.channel <> '##') then
//        flags+= [gtHttp]; { ciri does titles here, but for now doesn't handle https
//                             so we'll do it until it does. }

    if  (ciPos('bender', message.user.user) = 0) and (ciPos('sedbot', message.user.user) = 0)
    and (ciPos('exec', message.user.user) = 0) and (ciPos('ciri', message.user.user) = 0)
    and (ciPos('aqu4', message.user.user) = 0)
    and (message.message[1] <> '.') then begin
        x:= getTitles(message.message, flags);
        if x.count > 0 then
            for z:= 0 to x.count - 1 do
                bot.say(message.channel, '^ ' + clipText(x.Strings[z], 480));
        x.free
    end
end;

procedure tMonopolyBot.switchTitles(active: boolean);
begin
    { maybe do a check and write a message later }
    doTitles:= active;
end;

procedure tMonopolyBot.handleInvite(message: kIrcMessage);
begin
    bot.join(message.message);
    bot.say (message.message, 'Hi, ' + message.user.nick);
end;

procedure tMonopolyBot.handleSocket(message: string; x: boolean);
begin
    logger.Write(message[1], length(message));
    logger.WriteByte(10);
    writeLn('| ', message)
end;

procedure tMonopolyBot.doCommand(message: kIrcMessage);
var cmd,
    pars  : string;
    stuff : string;
    z     : dWord;
    authed: boolean = false;
begin
  { for authorization, we're assuming vhosts will be checked before being authorized
    by IRC staff and also the hack we call services is still running. }
    if (message.user.host = '0::1') or (message.user.nick = 'crutchy') or (ciPos('Soylent/Staff/', message.user.host) = 1) then
        authed:= true;

    z:= pos(' ', message.message);
    if (z > 1) and (z < length(message.message)) then begin
        cmd := LowerCase(message.message[2..z-1]);
        pars:= message.message[z+1..length(message.message)]
    end else
        cmd:= LowerCase(Trim(message.message[2..length(message.message)]));

    z:= 1;
    case cmd of
        'join'   : if pars <> '' then bot.join(pars);
        'part'   : if pars = '' then
                       bot.part(message.channel, 'You told me to')
                   else begin
                       stuff:= scanByDelimiter(' ', pars, z);
                       if z = length(pars) then
                           bot.part(stuff, 'Leaving')
                       else
                           bot.part(stuff, pars[z..length(pars)]);
                   end;
        ':q!'    : if authed then begin
                      if pars = '' then
                          bot.disconnect('Bye!')
                      else
                          bot.disconnect(pars);
                      mode:= bmStopped;
                  end;
        'restart': if authed then begin
                       if pars = '' then
                           bot.disconnect('Restarting')
                       else
                           bot.disconnect(pars);
                       mode:= bmRestarting;
                   end;
        's',
        'say'    : bot.say(message.channel, pars);
        'd',
        'do'     : bot.sayAction(message.channel, pars);
        'invite' : bot.invite(scanByDelimiter(' ', pars, z), pars[z..length(pars)]);
        'r'      : bot.say(message.channel, reverse(pars));
        'rdo'    : bot.sayAction(message.channel, reverse(pars));
        'sayto'  : if authed then begin
                       stuff:= scanByDelimiter(' ', pars, z);
                       bot.say(stuff, pars[z..length(pars)])
                   end;
        'doto'   : if authed then begin
                       stuff:= scanByDelimiter(' ', pars, z);
                       bot.sayAction(stuff, pars[z..length(pars)])
                   end;
        'o'      : if authed then
                       if pars = '' then
                           bot.setMode(message.channel, '+o', message.user.nick)
                       else
                           bot.setMode(message.channel, '+o', pars);
        '-o'      : if authed then
                       if pars = '' then
                           bot.setMode(message.channel, '-o', message.user.nick)
                       else
                           bot.setMode(message.channel, '-o', pars);
        'v'      : if authed then
                       if pars = '' then
                           bot.setMode(message.channel, '+v', message.user.nick)
                       else
                           bot.setMode(message.channel, '+v', pars);
        '-v'      : if authed then
                       if pars = '' then
                           bot.setMode(message.channel, '-v', message.user.nick)
                       else
                           bot.setMode(message.channel, '-v', pars);
        'source' : bot.say(message.channel, 'Source: ' + sourceLink);

        'nick'   : if authed then bot.nick(pars);
        'help'   : if pars = '' then
                       bot.say(message.channel, '[join; part; invite] [s/say; d/do; r; rdo] and if you''re special, then [sayto; doto] [(-)o; (-)v] [nick] [restart; :q!]');
    end;
end;

procedure tMonopolyBot.handleMessage(message: kIrcMessage);
var auth: boolean = false;
begin
    message.message:= stripSomeControls(message.message);

    if (message.message[1] = '/') and (length(message.message) > 1) then
        doCommand(message)
    else
        if length(message.message) > 5 then showTitles(message);
    if (ciPos('bacon--', message.message) = 1) and (message.channel = '##') then
        bot.say('##', 'bacon++ # bacon patrol');
end;

procedure tMonopolyBot.handleKick(message: kIrcMessage);
begin
    if ciPos('/soylent/staff/', message.user.host) = 0 then
        bot.join(message.channel)
end;

procedure tMonopolyBot.handleConnect;
begin
    mode:= bmRunning;
end;

procedure tMonopolyBot.DoRun;
var
    ErrorMsg  : String;
    buffer    : string;
    z         : dWord;
begin
    // quick check parameters
    ErrorMsg:=CheckOptions('h','help');
    if ErrorMsg<>'' then begin
        ShowException(Exception.Create(ErrorMsg));
        Terminate;
        Exit;
    end;
writeln('Checking options');
    // parse parameters
    if HasOption('h','help') then begin
        WriteHelp;
        Terminate;
        Exit;
    end;
writeln('Instantiating');
    bot                := kIRCclient.create;
    bot.me.user        := 'chromas';
    bot.me.nick        := 'testenopoly';
    bot.me.realName    := 'A Pascal robot';
    if FileExists(logFile + '.channels') then begin
        bot.channels.LoadFromFile(logFile + '.channels');
        DeleteFile(logFile + '.channels')
    end
    else
        bot.channels.Add ('#shell32.dll');

    bot.OnKick         := @handleKick;
    bot.onConnect      := @handleConnect;
    bot.onMessage      := @handleMessage;
    bot.onSocket       := @handleSocket;
    bot.onInvite       := @handleInvite;
    bot.onJoin         := @handleJoin;
    bot.identString    := readFile(root+'.sn.irc.p');

    if not FileExists(logFile) then
        logger:= tFileStream.Create(logFile, fmCreate or fmOpenWrite)
    else
        logger:= tFileStream.Create(logFile, fmOpenWrite);

    try
writeln('Connecting');
    bot.connect('irc.sylnt.us', 6667);
    mode:= bmStopped;

writeln('Waiting on server');
    while mode = bmStopped do begin // Why two loops? I don't recall. I think
        bot.doThings;               // it was so some flags could be set or something.
        sleep(69)                   // Whatever it was, it's not now.
    end;
writeln('Connected!');
    while mode = bmRunning do begin
        bot.doThings;
        sleep(69)
    end;
writeln('Exited main loop');

    // stop program loop

    finally
        logger.Free;
    end;
    if mode = bmRestarting then begin
        writeln('Restarting');
        bot.channels.SaveToFile(logFile + '.channels');
        reboot:= true
    end
    else begin
        writeln('Ending');
        reboot:= false
    end;
    Terminate;
end;

constructor tMonopolyBot.Create(TheOwner: TComponent);
begin
    inherited Create(TheOwner);
    StopOnException :=True;

end;

destructor tMonopolyBot.Destroy;
begin
    inherited Destroy;
end;

procedure tMonopolyBot.WriteHelp;
begin
    { add your help code here }
    writeln('Usage: ',ExeName,' -h');
end;

var
    Application: tMonopolyBot;
begin
    Application:=tMonopolyBot.Create(nil);
    Application.Title:='Monopoly robot';
writeln('Running');
    Application.Run;
writeln('Done');
    Application.Free;
writeln('Checking if we need to reboot');
    if reboot then
        if FpFork = 0 then
            FpExecv(paramStr(0), nil)
end.

