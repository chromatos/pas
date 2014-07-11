program termbot;

{$mode objfpc}{$H+}

uses
    {$IFDEF UNIX}{$IFDEF UseCThreads}
    cthreads,
    {$ENDIF}{$ENDIF}
    Classes, SysUtils, CustApp, process, tubeyIRC, kUtils;

type

  { tTermBot }

    tTermBot = class(TCustomApplication)
      protected
        procedure   DoRun; override;
      public
        constructor Create          (TheOwner: TComponent); override;
        destructor  Destroy; override;
        procedure   WriteHelp; virtual;

        procedure   handleMessage   (message: kIrcMessage);
        procedure   handleSockOutput(message: string; x: boolean);
        procedure   handleConnect;

      private
        workingDir : string;
        keepRunning: boolean;
        ircc       : kIRCclient;
        proc       : tProcess;
    end;

{ tTermBot }

procedure tTermBot.handleSockOutput(message: string; x: boolean);
begin
    writeln('--> ', message);
    x:= false
end;

procedure tTermBot.handleConnect;
begin
    writeln('Connected!');
    keepRunning:= true
end;

procedure tTermBot.handleMessage(message: kIrcMessage);
var buffer    : string;
    parameters: tStringList;
    command   : string;
    posish    : dWord = 1;
    exitstat  : integer;
begin
    writeln(message.user.nick, ': ', message.message);
    if (message.user.user = '~chromas') and (message.message = ':q!') then
    begin
        ircc.say('#shell', 'Okay');
        keepRunning:= false
    end
    else if message.message[1..3] = 'cd ' then
        workingDir:= message.message[4..length(message.message)]
    else begin
        parameters:= tStringList.create;
        buffer    := message.message + #10;
        command   := scanByDelimiter(' ', message.message, posish);
        ircc.say('#shell', 'Cmd: ' + command);

        if posish < length(message.message) then begin
            ircc.say('#shell', 'Params: ' + message.message[posish..length(message.message)]);
            parameters:= split(' ', message.message[posish..length(message.message)]);
            writeln(message.message[posish..length(message.message)]);
        end;

        proc.Executable:= command;
        proc.Parameters:= parameters;

        try
            proc.Execute;

            while proc.Active do
                sleep(69);
            proc.output.ReadBuffer(buffer, posish);

            if buffer <> '' then begin
                parameters:= split(#10, buffer);
                for posish:= 0 to parameters.Count-1 do
                    ircc.say('#shell', parameters.Strings[posish]);
            end;
        except
            ircc.say('#shell', 'Command not found');
        end;
    end
end;


procedure tTermBot.DoRun;
var ErrorMsg: String;
    buffer  : string;
begin
  // quick check parameters
    ErrorMsg:=CheckOptions('h','help');
    if ErrorMsg<>'' then begin
        ShowException(Exception.Create(ErrorMsg));
        Terminate;
        Exit;
    end;

  // parse parameters
    if HasOption('h','help') then begin
        WriteHelp;
        Terminate;
        Exit;
    end;

  try

    proc        := tProcess.Create(nil);
    proc.Options:= [poUsePipes];

    ircc:= kIRCclient.create;
    ircc.me.nick  :='shellbot';
    ircc.me.host  :='0::1';
    ircc.me.user  :='chromas';

    ircc.channels.Add('#shell');

    ircc.onSocket :=@handleSockOutput;
    ircc.onMessage:=@handleMessage;
    ircc.onConnect:=@handleConnect;
    ircc.connect('irc.sylnt.us', 6667);

    writeln('Waiting on server');

    while not keepRunning do begin // Waiting for onConnect event
        ircc.doThings;
        sleep(69)
    end;

    while keepRunning do begin // main loop. In Lazarus, lnet uses the Laz events
        ircc.doThings;         // but here we have to call the eventer all the time
        sleep(69)
    end;

    ircc.say('#shell', 'Bye!');


    ircc.doThings;
    finally

    ircc.disconnect;
    ircc.Free;
    proc.free;

    Terminate
    end;
end;

constructor tTermBot.Create(TheOwner: TComponent);
begin
    inherited Create(TheOwner);
    StopOnException:=True;
end;

destructor tTermBot.Destroy;
begin
    inherited Destroy
end;

procedure tTermBot.WriteHelp;
begin
    { add your help code here }
    writeln('Usage: ',ExeName,' -h');
end;

var Application: tTermBot;
begin
    Application:=tTermBot.Create(nil);
    Application.Title:='Shell Robot';
    Application.Run;
    Application.Free;
end.

