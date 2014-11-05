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
    kRWModes = (cp_No_touch, // don't let strangers touch this
                cp_Helmet,   // 'special' people, like admins
                cp_Pleebs);  // anyone can poke this

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
        cell_properties        : kCellProperties;

        function    getCount   : integer;virtual;abstract;
      protected
        function    getItem    (index: string): string;virtual;abstract;
        procedure   setItem    (index: string; aValue: string);virtual;abstract;
        function    getRandom  : string;virtual;abstract;
        procedure   setPerms   (permissions: string);
        function    getPerms   : string;
      public
        constructor Create     (HashObjectList:TFPHashObjectList;const s:shortstring);
      public
        procedure   add        (index: string; aValue: string);virtual;abstract;
        procedure   del        (index: string);virtual;abstract;
        function    to_stream  : string;virtual;abstract;
        procedure   from_stream(aStream: string);virtual;abstract;
        procedure   to_console;virtual;abstract;
      public
        property    items[index: string]: string read getItem write setItem; default;
        property    count      : integer read getCount;
        property    Permissions: string read getPerms write setPerms;
    end;

    { kKeyVal_hive }

    kKeyVal_hive = class(kHive_ancestor)
        content: TFPStringHashTable;

        function    getItem    (index: string): string;override;
        procedure   setItem    (index: string; aValue: string);override;

        procedure   add        (index: string; aValue: string);override;
        procedure   del        (index: string);override;

        function    to_stream  : string;override;
        procedure   from_stream(aStream: string);override;
      public
        constructor Create     (HashObjectList:TFPHashObjectList;const s:shortstring);
      protected
        function    getRandom  : string;override;
      public
        procedure   to_console;override;
      private
        buffer: string; // because the stupid iterator has to be a method and they
                        // don't just give a numerically-indexed accessor
        procedure   iteratee     (Item: String; const Key: string; var Continue: Boolean);
        procedure   dump_iteratee(Item: String; const Key: string; var Continue: Boolean);
        function    getCount     : integer;override;
    end;

    { kList_hive }

    kList_hive = class(kHive_ancestor)
        content: tStringList;

        function    getItem    (index: string): string;override;
        procedure   setItem    (index: string; aValue: string);override;

        procedure   add        (index: string; aValue: string);override;
        procedure   del        (index: string);override;

        function    to_stream  : string;override;
        procedure   from_stream(aStream: string);override;
      public
        constructor Create     (HashObjectList:TFPHashObjectList;const s:shortstring);
      public
        procedure   to_console;override;
      protected
        function    getRandom  : string;override;
      private
        function    getCount   : integer;override;
    end;


    { kHive_cluster }

    kHive_cluster = class(TFPHashObjectList)
      public
        theDirectory: string;


        function  add_hive       (name, h_class: string; permissions: kHivePermissions): kHive_ancestor;
        function  add_list_hive  (name: string; permissions: kHivePermissions): kList_hive;
        function  add_keyval_hive(name: string; permissions: kHivePermissions): kKeyVal_hive;
        function  del_hive       (name: string): boolean;

        procedure load           (path: string);
        procedure save           (path: string);

        procedure to_console     (hive: string);
      private
        function  kGetItem       (index: string; permission: string): string;
        procedure kSetItem       (index: string; permission: string; aValue: string);
        function  kGetPerm       (index: string): string;
        procedure kSetPerm       (index: string; perm: string);
      public
        lastError: string;
      public
        property  content[index: string;permission:string]: string read kGetItem write kSetItem; default;
        property  permission[index: string]: string read kGetPerm write kSetPerm;
      private
        dirty: boolean;
    end;

    eHive_error = class(Exception);

implementation
uses strutils, sha1, kUtils, tanks;

const
    c_ref= '## Error in cell reference: missing ';

{ I have no idea why I made these separate functions. }

function perm2string(perm: kRWModes): string;
begin
    case perm of
        cp_No_touch: result:= 'none';
        cp_Helmet  : result:= 'some';
        cp_Pleebs  : result:= 'everyone';
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
    case aString of
        'none'    : result:= cp_No_touch;
        'some'    : result:= cp_Helmet;
        'everyone': result:= cp_Pleebs;
    end
end;

function str2perms(aString: string): kHivePermissions;
var y: tStringList;
    z: integer = 0;
begin
    y:= splitByType(aString);
    while z+1 < y.Count do begin
        case y.Strings[z] of
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

procedure kHive_ancestor.setPerms(permissions: string);
begin
    kPermissions:= str2perms(permissions)
end;

function kHive_ancestor.getPerms: string;
begin
    result:= perms2string(kPermissions)
end;

constructor kHive_ancestor.Create(HashObjectList:TFPHashObjectList;const s:shortstring);
begin
    inherited;
    cell_properties := [];
    kPermissions.r  := cp_No_touch;
    kPermissions.w  := cp_No_touch;
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
            raise eHive_error.Create('Undefined hive class: ' + h_class)
    end
end;

function kHive_cluster.add_list_hive(name: string; permissions: kHivePermissions): kList_hive;
begin
    try
       result             := kList_hive.Create(self, name);
       result.cell_type   := ct_StringList;
       result.kPermissions:= permissions;
       dirty              := true;
    except
        on EDuplicate do result:= nil
    end
end;


function kHive_cluster.add_keyval_hive(name: string; permissions: kHivePermissions): kKeyVal_hive;
begin
    try
       result             := kKeyVal_hive.Create(self, name);
       result.cell_type   := ct_Hashlist;
       result.kPermissions:= permissions;
       dirty              := true;
    except
        on EDuplicate do result:= nil
    end
end;


function kHive_cluster.del_hive(name: string): boolean;
var aHive: kHive_ancestor;
begin
    lastError:= '';
    try
        dirty := true;
        aHive := kHive_ancestor(Find(name));
        if aHive = nil then begin
            lastError:= 'Hive "' + name + '" could not be deleted because it doesn''t exist';
            result   := false;
            exit
        end;
        aHive.free;
        DeleteFile(ConcatPaths([theDirectory, name+'.hive']));
        result:= true
    except
        result   := false;
        lastError:= 'Dunno what happened. The exceptional hive was "' + name + '"';
    end;
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
        else
            raise eHive_error.Create('Empty hive stream: ' + h_name);
    end;
    dirty:= false
end;

procedure kHive_cluster.save(path: string);
var z      : dWord;
    buffer : string = '';
    h_class: string;
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
                'kKeyVal_hive': h_class:= 'keyvalue';
                'kList_hive'  : h_class:= 'list'
            end;
            buffer+= tank(keyvalue2tanks('name', kHive_ancestor(items[z]).Name)
                        + keyvalue2tanks('class', h_class)
                        + keyvalue2tanks('permissions', kHive_ancestor(items[z]).Permissions), []);
        end;

        string2File(ConcatPaths([path, 'root.hive']), tank(buffer, [so_sha1]));
        dirty:= false
    end
end;

procedure kHive_cluster.to_console(hive: string);
var z    : integer;
    aHive: kHive_ancestor;
begin
    if hive <> '' then
    begin
        aHive:= kHive_ancestor(Find(hive));
        if aHive <> nil then
            aHive.to_console
        else
            writeln('Hive "', hive, '" does not exist; can''t dump!')
    end else begin
        writeln('No hive specified; dumping entire hive cluster');
        for z:= 0 to Count-1 do
            kHive_ancestor(Items[z]).to_console
    end
end;

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
        result.key:= path[1..z-1]
    else
        result.key:= '';
    if z < length(path) then
        result.value:=path[z+1..length(path)]
    else
        result.value:= ''
end;

function kHive_cluster.kGetItem(index: string; permission: string): string;
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

    aHive := kHive_ancestor(Find(kv.key));
    if aHive <> nil then begin
        if str2perm(permission) <= str2perms(aHive.Permissions).r then
            result:= aHive.items[kv.value]
        else
        begin
            result:= '';
            lastError:= 'Not enough permissions for ' + index
        end
    end
    else
        lastError:= '## Hive not found: ' + index
end;

procedure kHive_cluster.kSetItem(index: string; permission: string; aValue: string);
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

    aHive := kHive_ancestor(Find(kv.key));
    if aHive <> nil then begin
        if str2perm(permission) <= str2perms(aHive.Permissions).r then
            aHive.items[kv.value]:= aValue
        else
            lastError:= 'You require additional permissions for ' + index;
    end
    else
        lastError:= '## Hive not found' + index
end;

function kHive_cluster.kGetPerm(index: string): string;
begin
    result:= kHive_ancestor(Find(index)).Permissions
end;

procedure kHive_cluster.kSetPerm(index: string; perm: string);
begin
    kHive_ancestor(Find(index)).Permissions:=perm
end;


{ kList_hive }

procedure kList_hive.from_stream(aStream: string);
var z         : integer = 1;
begin
    content.Clear;

    content.AddStrings(detank2list(detank(aStream, z)));

    Exclude(cell_properties, cellProp_dirty)
end;

constructor kList_hive.Create(HashObjectList: TFPHashObjectList;
    const s: shortstring);
begin
    inherited;
    content:= tStringList.Create;
    content.Sorted    := true;      // Both of these should be optional
    content.Duplicates:= dupIgnore; // properties but I don't care at the moment
end;

procedure kList_hive.to_console;
var z: integer = 0;
begin
    writeln('==== HIVE DUMP ==== (', Name, '; list)');
    writeln('Permissions: ', Permissions);
    for z:= 0 to content.Count - 1 do
        writeln(#9, content.Strings[z]);
    writeln('==== END ==== (', Name, '; ', content.count, ' cells)')
end;

function kList_hive.to_stream: string;
var z     : integer;
    buffer: string = '';
begin
    for z:= 0 to content.count - 1 do
        buffer+= tank(content.Strings[z], []);

    result:= tank(buffer, [so_sha1])
end;

function kList_hive.getItem(index: string): string;
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

procedure kList_hive.setItem(index: string; aValue: string);
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

procedure kList_hive.add(index: string; aValue: string);
begin
    Include(cell_properties, cellProp_dirty);
    if (index <> '') and string_is_numeric(index) then
        content.Insert(StrToInt(index), aValue)
    else
        content.Add(aValue)
end;

procedure kList_hive.del(index: string);
begin
    Include(cell_properties, cellProp_dirty);
    if string_is_numeric(index) then
        content.Delete(strToInt(index))
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
    b:= detank(aStream);

    while z < length(b) do begin
        keyval:= tank2keyvalue(b, z);
        content.add(keyval.key, keyval.value)
    end;

    Exclude(cell_properties, cellProp_dirty)
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
    writeln(#9'KEY: ', key, #9'VALUE: ', Item);
    Continue:= true
end;

function kKeyVal_hive.getItem(index: string): string;
begin
    result:= content.Items[index]
end;

procedure kKeyVal_hive.setItem(index: string; aValue: string);
begin
    Include(cell_properties, cellProp_dirty);
    content.Items[index]:= aValue
end;

procedure kKeyVal_hive.add(index: string; aValue: string);
begin
    Include(cell_properties, cellProp_dirty);
    content.Add(index, aValue)
end;

procedure kKeyVal_hive.del(index: string);
begin
    Include(cell_properties, cellProp_dirty);
    content.Delete(index)
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
    writeln('==== HIVE DUMP ==== (', Name, '; keyval)');
    writeln('Permissions: ', Permissions);
    content.Iterate(@dump_iteratee);
    writeln('==== END ==== (', Name, '; ', content.count, ' cells)')
end;

end.

