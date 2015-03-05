{ A useless 2bIRC-based robot.

  License: wtfpl (See 'copying' file or the Internet)
}

program monopolybot;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, process, baseunix, CustApp, tubeyIRC, strutils, dateutils, kUtils,
  url_title4, textExtractors,
  hives, urlstuff, tanks, termctl;

var
    hive_root: string;

type
    kBotMode = (bmStopped, bmRunning, bmRestarting);

  { tMonopolyBot }

    tMonopolyBot = class(TCustomApplication)
        bot     : kIRCclient;
        procedure doCommand       (message: kIrcMessage);
        procedure do_hive_command (command, buffer: string; message: kIrcMessage; auth: kRWModes);

        function  doGrab          (who: string): boolean; // Returns true if there was a grabbable quote
        procedure doKarma         (message: kIrcMessage);

        procedure handleInvite    (message: kIrcMessage);
        procedure handleMessage   (message: kIrcMessage);
        procedure handleNotice    (message: kIrcMessage);
        procedure handleKick      (message: kIrcMessage);
        procedure handleJoin      (message: kIrcMessage);
        procedure handleNick      (message: kIrcMessage);
        procedure handlePart      (message: kIrcMessage);
        procedure handleConnect;
        procedure handleDisconnect;
        procedure handleSocket    (message: string; x: boolean);
        procedure showTitles      (message: kIrcMessage);

        procedure   doConfig;

        function  getAuthLevel(message: kIrcMessage): kRWModes;

      protected
        procedure   DoRun;override;
      public
        storage   : kHive_cluster;
        prefix    : string;
        logger    : tFileStream;
        logFile   : string;
        mode      : kBotMode;
        constructor Create(TheOwner: TComponent); override;
        destructor  Destroy; override;
        procedure   WriteHelp; virtual;
      private
        doTitles       : boolean;
        save_ticker    : TDateTime;
        save_interval  : integer;
    end;

var
    reboot     : boolean = false;

{ tMonopolyBot }

procedure tMonopolyBot.handleJoin(message: kIrcMessage);
begin
    if message.user.nick = bot.me.nick then
    begin
        if storage.select_hive('.channels').search(message.channel) = '' then
            storage.select_hive('.channels').add('-', message.channel)
    end
    else
    if (message.user.host = '0::1') or (message.user.nick = 'crutchy') or (TextPos('Soylent/Staff/', message.user.host) = 1) then
        bot.setMode(message.channel, '+v', message.user.nick);
end;

procedure tMonopolyBot.handleNick(message: kIrcMessage);
begin          writeln(#9'::', message.message, ' || ', message.user.nick);
    if message.user.nick = bot.me.nick then begin
        storage.content['.config/me.nick', cp_No_touch]:= message.message;
        bot.me.nick:= message.message
    end
end;

procedure tMonopolyBot.handlePart(message: kIrcMessage);
begin
    if message.user.nick = bot.me.nick then
        storage.del_cell_byval('.channels', message.channel);
end;

procedure tMonopolyBot.showTitles(message: kIrcMessage);
var z     : integer;
    x     : kPageList;
    flags : kSomeFlags;
    caret : array[kCacheStatus] of string;// = ('^', '"');


    function ignoreBots_and_stuff(): boolean;
  { I had to move this to its own function because random bits would cause
    getTitles to return nothing; for example, calling lowerCase here would
    actually cause another function to return an empty array! Now, while I
    moved these variables here for properosity, I didn't have to in order to
    get it to stop being stupid. }
    var b: string = '';
        z: integer = 0;
        a: tStringList;
        l: integer;
    begin
        result:= false;
        l     := length(message.message);

        b:= lowerCase(message.user.nick);
        a := kList_hive(storage.select_hive('.bots')).content;
        if a.Count > 0 then
            for z:= 0 to a.Count-1 do
                if lowerCase(a.Strings[z]) = b then
                    exit;

        b:= lowerCase(message.user.host);
        a := kList_hive(storage.select_hive('.bots.vhosts')).content;
        if a.Count > 0 then
            for z:= 0 to a.Count-1 do
                if lowerCase(a.Strings[z]) = b then
                    exit;

        l:= length(message.message);
        z:= 1;
        while (not(message.message[z] in ['A'..'Z','a'..'z'])) and (z < 6) and (z < l) do
            inc(z);
        dec(z);
        if z > 0 then
        begin
            if storage.content['.bots.prefixes/' + message.message[1..z], cp_Helmet] <> '' then
            begin
                writeln('Ignored links sent to bot');
                exit;
            end;
        end;
        result:= true
    end;

begin
    flags:= [gtHttps, gtHttp];

{    if storage.select_hive('.titles.enabled').search(message.channel) = '' then
        exit;} // for absolutely no reason, this only works on my server and not soylent's

  { We don't want to ejaculate titles whenever someone seds or .topics or something. }

    if ignoreBots_and_stuff() then
    begin
    //  This is dumb:
        caret[isNotCached]:= storage.select_hive('.config').items['caret_n'];
        caret[isSeen]     := storage.select_hive('.config').items['caret_s'];
        caret[isCached]   := storage.select_hive('.config').items['caret_c'];

        x:= getTitles(message.message, flags);
        if length(x) > 0 then
        begin
            for z:= 0 to high(x) do
                if x[z].title <> '' then
                    bot.say(message.channel, caret[x[z].cached] + ' ' + mIRCcolor(clGreen) + clip_text(x[z].title, 480) + mIRCcolor(clNone))
                else
                    bot.say(message.channel, caret[isNotCached] + ' [No title]')
        end

    end
end;

procedure tMonopolyBot.doConfig;
var h: kHive_ancestor;
begin
    h              := storage.select_hive('.config');
    bot.me.user    := h.items['me.user'];
    bot.me.nick    := h.items['me.nick'];
    bot.me.realName:= h.items['me.realname'];
    prefix         := h.items['prefix'];
    save_interval  := StrToIntDef(h.items['save_interval'], 2);
    logFile        := h.items['logfile'];
end;

function tMonopolyBot.getAuthLevel(message: kIrcMessage): kRWModes;
begin
    if (storage.select_hive('.config').items['owner.nick'] = message.user.nick)
    or (storage.select_hive('.config').items['owner.vhost'] = message.user.host) then
        result:= cp_DoubleHelmet
    else
    if (storage.select_hive('.bot.helmet.nicks').search(message.user.nick) <> '')
    or (storage.select_hive('.bot.helmet.vhosts').search(message.user.host) <> '') then
        result:= cp_Helmet
    else
        result:= cp_Plebes
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

procedure tMonopolyBot.do_hive_command(command, buffer: string; message: kIrcMessage; auth: kRWModes);
var z: integer = 1;
    y: integer = 0;
    l: integer;
    b: string;
    a: string;
    s: tStringList;
    h: kHive_ancestor;

const
    m_extra_p = 'Extra parameters ignored';
    procedure reply(aMessage: string);
    begin
        bot.say(message.channel, aMessage)
    end;

    procedure k;
    begin
        if storage.lastError <> '' then begin
            writeln(stdErr, '==Hive error: ', storage.lastError);
            reply(storage.lastError)
        end
        else
            reply('k')
    end;
begin
    if command = '' then exit;

    l:= length(buffer);
    storage.lastError:= ''; // Naturally, this should be set within the hive code but no time

    case command of
        'get': begin
                   while z < l do begin
                       a:= storage.content[ExtractSubstr(buffer, z, [' ']), auth];
                       if a <> '' then bot.say(message.channel, clip_text(a, 360))
                   end
               end;
        'del': if auth < cp_Plebes then
               begin
                   while z < l do
                   begin
                       storage.del_cell(ExtractSubstr(buffer, z, [' ']))
                   end;
                   k
               end;

        '!clear': if auth < cp_Plebes then
                 begin
                     storage.clear_hive(buffer);
                   if storage.lastError = '' then
                       k
                 end;


        'set': begin
                   a:= ExtractSubstr(buffer, z, [' ']);
                   if (a[1..7] = '.config') and (auth <> cp_DoubleHelmet) then
                       exit;
                   storage.content[a, auth]:= buffer[z..l];
                   if a[1..7] = '.config'then
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
                                                          + ' bytes in ' + intToStr(storage.select_hive(a).count) + ' cells')
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
        'dump': if auth < cp_Plebes then
                begin
                    if buffer = '' then
                        storage.to_console('')
                    else
                        while z < l do
                            storage.to_console(ExtractSubstr(buffer, z, [' ']));
                    k
                end;
        'list': if auth < cp_Plebes then
                begin
                    writeln('==== Listing hives ====');
                    for y:= 0 to storage.Count-1 do
                        writeln(storage.select_hive(y).Name, ':  ',
                                kHive_ancestor(storage.Items[y]).count, ' items;  ',
                                kHive_ancestor(storage.Items[y]).SPermissions);
                    writeln('==== Done listing ', storage.Count, ' hives ====');
                    k
                end;
        'new': begin
                   s:= split(' ', buffer);
                   if s.count > 1 then
                   begin
                       if (auth < cp_Plebes) and (s.count > 2) then
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
                              if auth < cp_Plebes then
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
                      if auth < cp_Plebes then
                      begin
                          s:= split(' ', buffer);
                          if s.Count = 1 then
                          begin
                              if storage.del_hive(s[0]) then
                                  k
                          end
                          else
                              reply('Requires exactly one parameters: hive_name')
                      end
                  end;
        'rename': begin
                      if auth < cp_Plebes then
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
        'auth'  : case auth of
                      cp_Plebes      : reply('Pleb');
                      cp_Helmet      : reply('Helmet');
                      cp_DoubleHelmet: reply('Double helmet');
                  else
                      reply('How did you get this number?');
                  end
        else
            bot.say(message.channel, storage.content['aliases/' + command, cp_No_touch]);
    end
end;

function tMonopolyBot.doGrab(who: string): boolean;
begin

end;

procedure tMonopolyBot.doKarma(message: kIrcMessage);
var z   : integer = 3;
    l   : integer;
    k   : Int64   = 0;
    what: string  = '';
    why : string  = '';
    b   : string  = '';
    up  : boolean = false;
    x   : tStringList;
    isOK: kKeyValue;
begin
    l   := length(message.message);
    up  := message.message[1] = '+';
    what:= lowerCase(ExtractSubstr(message.message, z, [' ']));

    b:= storage.content['.karma.timeout/' + message.user.nick + '.' + what, cp_Helmet];
    if b <> '' then
    begin
        isOK:= tank2keyvalue(b);

        if isOK.key   = '' then
        isOK.key  := DateTimeToStr(IncDay(now, -1), DefaultFormatSettings);

        if isOK.value = '' then
        isOK.value:= DateTimeToStr(IncDay(now, -1), DefaultFormatSettings);

        if up then
        begin
            if SecondsBetween(now, StrToDateTime(isOK.key, DefaultFormatSettings)) < StrToIntDef(storage.content['.toyconfig/karma.up.timeout', cp_Helmet], 0) then
                exit
        end else
        begin
            if SecondsBetween(now, StrToDateTime(isOK.value, DefaultFormatSettings)) < StrToIntDef(storage.content['.toyconfig/karma.down.timeout', cp_Helmet], 0) then
                exit
        end
    end
    else
    begin
        isOK.key  := DateTimeToStr(IncDay(now, -1), DefaultFormatSettings);
        isOK.value:= DateTimeToStr(IncDay(now, -1), DefaultFormatSettings)
    end;

    if z < l then
        why:= message.message[z..l];

{    if (what = 'coffee') and not(up) then
    begin
        what:= 'tea';
        why := 'to spite ' + message.user.nick;
        up  := true
    end;}

    k:= StrToInt64Def(storage.content['karma/' + what, cp_Helmet], 0);
    if up then
    begin
        isOK.key:= DateTimeToStr(now);
        inc(k);
        b:= 'up'
    end
    else
    begin
        isOK.value:= DateTimeToStr(now);
        dec(k);
        b:= 'down'
    end;

    storage.content['.karma.timeout/' + message.user.nick + '.' + what, cp_Helmet]:= keyvalue2tanks(isOK);
    storage.content['karma/' + what, cp_Helmet]:= IntToStr(k);

    x:= split(#9, storage.content['karma.who.' + b + '/' + what, cp_Helmet]);
    x.Sorted:= true;
    x.Duplicates:= dupIgnore;
    x.Add(message.user.nick);
    storage.content['karma.who.' + b + '/' + what, cp_Helmet]:= join_stringList(#9, x);
    x.free;

    if why <> '' then
    begin
        x:= split(#9, storage.content['karma.why.' + b + '/' + what, cp_Helmet]);
        x.Sorted:= true;
        x.Duplicates:= dupIgnore;
        x.Add(why);
        storage.content['karma.why.' + b + '/' + what, cp_Helmet]:= join_stringList(#9, x);
        x.free
    end;

    bot.say(message.channel, 'Karma - ' + what + ': ' + intToStr(k))
end;

procedure tMonopolyBot.doCommand(message: kIrcMessage);
var cmd   : string  = '';
    pars  : string  = '';
    stuff : string  = '';
    stuff2: string  = '';
    z     : integer = 0;
    y     : integer = 0;
    l     : integer = 0;
    auth  : kRWModes;
begin
  { for authorization, we're assuming vhosts will be checked before being authorized
    by IRC staff and also the hack we call services is still running. }
    auth:= getAuthLevel(message);

    z:= pos(' ', message.message);
    if (z > 1) and (z < length(message.message)) then
    begin
        cmd := LowerCase(message.message[2..z-1]);
        pars:= message.message[z+1..length(message.message)];
        l   := length(pars)
    end else
        cmd:= LowerCase(Trim(message.message[2..length(message.message)]));

    z:= 1;
    case cmd of
        'join'   : if (auth < cp_Plebes) and (pars <> '') then
                   while z < l do
                   begin
                       stuff:= ExtractSubstr(pars, z, [' ']);
                       if not(stuff[1] in ['#', '&', '!', '.', '~']) then
                           stuff:= '#' + stuff;
                       bot.join(stuff)
                   end;
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
        ':q!'    : if auth < cp_Plebes then begin
                      if pars = '' then
                          bot.disconnect('Bye!')
                      else
                          bot.disconnect(pars);
                      mode:= bmStopped;
                  end;
        'restart': if auth < cp_Plebes then begin
                       if pars = '' then
                           bot.disconnect('Restarting')
                       else
                           bot.disconnect(pars);
                       mode:= bmRestarting;
                       storage.content['.config/reboot_channel', cp_No_touch]:= message.channel
                   end;
        'kick'   : if (auth < cp_Plebes) and (pars <> '') then begin
                       stuff:= ExtractSubstr(pars, z, [' ']);
                       bot.kick(stuff, pars[z..l]);
                   end;
        's',
        'say'    : begin if pars <> '' then
                       if (pars[1] in ['.','!','$', '~']) then begin
                           if auth = cp_Plebes then
                               exit
                           end;
                           bot.say(message.channel, pars);
                       end;
        'grab'   : if pars <> '' then
                   begin
                       if doGrab(pars) then
                           bot.say(message.channel, ':D')
                       else
                           bot.say(message.channel, ':(')
                   end;
        'do',
        'me'     : if pars <> '' then bot.sayAction(message.channel, pars);
        'invite' : bot.invite(ExtractSubstr(pars, z, [' ']), pars[z..l]);
        'r'      : if pars <> '' then bot.say(message.channel, reverse(pars));
        'rdo'    : if pars <> '' then bot.sayAction(message.channel, reverse(pars));
        'sayto'  : if (auth < cp_Plebes) and (pars <> '') then
                   begin
                       stuff:= ExtractSubstr(pars, z, [' ']);
                       bot.say(stuff, pars[z..l])
                   end;
        'doto'   : if (auth < cp_Plebes) and (pars <> '') then
                   begin
                       stuff:= ExtractSubstr(pars, z, [' ']);
                       bot.sayAction(stuff, pars[z..l])
                   end;
        'topic'  : if (auth < cp_Plebes) and (pars <> '') then
                       bot.setTopic(message.channel, pars);
        'o'      : if auth < cp_Plebes then
                   begin
                       if pars = '' then
                           bot.setMode(message.channel, '+o', message.user.nick)
                       else
                           bot.setMode(message.channel, '+o', pars)
                   end;
        '-o'      : if auth < cp_Plebes then
                    begin
                       if pars = '' then
                           bot.setMode(message.channel, '-o', message.user.nick)
                       else
                           bot.setMode(message.channel, '-o', pars)
                    end;
        'v'      : if auth < cp_Plebes then
                   begin
                       if pars = '' then
                           bot.setMode(message.channel, '+v', message.user.nick)
                       else
                           bot.setMode(message.channel, '+v', pars)
                   end;
        '-v'      : if auth < cp_Plebes then
                    begin
                       if pars = '' then
                           bot.setMode(message.channel, '-v', message.user.nick)
                       else
                           bot.setMode(message.channel, '-v', pars)
                    end;
        'nick'   : if (auth < cp_Plebes) and (pars <> '') then bot.nick(pars);
        'help'   : begin
                       if pars = '' then
                           bot.say(message.channel, storage.content['.help/.', cp_Plebes])
                       else
                           bot.say(message.channel, storage.content['.help/' + pars, cp_Plebes]);
                   end;
        'karma'  : if pars <> '' then
                   begin
                        stuff:= lowerCase(storage.content['karma/' + pars, cp_Plebes]);
                        if stuff <> '' then
                            bot.say(message.channel, 'Karma - ' + pars + ': ' + stuff)
                        else
                            bot.say(message.channel, 'No karma');
                   end;
        'who'    : if pars <> '' then
                   begin
                       stuff:= lowerCase(lowerCase(ExtractSubstr(pars, z, [' '])));
                       if ((stuff = 'up') or (stuff = 'down')) and (z < l) then
                       begin
                           stuff:= storage.content['karma.who.'+stuff+'/' + pars[z..l], cp_Plebes];
                           if stuff <> '' then
                               bot.say(message.channel, pars[z..l] + ': '
                                                     + join_stringList(', ', split(#9, stuff)))
                           else
                               bot.say(message.channel, 'Nobody');
                       end
                   end;
        'why'    : if pars <> '' then
                   begin
                       stuff:= lowerCase(ExtractSubstr(pars, z, [' ']));
                       if ((stuff = 'up') or (stuff = 'down')) and (z < l) then
                       begin
                           stuff:= storage.content['karma.why.'+stuff+'/' + pars[z..l], cp_Plebes];
                           if stuff <> '' then
                               bot.say(message.channel, pars[z..l] + ': '
                                                       + join_stringList(', ', split(#9, stuff)))
                           else
                               bot.say(message.channel, 'No reason');
                       end
                   end;
        'ident'   : begin
                    if auth = cp_DoubleHelmet then
                        bot.say('NickServ', 'identify '
                      + storage.content['.config/nickserv.user', cp_No_touch] + ' '
                      + storage.content['.config/nickserv.pass', cp_No_touch])
                    end
        else
            do_hive_command(cmd, pars, message, auth);
    end
end;

procedure tMonopolyBot.handleMessage(message: kIrcMessage);
var auth: boolean = false;
    l   : integer;
begin
    message.message:= stripSomeControls(message.message);
    l:= length(message.message);

    if (Pos(prefix, message.message) = 1) then
        doCommand(message)
    else
    if ((l > length(bot.me.nick)+1)
        and (Pos(bot.me.nick, message.message) = 1)
        and (message.message[length(bot.me.nick)+1] in [',',':'])) then
    begin
        message.message:= '_'+TrimLeft(message.message[length(bot.me.nick)+2..l]);
        doCommand(message)
    end

    else
    if (message.user.nick = 'exec') and (message.message = 'exec_test_sn_site_down') then begin
        if not pageIsUp('http://soylentnews.org/') then
            bot.sayAction('#Soylent', 'confirms "SoylentNews.org has been abducted by aliens!"')
        else
            bot.say('exec', 'nuh uh!')
    end
    else
    if ((message.message[1..2] = '++') or (message.message[1..2] = '--')) and (l > 2) then
        doKarma(message)
    else
        if length(message.message) > 5 then showTitles(message);

{    if storage.select_hive('.debug') <> nil then
        with kList_hive(storage.select_hive('.debug')) do
        begin
            if content.count > 0 then
                for l:= 0 to content.count-1 do
                    bot.say(storage.content['.config/channel',cp_Helmet], content.Strings[l]);
            clear
        end
}
end;

procedure tMonopolyBot.handleNotice(message: kIrcMessage);
begin
    if (message.user.user = 'NickServ') and (message.user.host = 'services.') then
    begin
        if TextPos('welcome', message.message) > 0 then
            bot.say(message.user.nick, 'identify '
                  + storage.content['.config/nickserv.user', cp_No_touch] + ' '
                  + storage.content['.config/nickserv.pass', cp_No_touch])
        else
        if TextPos('you are now identified', message.message) > 0 then
        begin
            if storage.select_hive('.channels').Count > 0 then bot.join(kList_hive(storage.select_hive('.channels')).content);
            writeln('Identified')
        end
    end
end;

procedure tMonopolyBot.handleKick(message: kIrcMessage);
begin
    bot.join(message.channel)
end;

procedure tMonopolyBot.handleConnect;
begin
    mode:= bmRunning;
    buttmagic(); // divine what our nick should be when connecting to bouncers that don't tell us
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

writeln('Checking options');
    // parse parameters
    if HasOption('h','help') then begin
        WriteHelp;
        Terminate;
        Exit;
    end;
{    if hasOption('hiveroot') then
        hive_root:= GetOptionValue('hiveroot')
    else  }
        hive_root:= '/home/toobee/monopoly.bot/hives/';

writeln('Checking for hive cluster in ', hive_root);
    storage:= kHive_cluster.Create(true);
    if not FileExists(hive_root) then
    begin
        writeln(stderr, 'MISSING HIVE CLUSTER, YO!');
        halt(-10000)
    end;
    storage.load(hive_root);
    url_title4.hive_cluster:= storage;
    urlstuff.storage:= storage;

    save_ticker:= now;

    bot        := kIRCclient.create;
    doConfig;

    try
        iCantStrings:= kList_hive(storage.select_hive('.icant')).content;
    except
        iCantStrings:= tStringList.Create;
    end;
    kList_hive(storage.select_hive('.channels')).content.Sorted    := true;
    kList_hive(storage.select_hive('.channels')).content.Duplicates:= dupIgnore;

    bot.OnKick     := @handleKick;
    bot.onConnect  := @handleConnect;
    bot.onMessage  := @handleMessage;
    bot.onNick     := @handleNick;
    bot.onNotice   := @handleNotice;
    bot.onSocket   := @handleSocket;
    bot.onInvite   := @handleInvite;
    bot.onJoin     := @handleJoin;
    bot.onPart     := @handlePart;

    bot.identString:= storage.content['.config/nickserv.user', cp_No_touch] + ' '
                    + storage.content['.config/nickserv.pass', cp_No_touch];

    if logFile <> '' then
        if not FileExists(logFile) then
            logger:= tFileStream.Create(logFile, fmCreate or fmOpenWrite)
        else
            logger:= tFileStream.Create(logFile, fmOpenWrite)
    else
        writeln('Empty log filename');

    try
writeln('Connecting');
        bot.connect(storage.content['.config/server.host', cp_No_touch]
                                   , strToIntDef(storage.content['.config/server.port', cp_No_touch], 6969));
//    else
//        bot.connect(storage.content['.config/server.host', cp_No_touch]
//                   ,strToInt(storage.content['.config/server.port', cp_No_touch])
//                   ,strToInt(storage.content['.config/server.socket', cp_No_touch]));
    mode:= bmStopped;

writeln('Waiting on server');
    while mode = bmStopped do begin // Why two loops? I don't recall. I think
        bot.doThings;               // it was so some flags could be set or something.
        sleep(69)                   // Whatever it was, it's not now.
    end;
writeln('Connected!');

buffer:= storage.content['.config/reboot_channel', cp_No_touch];
if buffer <> '' then
begin
    bot.say(buffer, 'k');
    storage.content['.config/reboot_channel', cp_No_touch]:= ''
end;


    while mode = bmRunning do
    begin
        bot.doThings;

        if MinutesBetween(now, save_ticker) >= save_interval then
        begin
            save_ticker:= now;
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
    StopOnException :=true
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
    new_pid    : integer;
begin
    Application:=tMonopolyBot.Create(nil);
    Application.Title:='Monopoly robot';
    Application.Run;
    Application.Free;

    if reboot then
    begin
        //new_pid:= FpFork;
//        if new_pid = 0 then
            FpExecv(paramStr(0), nil)
//        else
//        if new_pid > 0 then

    end
end.

