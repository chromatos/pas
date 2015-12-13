// Stuff got evaluator unit

var
//Shit's hackish but I need a way to shove in a function type that's not of object:
  eval_pointer: kfunctionO;
  xStorage   : kDictionary_ancestor;
  xFunctions : kfunctionDict;
function eval(meta: p_metaParam; parameters: k_parameterList): string;
begin
  result:= eval_pointer(meta, parameters);
end;


function kEvaluator.xeval(meta: p_metaParam; parameters: k_parameterList): string;
var
  z: integer;
  x: kEvaluator;
begin
  result:= '';
  if parameters.Count > 0 then
  begin
    x:= kEvaluator.create;
    x.storage  := xStorage;
    x.functions:= xFunctions;
    x.meta_Params:= meta_Params;

    for z:= 0 to parameters.Count-1 do
      result+= x.evaluate(parameters[z]);
    x.free
  end
end;

function cat_stringlist(astringlist: TStringList): string;
var
  z: integer;
begin
  result:= '';
  if astringlist.count > 0 then
    for z:= 0 to astringlist.count-1 do
      result+= astringlist[z]
end;

procedure print_tokens(tokenList: kTokensList);
var
  z: integer = 0;
  l: integer;
  labels: array[ksToken] of string = ('none', 'invalid', '(', ')', 'identifier', ',', 'variable', 'string',
                                      '=', '!=', '>', '<', '>=', '<=', '&', '|', '!', '^');
begin
  l:= length(tokenList);
  if l > 0 then
  begin
    dec(l);
    for z:= 0 to high(tokenList) do
      begin
        writeln(tokenList[z].posish,#9,
                labels[tokenList[z].token_type], #9,
                tokenList[z].depth, #9,
                '[',tokenList[z].value,']')
      end;

  end
  else
    writeln('Empty token list');

end;

{ kEvaluator }

function kEvaluator.evaluate(buffer: string): string;
var
  z: integer = 0;
  x: k_parameterList;
begin
  posish:= -1;
//  result:= '';
  setLength(tokens, 0);
  tokens:= scan(buffer);
   t_len:= length(tokens)-1;
       x:= k_parameterList.create;
           parse(meta_Params, x);
  result:= x.cat;
  x.free
end;

procedure kEvaluator.parse(meta: p_metaParam; a_list: k_parameterList);
var
  a,b      : integer;
  depth    : integer;
  current  : kToken;
  func_name: string;
  buffer   : string;
  p_result : k_parameterList;
begin
  //a_list:= tstringlist.create;
  func_name:= '';
  buffer   := '';
  while not end_of_tokens do
  begin
    current:= next_token;
    case current.token_type of
      tk_none:    ;
      tk_invalid: ;// toss an error
      tk_lParen: begin
                   p_result:= k_parameterList.create;
                   parse(meta, p_result);
                   if func_name <> '' then
                   begin
                     buffer+= functions[func_name](meta, p_result);
                     func_name:= ''
                   end
                   else
                     buffer+= p_result.cat;

                   p_result.free
                 end;
      tk_rParen: begin
                   if buffer <> '' then
                     a_list.AddVal(buffer);
                   //skip_token;
                   exit
                 end;
      tk_identifier: begin
                       func_name:= current.value;
                       //if next_peek.token_type <> tk_lParen then
                         ;// toss an error

                     end;
      tk_comma: if buffer <> '' then
                begin;
                  a_list.AddVal(buffer);
                  buffer:= ''
                end;
      tk_variable: begin
                     current:= next_token;
                     if current.token_type = tk_identifier then
                     begin
                       {if (prev_peek.token_type in [tk_lParen, tk_comma]) and (next_peek.token_type in [tk_rParen, tk_comma]) then
                         a_list.AddVar(current.value)
                       else} writeln('VALUE: ', current.value);
                       writeln('BUFFER: ', buffer);
                         buffer+= storage[current.value]
                     end
                     else
                       ; // toss an error
                   end;
      tk_string: buffer+= current.value;
    end;
  end;
  //depth:= current.depth;
  if buffer <> '' then
    a_list.AddVal(buffer)
end;

function kEvaluator.next_token: kToken;
begin
  if posish < t_len then
  begin
    inc(posish);
    result:= tokens[posish];
  end
  else
    ;// err
end;

function kEvaluator.prev_token: kToken;
begin
  if posish > 0 then
  begin
    dec(posish);
    result:= tokens[posish]
  end
  else
    ;// err
end;

function kEvaluator.curr_token: kToken;
begin
  result:= tokens[posish]
end;

function kEvaluator.next_peek: kToken;
begin
  if posish < t_len then
    result:= tokens[posish+1]
end;

function kEvaluator.prev_peek: kToken;
begin
  if posish > 0 then
    result:= tokens[posish-1]
end;

function kEvaluator.skip_token: boolean;
begin
  if posish < t_len then
    inc(posish)
end;

function kEvaluator.skip_prev: boolean;
begin
  if posish > 0 then
    dec(posish)
end;

function kEvaluator.end_of_depth(depth: integer): integer;
var
  z: integer;
begin
  z:= posish+1;
  while (z < t_len) and (tokens[z].depth >= depth) do
    inc(z);
    if (z < t_len) and (tokens[z].depth < depth) then
      dec(z);
    result:= z - posish
end;

function kEvaluator.end_of_depth: integer;
begin
  result:= end_of_depth(tokens[posish].depth)
end;

function kEvaluator.end_of_tokens: boolean;
begin
  result:= posish = t_len
end;

procedure kEvaluator.initialize;
begin
  if assigned(functions) then
  begin
    xFunctions:= functions;
    functions.Add('eval', @eval)
  end
  else
    raise EInvalidContainer.Create('Function list not set');
  if assigned(storage) then
    xStorage:= storage
  else
    raise EInvalidContainer.Create('Variable storage container not set')
end;

constructor kEvaluator.create;
begin
  inherited;
  storage  := nil;
  functions:= nil;
  eval_pointer:=@xeval
end;
