{ An IRC client object with events and stuff.
  License: WTFPL (see /copying)
}

unit tubeyIRC;

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils, lnet, kUtils, ircUserManager;

type
    kMessageFlags = set of (mfHighlight, mfAction);


    kChannel      = record
        name : string;
        users: tStringList;
    end;

    kIrcMessage   = record
        user    : kIrcUser;
        flags   : kMessageFlags;
        channel,
        message : string;
    end;

    kServerReply  = record
        code   : word;
        message: string;
    end;

    kMessageEvent = procedure(message: kIrcMessage) of object;
    kReplyEvent   = procedure(reply: kServerReply) of object;
    kSocketEvent  = procedure(message: string; stopProcessing: boolean = false) of object;
    kStringEvent  = procedure(message: string) of object;
    kEvent        = procedure of object;


    kIRCclient = class(TComponent)
      public
        me          : kIrcUser;       // Your user info
        channels    : tStringList;    // The channels you're in

        onNotice,
        onMessage,                   // Any private message
        onSend,                      // Not implemented yet
        onAction,
        onJoin,
        onPart,
        OnKick,
        onInvite,
        onTopic,
        OnBan,
        onNick,
        onUnban      :  kMessageEvent;
        onServerReply : kReplyEvent;  // For the billion different numeric replies
        onSocket      : kSocketEvent; // When anything goes over the socket
        onConnect     : kEvent;

        onPing        : kEvent;       // You are NOT required to assign these;
        onPong        : kEvent;       // they're just informative.
        onError       : kStringEvent;

        autoReconnect : boolean;

        haveIdentified: boolean;
        nickServNick  : string;
        identString   : string; { This should probably include the /msg NickServ
                                  because apparently it's not standardized plus
                                  the whole system is a hack anyway.

                                  But for now, you just need the password
                                  (and your nick if you're using a different one). }

        procedure       sayAction         (channel, message: string);
        procedure       say               (channel, message: string);
        procedure       writeString       (message: string);

        procedure       join              (channel: string);
        procedure       join              (channelList: tStringList);
        procedure       part              (channel: string; reason: string = '');
        procedure       kick              (channel, user: string; reason: string = '');
        procedure       ban               (channel, mask: string);
        procedure       unban             (channel, mask: string);
        procedure       invite            (channel, user: string);

        procedure       nick              (nick: string);

        procedure       setTopic          (channel, topic: string);
        procedure       setMode           (channel, mode, what: string);

        procedure       connect           (host   : string; port: word);
        procedure       disconnect        (message: string = '');

        function        escapeString      (message: string): string;
        function        unEscapeString    (message: string): string;

        constructor     create;
        destructor      destroy;

        procedure       doThings;
      public
        procedure       processServerReply(number: word; buffer: string);
        function        getSocket: longInt;
      private
        theSocket     : TLTcp;
        bufferIn      : string;
        bufferOut     : string;
        procedure       handleMessage     (message: string);
        procedure       handleError       (const msg: string; aSocket: TLSocket);
        procedure       processMessageBuffer;
        procedure       doReceive         (aSocket: tLSocket);
        procedure       doSend            (aSocket: tLSocket);
        procedure       connected         (aSocket: tLsocket);
        procedure       disconnected      (aSocket: tLsocket);
    end;



implementation

procedure kIRCclient.doThings;
begin
    theSocket.CallAction
end;


function kIRCclient.getSocket: longInt;
begin
    result:= theSocket.getRootSock;
end;

constructor kIRCclient.create;
begin
    inherited;
    theSocket             := tltcp.Create(self);
    theSocket.OnConnect   := @connected;
    theSocket.OnCanSend   := @doSend;
    theSocket.OnReceive   := @doReceive;
    theSocket.OnError     := @handleError;
    theSocket.OnDisconnect:= @Disconnected;
    me.nick               := 'kIRCuser';
    me.host               := 'host';
    me.user               := 'testbot';
    me.realName           := 'teste test';
//    theSocket.Session     := TLSession.Create(self);
    autoReconnect         := true;
    haveIdentified        := false;
    nickServNick          := 'NickServ';

    channels              := tStringList.Create;
    channels.Sorted       := true;
    channels.CaseSensitive:= false;
//    theSocket.Session.;
end;

destructor kIRCclient.destroy;
begin
    if theSocket <> nil then
        theSocket.Free;
    channels.Free;
    inherited
end;

procedure kIRCclient.nick(nick: string);
begin
    writeString('NICK ' + nick)
end;

procedure kIRCclient.invite(channel, user: string);
begin
    writeString('INVITE ' + user + ' ' + channel)
end;

procedure kIRCclient.say(channel, message: string);
begin
    writeString('PRIVMSG ' + channel + ' :' + message)
end;

procedure kIRCclient.sayAction(channel, message: string);
begin
    say(channel, #1'ACTION ' + message + #1)
end;

procedure kIRCclient.writeString(message: string);
var
    nope: boolean; // But we'll ignore it
begin
    if onSocket <> nil then onSocket(message, nope);
    AppendStr(bufferOut, message + #13#10);
    doSend   (theSocket.Iterator);
end;

procedure kIrcClient.handleError(const msg: string; aSocket: TLSocket);
var z: string;
begin
    z:= 'Err ['
      + aSocket.LocalAddress + ':'
      + intToStr(aSocket.LocalPort) + ' | '
      + aSocket.PeerAddress + ':'
      + intToStr(aSocket.PeerPort) + '] ';
    if onError <> nil then
        onError(z + msg)
    else
        writeln(stderr, z + msg)
end;

procedure kIRCclient.doSend(aSocket: tLSocket);
{ This is the place where we directly write to the lnet component.
  It's the handler for onCanSend for full buffers or whatever. }
var count: integer = 1;

begin
{ Yes, this is terribly inefficient. We should use a cirular buffer or something
  but we'll put that off and then get bored and abandon the whole thing.
  Anyway, delete() should only be called if we have net congestion or something
  where the whole buffer doesn't get sent so it should be okay. }

    while (length(bufferOut) > 0) and (count > 0) do begin
        if aSocket.Connected then
          count:= aSocket.SendMessage(bufferOut)
        else begin handleError('wtf?!',aSocket);halt(69)end; // Descriptive, huh

        if length(bufferOut) = count then
            bufferOut:= ''
        else
            delete(bufferOut, 1, count)
    end;
end;

procedure kIRCclient.handleMessage(message: string);
{ This is where we actually parse the messages and dole them out to event
  handlers. }
var s       : string;
    z       : dWord = 1;
    y       : dWord;
    giver,
    command,
    receiver,
    value   : string;
    uMessage: kIrcMessage;
    nope    : boolean = false;
begin
    if onSocket <> nil then      // Let the user spy on our activity. They can
        onSocket(message, nope); // just read or even handle all the processing
    if nope then exit;           // if they want.

    if message[1..4] =  'PING' then begin
        writeString('PONG' + message[5..length(message)]);
        if onPing <> nil then
            onPing;
        exit
    end;

    if message[z] = ':' then
        inc(z);
    y:= z;
    findNext(' ', message, y);
    inc(y);
    value:=scanByDelimiter(' ', message, y);
    if (length(value) > 0) and isNumeric(value) then begin
        processServerReply(strToInt(value), message);
        exit
    end;

    giver  := scanByDelimiter(' ', message, z);
    command:= scanByDelimiter(' ', message, z);
    if command = 'MODE' then begin
// TODO
        exit
    end;

    uMessage.user   := string2user(giver);
    uMessage.channel:= scanByDelimiter(' ', message, z);
    findNext(':', message, z);
    uMessage.message:= message[z+1..length(message)];

    if wordPresent(me.nick, uMessage.message) then
        uMessage.flags:= uMessage.flags + [mfHighlight];

    case command of
        'KICK'   : if OnKick <> nil then
                      onKick(uMessage);
        'PRIVMSG': if onMessage <> nil then
                      onMessage(uMessage);
        'JOIN'   : if onJoin <> nil then
                      onJoin(uMessage);
        'PART'   : if onPart <> nil then
                      onPart(uMessage);
        'TOPIC'  : if onTopic <> nil then
                      onTopic(uMessage);
        'INVITE' : if onInvite <> nil then
                      onInvite(uMessage);
        'NOTICE' : begin
                       if (uMessage.user.nick = nickServNick) and (identString <> '') and (not haveIdentified) then begin
                           say(nickServNick, 'identify ' + identString);
                           HaveIdentified:= true;
                           writeln('Identified');
                           join(channels);
                       end;
                       if onNotice <> nil then
                           onNotice(uMessage);
                   end;
        'NICK'   : begin
                       if uMessage.user.nick = me.nick then
                           me.nick:= uMessage.message;
                       if onNick <> nil then
                           onNick(uMessage);
                   end;
        'PONG'   : if onPong <> nil then // Does this exist? Or does it work like PING?
                      onPong;
    end
end;

procedure kIRCclient.processMessageBuffer;
{ This extracts IRC messages from the buffer and calls handleMessage for each
  whole message. }
var z   : dWord = 1;
    y   : dWord;
    crlf: set of char = [#10,#13];
begin
    while z < length(bufferIn) do begin
        y:= z;
        while not(bufferIn[z] in crlf) and (z <length(bufferIn)) do
            inc(z);
        if bufferIn[z] in crlf then begin
            handleMessage(bufferIn[y..z-1]);
            while (bufferIn[z] in crlf) and (z < length(bufferIn)) do
                inc(z);
        end
    end;
    if (bufferIn[length(bufferIn)] in crlf) and (z >= length(bufferIn)) then
        bufferIn:= ''
    else
        delete(bufferIn, 1, y-1)
end;

procedure kIRCclient.doReceive(aSocket: tLSocket);
var buffer: string;
    size  : integer;
begin
    size:= aSocket.GetMessage(buffer); // do we need to check the result?
    appendStr(bufferIn, buffer);
    processMessageBuffer
end;

procedure kIRCclient.connect(host: string; port: word);
begin
    if not theSocket.connect(host, port) then
        handleError('Err: Could not connect to host ('+host+':'+intToStr(port)
                   ,theSocket.Iterator);
end;

procedure kIrcclient.connected(aSocket:tLSocket);
begin
    writeString('NICK ' + me.nick);
    writeString('USER '
               +me.user + ' '
               +me.host + ' '
               +me.host + ' :'
               +me.realName);
    if onConnect <> nil then
        onConnect
end;

procedure kIRCclient.disconnected(aSocket: TLSocket);
begin
    if autoReconnect then
        connect(aSocket.PeerAddress, aSocket.PeerPort);

end;

procedure kIRCclient.disconnect(message: string);
begin
    if theSocket.Connected then begin
        autoReconnect:= false;
        writeString('QUIT :' + message);

        theSocket.Disconnect()
    end
end;

function kIrcClient.escapeString(message: string): string;
{ This is mainly for ctcp stuff }
var z   : dWord = 1;
    y   : dWord;
    bads: set of char = [#0, #10, #13, #20];
begin
    result:= ''; { Should be initialized already but this pleases the compiler. }
    while z < length(message) do begin
        y:= z;
        if message[z] in bads then
            while (message[z] in bads) and (z < length(message)) do begin
                case message[z] of
                    #0 : result:= result + #20'0';
                    #10: result:= result + #20'n';
                    #13: result:= result + #20'r';
                    #20: result:= result + #20#20
                end;
                inc(z);
            end
        else begin
            while (not(message[z] in bads)) and (z < length(message)) do
                inc(z);
            result:= result + message[y..z-1]
        end
    end
end;

function kIrcClient.unEscapeString(message: string): string;
{ Also for ctcp }
var z   : dWord = 1;
    y   : dWord;
    bads: set of char = [#0, #10, #13];
begin
    result:= '';
    while z < length(message) do begin
        y:= z;
        if message[z] in [#20] then
            while (message[z] in [#20]) and (z < length(message)) do begin
                inc(z);
                case message[z] of
                    '0': begin result:= result + #0; inc(z) end;
                    'n': begin result:= result + #10 end;
                    'r': begin result:= result + #13 end;
                    #20: begin result:= result + #20 end
                end;
                inc(z)
            end
        else begin
            while (not(message[z] in [#20])) and (z < length(message)) do
                inc(z);
            result:= result + message[y..z-1]
        end
    end
end;

procedure kIrcClient.join(channel: string);
var
    z: integer;
begin
//    if channels.Find(channel, z) then begin
        writeString('JOIN ' + channel);
//        channels.Add(channel);
//    end;
end;

procedure kIrcClient.join(channelList: tStringList);
var z: dWord;
begin
    for z:= 0 to channelList.Count-1 do
        join(channelList.Strings[z])
end;

procedure kIrcClient.part(channel: string; reason: string = '');
var
    z: integer;
begin
//    if channels.Find(channel, z) then begin
        writeString('PART ' + channel + ' :' + reason);
//        channels.Delete(z)
//    end
end;

procedure kIrcClient.kick(channel, user: string; reason: string = '');
begin
    writeString('KICK ' + channel + ' ' + user + ' ' + reason)
end;

procedure kIrcClient.ban(channel, mask: string);
begin
    setMode(channel, '+b', mask)
end;

procedure kIrcClient.unban(channel, mask: string);
begin
    setMode(channel, '-b', mask)
end;

procedure kIrcClient.setTopic(channel, topic: string);
begin
    writeString('TOPIC ' + channel + ' :' + topic)
end;

procedure kIrcClient.setMode(channel, mode, what: string);
begin
    writeString('MODE ' + channel + ' ' + mode + ' ' + what)
end;


procedure kIRCclient.processServerReply(number: word; buffer: string);
{ Most of these are commented to keep down the bloat because they're not
  being handled. }
var r: kServerReply;
begin
    if onServerReply <> nil then begin
        r.code   := number;
        r.message:= buffer;
        onServerReply(r)
    end;
    case number of
//        200: ; // RPL_TRACELINK       |
//        201: ; // RPL_TRACECONNECTING | "Try. "
//        202: ; // RPL_TRACEHANDSHAKE  | "H.S. "
//        203: ; // RPL_TRACEUNKNOWN    | "???? []"
//        204: ; // RPL_TRACEOPERATOR   | "Oper "
//        205: ; // RPL_TRACEUSER       | "User "
//        206: ; // RPL_TRACESERVER     | "Serv S C <nick!user|!>@<host|server>"
//        208: ; // RPL_TRACENEWTYPE    | " 0 "
//        212: ; // RPL_STATSCOMMANDS   | " "
//        213: ; // RPL_STATSCLINE      | "C * "
//        214: ; // RPL_STATSNLINE      | "N * "
//        215: ; // RPL_STATSILINE      | "I * "
//        216: ; // RPL_STATSKLINE      | "K * "
//        218: ; // RPL_STATSYLINE      | "Y "
//        219: ; // RPL_ENDOFSTATS      | " :End of /STATS report"
//        221: ; // RPL_UMODEIS         | ""
//        241: ; // RPL_STATSLINE       | "L * "
//        242: ; // RPL_STATSUPTIME     | ":Server Up %d days %d:%02d:%02d"
//        243: ; // RPL_STATSOLINE      | "O * "
//        244: ; // RPL_STATSHLINE      | "H * "
//        251: ; // RPLLUSERCLIENT      | _":There are users and invisible on servers"
//        252: ; // RPL_LUSEROP         | " :operator(s) online"
//        253: ; // RPL_USERUNKNOWN     | " :unknown connection(s)"
//        254: ; // RPL_LUSERCHANNELS   | " :channels formed"
//        255: ; // RPL_USERNAME        | ":I have clients and servers"
//        256: ; // RPLADMINME          | _" :Administrative info"
//        257: ; // RPL_ADMINLOC2       | ":"
//        258: ; // RPL_ADMINLOC2       | ":"
//        259: ; // RPL_ADMINEMAIL      | ":"
//        261: ; // RPL_TRACELOG        | _" "

//        302: ; // RPL_USERHOST        | USERHOST lists replies to query list ::= [`*'] `=' <'+'|'-`>
//        303: ; // RPL_ISON            | ISON lists replies to query list ":[ {}]"
//        305: ; // RPL_UNAWAY          | You are no longer away
//        306: ; // RPL_NOWAWAY         | You are now away
//        312: ; // RPL_WHOISSERVER     | " :"
//        313: ; // RPL_WHOISOPERATOR   | " :is an IRC operator"
//        314: ; // RPL_WHOWASUSER      | _" * :"
//        315: ; // RPL_ENDOFWHO        | " :End of /WHO list"
//        317: ; // RPL_WHOISIDLE       | " :seconds idle"
//        318: ; // RPL_ENDOFWHOIS      | " :End of /WHOIS list"
//        319: ; // RPL_WHOISCHANNELS   | " :{[@|+]}"
//        322: ; // RPL_LIST            | " <# visible> :"
//        323: ; // RPL_LISTEND         | ":End of /LIST"
//        331: ; // RPL_NOTOPIC         | " :No topic is set"
//        332: ; // RPL_TOPIC           | " :"
//        341: ; // RPLINVITING         | _" "
//        342: ; // RPLSUMMONING        | _" :Summoning user to IRC"
//        351: ; // RPLVERSION          | Server version details _". :"
//        352: ; // RPL_WHOREPLY        | <H|G>[*][@|+] : "
//        353: ; // RPLNAMEREPLY        | _" :[[@|+] [[@|+] [...]]]"
//        365: ; // RPL_ENDOFLINKS      | " :End of /LINKS list"
//        366: ; // RPL_ENDOFNAMES      | " :End of /NAMES list"
//        368: ; // RPL_ENDOFBANLIST    | " :End of channel ban list"
//        369: ; // RPL_ENDOFWHOWAS     | _"Channel :Users Name"
//        372: ; // RPL_MOTD            | ":- "
//        374: ; // RPL_ENDOFINFO       | ":End of /INFO list"
        { we'll do this onMessage to auth with NickServ before entering channels }
        376: if (nickServNick = '') and (channels.Count > 0) then join(channels); // RPL_ENDOFMOTD       | ":End of /MOTD command"
//        381: ; // RPLYOUREOPER        | _":You are now an IRC operator"
//        382: ; // RPLREHASHING        | _" :Rehashing"
//        391: ; // RPLTIME             | _" :<server local time>"
//        392: ; // RPLUSERSTART        | _":UserID Terminal Host"
//        393: ; // RPL_USERS           | ":%-8s %-9s %-8s"
//        394: ; // RPL_ENDOFUSERS      | ":End of users"
//        395: ; // RPL_NOUSERS         | ":Nobody logged in"
{ Errors }
//        401: ; // ERR_NOSUCHNICK      | " :No such nick/channel"
//        402: ; // ERRNOSUCHSERVER     | _" :No such server"
//        403: ; // ERRNOSUCHCHANNEL    | _" :No such channel"
//        404: ; // ERRCANNOTSENDTOCHAN | _" :Cannot send to channel"
//        405: ; // ERRTOOMANYCHANNELS  | _" :You have joined too many channels"
//        406: ; // ERRWASNOSUCHNICK    | _" :There was no such nickname"
//        407: ; // ERRTOOMANYTARGETS   | _" :Duplicate recipients. No message delivered"
//        409: ; // ERRNOORIGIN         | _":No origin specified"
//        411: ; // ERRNORECIPIENT      | _":No recipient given ()"
//        412: ; // ERR_NOTEXTTOSEND    | _":No text to send"
//        413: ; // RTT_NOTOPLEVEL      | " :No toplevel domain specified"
//        414: ; // ERR_WILDTOPLEVEL    | " :Wildcard in toplevel tomain"
//        421: ; // ERRUNKNOWNCOMMAND   | _" :Unknown command"
//        422: ; // ERRNOMOTD           | _":MOTD File is missing"
//        423: ; // ERRNOADMININFO      | _" :No administrative info available"
//        424: ; // ERRFILEERROR        | _":File error doing on "
//        431: ; // ERRNONICKNAMEGIVEN  | _":No nickname given"
//        432: ; // ERRONEOSNICKNAME    | _" :Erroneus nickname"
//        433: ; // ERRNICKNAMEINUSE    | _" :Nickname is already in use"
//        436: ; // ERRNICKCOLLISION    | _" :Nickname collision KILL"
//        441: ; // ERRUSERNOTINCHANNEL | _" :They aren't on that channel"
//        442: ; // ERRNOTONCHANNEL     | _" :You're not on that channel"
//        443: ; // ERRUSERONCHANNEL    | _" :is already on channel"
//        444: ; // ERRNOLOGIN          | _" :User not logged in"
//        445: ; // ERRSUMMONDISABLED   | _":SUMMON has been disabled"
//        446: ; // ERRUSERDISABLED     | _":USERS has been disabled"
//        451: ; // ERRNOTREGISTERED    | _":You have not registered"
//        461: ; // ERRNEEDMOREPARAMS   | _" :Not enough parameters"
//        462: ; // ERRALREADYREGISTERED| _":You may not register"
//        463: ; // ERRNOPERMFORHOST    | _":Your host isn't among the privileged"
//        464: ; // ERRPASSWDMISMATCH   | _":Password incorrect"
//        465: ; // ERRYOUREBANNEDCREEP | _":You are banned from this server"
//        467: ; // ERRKEYSET           | _" :Channel key already set"
//        471: ; // ERR_CHANNELISFULL   | " :Cannot join channel (+l)"
//        472: ; // ERR_UNKNOWNMODE     | " :is unknown mode char to me"
//        473: ; // ERR_INVITEONLYCHAN  | " :Cannot join channel (+i)"
//        474: ; // ERR_BANNEDFROMCHAN  | " :Cannot join channel (+b)"
//        475: ; // ERR_BADCHANNELKEY   | " :Cannot join channel (+k)"
//        481: ; // ERR_NOPRIVILEGES    | ":Permission Denied- You're not an IRC operator"
//        482: ; // ERRCHANOPRIVSNEEDED | _" :You're not a channel operator"
//        483: ; // ERRCANTKILLSERVER   | _":You cant kill a server!"
//        491: ; // ERRNOOPERHOST       | _":No O-lines for your host"
//        501: ; // ERRMODEUNKNOWNFLAG  | _":Unkown MODE flag"
//        502: ; // ERRUSERSDONTMATCH   | _":Cant change mode for other users"
    end
end;

end.

