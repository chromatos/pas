{ A hashlist-based key/value string storage box.

  Each hive is stored to its own text file for easy offline editing and so we don't
  have to rewrite the entire thing to disk every time something changes.
  Actually, hives are flagged as dirty buffers and they get written periodically.

  For storage, we abuse the shit out of the serialized 'tank' strings instead
  of just using a database or something normal.

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
    kRWModes = (cp_No_touch,     // don't let strangers touch this
                cp_DoubleHelmet, // owner
                cp_Helmet,       // 'special' people, like admins
                cp_Plebes);      // anyone can poke this

    kHivePermissions = record
        r,
        w: kRWModes
    end;

    kCellProperties = set of (cellProp_dirty);
    kCellType       = (ct_None, ct_StringList, ct_Hashlist);

    kResult         = (kr_fine, kr_exists, kr_not_exists, kr_wtf);

    { kHive_ancestor }

    kHive_ancestor = class(TFPHashObject)
      private
        kPermissions           : kHivePermissions;
        cell_type              : kCellType;
        dirty                  : boolean;

      protected
        function    kGetItem   (index: string): string;virtual;abstract;
        procedure   kSetItem   (index: string; aValue: string);virtual;abstract;
        function    getRandom  : string;virtual;abstract;
        procedure   setStrPerms(permissions: string);
        function    getStrPerms: string;
        procedure   setPerms   (permissions: kHivePermissions);
        function    getPerms   : kHivePermissions;
      public
        constructor Create     (HashObjectList:TFPHashObjectList;const s:shortstring);
      public
        procedure   add        (index: string; aValue: string);virtual;abstract;
        function    del        (index: string): boolean;virtual;abstract;
        function    del_byval  (aValue: string): boolean;virtual;abstract;

        function    search     (exactValue: string): string;virtual;abstract;

        procedure   clear;virtual;abstract;

        function    to_stream  : string;virtual;abstract;
        procedure   from_stream(aStream: string);virtual;abstract;
        procedure   to_console;virtual;abstract;
        function    getCount   : integer;virtual;abstract;
        function    getSize    : integer;virtual;abstract;
      public
        property    items[index: string]: string read kGetItem write kSetItem; default;
        property    count      : integer read getCount;
        property    SPermissions: string read getStrPerms write setStrPerms;
        property    Permissions: kHivePermissions read getPerms write setPerms;
    end;

    { kKeyVal_hive }

    kKeyVal_hive = class(kHive_ancestor)
        content: TFPStringHashTable;

        function    kGetItem   (index: string): string;override;
        procedure   kSetItem   (index: string; aValue: string);override;

        procedure   add        (index: string; aValue: string);override;
        function    del        (index: string): boolean;override;
        function    del_byval  (aValue: string): boolean;override;

        function    search     (exactValue: string): string;override;

        procedure   clear;override;

        function    to_stream  : string;override;
        procedure   from_stream(aStream: string);override;
      public
        constructor Create     (HashObjectList:TFPHashObjectList;const s:shortstring);
      protected
        function    getRandom  : string;override;
      public
        procedure   to_console;override;
        function    getSize    : integer;override;
        function    getCount   : integer;override;
      private
        buffer : string; // because the stupid iterator has to be a method and they
        buffer2: string; // don't just give a numerically-indexed accessor
        aValue : integer;

        procedure   iteratee       (Item: String; const Key: string; var Continue: Boolean);
        procedure   dump_iteratee  (Item: String; const Key: string; var Continue: Boolean);
        procedure   search_iteratee(Item: String; const Key: string; var Continue: Boolean);
        procedure   size_iteratee  (Item: String; const Key: string; var Continue: Boolean);
    end;

    { kList_hive }

    kList_hive = class(kHive_ancestor)
        content: tStringList;

        function    kGetItem   (index: string): string;override;
        procedure   kSetItem   (index: string; aValue: string);override;

        procedure   add        (index: string; aValue: string);override;
        function    del        (index: string): boolean;override;
        function    del_byval  (aValue: string): boolean;override;

        function    search     (exactValue: string): string;override;

        procedure   clear;override;

        function    to_stream  : string;override;
        procedure   from_stream(aStream: string);override;
      public
        constructor Create     (HashObjectList:TFPHashObjectList;const s:shortstring);
      public
        procedure   to_console;override;
        function    getSize    : integer;override;
        function    getCount   : integer;override;
      protected
        function    getRandom  : string;override;
    end;


    { kMultiList_hive }

    { kDir_hive }

{    kDir_hive = class(kHive_ancestor)
        content: TFPHashObjectList;

        function    kGetItem   (index: string): string;override;
        procedure   kSetItem   (index: string; aValue: string);override;

        procedure   add        (index: string; aValue: string);override;
        procedure   del        (index: string);override;
        procedure   del_byval  (aValue: string);override;

        function    search     (exactValue: string): string;override;

        procedure   clear;override;

        function    to_stream  : string;override;
        procedure   from_stream(aStream: string);override;
      public
        constructor Create     (HashObjectList:TFPHashObjectList;const s:shortstring);
      public
        procedure   to_console;override;
        function    getSize    : integer;override;
        function    getCount   : integer;override;
      protected
        function    getRandom  : string;override;
    end;}


    { kHive_cluster }

    kHive_cluster = class(TFPHashObjectList)
      public
        theDirectory: string;


        function  add_hive       (name, h_class: string; permissions: kHivePermissions): kHive_ancestor;
        function  add_list_hive  (name: string; permissions: kHivePermissions): kList_hive;
        function  add_keyval_hive(name: string; permissions: kHivePermissions): kKeyVal_hive;
        function  del_hive       (name: string): boolean;
        function  clear_hive     (name: string): boolean;

        function  del_cell       (name: string): boolean;
        function  del_cell_byval (name: string; aValue: string): boolean;

        function  select_hive    (name: string): kHive_ancestor;
        function  select_hive    (index: integer): kHive_ancestor;

        function  getSize       : integer;
        function  get_full_size : integer;
        function  get_overhead  : integer;
        function  get_cell_count: integer;

        procedure load           (path: string);
        procedure save           (path: string);

        procedure to_console     (hive: string);
      private
        function  kGetItem       (index: string; permission: kRWModes): string;
        procedure kSetItem       (index: string; permission: kRWModes; aValue: string);
        function  kGetPerm       (index: string): string;
        procedure kSetPerm       (index: string; perm: string);
      public
        lastError: string;
      public
        property  content[index: string;permission:kRWModes]: string read kGetItem write kSetItem; default;
        property  permission[index: string]: string read kGetPerm write kSetPerm;
      private
        dirty: boolean;
    end;

    eHive_error = class(Exception);

    function str2perms(aString: string): kHivePermissions;
    function str2perm(aString: string): kRWModes;
    function perms2string(perms: kHivePermissions): string;

implementation
uses strutils, sha1, kUtils, tanks;

const
    c_ref= '## Error in cell reference: missing ';

function resolve_path(path: string): kKeyValue;
    var z: integer;
    begin
        z:= pos('/', path);
        if z = 1 then begin      // Allow a '/' at start for 'root' but still
            PosEx('/', path, z); // require a later '/' to delimit the node levels.
            if z > 1 then begin
                path:= path[2..length(path)];
                dec(z) // Since we nuked the first character.
            end
            else
                z:= 0
        end;
        if z > 1 then
            result.key:= lowerCase(path[1..z-1])
        else
            result.key:= '';
        if z < length(path) then
            result.value:=path[z+1..length(path)]
        else
            result.value:= ''
    end;

{ I have no idea why I made these separate functions. }

function perm2string(perm: kRWModes): string;
begin
    case perm of
        cp_No_touch    : result:= 'none';
        cp_DoubleHelmet: result:= 'one';
        cp_Helmet      : result:= 'some';
        cp_Plebes      : result:= 'everyone';
    else
        result:= 'none' // Err on the side of caution. The constructor is
                        // supposed to be filling this in; it's not
    end
end;

function perms2string(perms: kHivePermissions): string;
begin
    result:= 'r:' + perm2string(perms.r) + ';'
           + 'w:' + perm2string(perms.w)
end;

function str2perm(aString: string): kRWModes;
begin
    case lowerCase(aString) of
        'none'    : result:= cp_No_touch;
        'one'     : result:= cp_DoubleHelmet;
        'some'    : result:= cp_Helmet;
        'everyone': result:= cp_Plebes;
    end
end;

function str2perms(aString: string): kHivePermissions;
var y: tStringList;
    z: integer = 0;
begin

    y:= splitByType(aString);
    z:= 0;
    while z+1 < y.Count do begin
        case lowerCase(y.Strings[z]) of
            'r': begin
                     inc(z, 2);
                     result.r:= str2perm(y.Strings[z]);
                 end;
            'w': begin
                     inc(z, 2);
                     result.w:= str2perm(y.Strings[z]);
                 end
            else inc(z);
        end
    end
end;


{ kHive_ancestor }

procedure kHive_ancestor.setStrPerms(permissions: string);
begin
    kPermissions:= str2perms(permissions)
end;

function kHive_ancestor.getStrPerms: string;
begin
    result:= perms2string(kPermissions)
end;

procedure kHive_ancestor.setPerms(permissions: kHivePermissions);
begin
    kPermissions:= permissions
end;

function kHive_ancestor.getPerms: kHivePermissions;
begin
    result:= kPermissions
end;

constructor kHive_ancestor.Create(HashObjectList:TFPHashObjectList;const s:shortstring);
begin
    inherited;
    dirty         := false;
    kPermissions.r:= cp_Helmet;
    kPermissions.w:= cp_Helmet;
end;


{ kHive_cluster }

function kHive_cluster.add_hive(name, h_class: string; permissions: kHivePermissions): kHive_ancestor;
begin
    if name = '' then
        raise eHive_error.Create('Empty hive name')
    else if h_class = '' then
        raise eHive_error.Create('Empty hive class');

    case h_class of
        'keyvalue': result:= add_keyval_hive(name, permissions);
        'list'    : result:= add_list_hive(name, permissions);
        else
            lastError:= 'Undefined hive class: ' + h_class
    end
end;

function kHive_cluster.add_list_hive(name: string; permissions: kHivePermissions): kList_hive;
begin
    name:= lowerCase(name);
    try
        if FindIndexOf(name) = -1 then
        begin
            result                := kList_hive.Create(self, name);
            result.cell_type      := ct_StringList;
            result.kPermissions   := permissions;
            result.dirty          := false;
            dirty                 := true
        end
    except
        on EDuplicate do result:= kList_hive(Find(name))
    end
end;


function kHive_cluster.add_keyval_hive(name: string; permissions: kHivePermissions): kKeyVal_hive;
begin
    name:= lowerCase(name);
    try
        if FindIndexOf(name) = -1 then
        begin
            result                := kKeyVal_hive.Create(self, name);
            result.cell_type      := ct_Hashlist;
            result.kPermissions   := permissions;
            result.dirty          := false;
            dirty                 := true
        end
    except
        on EDuplicate do result:= kKeyVal_hive(Find(name))
    end
end;


function kHive_cluster.del_hive(name: string): boolean;
var aHive: kHive_ancestor;
begin
    lastError:= '';
    try
        dirty := true;
        aHive := select_hive(lowerCase(name));
        if aHive = nil then begin
            lastError:= 'Hive "' + name + '" could not be deleted because it doesn''t exist';
            result   := false;
            exit
        end;
        Remove(aHive);
        DeleteFile(ConcatPaths([theDirectory, name+'.hive']));
        result:= true
    except
        result   := false;
        lastError:= 'Dunno what happened. The exceptional hive was "' + name + '"';
    end;
end;

function kHive_cluster.clear_hive(name: string): boolean;
var x: kHive_ancestor;
begin
    x:= select_hive(name);
    if x <> nil then
        x.clear
    else
        lastError:= 'Couldn''t clear hive "' + name + '"'
end;

function kHive_cluster.del_cell(name: string): boolean;
var v: kKeyValue;
    x: kHive_ancestor;
begin
    lastError:= '';
    result   := false;
    v        := resolve_path(name);
    x        := select_hive(v.key);

    if x <> nil then
        if x.del(v.value) then
            result:= true
    else
        lastError:= 'Couldn''t delete cell "' + name + '"'
end;

function kHive_cluster.del_cell_byval(name: string; aValue: string): boolean;

begin
    if not select_hive(name).del_byval(aValue) then
        lastError:= 'Couldn''t delete cell "' + name + '"'
end;



function kHive_cluster.select_hive(name: string): kHive_ancestor;
begin
    result:= kHive_ancestor(Find(name))
end;

function kHive_cluster.select_hive(index: integer): kHive_ancestor;
begin
    result:= kHive_ancestor(GetItem(index))
end;

function kHive_cluster.getSize: integer;
var z: integer;
begin
    result:= 0;
    for z:= 0 to Count-1 do
        inc(result, select_hive(z).getSize);
end;

function kHive_cluster.get_full_size: integer;
{ This one includes the overhead of the keys as well as the classes }
var z: integer;
    y: kHive_ancestor;
begin
    result:= 0;
    for z:= 0 to Count-1 do
    begin
        y:= select_hive(z);
        inc(result, y.getSize);
        inc(result, length(y.Name));
        inc(result, y.InstanceSize);  // Well, technically, we gloss over the size
        inc(result, self.InstanceSize)// difference between hive classes. Whatever.
    end
end;

function kHive_cluster.get_overhead: integer;
var z: integer;
    y: kHive_ancestor;
begin
    result:= 0;
    for z:= 0 to Count-1 do
    begin
        y:= select_hive(z);
        inc(result, length(y.Name));
        inc(result, y.InstanceSize);
        inc(result, self.InstanceSize)
    end
end;

function kHive_cluster.get_cell_count: integer;
var z: integer;
begin
    result:= 0;
    for z:= 0 to count-1 do
        inc(result, select_hive(z).getCount)
end;


procedure kHive_cluster.load(path: string);
var z      : integer = 0;
    y      : integer = 0;
    buffer : string;
    hives  : tStringList;
    aHive  : kHive_ancestor;
    perms  : kHivePermissions;
    props  : kKeyValues;

    h_name : string;
    h_class: string;
begin
    theDirectory:= path;
    buffer      := file2string(ConcatPaths([path, 'root.hive']));

    if buffer = '' then // It's either empty or non-existant.
        raise EFOpenError.Create('Could not open root hive in ' + path);

    hives:= detank2list(detank(buffer));

    for z:= 0 to hives.Count - 1 do
    begin
        props  := tanks2keyvalues(hives.Strings[z]);
        h_name := '';
        h_class:= '';
        perms.r:= cp_No_touch;
        perms.w:= cp_No_touch;

        for y:= 0 to length(props)-1 do
        begin
            case props[y].key of
                'name'       : h_name := props[y].value;
                'class'      : h_class:= props[y].value;
                'permissions': perms  := str2perms(props[y].value);
            end
        end;

        aHive := add_hive(h_name, h_class, perms);

        buffer:= file2string(ConcatPaths([path, h_name + '.hive']));

        if buffer <> '' then
            aHive.from_stream(buffer)
        else  // maybe it's just not been saved yet
            writeln(stdErr, 'Empty hive stream: ', h_name)
//            raise eHive_error.Create('Empty hive stream: ' + h_name);
    end;
    dirty:= false
end;

procedure kHive_cluster.save(path: string);
var z      : integer;
    buffer : string = '';
    h_class: string;
    y      : kHive_ancestor;
begin
  { Write out any modified hives }
    for z:= 0 to Count - 1 do
    begin
        y:= select_hive(z);
        if y.dirty then
        begin
            string2File(ConcatPaths([path, y.Name + '.hive']), y.to_stream);
            y.dirty:= false;
            writeln('Hive saved: ', y.Name)
        end;
    end;
  { Write index if modified }
    if dirty then begin
        for z:= 0 to Count - 1 do
        begin
//            if kHive_ancestor(items[z]).count > 0 then
//            begin
                case items[z].ClassName of
                    'kKeyVal_hive': h_class:= 'keyvalue';
                    'kList_hive'  : h_class:= 'list'
                end;
                buffer+= tank(keyvalue2tanks('name', kHive_ancestor(items[z]).Name)
                            + keyvalue2tanks('class', h_class)
                            + keyvalue2tanks('permissions', kHive_ancestor(items[z]).SPermissions), []);
            end;
//        end;

        string2File(ConcatPaths([path, 'root.hive']), tank(buffer, [so_sha1]));
        writeln('Hive root saved');
        dirty:= false
    end
end;

procedure kHive_cluster.to_console(hive: string);
var z    : integer;
    aHive: kHive_ancestor;
begin
    if hive <> '' then
    begin
        aHive:= kHive_ancestor(Find(lowerCase(hive)));
        if aHive <> nil then
            aHive.to_console
        else
            lastError:= 'Hive "' + hive + '" does not exist; can''t dump!'
    end else begin
        writeln('No hive specified; dumping entire hive cluster');
        for z:= 0 to Count-1 do
            kHive_ancestor(Items[z]).to_console
    end
end;

function kHive_cluster.kGetItem(index: string; permission: kRWModes): string;
var kv    : kKeyValue;
    aHive : kHive_ancestor;
begin
    lastError:= '';
    result   := '';
    kv       := resolve_path(index);

    if kv.key = '' then
    begin
        lastError:= c_ref + 'hive name';
        exit
    end;
    if kv.value = '' then
    begin
        lastError:= c_ref + 'cell name';
        exit
    end;

    aHive := select_hive(kv.key);
    if aHive <> nil then begin
        if permission <= aHive.Permissions.r then
        begin
            result:= aHive.items[kv.value]
        end
        else
        begin
            result   := '';
            lastError:= 'Not enough permissions for ' + index
        end
    end
    else
        lastError:= 'Hive not found: ' + index
end;

procedure kHive_cluster.kSetItem(index: string; permission: kRWModes; aValue: string);
var kv   : kKeyValue;
    aHive: kHive_ancestor;
begin
    lastError:= '';
    kv       := resolve_path(index);

    if kv.key = '' then
    begin
        lastError:= c_ref + 'hive name';
        exit
    end;
    if kv.value = '' then
    begin
        lastError:= c_ref + 'cell name';
        exit
    end;

    aHive := select_hive(kv.key);
    if aHive <> nil then begin
        if permission <= aHive.Permissions.w then
            aHive.items[kv.value]:= aValue
        else
            lastError:= 'You require additional permissions for ' + index;
    end
    else
        lastError:= '## Hive not found' + index
end;

function kHive_cluster.kGetPerm(index: string): string;
begin
    result:= select_hive(lowerCase(index)).SPermissions
end;

procedure kHive_cluster.kSetPerm(index: string; perm: string);
begin
    select_hive(lowerCase(index)).SPermissions:=perm
end;


{ kList_hive }

procedure kList_hive.from_stream(aStream: string);
var z         : integer = 1;
begin
    if aStream <> '' then begin
        content.Clear;

        content.AddStrings(detank2list(detank(aStream, z)));

        dirty:= false;
    end else
        writeln(stdErr, 'Empty hive stream; not loading');
end;

constructor kList_hive.Create(HashObjectList: TFPHashObjectList;
    const s: shortstring);
begin
    inherited;
    content:= tStringList.Create;
//    content.Sorted    := true;      // Both of these should be optional
    content.Duplicates:= dupIgnore; // properties but I don't care at the moment
end;

procedure kList_hive.to_console;
var z: integer = 0;
begin
    writeln('==== HIVE DUMP ==== (', Name, '; list)'#9,
            'Permissions: ', SPermissions);
    for z:= 0 to content.Count - 1 do
        writeln(#9, z, #9, content.Strings[z]);
    writeln('==== END ==== (', Name, '; ', content.count, ' cells)')
end;

function kList_hive.getSize: integer;
var z: integer;
begin
    result:= 0;
    if content.Count > 0 then
        for z:= 0 to content.Count-1 do
            inc(result, length(content.Strings[z]))
end;

function kList_hive.to_stream: string;
var z     : integer;
    buffer: string = '';
begin
    for z:= 0 to content.count - 1 do
        buffer+= tank(content.Strings[z], []);

    result:= tank(buffer, [so_sha1])
end;

function kList_hive.kGetItem(index: string): string;
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

procedure kList_hive.kSetItem(index: string; aValue: string);
var z: integer;
begin
    dirty:= true;

    if string_is_numeric(index) then begin
        z:= strToInt(index);
        if (z < content.Count) and (z >= 0) then
            content.strings[z]:= aValue
        else
            content.Add(aValue)
    end
    else
        content.Append(aValue)
end;

procedure kList_hive.add(index: string; aValue: string);
begin
    dirty:= true;
    if (index <> '') and string_is_numeric(index) then
        content.Insert(StrToInt(index), aValue)
    else
        content.Add(aValue)
end;

function kList_hive.del(index: string): boolean;
var z: integer;
begin
    result:= false;
    if string_is_numeric(index) then
    begin
        z:= StrToInt(index);
        if (z > 0) and (z < content.Count) then begin
            content.Delete(z);
            result:= true;
            dirty := true
        end
    end
end;

function kList_hive.del_byval(aValue: string): boolean;
var z: integer;
begin
    if content.Find(aValue, z) then
    begin
        content.Delete(z);
        result:= true
    end
    else
        result:= false
end;

function kList_hive.search(exactValue: string): string;
var z: integer;
begin
    if content.Find(exactValue, z) then
        result:= intToStr(z)
    else result:= ''
end;

procedure kList_hive.clear;
begin
    content.Clear
end;

function kList_hive.getCount: integer;
begin
    result:= content.Count
end;

function kList_hive.getRandom: string;
begin
    result:= content.Strings[Random(content.Count)]
end;

{ kKeyVal_hive }

procedure kKeyVal_hive.from_stream(aStream: string);
var z     : integer = 1;
    keyval: kKeyValue;
    b     : string;
begin
    if aStream <> '' then begin
        b:= detank(aStream);

        while z < length(b) do begin
            keyval:= tank2keyvalue(b, z);
            Items[keyval.key]:= keyval.value
        end;

        dirty:= false
    end
    else
        writeln(stdErr, 'Empty hive stream; not loading')
end;

constructor kKeyVal_hive.Create(HashObjectList: TFPHashObjectList;
    const s: shortstring);
begin
    inherited;
    content:= TFPStringHashTable.Create
end;

function kKeyVal_hive.to_stream: string;
begin
    buffer:= '';
    content.Iterate(@iteratee);
    result:= tank(buffer, [so_sha1])
end;

procedure kKeyVal_hive.iteratee(Item: String; const Key: string; var Continue: Boolean);
begin
    buffer  += keyvalue2tanks(key, item);
    Continue:= true
end;

procedure kKeyVal_hive.dump_iteratee(Item: String; const Key: string; var Continue: Boolean);
begin
    writeln(#9, key, #9, Item);
    Continue:= true
end;

procedure kKeyVal_hive.search_iteratee(Item: String; const Key: string; var Continue: Boolean);
begin
    continue:= item <> buffer
end;

procedure kKeyVal_hive.size_iteratee(Item: String; const Key: string;
    var Continue: Boolean);
begin
    inc(aValue, length(item));
    Continue:= true
end;

function kKeyVal_hive.kGetItem(index: string): string;
begin
    result:= content.Items[index]
end;

procedure kKeyVal_hive.kSetItem(index: string; aValue: string);
begin
    dirty:= true;
    content.Items[index]:= aValue
end;

procedure kKeyVal_hive.add(index: string; aValue: string);
begin
    dirty:= true;
    content.Add(index, aValue)
end;

function kKeyVal_hive.del(index: string): boolean;
begin
    dirty:= true;
    if content.Find(index) <> nil then
    begin
        content.Delete(index);
        dirty := true;
        result:= true
    end
    else
        result:= false
end;

function kKeyVal_hive.del_byval(aValue: string): boolean;
var g: string;
begin
    g:= search(aValue);
    if g <> '' then
    begin
        content.Delete(g);
        dirty := true;
        result:= true
    end
    else
        result:= false
end;

function kKeyVal_hive.search(exactValue: string): string;
begin
    buffer:= exactValue;
    result:= content.Iterate(@search_iteratee)
end;

procedure kKeyVal_hive.clear;
begin
    content.Clear
end;

function kKeyVal_hive.getCount: integer;
begin
    result:= content.Count
end;

function kKeyVal_hive.getRandom: string;
begin
    { Not sure how to implement this. Could set up an iterator callback but
      there's gotta be a less slow and stupid way to do it. }
//    result:= (content.HashTable.Items[random(count)]);
    result:= ''
end;

procedure kKeyVal_hive.to_console;
begin
    writeln('==== HIVE DUMP ==== (', Name, '; keyval)'#9,
            'Permissions: ', SPermissions);
    content.Iterate(@dump_iteratee);
    writeln('==== END ==== (', Name, '; ', content.count, ' cells)')
end;

function kKeyVal_hive.getSize: integer;
begin
    aValue:= 0;
    content.Iterate(@size_iteratee);
    result:= aValue
end;

end.

