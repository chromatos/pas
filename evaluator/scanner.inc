// Stuff for evaluator unit

function ExtractUp2delimiter(const S: string; var Pos: Integer; const Delims: TSysCharSet): string;
var
  i,l: Integer;

begin
  i:=Pos;
  l:=Length(S);
  while (i<=l) and not (S[i] in Delims) do
    inc(i);
  Result:=Copy(S,Pos,i-Pos);
  Pos:=i;
end;


procedure SkipSubStr(buffer: string; aSet: tCharSet; var position: longint);
var
  l: longint;
begin
  l:= length(buffer);
  while (position < l) and (buffer[position] in aSet) do
    inc(position)
end;

function hex2string(buffer: string): string;
var
  l,
  z: integer;
  b: string;
begin
result:= buffer
{  l:= length(buffer);

  if odd(l) then
    b:= '0' + buffer
  else
    b:= buffer;

  z:= 1;
  while (z+1 < l) do
  begin
    result+= char(dec2hex(b[z..z+1]));
    inc(z, 2)
  end; }
end;

function unescape(buffer: string): string;
var
  l,
  m,
  z: integer;
begin
  l:= length(buffer);
  z:= 1;
  result:= '';
  while z < l do
  begin
    result+= ExtractSubstr(buffer, z, ['\']);
    if z < l-1 then
    begin
      inc(z);
      case buffer[z] of
        'a': result+= #7;
        'b': result+= #8;
        'f': result+= #12;
        'n': result+= #10;
        'r': result+= #13;
        't': result+= #9;
        'v': result+= #11;
        'x': begin
               inc(z);
               m:= z;
               while (z < l) and (buffer[z] in ['0'..'9','A'..'F','a'..'f']) do
                 inc(z);
               if z-1 > m then
                   result:= hex2String(buffer[m..z-1]);
             end
      end
    end
  end
end;

function ExtractQuoteStr(buffer: string; var position: longint): string;
var
  l: longint;
  s: longint;
  d: boolean = false;
begin
  l:= length(buffer);

  //if buffer[position] = '"' then
    s:= position+1;

  while (position < l) and (not d) do
  begin
    inc(position);
    if buffer[position] in ['"'] then
      begin
        d:= true
      end
    else
    if buffer[position] in ['\'] then
      inc(position)
  end;
  if d and (position > s) then
    result:= buffer[s..position-1];
  inc(position);
end;

function extract_number(buffer: string; var position: longint): string;
var
  l: longInt;
  y: longint;
begin
  l:= length(buffer);
  y:= position;
  if buffer[position] in ['-'] then
    inc(position);
  if (position + 2 < l) and (buffer[position+1] in ['b', 'x']) then
  begin
    inc(position);
    if (buffer[position] = 'x') then
    begin
      inc(position);
      while (position < l) and (buffer[position] in ['0'..'9','A'..'F','a'..'f']) do
        inc(position);
    end
    else
    if (buffer[position] = 'b') then
    begin
      inc(position);
      while (position < l) and (buffer[position] in ['0', '1']) do
        inc(position)
    end;
  end
  else
    while (position < l) and (buffer[position] in ['0'..'9']) do
      inc(position);
  result:= buffer[y..position-1]
end;

function ExtractToken(buffer: string; var position: longint): kToken;
var
  l: longint;

begin
  l:= length(buffer);

  SkipSubStr(buffer, [#0..#32], position);
  if position > l then
    exit;
  result.posish:= position;

  case buffer[position] of
    ',': begin
           result.token_type:= tk_comma;
           result.value:= '';
         end;
    '(': begin
           result.token_type:= tk_lParen;
           result.value:= '';
         end;
    ')': begin
           result.token_type:= tk_rParen;
           result.value:= '';
         end;
    '"': begin
           result.token_type:= tk_string;
           result.value     := ExtractQuoteStr(buffer, position);
         end;
    '$': begin
           result.token_type:= tk_variable;
           result.value:= '';
         end;
    '!': begin
           if buffer[position+1] = '=' then
             result.token_type:= tk_notEqual
           else
             result.token_type:= tk_not;
           result.value:= '';
         end;
    '=': begin
           result.token_type:= tk_equal;
           result.value:= ''
         end;
    '>': begin
           if buffer[position+1] = '=' then
             result.token_type:= tk_greatOrEqual
         end;
    '-',
    '0'..
    '9': begin
           result.token_type:= tk_string;
           result.value:= extract_number(buffer, position)
         end
    else
    begin
      result.token_type:=tk_identifier;
      result.value     := ExtractUp2delimiter(buffer, position, [' ', '"','''',',', '(',')','$']);
    end
  end;

  if (result.token_type <> tk_identifier) and (result.token_type <> tk_string) then
    inc(position);
end;

function scan(buffer: string): kTokensList;
var
  p: integer = 1;
  z: integer = 0;
  l: integer;
  a: integer = 0;
begin
  setLength(result, 64);
  l:= length(buffer);

  while p < l do
  begin
    if z = length(result) then
      setLength(result, z+16);

    result[z]:= ExtractToken(buffer, p);
    case result[z].token_type of
      tk_string: result[z].value:= {unescape}(result[z].value);
      tk_lParen: begin
                   inc(a);
                   result[z].depth:= a
                 end;
      tk_rParen: begin
                   result[z].depth:= a;
                   dec(a)
                 end;
    end;
    inc(z)
  end;
  setLength(result, z)
end;
