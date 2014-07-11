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

// I'm putting this off for now:
{    kIrcUsers = class(tFpList)
        function  add(user: kIrcUser): dWord;
        function  add(user: string)  : dWord;
        procedure del(user: string);
        procedure del(index: dWord);

        function  find(user: string): dWord;
    end;
}

    function string2user(buffer: string): kIrcUser;
    function user2string(user: kIrcUser): string;

implementation
uses
    kUtils;
function string2user(buffer: string): kIrcUser;
var z: dWord = 1;
begin
    with string2user do begin
        nick:= scanByDelimiter('!', buffer, z);
        user:= scanByDelimiter('@', buffer, z);
        host:= buffer[z..length(buffer)]
    end
end;

function user2string(user: kIrcUser): string;
begin
    with user do begin
        user2string:= nick + '!' + user + '@' + host
    end
end;
{
function kIrcUsers.add(user: kIrcUser): dWord;
begin
    kIrcUser(Items[Add(pointer(new(kIrcUser)))]^):= user;
end;

function kIrcUsers.add(user: string) : dWord;
begin
    result:= find(user);
    if result = high(dWord) then
        kIrcUser(Items[Add(pointer(new(kIrcUser)))]^).user:= user;
end;

procedure kIrcUsers.del(user: string);
begin

end;

procedure kIrcUsers.del(index: dWord);
begin

end;

function kIrcUsers.find(user: string): dWord;
begin

end;
}

end.

