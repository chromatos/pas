{ This was going to hold all the junk for irc users but now it's all going
  into the hive cluster so for now this is just a place to hold a record

  License: wtfpl (See 'copying' file or the Internet)
}


unit ircUserManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;


type
    kIrcUser = record
        nick,
        user,
        host,
        realName: string;
    end;

    function string2user(buffer: string): kIrcUser;
    function user2string(user: kIrcUser): string;

implementation
uses
  strutils;

function string2user(buffer: string): kIrcUser;
var z: longInt = 1;
begin
    with string2user do begin
        nick:= ExtractSubstr(buffer, z, ['!']);
        user:= ExtractSubstr(buffer, z, ['@']);
        host:= buffer[z..length(buffer)]
    end
end;

function user2string(user: kIrcUser): string;
begin
    with user do begin
        user2string:= nick + '!' + user + '@' + host
    end
end;


end.

