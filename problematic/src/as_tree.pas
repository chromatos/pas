{ License: wtfpl; see /copying or the Internet }

{ Provides a node class for creating abstract syntax trees }
unit as_tree;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs;

type

  ksToken = (tk_invalid, tk_nop, tk_lParen, tk_rParen, tk_identifier, tk_variable, tk_value,
             tk_function, tk_if, tk_equal, tk_notEqual, tk_greaterThan, tk_lessThan, tk_greatOrEqual,
             tk_lessOrEqual, tk_and, tk_nand, tk_or, tk_nor, tk_xor, tk_not,
             tk_plus, tk_minus, tk_divide, tk_mult, tk_mod, tk_comma, tk_end, tk_begin);

  ksTokenSet = set of ksToken;

  kNode_str_array = array[ksToken] of string;


const
  ksTokenOpSet: set of ksToken = [tk_equal..tk_comma];

type
  { k_as_node }

  k_as_node = class
  private
    function  get_child(index: integer): k_as_node;
    procedure set_child(index: integer; AValue: k_as_node);
  public
    storage: TFPList;

    node_type: ksToken;
    value    : string;

    parent   : k_as_node;

    mbp,
    posish   : integer;

    current_pos: integer;

    procedure add   (aNode: k_as_node);
    function  new: k_as_node;
    function  new   (aNode_type: ksToken; aValue: string): k_as_node;
    procedure insert(aNode: k_as_node; index: integer);

    procedure del   (index: integer);
    function  remove(index: integer): k_as_node;
    procedure clear;

    property  children[index: integer]: k_as_node read get_child write set_child;default;

    procedure print(indent: integer = 0);

    function  current: k_as_node;
    function  peek(offset: integer = 1): k_as_node;
    function  next: k_as_node;
    function  prev: k_as_node;

    constructor create;
    destructor  destroy;
  end;

  procedure reparent(aNode, newNode: k_as_node);

implementation
uses strutils, kUtils;

procedure reparent(aNode, newNode: k_as_node);
var
  x: k_as_node;
begin
  x      := aNode;
  aNode  := newNode;
  newNode:= x;

  aNode.parent:= x.parent;
  newNode.parent:= aNode
end;

{ k_as_node }

function k_as_node.get_child(index: integer): k_as_node;
begin
  if (index >= 0) and (index < storage.Count) then
    Result:= k_as_node(storage.Items[index])
  else
    result:= k_as_node(storage.Items[storage.count-1])
end;

procedure k_as_node.set_child(index: integer; AValue: k_as_node);
begin
  if index < storage.Count then
  begin
    k_as_node(storage.Items[index]).free;
    storage.Items[index]:= AValue
  end
  else
    add(AValue)
end;

procedure k_as_node.add(aNode: k_as_node);
begin
  storage.Add(aNode)
end;

function k_as_node.new: k_as_node;
begin
  result:= k_as_node.create;
  result.parent:= self;
  add(result)
end;

function k_as_node.new(aNode_type: ksToken; aValue: string): k_as_node;
begin
  result:= new;
  result.node_type:= aNode_type;
  result.value:= aValue
end;

procedure k_as_node.insert(aNode: k_as_node; index: integer);
begin
  storage.Insert(index, aNode)
end;

procedure k_as_node.del(index: integer);
begin
  children[index].Free;
  storage.Delete(index)
end;

function k_as_node.remove(index: integer): k_as_node;
begin
  if (index >= 0) and (index < storage.Count) then
  begin
    result:= children[index];
    storage.Delete(index);
  end;
end;

procedure k_as_node.clear;
var
  z: integer;
begin
  if storage.Count > 0 then
    for z:= 0 to storage.Count-1 do
      children[z].Free;
  storage.Clear
end;

procedure k_as_node.print(indent: integer);
var
  z: integer;
begin
  if storage.Count > 0 then
  begin
    for z:= 0 to storage.Count-1 do
    begin
      writeln(DupeString('-', indent*2),'{', children[z].node_type, '}'#9, {, IfThen(z < storage.Count-1, '├', '└'), '╴'} children[z].value);
      children[z].print(indent+1);
    end;
  end;
end;

function k_as_node.current: k_as_node;
begin
  result:= children[current_pos]
end;

function k_as_node.peek(offset: integer = 1): k_as_node;
begin
  result:= children[current_pos+offset]
end;

function k_as_node.next: k_as_node;
begin
  inc(current_pos);
  result:= children[current_pos]
end;

function k_as_node.prev: k_as_node;
begin
  dec(current_pos);
  result:= children[current_pos]
end;

constructor k_as_node.create;
begin
  inherited;
  node_type:= tk_nop;
  storage  := TFPList.Create;
  posish   := 0
end;

destructor k_as_node.destroy;
begin
  clear;
  FreeAndNil(storage);
  inherited
end;

end.

