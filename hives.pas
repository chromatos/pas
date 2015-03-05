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


    { kDict_hive }

    kDict_hive = class(kHive_ancestor)
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

        procedure   to_stream_iteratee(Item: String; const Key: string; var Continue: Boolean);
        procedure   dump_iteratee     (Item: String; const Key: string; var Continue: Boolean);
        procedure   search_iteratee   (Item: String; const Key: string; var Continue: Boolean);
        procedure   size_iteratee     (Item: String; const Key: string; var Continue: Boolean);
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


    { kTable_hive }

{    kTable_hive = class(kHive_ancestor)
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
}

    { kHive_cluster }

    kHive_cluster = class(TFPHashObjectList)
      public
        theDirectory: string;


        function  add_hive       (name, h_class: string; permissions: kHivePermissions): kHive_ancestor;
        function  add_list_hive  (name: string; permissions: kHivePermissions): kList_hive;
        function  add_keyval_hive(name: string; permissions: kHivePermissions): kDict_hive;
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

//        function  kGetColumn     (index: string; permission: kRWModes): kPortableColumn;
//        function  kGetRow        (index: string; permission: kRWModes): kPortableColumn;
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
uses strutils, IniFiles, sha1, kUtils, tanks;

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


{$i 'hive_ancestor.inc'}

{$i 'hive_cluster.inc'}

{$i 'list_hive.inc'}
{$i 'dict_hive.inc'}

end.

