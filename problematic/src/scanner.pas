{ License: wtfpl; see /copying or the Internet }

{ Code scanner/lexer. Eats substrings and poops tokens (tree nodes) }

unit scanner;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, as_tree;

function ExtractToken(buffer: string; var position: longint): k_as_node;
function scan(buffer: string): k_as_node;


implementation
uses
  kUtils;

function ExtractToken(buffer: string; var position: longint): k_as_node;
var
  l: longint;

begin
  l:= length(buffer);
  result:= k_as_node.create;
  SkipSubStr(buffer, [#0..#32], position);

  if position > l then
  begin
    result.node_type:= tk_nop;
    exit
  end;
  result.posish:= position;
  result.mbp   := 0;
  result.value := '';

  case buffer[position] of
    ',': begin
           result.node_type:= tk_comma;
           result.mbp:= 10
         end;
    '(': begin
           result.node_type:= tk_lParen;
           result.mbp:= high(integer)
         end;
    ')': begin
           result.node_type:= tk_rParen;
           result.mbp:= low(integer)
         end;
    '"': begin
           result.node_type:= tk_value;
           result.value     := ExtractQuoteStr(buffer, position);
         end;
    '$': begin
           result.node_type:= tk_variable;

         end;
    '!': begin
           inc(position);
           case buffer[position+1] of
             '=': begin
                    Result.node_type:= tk_notEqual;
                    Result.mbp:= 50
                  end;
             '&': begin
                    Result.node_type:= tk_nand;
                    Result.mbp:= 40
                  end;
             '|': begin
                    Result.node_type:= tk_nor;
                    Result.mbp:= 30
                  end
           else
           begin
             result.node_type:= tk_not;
             dec(position)
           end
           end
         end;
    '|': begin
           result.node_type:= tk_or;
           result.mbp:= 20
         end;
    '^': begin
           if buffer[position+1] = '|' then
           begin
             Result.node_type:= tk_xor;
             result.mbp:= 30
           end
         end;
    '=': begin
           result.node_type:= tk_equal;
           result.mbp:= 50
         end;
    '>': begin
           if buffer[position+1] = '=' then
             result.node_type:= tk_greatOrEqual
           else
             result.node_type:= tk_greaterThan;
           result.mbp:= 60
         end;
    '<': begin
           if buffer[position+1] = '=' then
             result.node_type:= tk_lessOrEqual
           else
             result.node_type:= tk_lessThan;
           result.mbp:= 60
         end;
    '&': begin
           result.node_type:= tk_and;
           result.mbp:= 40
         end;
    '+': begin
           result.node_type:= tk_plus;
           result.mbp:= 70
         end;
    '-': begin
           result.node_type:= tk_minus;
           result.mbp:= 70
         end;
    '*': begin
           result.node_type:= tk_mult;
           result.mbp:= 80
         end;
    '/': begin
           result.node_type:= tk_divide;
           result.mbp:= 80
         end;
    '%': begin
           result.node_type:= tk_mod;
           result.mbp:= 80
         end;
    '0'..
    '9': begin
           result.node_type:= tk_value;
           result.value:= extract_number(buffer, position)
         end
    else
    begin
      result.node_type:=tk_identifier;
      result.value    := ExtractUp2delimiter(buffer, position, [' ', '"','''',',', '(',')','$']);
    end
  end;

  if (result.node_type <> tk_identifier) and (result.node_type <> tk_value) then
    inc(position);
end;

function scan(buffer: string): k_as_node;
var
  p: integer = 1;
  y: k_as_node;
  l: integer;
  a: integer = 0;
begin
  result:= k_as_node.create;
  l:=length(buffer);

  while p <= l do
  begin
    y:= ExtractToken(buffer, p);
    {case y.node_type of
      //tk_value: y.value:= unescape(y.value);
      tk_lParen: begin
                   inc(a);
                   y.depth:= a
                 end;
      tk_rParen: begin
                   y.depth:= a;
                   dec(a)
                 end;
    end;}
    result.Add(y)
  end;
  y:= k_as_node.create;
  y.node_type:= tk_end;
  result.Add(y)
end;

end.
