{ License: wtfpl; see /copying or the Internet }

{ Laz project for testing evaluation code bits }

program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, strutils, dictionary, {evalParser, parameterStuff,} evaluator, parameters, functiondict,
unit_strings, kUtils, as_tree;

var
  z: longint;
  b: string = 'avg()';
//  e: kEvaluator;
  f: kfunction_set;
  d: kDictionary;
  params: kParameterList;
  a: kSeries;

begin
d:= kDictionary.create;
f:= kfunction_set.create;
f.add('str', unit_strings.kUnit_strings.create);

writeln('Buffer: ', b);
writeln;

eval('reverse(10 + 84) test(1+0) aFunction(0), 12', d, f);


//print_tokens(scan(b));
{
e          := kEvaluator.create;
e.functions:= kfunctiondict.create; // All the functions in the world
e.storage  := kdictionary.create;   // Variable storage

e.initialize;
mathUnit.load(e.functions);
stringUnit.load(e.functions);

// Set up some variables:
e.storage['a']      := '45';
e.storage['donkey'] := 'house';
e.storage['free']   := 'hat';
e.storage['plus']   := '1';
e.storage['cloud']  := 'internet';
e.storage['chicken']:= 'wing';
e.storage['ding']   := 'dong';

// Fire off test:
writeln(e.evaluate(b));
writeln(e.evaluate('("I put my music and videos in my cloud. I love my cloud!")'));
}
writeln('done');

end.
