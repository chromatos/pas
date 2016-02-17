{ License: wtfpl; see /copying or the Internet }

{ eval unit for math functions }

unit unit_math;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, functiondict, parameters;

type

  { kUnit_strings }

  kUnit_strings = class(kfunction_list)
    function sum      (params: kParameterList): kSeries;
    function avg      (params: kParameterList): kSeries;
    function median   (params: kParameterList): kSeries;
    function mode     (params: kParameterList): kSeries;
    function xdiv     (params: kParameterList): kSeries;
    function mult     (params: kParameterList): kSeries;
    function sub      (params: kParameterList): kSeries;
    function min      (params: kParameterList): kSeries;
    function max      (params: kParameterList): kSeries;
    function cubicmean(params: kParameterList): kSeries;

    constructor create;
  end;
implementation

{ kUnit_strings }

function kUnit_strings.sum(params: kParameterList): kSeries;
begin

end;

function kUnit_strings.avg(params: kParameterList): kSeries;
begin

end;

function kUnit_strings.median(params: kParameterList): kSeries;
begin

end;

function kUnit_strings.mode(params: kParameterList): kSeries;
begin

end;

function kUnit_strings.xdiv(params: kParameterList): kSeries;
begin

end;

function kUnit_strings.mult(params: kParameterList): kSeries;
begin

end;

function kUnit_strings.sub(params: kParameterList): kSeries;
begin

end;

function kUnit_strings.min(params: kParameterList): kSeries;
begin

end;

function kUnit_strings.max(params: kParameterList): kSeries;
begin

end;

function kUnit_strings.cubicmean(params: kParameterList): kSeries;
begin

end;

constructor kUnit_strings.create;
begin
  inherited;
  Add('sum'      , @sum);
  Add('avg'      , @avg);
  Add('median'   , @median);
  Add('mode'     , @mode);
  Add('div'      , @xdiv);
  Add('mult'     , @mult);
  Add('sub'      , @sub);
  Add('min'      , @min);
  Add('max'      , @max);
  Add('cubicmean', @cubicmean);
end;

end.

