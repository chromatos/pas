{ A useless 2bIRC-based robot.

  License: wtfpl (See 'copying' file or the Internet)
}

program monopolybot;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, process, baseunix, CustApp, tubeyIRC, strutils, kUtils,
  url_title4, textExtractors,
  hives;

const
    root            = '/home/toobee/';
    logFile         = root + 'monopo.log';
    sourceLink      = 'https://github.com/chromatos/pas/tree/master/2birc';
    save_ticker_max = 100;
type
    kBotMode = (bmStopped, bmRunning, bmRestarting);

  { tMonopolyBot }

    tMonopolyBot = class(TCustomApplication)
        bot        : kIRCclient;
        procedure    doCommand       (message: kIrcMessage);
        procedure    do_hive_command (command, buffer: string; message: kIrcMessage; authed: boolean);

        procedure    handleInvite    (message: kIrcMessage);
        procedure    handleMessage   (message: kIrcMessage);
        procedure    handleNotice    (message: kIrcMessage);
        procedure    handleKick      (message: kIrcMessage);
        procedure    handleJoin      (message: kIrcMessage);
        procedure    handlePart      (message: kIrcMessage);
        procedure    handleConnect;
        procedure    handleDisconnect;
        procedure    handleSocket    (message: string; x: boolean);
        procedure    switchTitles    (active: boolean);
        procedure    showTitles      (message: kIrcMessage);

        procedure    doConfig;

      protected
        procedure    DoRun;override;
      public
        storage    : kHive_cluster;
        prefix     : char;
        logger     : tFileStream;
        mode       : kBotMode;
        constructor  Create(TheOwner: TComponent); override;
        destructor   Destroy; override;
        procedure    WriteHelp; virtual;
      private
        doTitles   : boolean;
        save_ticker: dWord;
    end;

var
    reboot     : boolean = false;
{ tMonopolyBot }

procedure tMonopolyBot.handleJoin(message: kIrcMessage);
begin
    if message.user.nick = bot.me.nick then
        storage.select_hive('.channels').add('', message.channel)
    else
    if (message.user.host = '0::1') or (message.user.nick = 'crutchy') or (TextPos('Soylent/Staff/', message.user.host) = 1) then
        bot.setMode(message.channel, '+v', message.user.nick);
end;

procedure tMonopolyBot.handlePart(message: kIrcMessage);
begin
    if message.user.nick = bot.me.nick then
        storage.del_cell_byval('.channels', message.channel);
end;

procedure tMonopolyBot.showTitles(message: kIrcMessage);
var buffer: string;
    z     : dWord;
    x     : kPageList;
    flags : kSomeFlags;
begin
  { We don't want to ejaculate titles whenever someone seds or .topics or something.
    Also aqu4 has $title so we want to ignore that, too, although we could detect
    what it's doing first. }

    flags:= [gtHttps, gtHttp];
//    if (TextPos('#soylent', message.channel) = 0) and(message.channel <> '##') then
//        flags+= [gtHttp]; { ciri does titles here, but for now doesn't handle https
//                             so we'll do it until it does. }

    if  (TextPos('bender', message.user.user) = 0) and (TextPos('sedbot', message.user.user) = 0)
    and (TextPos('exec', message.user.user) = 0) and (TextPos('ciri', message.user.user) = 0)
    and (TextPos('aqu4', message.user.user) = 0) and (TextPos('supybot', message.user.user) = 0)
    and not(message.message[1] in ['.','!','$', '~']) then begin
        x:= getTitles(message.message, flags);
        writeln(length(x), ' titles returned');
        if length(x) > 0 then
            for z:= 0 to high(x) do
                if x[z].title <> '' then bot.say(message.channel, '^ ' + mIRCcolor(clGreen) + clip_text(x[z].title, 480) + mIRCcolor(clNone))
    end
end;

procedure tMonopolyBot.doConfig;
var h: kHive_ancestor;
begin
    h              := storage.select_hive('.config');
    bot.me.user    := h.items['me.user'];
    bot.me.nick    := h.items['me.nick'];
    bot.me.realName:= h.items['me.realname'];
    prefix         := h.items['prefix'][1];
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
    if not((pos('PING', message) = 1) or (pos('PONG', message) = 1)) then
    begin
        message:= DateTimeToStr(now, DefaultFormatSettings) + #9 + message;
        logger.Write(message[1], length(message));
        logger.WriteByte(10);
        writeLn('| ', message)
    end
end;

procedure tMonopolyBot.do_hive_command(command, buffer: string; message: kIrcMessage; authed: boolean);
var z: integer = 1;
    y: integer = 0;
    l: integer;
    b: string;
    a: string;
    s: tStringList;
    h: kHive_ancestor;
    p: kRWModes;
const
    m_extra_p = 'Extra parameters ignored';
    procedure reply(aMessage: string);
    begin
        bot.say(message.channel, aMessage)
    end;

    procedure k;
    begin
        reply('k')
    end;
begin
    l:= length(buffer);
    storage.lastError:= ''; // Naturally, this should be set within the hive code but no time
    if authed then p:= cp_Helmet else p:= cp_Plebes;
    case command of
        'get': begin
                   while z < l do begin
                       a:= storage.content[ExtractSubstr(buffer, z, [' ']), p];
                       if a <> '' then bot.say(message.channel, clip_text(a, 360))
                   end;
                   if storage.lastError <> '' then
                       reply(storage.lastError)
               end;
        'del': if authed then
               begin
                   while z < l do
                   begin
                       storage.del_cell(ExtractSubstr(buffer, z, [' ']))
                   end;
                   if storage.lastError <> '' then
                       reply(storage.lastError)
               end;

        '!clear': if authed then
                 begin
                     storage.clear_hive(buffer);
                   if storage.lastError = '' then
                       k
                   else
                       reply(storage.lastError)
                 end;


        'set': begin
                   a:= ExtractSubstr(buffer, z, [' ']);
                   storage.content[a, p]:= buffer[z..l];
                   if a[1..7] = '.config' then
                       doConfig;
                   k
               end;
        'stats': begin
                   if z < l then
                       try
                       while z < l do
                       begin
                           a:= ExtractSubstr(buffer, z, [' ']);
                           h:= storage.select_hive(a);
                           if h <> nil then
                               reply(a + ': ' + intToStr(storage.select_hive(a).getSize)
                                                          + ' in ' + intToStr(storage.select_hive(a).count) + ' cells')
                           else
                               reply('There is no ' + a + '!')
                       end
                       except
                           reply(a + ' is not a hive')
                       end
                   else
                       reply(intToStr(storage.Count) + ' hives, holding '
                             + intToStr(storage.getSize) + ' bytes in '
                             + intToStr(storage.get_cell_count) + ' cells (with '
                             + intToStr(storage.get_overhead) + ' bytes overhead)')
               end;
{        'show': begin
                    while z < l do
                        storage.
                end;}
        'dump': if authed then
                begin
                    if buffer = '' then
                        storage.to_console('')
                    else
                        while z < l do
                            storage.to_console(ExtractSubstr(buffer, z, [' ']));
                    k
                end;
        'list': if authed then
                begin
                    writeln('==== Listing hives ====');
                    for y:= 0 to storage.Count-1 do
                        writeln(storage.NameOfIndex(y), ' | ',
                                storage.select_hive(y).Name, ': ',
                                kHive_ancestor(storage.Items[y]).count, ' items; ',
                                kHive_ancestor(storage.Items[y]).SPermissions);
                    writeln('==== Done listing ', storage.Count, ' hives ====');
                    k
                end;
        'new': begin
                   s:= split(' ', buffer);
                   if s.count > 1 then
                   begin
                       if authed and (s.count > 2) then
                       begin
                           storage.add_hive(s[1], s[0], str2perms(s[2]));
                           k
                       end else
                       begin
                           storage.add_hive(s[1], s[0], str2perms('r:everyone;w:everyone')); // Plebes' permission strings are ignored
                           k
                       end;

                       if s.count > 3 then
                           reply(m_extra_p);
                   end
                   else
                       reply('requires three parameters: class name [permissions] (except for plebes, who can''t set permissions)');
                   s.free
               end;
        'setpermissions': begin
                              if authed then
                              begin
                                  s:= split(' ', buffer);
                                  if s.Count = 2 then
                                  begin
                                      storage.permission[s[0]]:= s[1];
                                      k
                                  end
                                  else
                                      reply('Requires two parameters: hive_name permission_string')
                              end
                          end;
        '!deletehive': begin
                      if authed then
                      begin
                          s:= split(' ', buffer);
                          if s.Count = 1 then
                          begin
                              a:= intToStr(storage.select_hive(s[0]).count);
                              if storage.del_hive(s[0]) then
                                  reply('You just killed ' + a + 'bees')
                          end
                          else
                              reply('Requires exactly one parameters: hive_name')
                      end
                  end;
        'rename': begin
                      if authed then
                      begin
                          s:= split(' ', buffer);
                          if s.Count = 2 then begin
//                              storage.Rename(s[0], s[1]);
                              storage.select_hive(s[0]).Rename(s[1]);
                              k
                          end
                          else
                              reply('Requires two parameters: old_name new_name')
                      end
                  end;
        'save'  : if authed then
                  begin
                      storage.save(storage.theDirectory);
                      k
                  end;
    end;
    if storage.lastError <> '' then begin
        writeln(stdErr, '==Hive error: ', storage.lastError);
        reply(storage.lastError)
    end
end;

procedure tMonopolyBot.doCommand(message: kIrcMessage);
var cmd,
    pars  : string;
    stuff : string;
    z     : integer;
    y     : integer;
    authed: boolean = false;
begin
  { for authorization, we're assuming vhosts will be checked before being authorized
    by IRC staff and also the hack we call services is still running. }
    if (message.user.host = '0::1') or (message.user.nick = 'chromas') or (message.user.nick = 'crutchy') or (TextPos('Soylent/Staff/', message.user.host) = 1) then
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
                       stuff:= ExtractSubstr(pars, z, [' ']);
                       if (stuff <> '') and (stuff[1] in ['#', '&', '!', '.', '~']) then begin
                           message.channel:= stuff;
                           pars:= pars[z..length(pars)];

                           if pars = '' then
                               pars:= 'Leaving';
                       end;
                       bot.part(message.channel, pars)
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
        'reload' : if authed then begin
                       bot.say(message.channel, 'noctl');
                   end;
        'kick'   : if authed and (pars <> '') then begin
                       stuff:= ExtractSubstr(pars, z, [' ']);
                       bot.kick(stuff, pars[z..Length(pars)]);
                   end;
        's',
        'say'    : begin if pars <> '' then
                       if (pars[1] in ['.','!','$', '~']) then begin
                           if not authed then
                               exit
                           end;
                           bot.say(message.channel, pars);
                       end;
        'do',
        'me'     : if pars <> '' then bot.sayAction(message.channel, pars);
        'invite' : bot.invite(ExtractSubstr(pars, z, [' ']), pars[z..length(pars)]);
        'r'      : if pars <> '' then bot.say(message.channel, reverse(pars));
        'rdo'    : if pars <> '' then bot.sayAction(message.channel, reverse(pars));
        'sayto'  : if authed and (pars <> '') then begin
                       stuff:= ExtractSubstr(pars, z, [' ']);
                       bot.say(stuff, pars[z..length(pars)])
                   end;
        'doto'   : if authed and (pars <> '') then begin
                       stuff:= ExtractSubstr(pars, z, [' ']);
                       bot.sayAction(stuff, pars[z..length(pars)])
                   end;
        'topic'  : if authed and (pars <> '') then
                       bot.setTopic(message.channel, pars);
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
        'source' : //bot.say(message.channel, 'Source: ' + sourceLink);
                   bot.sayAction(message.channel, 'is ashamed of the source');

        'nick'   : if authed and (pars <> '') then bot.nick(pars);
        'help'   : if pars = '' then
                       bot.say(message.channel, '[join; part; invite] [say; me,do; r; rdo] and if you''re special, then [sayto; doto] [(-)o; (-)v] [topic] [nick] [reload; restart; :q!]. Also, ask about hives!')
                   else if lowerCase(pars) = 'hives' then
                       bot.say(message.channel, 'Hive commands: get, set, show, new, dump, list, stats');
        else
            do_hive_command(cmd, pars, message, authed);
    end;
end;

procedure tMonopolyBot.handleMessage(message: kIrcMessage);
var auth: boolean = false;
begin
    message.message:= stripSomeControls(message.message);

    if (length(message.message) > 1) and (message.message[1] = prefix) then
        doCommand(message)
    else
    if (message.user.nick = 'exec') and (message.message = 'exec_test_sn_site_down') then begin
        if not pageIsUp('http://soylentnews.org/') then
            bot.sayAction('#Soylent', 'confirms "SoylentNews.org has been abducted by aliens!"')
        else
            bot.say('exec', 'nuh uh!')
    end
    else
        if length(message.message) > 5 then showTitles(message);
    if (TextPos('bacon--', message.message) = 1) and (message.channel = '##') then
        bot.say('##', 'bacon++ # bacon patrol');
end;

procedure tMonopolyBot.handleNotice(message: kIrcMessage);
begin
    if (message.user.user = 'NickServ') and (message.user.host = 'services.') then
    begin
        if TextPos('welcome', message.message) > 0 then
        begin
            bot.say(message.user.nick, 'identify '
                  + storage.content['.config/nickserv.user', cp_No_touch] + ' '
                  + storage.content['.config/nickserv.pass', cp_No_touch]);
            writeln('Identified')
        end
        else
        if TextPos('you are now identified', message.message) > 0 then
            if storage.select_hive('.channels').Count > 0 then bot.join(kList_hive(storage.select_hive('.channels')).content)
    end
end;

procedure tMonopolyBot.handleKick(message: kIrcMessage);
begin
    if TextPos('/soylent/staff/', message.user.host) = 0 then
        bot.join(message.channel)
end;

procedure tMonopolyBot.handleConnect;
begin
    mode:= bmRunning;
end;

procedure tMonopolyBot.handleDisconnect;
begin
    mode:= bmRestarting
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
    storage            := kHive_cluster.Create(true);
    storage.load('/home/toobee/monopolybot/hives/');
    url_title4.hive_cluster:= storage;

    save_ticker        := 0;

    bot                := kIRCclient.create;
    doConfig;

    bot.OnKick         := @handleKick;
    bot.onConnect      := @handleConnect;
    bot.onMessage      := @handleMessage;
    bot.onNotice       := @handleNotice;
    bot.onSocket       := @handleSocket;
    bot.onInvite       := @handleInvite;
    bot.onJoin         := @handleJoin;
    bot.onPart         := @handlePart;

    bot.identString    := storage.content['.config/nickserv.user', cp_No_touch] + ' '
                        + storage.content['.config/nickserv.pass', cp_No_touch];

    if not FileExists(logFile) then
        logger:= tFileStream.Create(logFile, fmCreate or fmOpenWrite)
    else
        logger:= tFileStream.Create(logFile, fmOpenWrite);

    try
writeln('Connecting');
    bot.connect(storage.content['.config/server.host', cp_No_touch], strToInt(storage.content['.config/server.port', cp_No_touch]));
//    bot.connect('irc.sylnt.us', 6667);
    mode:= bmStopped;

writeln('Waiting on server');
    while mode = bmStopped do begin // Why two loops? I don't recall. I think
        bot.doThings;               // it was so some flags could be set or something.
        sleep(69)                   // Whatever it was, it's not now.
    end;
writeln('Connected!');
    while mode = bmRunning do begin
        bot.doThings;
        inc(save_ticker);
        if save_ticker = save_ticker_max then
        begin
            save_ticker:= 0;
            storage.save(storage.theDirectory)
        end;
        sleep(69)
    end;
writeln('Exited main loop');

    // stop program loop

    finally
        logger.Free;
        storage.save(storage.theDirectory);
        storage.Free
    end;
    if mode = bmRestarting then begin
        writeln('Restarting');
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
    StopOnException :=True
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
    Application.Run;
    Application.Free;

    if reboot then
        if FpFork = 0 then
            FpExecv(paramStr(0), nil)
end.

