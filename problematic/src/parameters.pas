{ License: wtfpl; see /copying or the Internet }

{ Classes for handling parameter passing within the evaluator }

unit parameters;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, dictionary;

const

  err_param = ' needs moar parameters!';

type

  k_paramType = (param_nil, param_val, param_ref, param_err);

  { kSeries }

  kSeries = class
  private
    function  get_item(index: integer): string;
    procedure set_item(index: integer; AValue: string);

  public
    store_type: k_paramType;
    Values    : TStringList;

    function  count: integer;

    function  has_content: boolean;
    procedure set_ref  (name: string);
    procedure set_value(value: string);
    procedure set_err  (value: string);
    procedure append   (value: string);

    procedure set_strings   (strings: TStrings);
    procedure append_strings(series: TStrings);

    procedure set_series   (series: kSeries);
    procedure append_series(series: kSeries);

    procedure del(index: integer);
    procedure clear;

    property  items[index: integer]: string read get_item write set_item;default;
    constructor create;
    destructor  destroy;
  end;


  { kParameterList }

  kParameterList = class
  private
    function fcount: integer;inline;
  public
    storage  : TFPList;
    variables: kDictionary_ancestor;

    function  new: integer;

    procedure add(parameter: kSeries);
    procedure add(parameter: string);
    procedure add(parameter: TStrings);

    function  merge(offset: integer): kSeries;
    function  merge2string(offset: integer): string;

    procedure resolve_vars(offset: integer);

    function  get(index: integer): kSeries;

    procedure del(index: integer);
    procedure clear;
    property  count: integer read fcount;
    property  items[index: integer]: kseries read get;default;

    constructor create;
    destructor  destroy;
  end;

implementation
uses
  kUtils;

{ kParameterList }

function kParameterList.fcount: integer;inline;
begin
  result:= storage.Count
end;

function kParameterList.new: integer;
var
  z: kSeries;
begin
  z:= kSeries.create;
  result:= storage.Add(z)
end;

procedure kParameterList.add(parameter: kSeries);
begin
  storage.Add(parameter)
end;

procedure kParameterList.add(parameter: string);
var
  z: integer;
begin
  z:= new;
  kSeries(storage.Items[z]).set_value(parameter)
end;

procedure kParameterList.add(parameter: TStrings);
var
  z: integer;
begin
  z:= new;
  kSeries(storage.Items[z]).set_strings(parameter)
end;

function kParameterList.merge(offset: integer): kSeries;
var
  z: integer;
begin
  result:= kSeries.create;
  if offset < storage.Count then
    for z:= offset to storage.Count-1 do
    begin
      result.append_series(get(offset));
      del(offset)
    end
end;

function kParameterList.merge2string(offset: integer): string;
var
  z: integer;
begin
  result:= '';
  if offset < storage.Count then
    for z:= offset to storage.Count-1 do
    begin
      result+= strings2string(items[offset].Values);
      del(offset)
    end
end;

procedure kParameterList.resolve_vars(offset: integer);
var
  z: integer;
begin
  if offset < storage.Count then
  begin
    for z:= offset to storage.Count-1 do
      if items[z].store_type = param_ref then
        items[z].set_value(variables[items[z].get_item(0)])
  end;
end;

function kParameterList.get(index: integer): kSeries;
begin
  if index < storage.Count then
    result:= kSeries(storage[index])
  else
    result:= nil
end;

procedure kParameterList.del(index: integer);
begin
  if index < storage.Count then
    storage.Delete(index)
end;

procedure kParameterList.clear;
var
  z: integer;
begin
  if storage.Count > 0 then
  begin
    for z:= 0 to storage.Count-1 do
      kSeries(storage[z]).Free;
    storage.Clear
  end;
end;

constructor kParameterList.create;
begin
  inherited;
  storage:= TFPList.Create;
end;

destructor kParameterList.destroy;
begin
  clear;
  storage.Free
end;

{ kSeries }

function kSeries.get_item(index: integer): string;
begin
  result:= Values[index]
end;

procedure kSeries.set_item(index: integer; AValue: string);
begin
  if index < Values.Count then
    values[index]:= AValue
end;

function kSeries.count: integer;
begin
  result:= Values.Count
end;

function kSeries.has_content: boolean;
begin
  result:= store_type in [param_ref, param_val]
end;

procedure kSeries.set_ref(name: string);
begin
  store_type:= param_ref;
  Values.Clear;
  Values.Add(name)
end;

procedure kSeries.set_value(value: string);
begin
  store_type:= param_val;
  Values.Text:= value
end;

procedure kSeries.set_err(value: string);
begin
  store_type:= param_err;
  values.Text:= value
end;

procedure kSeries.append(value: string);
begin
  store_type:= param_val;
  values.Append(value)
end;

procedure kSeries.set_strings(strings: TStrings);
begin
  values.Clear;
  store_type:= param_val;
  values.AddStrings(strings)
end;

procedure kSeries.append_strings(series: TStrings);
begin
  store_type:= param_val;
  values.AddStrings(series)
end;

procedure kSeries.set_series(series: kSeries);
begin
  store_type:= series.store_type;
  set_strings(series.Values)
end;

procedure kSeries.append_series(series: kSeries);
begin
  append_strings(series.Values)
end;

procedure kSeries.del(index: integer);
begin
  if store_type = param_val then
    Values.Delete(index)
end;

procedure kSeries.clear;
begin
  Values.Clear;
  store_type:= param_nil
end;

constructor kSeries.create;
begin
  inherited;
  store_type:= param_nil;
  values:= TStringList.Create
end;

destructor kSeries.destroy;
begin
  values.Free;
  inherited
end;

end.
