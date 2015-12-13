// Stuff for evaluator.pas

{ k_parameterList }

function k_parameterList.DoCount: integer;
begin
  result:= Storage.Count
end;

procedure k_parameterList.Add_Replace(Index: integer; AValue: kStringItem);
begin
  if index < storage.count then
    kStringItem(storage.Items[Index]^):= AValue
  else Add(AValue)
end;

procedure k_parameterList.Add_ReplaceString(Index: integer; value: string);
var
  x: kStringItem;
begin
  x.value:= value;
  x.what:= param_val;
  Add_replace(Index, x)
end;

function k_parameterList.Get(Index: integer): kStringItem;
begin
  if index < storage.Count then
    result:= kStringItem(storage.Items[Index]^)
  else
    result.what:= param_nil
end;

procedure k_parameterList.Add_Replace(Index: integer);
begin

end;

function k_parameterList.GetString(Index: integer): string;
begin
  result:= Get(Index).value
end;

function k_parameterList.GetNext: kStringItem;
begin
  inc(posish);
  result:= Get(posish)
end;

function k_parameterList.GetNextString: string;
begin
  inc(posish);
  result:= GetString(posish)
end;

procedure k_parameterList.AddVal(value: string);
var
  z: kStringItem;
begin
  z.value:= value;
  z.what := param_val;

  Add(z)
end;

function k_parameterList.Add(value: kStringItem): integer;
var
  x: pStringItem;
begin
  new(x);
  x^:= value;
  result:= storage.Add(x);
end;

procedure k_parameterList.AddVar(value: string);
var
  z: kStringItem;
begin
  z.value:= value;
  z.what := param_ref;

  Add(z)
end;

procedure k_parameterList.Del(Index: integer);
begin
  if Index < storage.Count then
  begin
    Dispose(pStringItem(storage.Items[Index]));
    storage.Delete(Index)
  end
end;

procedure k_parameterList.clear;
var
  z: integer;
begin
    for z:= 0 to storage.count-1 do
      Dispose(pStringItem(Storage.Items[z]));
  storage.Clear;
  Rewind;
end;

procedure k_parameterList.Rewind;
begin
  posish:= 0
end;

function k_parameterList.the_end: boolean;
begin
  result:= posish >= storage.count
end;

function k_parameterList.cat: string;
var
  z: integer;
begin
  result:= '';

  if storage.count > 0 then
    for z:= 0 to storage.count-1 do
      result+= GetString(z);
end;

constructor k_parameterList.create;
begin
  inherited;
  storage:= TFPList.Create;
  Rewind
end;

destructor k_parameterList.destroy;
begin
  clear;
  storage.Free
end;
