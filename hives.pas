{ A hashlist-based key/value string storage box.

  Each hive is stored to its own text file for easy offline editing and so we don't
  have to rewrite the entire thing to disk every time something changes.
  Actually, hives are flagged as dirty buffers and they get written periodically.

  The root node is a hashlist and then each hive under it is either another hashlist
  (for key/value) or a stringlist (for series).

  License: wtfpl (See 'copying' file or the Internet)
}

unit hives;

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils, contnrs;

type
    kRWModes = (wm_No_touch, // don't let strangers touch this
                wm_Helmet,   // 'special' people, like admins
                wm_Pleebs);  // anyone can poke this

    kCellPermissions = record
        r,
        w: kRWModes
    end;

    kCellProperties = set of (cellProp_dirty);
    kCellType       = (ct_None, ct_StringList, ct_Hashlist);

    kResult         = (kr_fine, kr_exists, kr_not_exists, kr_wtf);



    kHive_ancestor = class(TFPHashObject)
        permissions        : kCellPermissions;
        cell_type          : kCellType;
        cell_properties    : kCellProperties;

        property  items[index: string]: string;

        procedure add(index: string; aValue: string);virtual;abstract;
        procedure del(index: string);virtual;abstract;

        function  getItem(index: string): string;virtual;abstract;
        procedure setItem(index: string; aValue: string);virtual;abstract;

        function  to_stream: string;virtual;abstract;
        procedure from_stream(aStream: string);virtual;abstract;
    end;

    kHash_hive = class(kHive_ancestor)
        content: TFPStringHashTable;

        function  getItem(index: string): string;virtual;
        procedure setItem(index: string; aValue: string);virtual;

        procedure add(index: string; aValue: string);virtual;
        procedure del(index: string);virtual;

        function  to_stream: string;virtual;
        procedure from_stream(aStream: string);virtual;
      private
        buffer: string; // because the stupid iterator has to be a method and they
                        // don't just give a numerically-indexed accessor
        procedure iteratee(Item: String; const Key: string; var Continue: Boolean);
    end;

    kStringList_hive = class(kHive_ancestor)
        content: tStringList;

        function  getItem(index: string): string;virtual;
        procedure setItem(index: string; aValue: string);virtual;

        procedure add(index: string; aValue: string);virtual;
        procedure del(index: string);virtual;

        function  to_stream: string;virtual;
        procedure from_stream(aStream: string);virtual;
    end;


    kHive_cluster = class(TFPHashObjectList)
      public
        theDirectory: string;

        function  add_list_hive(name: string; permissions: kCellPermissions): boolean;
        function  add_hash_hive(name: string; permissions: kCellPermissions): boolean;
        function  del_hive     (name: string): boolean;

        procedure load         (path: string);
        procedure save;

      private
        dirty: boolean;
    end;

    eHive_error = class(Exception);

implementation
uses strutils, sha1, kUtils, tanks;

function kHive_cluster.add_list_hive(name: string; permissions: kCellPermissions): boolean;
var hive: kStringList_hive;
begin
    try
       hive                := kStringList_hive.Create(self, name);
       hive.content        := tStringList.Create;
       hive.cell_type      := ct_StringList;
       hive.permissions    := permissions;
       hive.cell_properties:= [];
       dirty               := true
    except
        on EDuplicate do result:= false;
    end
end;

function kHive_cluster.add_hash_hive(name: string; permissions: kCellPermissions): boolean;
var hive: kHash_hive;
begin
    try
       hive                := kHash_hive.Create(self, name);
       hive.content        := TFPStringHashTable.Create;
       hive.cell_type      := ct_Hashlist;
       hive.permissions    := permissions;
       hive.cell_properties:= [];
       dirty               := true
    except
        on EDuplicate do result:= false;
    end
end;


function kHive_cluster.del_hive(name: string): boolean;
var aHive: kHive_ancestor;
begin
    dirty:= true;
    aHive:= kHive_ancestor(Find(name));
    aHive.free;
//    Delete(FindIndexOf(name));
end;


procedure kHive_cluster.load(path: string);
var z      : integer;
    y      : integer;
    x      : integer;
    buffer : string;
    hives  : tStringList;
    aHive  : kHive_ancestor;
    h_name : string;
    h_type : string;
begin
    theDirectory:= path;
    buffer:= file2string(ConcatPaths([path, 'root.hive']));

    if buffer = '' then begin // It's either empty or non-existant. Either way
        exit;                 // doesn't matter but we should probably raise an
    end;                      // exception to that.

    hives:= detank2list(detank(buffer));

    for z:= 0 to hives.Count - 1 do
    begin
        y:= Pos(':', hives.Strings[z]);
        h_name:= hives.Strings[z][1..y-1];
        h_type:= hives.Strings[z][y+1..length(hives.Strings[z])];
        if h_name = '' then
            raise eHive_error.Create('Empty hive name')
        else if h_type = '' then
            raise eHive_error.Create('Empty hive class');

        case h_type of
            'hashlist'  : aHive:= kHash_hive.Create(self, h_name);
            'stringlist': aHive:= kStringList_hive.Create(self, h_name);
        end;

        buffer:= file2string(ConcatPaths([theDirectory, h_name + '.hive']));
        if buffer <> '' then
            aHive.from_stream(buffer)
        else
            raise eHive_error.Create('Empty hive stream: ' + h_name);
    end

end;

procedure kHive_cluster.save;
var z     : dWord;
    buffer: string = '';
begin
  { Write out any modified hives }
    for z:= 0 to Count - 1 do
        if cellProp_dirty in kHive_ancestor(items[z]).cell_properties then
        begin
            case items[z].ClassName of
                'kHash_hive'      : buffer:= 'hashlist';
                'kStringList_hive': buffer:= 'stringlist';
            end;
            string2File(ConcatPaths([theDirectory, NameOfIndex(z) + '.hive']), buffer + kHive_ancestor(items[z]).to_stream)
        end;


  { Write index if modified }
    if dirty then begin
        for z:= 0 to Count - 1 do
            buffer+= tank(kHive_ancestor(items[z]).Name, []);

        string2File(ConcatPaths([theDirectory, 'root.hive']), tank(buffer, [so_sha1]))
    end
end;


{ kStringList_hive }

procedure kStringList_hive.from_stream(aStream: string);
begin
    content.Clear;
    content.AddStrings(detank2list(aStream))
end;

function kStringList_hive.to_stream: string;
var z     : integer;
    buffer: string;
begin
    for z:= 0 to content.count - 1 do
        buffer+= tank(content.Strings[z], []);
    result:= tank(buffer, [so_md5])
end;

function kStringList_hive.getItem(index: string): string;
begin
    if string_is_numeric(index) then
        result:= content.Strings[strToInt(index)]
    else
        result:= ''
end;

procedure kStringList_hive.setItem(index: string; aValue: string);
begin
    if string_is_numeric(index) then
        content.strings[StrToInt(index)]:= aValue
end;

procedure kStringList_hive.add(index: string; aValue: string);
begin
    if (index <> '') and string_is_numeric(index) then
        content.Insert(StrToInt(index), aValue)
    else
        content.Add(aValue)
end;

procedure kStringList_hive.del(index: string);
begin
    if string_is_numeric(index) then
        content.Delete(strToInt(index))
end;

{ kHash_hive }

procedure kHash_hive.from_stream(aStream: string);
var z    : integer;
    y    : integer;
    itemz: tStringList;
    item : string;
    key,
    value: string;

begin
    itemz:= detank2list(aStream);
    if z > 0 then
        for z:= 0 to itemz.count - 1 do begin
            item := detank(itemz[z]);
            y    := Pos(#30, item);
            key  := item[1..y-1];
            value:= item[y+1..length(item)];
            content.Add(key, value)
        end
end;

function kHash_hive.to_stream: string;
var z     : dWord;
begin
    for z:= 0 to content.Count-1 do
        content.Iterate(@iteratee);
    result:= tank(buffer, [so_sha1]);
end;

procedure kHash_hive.iteratee(Item: String; const Key: string; var Continue: Boolean);
begin
    buffer  += tank(key + #30 + item, []);
    Continue:= true
end;

function kHash_hive.getItem(index: string): string;
begin
    result:= content.Items[index]
end;

procedure kHash_hive.setItem(index: string; aValue: string);
begin
    content.Items[index]:= aValue
end;

procedure kHash_hive.add(index: string; aValue: string);
begin
    content.Add(index, aValue)
end;

procedure kHash_hive.del(index: string);
begin
    content.Delete(index)
end;


end.

