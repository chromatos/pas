{ License: wtfpl; see /copying or the Internet }

{ The main evaluation unit, which exposes the eval() function. }

unit evaluator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, strutils, contnrs, dictionary, functiondict, parameters, as_tree;

type
  eFunction = class(exception);


function eval(buffer: string; storage: kDictionary_ancestor; functions: kfunction_set): string;

implementation
uses
  scanner;

{$i evaluator.inc}


procedure fold(root: k_as_node; offset: integer);
var
  z: integer;
  procedure fold_parens;
  begin
     root.del(z);
     fold(root, z);
     root.del(z+1);
  end;

  procedure fold_function;
  begin
     root[z].node_type:= tk_function;
     if (z < root.storage.Count-1) and (root[z+1].node_type = tk_lParen) then
     begin
       inc(z);
       fold_parens;
       dec(z);
       root[z].add(root[z+1]);
       root.remove(z+1)
     end
  end;

begin
  z:= offset;

  while z < root.storage.Count do
  begin
    while z < root.storage.Count do
      case root[z].node_type of
        tk_lParen: begin
                     fold_parens;
                     {if (z > 0) and (root[z-1].node_type = tk_function) then
                     begin
                       root[z-1].add(root[z]);
                       root.remove(z)
                     end;}                    
                     inc(z)
                   end;
        tk_rParen: exit;
        tk_identifier: fold_function;
        tk_variable: begin
                       root[z].value:= root[z+1].value;
                       root.del(z+1)
                     end;
        tk_if: begin
                 inc(z);
                 fold_parens;
                 //dec(z);
                 root[z-1].add(root[z]);
                 root.remove(z);
                 //inc(z)
               end;
        tk_equal..tk_comma: begin
                      // The left side is always 'done', so we can set it into the left side of the operator:
                        if (z > 0) then
                          root[z].add(root[z-1]);

                        if (root[z+1].node_type = tk_lParen) then
                        begin
                          inc(z);
                          fold_parens;
                          dec(z)
                        end else
                        if (z < root.storage.Count-1) and (root[z+1].node_type = tk_identifier) then
                          begin inc(z);fold_function;dec(z) end;

                        // Descend if the next operator precedes the current one:
                        if (root[z+2].node_type in ksTokenOpSet) and (root[z+2].mbp > root[z].mbp) then
                          fold(root, z+2);


                        // Set the right side into the current operator. It's either an identifier or
                        // a preceding operator with children:
                        if z < root.storage.Count then
                          root[z].add(root[z+1]);

                        // Remove the left-side operand, moving the current operator to the left:
                        if z > 0 then
                          root.remove(z-1);;

                        // which makes [z] the right-hand operand:
                        if z < root.storage.Count then
                          root.remove(z);

                      end;
      else
        inc(z)
      end

  end
end;

function descend(aNode: k_as_node): kSeries;
  function do_math(xNode: k_as_node): kSeries;
  var
    z: integer;
    y: float = 0;
    l: integer;
  begin
    result:= kSeries.create;
    l:= xNode.storage.Count;
    if l > 0 then
      z:= StrToFloatDef(descend(xnode[0]), 0);
    if l > 1 then
      case xNode.node_type of
        tk_plus  : for z:= 1 to l-1 do y+= StrToFloatDef(descend(xNode[z]), 0);
        tk_minus : for z:= 1 to l-1 do y-= StrToFloatDef(descend(xNode[z]), 0);
        tk_mult  : for z:= 1 to l-1 do y*= StrToFloatDef(descend(xNode[z]), 0);
        tk_divide: for z:= 1 to l-1 do y/= StrToFloatDef(descend(xNode[z]), 0);
      end;
    result.append(FloatToStr(y))
  end;

  function do_gate(xNode: k_as_node): kseries;
  var
    z: integer;
    l: integer;
    y: boolean = false;
  begin
    l:= xNode.storage.Count;
    if l > 0 then
      y:= descend(xNode[0]) = ;
  end;

var
  z: integer;
  y: integer = 0;
  x: TStrings;
  b: integer;
begin
  result:= kSeries.create;

  if (aNode.node_type = tk_value) then
  begin
      result.append(aNode.value);
  end else
  if aNode.storage.Count > 0 then
  begin
    case aNode.node_type of
      tk_function: begin result.append('FUNCTION TEST'); y:= 69;end;
      tk_comma: result.append('COMMA TEST');
      tk_plus..
      tk_mult: result.append(do_math(aNode));
    else begin
    y:= StrToIntDef(descend(aNode[0]), 0);

    if aNode.storage.Count > 1 then
    for z:= 1 to aNode.storage.Count-1 do
      begin
        b:= StrToIntDef(descend(aNode[z]), 0);
        writeln('b: ', b);
          case aNode.node_type of
            tk_plus  : y+= b;
            tk_minus : y-= b;
            tk_mult  : y*= b;
            tk_divide: y:= y div b;

//            tk_value : y:= b;
          else begin
            result+= aNode[z].value;
            writeln('UNHANDLED NODE ', aNode[z].node_type);
          end;
        end;
      end;
    result+= IntToStr(y);
  end;
    end;
  end;
end;

function eval(buffer: string; storage: kDictionary_ancestor; functions: kfunction_set): string;
var
  z: k_as_node;
begin
  writeln('buffer: [', buffer, ']');

  writeln(#9'SCANNING:');
  z:= scan(buffer);
  writeln(#9'== TOKENS ==');
  z.print;

  writeln('Token count: ', z.storage.Count);
  writeln(#9'== Folding tree ==');

  //while not(z.next.node_type in ksTokenOpSet) do;

  fold(z, 0);

writeln(#9'== AST == [', z.storage.Count, ']');

  z.print;

  writeln;
  writeln('RESULT: ', descend(z), ' <--');


  z.free
end;

end.

