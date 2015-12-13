// Stuff for evaluator unit
{ kfunctionDict }

function kfunctionDict.Add(const AName: shortstring; Item: kfunction): integer;
begin
    result:= storage.Add(AName, Item)
end;

constructor kfunctionDict.create;
begin
    inherited;
    storage:= TFPHashList.Create
end;

destructor kfunctionDict.destroy;
begin
    inherited
end;

function kfunctionDict.Get(Index: string): kfunction;
var
  y: pointer;
begin
    y:= storage.Find(Index);
    if y <> nil then
      result:= kfunction(y)
    else
      ;//raise eFunction.create()
end;

procedure kfunctionDict.Put(Index: string; Item: kfunction);
var
    z: pointer;
begin
    z:= storage.Find(index);
    z:= Item
end;
