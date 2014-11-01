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



    { kHive_ancestor }

    kHive_ancestor = class(TFPHashObject)
      private
        permissions            : kCellPermissions;
        cell_type              : kCellType;
        cell_properties        : kCellProperties;

        function    getCount   : integer;virtual;abstract;
      protected
        function    getItem    (index: string): string;virtual;abstract;
        procedure   setItem    (index: string; aValue: string);virtual;abstract;
        function    getRandom  : string;virtual;abstract;
      public
        constructor Create     (HashObjectList:TFPHashObjectList;const s:shortstring);
      public
        procedure   add        (index: string; aValue: string);virtual;abstract;
        procedure   del        (index: string);virtual;abstract;
        function    to_stream  : string;virtual;abstract;
        procedure   from_stream(aStream: string);virtual;abstract;
      public
        property    items[index: string]: string read getItem write setItem; default;
        property    count      : integer read getCount;
    end;

    kHash_hive = class(kHive_ancestor)
        content: TFPStringHashTable;

        function  getItem    (index: string): string;override;
        procedure setItem    (index: string; aValue: string);override;

        procedure add        (index: string; aValue: string);override;
        procedure del        (index: string);override;

        function  to_stream  : string;override;
        procedure from_stream(aStream: string);override;
      protected
        function  getRandom  : string;override;
      private
        buffer: string; // because the stupid iterator has to be a method and they
                        // don't just give a numerically-indexed accessor
        procedure iteratee   (Item: String; const Key: string; var Continue: Boolean);
        function  getCount   : integer;override;
    end;

    kStringList_hive = class(kHive_ancestor)
        content: tStringList;

        function  getItem    (index: string): string;override;
        procedure setItem    (index: string; aValue: string);override;

        procedure add        (index: string; aValue: string);override;
        procedure del        (index: string);override;

        function  to_stream  : string;override;
        procedure from_stream(aStream: string);override;
      protected
        function  getRandom  : string;override;
      private
        function  getCount   : integer;override;
    end;


    kHive_cluster = class(TFPHashObjectList)
      public
        theDirectory: string;

        function  add_list_hive(name: string; permissions: kCellPermissions): kStringList_hive;
        function  add_hash_hive(name: string; permissions: kCellPermissions): kHash_hive;
        function  del_hive     (name: string): boolean;

        procedure load         (path: string);
        procedure save         (path: string);

      private
        dirty: boolean;
    end;

    eHive_error = class(Exception);

implementation
uses strutils, sha1, kUtils, tanks;

{ kHive_ancestor }

constructor kHive_ancestor.Create(HashObjectList:TFPHashObjectList;const s:shortstring);
begin
    inherited;
    cell_properties:= [];
    permissions.r  := wm_No_touch;
    permissions.w  := wm_No_touch;
end;


{ kHive_cluster }

function kHive_cluster.add_list_hive(name: string; permissions: kCellPermissions): kStringList_hive;
begin
    try
       result:= kStringList_hive.Create(self, name);
       result.content    := tStringList.Create;
       result.cell_type  := ct_StringList;
       result.permissions:= permissions;
       dirty             := true;
    except
        on EDuplicate do result:= nil
    end
end;

function kHive_cluster.add_hash_hive(name: string; permissions: kCellPermissions): kHash_hive;
begin
    try
       result            := kHash_hive.Create(self, name);
       result.content    := TFPStringHashTable.Create;
       result.cell_type  := ct_Hashlist;
       result.permissions:= permissions;
       dirty             := true;
    except
        on EDuplicate do result:= nil
    end
end;


function kHive_cluster.del_hive(name: string): boolean;
var aHive: kHive_ancestor;
begin
    dirty:= true;
    aHive:= kHive_ancestor(Find(name));
    aHive.free;
    DeleteFile(ConcatPaths([theDirectory, name+'.hive']))
end;


procedure kHive_cluster.load(path: string);
var z     : integer;
    y     : integer;
    x     : integer;
    buffer: string;
    hives : tStringList;
    aHive : kHive_ancestor;
    perms : kCellPermissions;
    h_name: string;
    h_type: string;
begin
    theDirectory:= path;
    buffer      := file2string(ConcatPaths([path, 'root.hive']));

    if buffer = '' then begin // It's either empty or non-existant. Either way
        exit;                 // doesn't matter but we should probably raise an
    end;                      // exception to that.

    hives:= detank2list(detank(buffer));

    for z:= 0 to hives.Count - 1 do
    begin
        y     := Pos(':', hives.Strings[z]);
        h_name:= hives.Strings[z][1..y-1];
        h_type:= hives.Strings[z][y+1..length(hives.Strings[z])];
        if h_name = '' then
            raise eHive_error.Create('Empty hive name')
        else if h_type = '' then
            raise eHive_error.Create('Empty hive class');

        case h_type of
            'keyvalue': aHive:= add_hash_hive(h_name, perms);
            'list'    : aHive:= add_list_hive(h_name, perms);
            else
                raise eHive_error.Create('Undefined hive class: ' + h_type);
        end;

        buffer:= file2string(ConcatPaths([path, h_name + '.hive']));

        if buffer <> '' then
            aHive.from_stream(buffer)
        else
            raise eHive_error.Create('Empty hive stream: ' + h_name);
    end;
    dirty:= false
end;

procedure kHive_cluster.save(path: string);
var z     : dWord;
    buffer: string = '';
    h_type: string;
begin
  { Write out any modified hives }
    for z:= 0 to Count - 1 do
        if cellProp_dirty in kHive_ancestor(items[z]).cell_properties then
            string2File(ConcatPaths([path, NameOfIndex(z) + '.hive']), kHive_ancestor(items[z]).to_stream);

  { Write index if modified }
    if dirty then begin
        for z:= 0 to Count - 1 do
        begin
            case items[z].ClassName of
                'kHash_hive'      : h_type:= 'keyvalue';
                'kStringList_hive': h_type:= 'list';
            end;
            buffer+= tank(kHive_ancestor(items[z]).Name + ':' + h_type, []);
        end;

        string2File(ConcatPaths([path, 'root.hive']), tank(buffer, [so_sha1]));
        dirty:= false
    end
end;


{ kStringList_hive }

procedure kStringList_hive.from_stream(aStream: string);
begin
    if content = nil then
        content:= tStringList.Create;
    content.Clear;
    content.AddStrings(detank2list(detank(aStream)));

    Exclude(cell_properties, cellProp_dirty);
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
var z: integer;
begin
    if string_is_numeric(index) then begin
        z:= strToInt(index);
        if z < content.Count then
            result:= content.Strings[z]
    end
    else
        result:= ''
end;

procedure kStringList_hive.setItem(index: string; aValue: string);
var z: integer;
begin
    Include(cell_properties, cellProp_dirty);
    if string_is_numeric(index) then begin
        z:= strToInt(index);
        if z < content.Count then
            content.strings[z]:= aValue
        else
            content.Append(aValue)
    end
    else
        content.Append(aValue)
end;

procedure kStringList_hive.add(index: string; aValue: string);
begin
    Include(cell_properties, cellProp_dirty);
    if (index <> '') and string_is_numeric(index) then
        content.Insert(StrToInt(index), aValue)
    else
        content.Add(aValue)
end;

procedure kStringList_hive.del(index: string);
begin
    Include(cell_properties, cellProp_dirty);
    if string_is_numeric(index) then
        content.Delete(strToInt(index))
end;

function kStringList_hive.getCount: integer;
begin
    result:= content.Count
end;

function kStringList_hive.getRandom: string;
begin
    result:= content.Strings[Random(content.Count)]
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
    itemz:= detank2list(detank(aStream));

    if itemz.Count > 0 then begin
        for z:= 0 to itemz.count - 1 do begin
            item := itemz[z];
            y    := Pos(#30, item);
            key  := item[1..y-1];
            value:= item[y+1..length(item)];
            content.Add(key, value)
        end
    end;
    Exclude(cell_properties, cellProp_dirty);
end;

function kHash_hive.to_stream: string;
begin
    buffer:= '';
    content.Iterate(@iteratee);
    result:= tank(buffer, [so_sha1])
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
    Include(cell_properties, cellProp_dirty);
    content.Items[index]:= aValue
end;

procedure kHash_hive.add(index: string; aValue: string);
begin
    Include(cell_properties, cellProp_dirty);
    content.Add(index, aValue)
end;

procedure kHash_hive.del(index: string);
begin
    Include(cell_properties, cellProp_dirty);
    content.Delete(index)
end;

function kHash_hive.getCount: integer;
begin
    result:= content.Count
end;

function kHash_hive.getRandom: string;
begin
    { Not sure how to implement this. Could set up an iterator but there's
      gotta be a less stupid way to do it. }
end;

end.

