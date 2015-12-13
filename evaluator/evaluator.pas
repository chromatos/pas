unit evaluator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, strutils, contnrs, dictionary;

type
  eFunction = class(exception);
  PEvaluator= ^kEvaluator;

  { Parameter stuff }
  p_metaParam = ^k_metaParam;

  k_metaParam = record
    parser: pEvaluator;
  end;

  k_param = (param_val, param_ref, param_nil);

  pStringItem = ^kStringItem;
  kStringItem = record
    value: string;
    what : k_param;
  end;


  { k_parameterList }

  k_parameterList = class
  private
    storage: TFPList;
    posish : integer;
    procedure Add_Replace(Index: integer; AValue: kStringItem);
    procedure   Add_ReplaceString(Index: integer; value: string);

    function DoCount: integer;inline;
  public
    function    Get(Index: integer): kStringItem;
    procedure   Add_Replace(Index: integer);

    function    GetString(Index: integer): string;
    function    GetNext: kStringItem;
    function    GetNextString: string;
    function    Add(value: kStringItem): integer;

    procedure   AddVal(value: string);
    procedure   AddVar(value: string);

    procedure   Del(Index: integer);

    procedure   clear;
    procedure   Rewind;

    function    the_end: boolean;

    function    cat: string;

    property    Count: integer read DoCount;
    property    Items[Index: integer]: kStringItem read Get write Add_Replace;
    property    Strings[Index: Integer]: String read GetString write Add_ReplaceString; default;
    constructor create;
    destructor  destroy;
  end;

  kfunction  = function (meta: p_metaParam; parameters: k_parameterList): string;
// We can blow this away in a bit:
  kfunctionO = function (meta: p_metaParam; parameters: k_parameterList): string of object;

  ksToken = (tk_none, tk_invalid, tk_lParen, tk_rParen, tk_identifier, tk_comma, tk_variable, tk_string,
             tk_equal, tk_notEqual, tk_greaterThan, tk_lessThan, tk_greatOrEqual, tk_lessOrEqual,
             tk_and, tk_or, tk_not, tk_xor);
  ksTokenSet = set of ksToken;

  kToken = record
    token_type: ksToken;
    value     : ansistring;
    depth     : integer;
    posish    : integer;
  end;

  tCharSet = set of char;

  kTokensList = array of kToken;


  { kfunctionDict }

  kfunctionDict = class
    namespace: string;
    storage: TFPHashList;

    function  Get(Index: string): kfunction; {$ifdef CCLASSESINLINE}inline;{$endif}
    procedure Put(Index: string; Item: kfunction); {$ifdef CCLASSESINLINE}inline;{$endif}

    function  Add(const AName: shortstring; Item: kfunction): integer;
    property  Items[Index: string]: kfunction read Get write Put; default;

    constructor create;
    destructor  destroy;

  end;

{ kEvaluator }

kEvaluator = class
  storage  : kDictionary_ancestor;
  functions: kfunctionDict;

  function evaluate(buffer: string): string;

  procedure initialize;
  constructor create;
private
  tokens: kTokensList;
  t_len : integer;
  posish: integer;

  meta_Params: p_metaParam;

  procedure parse(meta: p_metaParam; a_list: k_parameterList);
  function next_token: kToken;
  function prev_token: kToken;
  function curr_token: kToken;

  function next_peek : kToken;
  function prev_peek : kToken;

  function skip_token: boolean;
  function skip_prev : boolean;

  function end_of_depth(depth: integer): integer;
  function end_of_depth: integer;
  function end_of_tokens: boolean;

  function xeval(meta: p_metaParam; parameters: k_parameterList): string;
end;

procedure print_tokens(tokenList: kTokensList);


function ExtractQuoteStr(buffer: string; var position: longint): string;
function ExtractToken(buffer: string; var position: longint): kToken;

function scan(buffer: string): kTokensList;

implementation

{$i parameterlist.inc}
{$i scanner.inc}
{$i evaluator.inc}
{$i functiondict.inc}
end.
