#!/usr/bin/perl
# ---   *   ---   *   ---
# AVT
# avtomat utils as a package
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb
# ---   *   ---   *   ---

# deps
package avt;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use Storable;

  use Cwd qw(abs_path getcwd);

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/hacks';
  use shwl;

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;

  use emit::std;
  use emit::c;

  use lang;
  use langdefs::c;
  use langdefs::perl;
  use langdefs::peso;

  use peso::st;
  use peso::rd;
  use peso::ipret;

# ---   *   ---   *   ---
# info

  our $VERSION=v3.21.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $CONFIG_DEFAULT=>{

    name=>$NULLSTR,

    scan=>$NULLSTR,
    build=>$NULLSTR,

    xcpy=>[],
    lcpy=>[],
    incl=>[],
    libs=>[],

    gens=>{},

    defs=>[],
    xprt=>[],
    deps=>[],

    pre_build=>$NULLSTR,
    post_build=>$NULLSTR,

  };

  Readonly my $BIND=>'./bin';
  Readonly my $LIBD=>'./lib';
  Readonly my $INCD=>'./include';

# ---   *   ---   *   ---
# gcc switches

  Readonly our $OFLG=>
    q{-s -Os -fno-unwind-tables}.q{ }.
    q{-fno-asynchronous-unwind-tables}.q{ }.
    q{-ffast-math -fsingle-precision-constant}.q{ }.
    q{-fno-ident -fPIC}

  ;

  Readonly our $LFLG=>
    q{-flto -ffunction-sections}.q{ }.
    q{-fdata-sections -Wl,--gc-sections}.q{ }.
    q{-Wl,-fuse-ld=bfd}

  ;

# ---   *   ---   *   ---
# lenkz

  Readonly our $GITHUB=>q{https://github.com};
  Readonly our $LYEB=>$GITHUB.q{/Liebranca};

# ---   *   ---   *   ---
# global storage

  my %CACHE=(
    _include=>[],
    _lib=>[],

    _config=>{},
    _scan=>[],
    _modules=>[],

    _post_build=>{},
    _pre_build=>{},

  );

# ---   *   ---   *   ---

sub MODULES {return @{$CACHE{_modules}}};

# ---   *   ---   *   ---
# add to search path (include)

sub stinc(@args) {

  my $ref=$CACHE{_include};
  for my $path(@args) {

    $path=~ s/\-I//;
    $path=abs_path(glob($path));

    push @$ref,$path;

  };

};

# ---   *   ---   *   ---
# add to search path (library)

sub stlib(@args) {

  my $ref=$CACHE{_lib};
  for my $path(@args) {

    $path=~ s/\-L//;
    $path=abs_path(glob($path));

    push @$ref,$path;

  };

  return;

};

# ---   *   ---   *   ---
# in:filename
# sets search path and filelist accto filename

sub illnames($fname) {

  my @files=();
  my $ref;

# ---   *   ---   *   ---
# point to lib on -l at strbeg

  if($fname=~ m/^\s*\-l/) {
    $ref=$CACHE{_lib};
    $fname=~ s/^\s*\-l//;

    for my $i(0..1) {
      push @files,'lib'.$fname.(
        ('.so','.a')[$i]

      );

    };

    push @files,$fname;

# ---   *   ---   *   ---
# common file search

  } else {
    $ref=$CACHE{_include};
    push @files,$fname;

  };

  return [$ref,\@files];

};

# ---   *   ---   *   ---
# find file within search path

sub ffind($fname) {

  if(-e $fname) {return $fname;};

  my ($ref,@files);

  { my @ret=@{ illnames($fname) };

    $ref=$ret[0];@files=@{ $ret[1] };
    $fname=$files[$#files];

  };

# ---   *   ---   *   ---

  my $src=undef;
  my $path=undef;

  # iter search path
  for $path(@$ref,$shb7::root) {
    if(!$path) {next};

    # iter alt names
    for my $f(@files) {
      if(-e "$path/$f") {
        $src="$path/$f";
        last;

      };

    };

    # early exit on found
    if(defined $src) {last};

  };

# ---   *   ---   *   ---
# catch no such file

  if(!defined $src) {

    arstd::errout(
      "Could not find file '%s' in path\n",

      args=>[$fname],
      lvl=>$ERROR,

    );

  };

  return $src;

};

# ---   *   ---   *   ---
# wildcard search

sub wfind($in) {

  my $ref=undef;
  my @patterns=();

  { my @ret=@{ illnames($in) };
    $ref=$ret[0];@patterns=@{ $ret[1] };

  };

# ---   *   ---   *   ---

  # non wildcard escaping
  for my $pat(@patterns) {
    my $beg=substr(
      $pat,0,
      index($pat,'%')

    );my $end=substr(
      $pat,index($pat,'%')+1,
      length $pat

    );$beg="\Q$beg";
      $end="\Q$end";

    $pat=$beg.'%'.$end;

    # substitute %
    $pat=~ s/\%/.*/;

  };$in=join '|',@patterns;

# ---   *   ---   *   ---

  # find files matching pattern
  my @ar=();

  # iter search path
  for my $path(@$ref) {

    my %h=%{ walk($path) };
    for my $dir(keys %h) {
      my @files=@{ $h{$dir} };
      my @matches=(grep m/${ in }/,@files);

      $dir=($dir eq '<main>')
        ? ''
        : $dir
        ;

      for my $match(@matches) {
        $match="$path$dir/$match";

      };push @ar,@matches;

    };
  };

  return \@ar;

};

# ---   *   ---   *   ---
# finds .lib files

sub libsearch($lbins,$lsearch,$deps) {

  my @lbins=@$lbins;
  my @lsearch=@$lsearch;

  my $found=$NULLSTR;

# ---   *   ---   *   ---

  for my $lbin(@lbins) {
    for my $ldir(@lsearch) {

      # .lib file found
      if(-e "$ldir/.$lbin") {

        my $f=retrieve("$ldir/.$lbin")
        or croak STRERR("$ldir/.$lbin");

        my $ndeps.=(defined $f->{deps})
          ? $f->{deps} : $NULLSTR;

        chomp $ndeps;

        $ndeps=join q{|},(
          lang::ws_split($SPACE_RE,$ndeps)

        );

# ---   *   ---   *   ---

        # filter out the duplicates
        my @matches=grep(
          m/${ ndeps }/,
          lang::ws_split($SPACE_RE,$deps)

        );while(@matches) {
          my $match=shift @matches;
          $ndeps=~ s/${ match }\|?//;

        };$ndeps=~ s/\|/ /g;

        $found.=q{ }.$ndeps.q{ };
        last;

# ---   *   ---   *   ---

      };
    };
  };

  return $found;

};

# ---   *   ---   *   ---
# recursively appends lib dependencies to LIBS var

sub libexpand($LIBS) {

  my $ndeps=$LIBS;
  my $deps='';my $i=0;
  my @lsearch=@{ $CACHE{_lib} };

# ---   *   ---   *   ---

  while(1) {
    my @lbins=();

    $ndeps=~ s/^\s+//;

    # get search path(s)
    for my $mlib(split($SPACE_RE,$ndeps)) {

      if((index $mlib,'-L')==0) {

        my $s=substr $mlib,2,length $mlib;
        my $lsearch=join q{ },@lsearch;

# ---   *   ---   *   ---

        if(!($lsearch=~ m/${s}/)) {
          push @lsearch,$s;

        };

        next;

      };

# ---   *   ---   *   ---

      # append found libs to bin search
      $mlib=substr $mlib,2,length $mlib;
      push @lbins,$mlib;

    };

# ---   *   ---   *   ---

    # find dependencies of found libs
    $ndeps=libsearch(\@lbins,\@lsearch,$deps);

    # stop when none found
    if(!(length $ndeps)) {last};

    # else append and start over
    $deps=$ndeps.' '.$deps;

  };

# ---   *   ---   *   ---

  # append deps to libs
  $deps=join q{|},(split($SPACE_RE,$deps));

  # filter out the duplicates
  my @matches=grep(
    m/${ deps }/,split($SPACE_RE,$LIBS)

  );

  while(@matches) {
    my $match=shift @matches;
    $deps=~ s/${ match }\|?//;

  };$deps=~ s/\|/ /g;

  $LIBS.=q{ }.$deps.q{ };
  return $LIBS;

};

# ---   *   ---   *   ---
# Python emitter tools

sub cpyboil($name,$closed) {

  return

    q{#!/usr/bin/python}."\n".
    q{$:NOTE;>}."\n"

  ;

};

sub wrcpyboil {

  my $dir=shift;
  my $fname=shift;
  my $author=shift;
  my $call=shift;
  my $call_args=shift;

  # create file
  my $path=shb7::file($dir."$fname.py");

  open my $FH,'>',$path
  or croak STRERR($path);

# ---   *   ---   *   ---

  # generate notice
  my $n=note($author,'#');

  # open boiler and subst notice
  my $op=cpyboil(uc($fname),0);
  $op=~ s/\$\:NOTE\;\>/${ n }/;

  # write it to file
  print $FH $op;

  # write the code through the generator
  $call->($FH,@$call_args);

#  # close boiler
#  print $FH avt::cplboil_pm uc($fname),1;
  close $FH or croak STRERR($path);

};

# ---   *   ---   *   ---

sub py_typecon($type) {

  state %types=qw{

    string c_char_p
    string* POINTER(c_char_p)

    void None
    void* c_void_p

    size_t c_size_t

    float c_float
    float* POINTER(c_float)

    char c_int8_t
    uchar c_uint8_t

    uchar* POINTER(c_uint8_t)

    short c_int16_t
    ushort c_uint16_t

    short* POINTER(c_int16_t)
    ushort* POINTER(c_uint16_t)

    int c_int32_t
    uint c_uint32_t

    int* POINTER(c_int32_t)
    uint* POINTER(c_uint32_t)

    long c_int64_t
    ulong c_uint64_t

    long* POINTER(c_int64_t)
    ulong* POINTER(c_uint64_t)


  };

# ---   *   ---   *   ---

  if(exists $types{$type}) {
    $type=$types{$type};

  };

  return $type;

};

# ---   *   ---   *   ---

sub ctopy($FH,$soname,$libs_ref) {
  my %symtab=%{soregen($soname,$libs_ref)};

# ---   *   ---   *   ---

my $code=q{

from ctypes import *;
ROOT='/'.join(__file__.split("/")[0:-1]);

$:structs;>

class $:soname;>:

  @classmethod
  def nit():
    self=cdll.LoadLibrary(
      ROOT+"lib$:soname;>.so"

    );

$:iter (

      x0=>[@{$O{names}}],
      x1=>[@{$O{rtypes}}],
      x2=>[@{$O{arg_types}}],

    )

      "    self.call_$x0=self.__getattr__".
      "('$x0');\n".

      "    self.call_$x0.restype=$x1;\n".
      "    self.call_$x0.argtypes=$x2;\n\n"

    ;>

    return self;

};

# ---   *   ---   *   ---
# walk the symbol table

  my @names=();
  my @rtypes=();
  my @arg_types=();

  my $structs=$NULLSTR;

  for my $o(keys %{$symtab{objects}}) {

    my $obj=$symtab{objects}->{$o};
    my $funcs=$obj->{functions};

# ---   *   ---   *   ---
# functions in object

    for my $fn_name(keys %$funcs) {

      my $fn=$funcs->{$fn_name};

      my $rtype=$fn->{type};
      $rtype=py_typecon($rtype);

      my @arg_names=keys %{$fn->{args}};

      my @args=map
        {py_typecon($ARG)}
        values %{$fn->{args}}

      ;

      push @names,$fn_name;
      push @rtypes,$rtype;

      push @arg_types,
        '['.(join q{,},@args).']';

    };

# ---   *   ---   *   ---
# user-defined types in object

    my $utypes=$obj->{utypes};

    for my $ut_name(keys %$utypes) {

      $structs.="class $ut_name(Structure):\n";
      $structs.="  _fields_=[\n";

      my $utype=$utypes->{$ut_name};

      my @field_names=keys %$utype;
      my @field_types=map

        {py_typecon($ARG)}
        values %$utype

      ;

# ---   *   ---   *   ---

      while(@field_names && @field_types) {
        my $field_name=shift @field_names;
        my $field_type=shift @field_types;

        $structs.=q{    }.
          "('$field_name',".
          "$field_type),\n"

        ;

      };

      $structs.="  ];\n\n";

# ---   *   ---   *   ---

    };

  };

  # replace the $:escapes;>
  $code=peso::ipret::pesc(

    $code,

    structs=>$structs,
    soname=>$soname,

    names=>\@names,
    rtypes=>\@rtypes,
    arg_types=>\@arg_types,

  );

  # spit it out
  return print {$FH} "$code\n";

};

# ---   *   ---   *   ---
# looks at a single file for symbols

sub file_sbl($f) {

  my $found='';
  my $langname=lang::file_ext($f);

  my $object={

    utypes=>{},

    functions=>{},
    variables=>{},
    constants=>{},

  };

# ---   *   ---   *   ---
# read source file

  my $rd=peso::rd::new_parser(
    lang->$langname,$f

  );

  my $block=$rd->select_block(-ROOT);
  my $tree=$block->{tree};

  $rd->recurse($tree);
  $rd->hier_sort();

# ---   *   ---   *   ---
# mine the tree

  my $typecon=eval(
    q{\&emit::} . $langname . q{::typecon}

  );

  $rd->fn_search(

    $tree,

    $object->{functions},
    $typecon

  );

  $rd->utype_search(

    $tree,

    $object->{utypes},
    $typecon

  );

  return $object;

};

# ---   *   ---   *   ---
# in:modname,[files]
# write symbol typedata (return,args) to shadow lib

sub symscan($mod,$dst,$deps,@fnames) {

  stinc(shb7::dir($mod));

  my @files=();

# ---   *   ---   *   ---
# iter filelist

  { for my $fname(@fnames) {

      if( ($fname=~ m/\%/) ) {
        push @files,@{ wfind($fname) };

      } else {
        push @files,ffind($fname);

      };

    };
  };

# ---   *   ---   *   ---

  my $shwl={

    deps=>$deps,
    objects=>{},

  };

# ---   *   ---   *   ---
# iter through files

  for my $f(@files) {
    if(!$f) {next};

    $f=~ s/^${shb7::root}/./;
    my $o=shb7::obj_from_src($f);

    $shwl->{objects}->{$o}=file_sbl($f);

  };

  store($shwl,$dst) or croak STRERR($dst);

};

# ---   *   ---   *   ---
# in:modname
# get symbol typedata from shadow lib

sub symrd($mod) {

  my $src=shb7::lib(".$mod");

  my $out={};

  # existence check
  if(!(-e $src)) {
    print "Can't find shadow lib '$mod'\n";
    goto TAIL;

  };

  $out=retrieve($src) or croak STRERR($src);

# ---   *   ---   *   ---

TAIL:
  return $out;

};

# ---   *   ---   *   ---
# rebuilds shared objects if need be

sub soregen($soname,$libs_ref,$no_regen=0) {

  my $sopath=shb7::so($soname);
  my $so_gen=!(-e $sopath);

  my @libs=@{$libs_ref};
  my %symtab=(

    deps=>[],
    objects=>{}

  );

# ---   *   ---   *   ---
# recover symbol table

  my @o_files=();
  for my $lib(@libs) {
    my $f=symrd($lib);

    # so regen check
    if(!$so_gen) {
      $so_gen=ot($sopath,ffind('-l'.$lib));

    };

    # append
    for my $o(keys %{$f->{objects}}) {
      my $obj=$f->{objects}->{$o};
      $symtab{objects}->{$shb7::root.$o}=$obj;

    };

    push @{$symtab{deps}},$f->{deps};

  };

# ---   *   ---   *   ---
# generate so

  if($so_gen && !$no_regen) {

    # recursively get dependencies
    my $O_LIBS='-l'.( join ' -l',@libs );
    stlib(shb7::lib());

    my $LIBS=libexpand($O_LIBS);
    my $OBJS=join ' ',keys %{$symtab{objects}};

    # link
    my $call='gcc -shared'.q{ }.
      "$OFLG $LFLG ".
      "-m64 $OBJS $LIBS -o $sopath";

    `$call`;

  };

  return \%symtab;

};

# ---   *   ---   *   ---
# C to Perl code emitter stuff

# name=what your file is called
# x=1==end, 0==beg
# makes open and close boiler for Platypus modules
sub cplboil_pm {
  my $name=uc shift;
  my $x=shift;

  # guard start
  if(!$x) {
    my $s=<<'EOF'
#!/usr/bin/perl
$:NOTE;>

EOF

  ;$s.='package '.( lc $name ).";\n";
  $s.=<<'EOF'

# deps

  use v5.36.0;
  use strict;
  use warnings;

  use FFI::Platypus;
  use FFI::CheckLib;

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;

  use avt;

# ---   *   ---   *   ---

EOF

  ;return $s;

  # guard end
  };my $s=<<'EOF'

# ---   *   ---   *   ---
1; # ret

EOF

  ;return $s;

# ---   *   ---   *   ---

# dir=where to save the file to
# fname=fname
# call=reference to a sub taking filehandle

# author=your name

# wraps sub in Platypus module boilerplate
};sub wrcplboil_pm {

  my $dir=shift;
  my $fname=shift;
  my $author=shift;
  my $call=shift;
  my $call_args=shift;

  # create file
  open my $FH,'>',shb7::file("$dir/$fname.pm")
  or croak STRERR($fname);

  # generate notice
  my $n=note($author,'#');

  # open boiler and subst notice
  my $op=avt::cplboil_pm(uc($fname),0);
  $op=~ s/\$\:NOTE\;\>/${ n }/;

  # write it to file
  print $FH $op;

  # write the code through the generator
  $call->($FH,@$call_args);

  # close boiler
  print $FH avt::cplboil_pm uc($fname),1;
  close $FH;

};

# ---   *   ---   *   ---
# C to Perl binding

# in: file handle,soname,[libraries]
# reads in symbol tables and generates exports
sub ctopl($FH,$soname,$libs_ref) {

  my %symtab=%{soregen($soname,$libs_ref)};
  my $search=<<"EOF"

my \%CACHE=(
  ffi=>undef,
  nitted=>0,

);

sub ffi {return \$CACHE{ffi};};

sub nit {

  if(\$CACHE{nitted}) {return};

  my \$libfold=arstd::dirof(__FILE__);

  my \$olderr=arstd::errmute();
  my \$ffi=FFI::Platypus->new(api => 2);
  \$ffi->lib(
    "\$libfold/lib$soname.so"

  );

  arstd::erropen(\$olderr);

  \$ffi->load_custom_type(
    '::WideString'=>'wstring'

  );\$ffi->type('(void)->void'=>'nihil');
  \$CACHE{ffi}=\$ffi;

EOF
;print {$FH} $search;

# ---   *   ---   *   ---
# attach symbols from table

  my $tab=$NULLSTR;

  for my $o(keys %{$symtab{objects}}) {

    my $obj=$symtab{objects}->{$o};
    my $funcs=$obj->{functions};
    $tab.="\n\n".

    '# ---   *   ---   *   ---'."\n".
    "# $o\n\n";

    for my $fn_name(keys %$funcs) {

      my $fn=$funcs->{$fn_name};

      my @ar=values %{$fn->{args}};
      for my $s(@ar) {
        $s=sqwrap($s);

      };

# ---   *   ---   *   ---

      my $arg_types='['.( join(
        ',',@ar

      )).']';

      my $rtype=$fn->{type};

      $tab.=''.
        "my \$$fn_name=\'$fn_name\';\n".

        '$ffi->attach('.
        "\$$fn_name,".
        "$arg_types,".

        "'$rtype');\n\n";

# ---   *   ---   *   ---

    };

  };

  my $nit='$CACHE{nitted}=1;';
  my $callnit

    ='(\&nit,$NOOP)'.
    '[$CACHE{nitted}]->();';

  print {$FH} $tab."\n$nit\n};$callnit\n";

};

# ---   *   ---   *   ---
# in: filepaths dst,src
# extends one perl file with another

sub plext($dst_path,$src_path) {

  $dst_path=shb7::file($dst_path);
  $src_path=shb7::file($src_path);

  my $src=arstd::orc($src_path);
  $src=~ s/.+#:CUT;>\n//sg;

  my $dst=arstd::orc($dst_path);
  $dst=~ s/1; # ret\n//sg;

  $dst.=$src;
  open FH,'>',$dst_path
  or croak STRERR($dst_path);

  print FH $dst;
  close FH;

};

# ---   *   ---   *   ---
# arg=string any
# multi-byte ord

sub mord {
  my @s=split $NULLSTR,shift;
  my $seq=0;
  my $i=0;while(@s) {
    $seq|=ord(shift @s)<<$i;$i+=8;

  };return $seq;
};

# ^ for wide strings
sub wmord($string) {
  my @s=split $NULLSTR,$string;
  my $seq=0;
  my $i=0;while(@s) {
    $seq|=ord(shift @s)<<$i;$i+=16;

  };return $seq;
};

# arg=int arr
# multi-byte chr
sub mchr(@s) {

  for my $c(@s) {
    $c=chr($c);

  };return @s;

};

# ---   *   ---   *   ---

sub sqwrap($s) {return "'$s'"};
sub dqwrap($s) {return "\"$s\""};

sub ex($name,$opts,$tail) {

  my @opts=@{ $opts };

  for(my $i=0;$i<@opts;$i++) {
    if(($opts[$i]=~ m/\s/)) {
      $opts[$i]=dqwrap($opts[$i]);

    };
  };

  return `$ENV{'ARPATH'}/bin/$name @opts $tail`;

};

# ---   *   ---   *   ---
# path utils

# args=chkpath,name,repo-url,actions
# pulls what you need

sub depchk($chkpath,$deps) {

  $chkpath=abs_path($chkpath);

  my $old_cwd=abs_path(getcwd());
  chdir $chkpath;

# ---   *   ---   *   ---

  while(@$deps) {
    my ($name,$url,$act)=@{ shift @$deps };

# ---   *   ---   *   ---
# pull if dir not found in provided path

    if(!(-e $chkpath."/$name")) {
      `git clone $url`;

# ---   *   ---   *   ---
# blank for now, use this for building extdeps

    };if($act) {
      ;

    };

# ---   *   ---   *   ---

  };

  chdir $old_cwd;

};

# ---   *   ---   *   ---
# args=path
# recursively list dirs and files in path

sub walk($path) {

  state $EXCLUDED=qr{

     \/

   | (?:GNUmakefile)
   | (?:Makefile)
   | (?:makefile)

  }x;

  my %dirs=();

# ---   *   ---   *   ---
# dissect recursive ls

  my @ls=split "\n\n",`ls -FBR1 $path`;
  while(@ls) {
    my @sub=split ":\n",shift @ls;

    # shorten dirnames
    $sub[0]=~ s/${ path }//;
    if(!$sub[0]) {$sub[0]='<main>';};

    # exclude hidden folders and documentation
    if( ($sub[0]=~ m/\./)
    ||  ($sub[0] eq '/docs')
    ) {next;};

    # remove ws
    if(not defined $sub[1]) {next};
    $sub[1]=~ s/^\s+|\s+$//;

# ---   *   ---   *   ---
# filter out folders and headers

    my @tmp=split "\n",$sub[1];
    my @files=();

# ---   *   ---   *   ---

    while(@tmp) {
      my $entry=shift @tmp;
      if($entry=~ $EXCLUDED) {next};

      push @files,$entry;

    };

    # dirs{folder}=ref(list of files)
    $dirs{ $sub[0] }=\@files;

# ---   *   ---   *   ---

  };

  return (\%dirs);

};

# ---   *   ---   *   ---
# ensures trsh and bin exist
# outs file/dir list

sub scan() {

  my $modules={};
  my $fpath=shb7::cache_file("avto-modules");

  # just ensure we have these standard paths
  for my $path(

    shb7::dir("bin"),
    shb7::dir("lib"),
    shb7::dir("include"),

    $shb7::trash,
    $shb7::cache,

  ) {if(!(-e $path)) {mkdir $path}};

# ---   *   ---   *   ---
# iter provided names

  my @ar=@{$CACHE{_scan}};
  while(@ar) {

    my ($mod,$excluded)=split m[\s],shift @ar;

    if(defined $excluded) {

      # handle exclude flag short
      if($excluded=~ m/-x/) {
        $excluded=~ s/-x\s*//;

      # handle exclude flag long
      } elsif($excluded=~
          m/\-\-exclude\=[\w|\d]*/

      ) {
        $excluded=~ s/\-\-exclude\=//;

      };

    };

# ---   *   ---   *   ---

    $excluded//=$NULLSTR;

    $excluded='('.(join q{|},
      'nytprof','docs','tests','data',
      lang::ws_split($COMMA_RE,$excluded)

    ).')';

    $excluded=qr{$excluded};

# ---   *   ---   *   ---

    my $trsh=shb7::obj_dir($mod);
    my $modpath=shb7::dir($mod);

    # ensure there is a trashcan
    if(!(-e $trsh)) {
      system 'mkdir',('-p',"$trsh");

    };

# ---   *   ---   *   ---
# walk module path

    my %h=%{ walk($modpath) };
    my $list={};

    # paths/dir checks
    for my $dir (keys %h) {

      if( defined $excluded
      &&  $dir=~ m/$excluded/

      ) {next};

      # ensure directores exist
      my $tdir=$trsh.$dir;
      $tdir=~ s[<main>][/];

      if(!(-e $tdir)) {
        `mkdir -p $tdir`;

      };

# ---   *   ---   *   ---
# capture file list

      my $full=$dir;
      $full=~ s[<main>][];
      $full=~ s[^/][];

      if(length $full) {$full.=q[/]};

      my $files=[map
        {$ARG=~ s[^/][];"$full$ARG"}
        @{$h{$dir}}

      ];

      $list->{$dir}=$files;

# ---   *   ---   *   ---

    };

    $modules->{$mod}=$list;

  };

  store($modules,$fpath)
  or croak STRERR($fpath);

};

# ---   *   ---   *   ---
# ^read in the file/dir list

sub read_modules() {

  my $src=shb7::cache_file("avto-modules");

  my $modules=retrieve($src)
    or croak STRERR($src);

  return $modules;

};

# ---   *   ---   *   ---

sub get_config_build($M,$config) {

  $M->{fswat}=$config->{name};

# ---   *   ---   *   ---

  my ($lmode,$mkwat)=($NULLSTR,$NULLSTR);

  if(length $config->{build}) {

    ($lmode,$mkwat)=
      lang::ws_split($COLON_RE,$config->{build});

  };

# ---   *   ---   *   ---

  if($lmode eq 'so') {
    $lmode='-shared ';

  } elsif($lmode ne 'ar') {
    $lmode=$NULLSTR;

  };

  $M->{lmode}=$lmode;
  $M->{mkwat}=$lmode;

# ---   *   ---   *   ---

  if(length $mkwat) {

    $M->{ilib}="$LIBD/.$mkwat";

    if($lmode eq 'ar') {
      $M->{main}="$LIBD/lib$mkwat.a";
      $M->{mlib}=undef;

    } elsif($lmode eq '-shared ') {
      $M->{main}="$LIBD/lib$mkwat.so";
      $M->{mlib}=undef;

    } else {
      $M->{main}="$BIND/$mkwat";
      $M->{mlib}="$LIBD/lib$mkwat.a";

    };

  } else {
    $M->{ilib}=undef;
    $M->{main}=undef;
    $M->{mlib}=undef;

  };

};

# ---   *   ---   *   ---

sub get_config_paths($M,$config) {

  $M->{libs}=q{-L}.$LIBD.q{ }.(
    join q{ },@{$config->{libs}}

  );

  $M->{incl}=q{-I}.$INCD.q{ -I./ }.(
    join q{ },@{$config->{incl}}

  );

};

# ---   *   ---   *   ---
# find hashkeys in list
# returns matches ;>

sub lfind($search,$l) {
  return [grep {exists $search->{$ARG}} @$l];

};

# ---   *   ---   *   ---

sub get_config_files($M,$config,$module) {

  state $c_ext=qr{\.c$};
  state $perl_ext=qr{\.pm$};

  $M->{fcpy}=[];
  $M->{xprt}=[];
  $M->{gens}=[];
  $M->{srcs}=[];
  $M->{objs}=[];

# ---   *   ---   *   ---

  for my $dir(keys %{$module}) {

    my $name=$config->{name};
    my $trsh=$NULLSTR;

    my $files=$module->{$dir};

    if((index $dir,q{/})==0) {
      $dir=substr $dir,1,length $dir;

    };

    # get path to
    $dir="./$name";
    $trsh=shb7::rel(shb7::obj_dir($name));

# ---   *   ---   *   ---

    my $matches=lfind($config->{gens},$files);

    while(@$matches) {

      my $match=shift @$matches;
      my ($outfile,$srcs)=@{
        $config->{gens}->{$match}

      };

      delete $config->{gens}->{$match};
      $match=~ s[\*][];

      map {$ARG="$dir/$ARG"} @$srcs;

      push @{$M->{gens}},(
        "$dir/$match",
        "$dir/$outfile",

        (join q{,},@$srcs)

      );

    };

# ---   *   ---   *   ---

    $matches=lfind($config->{xcpy},$files);

    while(@$matches) {

      my $match=shift @$matches;
      delete $config->{xcpy}->{$match};

      $match=~ s[\*][];
      $match=~ s[\\][]g;

      push @{$M->{fcpy}},(
        "$dir/$match",
        "$BIND/$match"

      );

    };

# ---   *   ---   *   ---

    $matches=lfind($config->{lcpy},$files);

    while(@$matches) {
      my $match=shift @$matches;
      delete $config->{lcpy}->{$match};

      $match=~ s[\\][]g;

      my $lmod=$dir;
      $lmod=~ s[${shb7::root}/${name}][];
      $lmod.=($lmod) ? q{/} : $NULLSTR;

      push @{$M->{fcpy}},(
        "$dir/$match",
        "$LIBD/$lmod$match"

      );

    };

# ---   *   ---   *   ---

    $matches=lfind($config->{xprt},$files);

    while(@$matches) {
      my $match=shift @$matches;
      delete $config->{xprt}->{$match};

      $match=~ s[\\][]g;
      push @{$M->{xprt}},"$dir/$match";

    };

# ---   *   ---   *   ---

    my @matches=grep m/$c_ext/,@$files;

    while(@matches) {
      my $match=shift @matches;
      $match=~ s[\\][]g;

      my $ob=$match;$ob=(substr $ob,0,
        (length $ob)-1).'o';

      my $dep=$match;$dep=(substr $dep,0,
        (length $dep)-1).'d';

      push @{$M->{srcs}},"$dir/$match";
      push @{$M->{objs}},(
        "$trsh/$ob",
        "$trsh/$dep"

      );

    };

# ---   *   ---   *   ---

    @matches=grep m/$perl_ext/,@$files;

    while(@matches) {
      my $match=shift @matches;
      $match=~ s[\\][]g;

      my $dep=$match;
      $dep.='d';

      push @{$M->{srcs}},"$dir/$match";

      my $lmod=$dir;
      $lmod=~ s([.]/${name})();

      push @{$M->{objs}},(
        "$LIBD$lmod/$match",
        "$trsh/$dep"

      );

    };

# ---   *   ---   *   ---

  };

};

# ---   *   ---   *   ---
# registers module configuration

sub set_config(%C) {

  state $sep_re=lang::ws_split_re(q{,});
  state $list_to_hash=qr{(?:

    lcpy
  | xcpy
  | xprt

  )}x;

# ---   *   ---   *   ---

  my $modules=$CACHE{_modules};
  my $scan=$CACHE{_scan};

  # ensure all needed fields are there
  for my $key(keys %{$CONFIG_DEFAULT}) {
    if(!(exists $C{$key})) {
      $C{$key}=$CONFIG_DEFAULT->{$key};

    };
  };

# ---   *   ---   *   ---
# convert file lists to hashes

  for my $key(keys %C) {

    if($key=~ $list_to_hash) {

      if(@{$C{$key}}) {
        $C{$key}={
          map {$ARG=>1} @{$C{$key}}

        };

      } else {
        $C{$key}={};

      };

    };

  };

# ---   *   ---   *   ---
# run dependency checks

  depchk(

    shb7::dir($C{name}),
    $C{deps}

  ) if $C{deps};

# ---   *   ---   *   ---
# prepare the libs && includes

  for my $lib(@{$C{libs}}) {
    if((index $lib,q{/})>=0) {
      $lib=q{-L}.$lib;

    } else {
      $lib=q{-l}.$lib;

    };
  };

  for my $include(@{$C{incl}}) {
    $include=q{-I./}.$include;

  };

# ---   *   ---   *   ---
# invert generator hash
#
#   > from: generated=>[generator,dependencies]
#     to: generator=>[generated,dependencies]
#
# the reason why is the first form makes more
# sense visually (at least to me), so that's
# what i'd rather write to a config file
#
# however, the second form is more convenient
# for a file search, so...

  my %gens=();

  for my $outfile(keys %{$C{gens}}) {

    my $srcs=$C{gens}->{$outfile};
    my $exec=shift @$srcs;

    $gens{$exec}=[$outfile,$srcs];

  };

  $C{gens}=\%gens;

# ---   *   ---   *   ---
# append

  push @$modules,$C{name};

  if(length $C{scan}) {
    push @$scan,
      $C{name}.q{ }.$C{scan}

  } else {
    push @$scan,$C{name};

  };

  $CACHE{_config}->{$C{name}}=\%C;

};

# ---   *   ---   *   ---
# ^saves whole project configuration to file

sub config() {

  my $src=shb7::cache_file("avto-config");
  my $config=$CACHE{_config};

  store($config,$src) or croak STRERR($src);

};

# ---   *   ---   *   ---
# ^reads it in

sub read_config() {

  my $src=shb7::cache_file("avto-config");
  my $config=retrieve($src)
  or croak STRERR($src);

};

# ---   *   ---   *   ---
# emits builders

sub make {

  # fetch project data
  my $modules=read_modules();
  my $configs=read_config();

  # now iter
  for my $name(keys %$configs) {

    my $C=$configs->{$name};

    my $module=$modules->{$name};
    my $avto_path=shb7::file("$name/avto");

    # build the makescript object
    my $M={};
    get_config_build($M,$C);
    get_config_paths($M,$C);
    get_config_files($M,$C,$module);

    # save it to disk
    my $cache_path=shb7::file("$name/.avto-cache");

    store($M,$cache_path)
    or croak STRERR($cache_path);

# ---   *   ---   *   ---
# now dump the boiler

    open my $FH,'>',$avto_path
    or croak STRERR($avto_path);

    my $FILE=$NULLSTR;

    # write notice
    $FILE.='#!/usr/bin/perl'."\n";
    $FILE.=emit::std::note('IBN-3DILA','#');

    # paste in the pre-build hook

    if(length $C->{pre_build}) {
      $FILE.=

      "\n\n".

      'INIT {'."\n\n".

        'print "'.
        $emit::std::ARSEP.
        'running pre-build hook... \n";'.

        $C->{pre_build}.';'.
        "\n\n".

      "};\n";

    };

    $FILE.=<<'EOF'

# ---   *   ---   *   ---
#deps

  use 5.36.0;
  use strict;
  use warnings;

  use Storable;

  use lib $ENV{'ARPATH'}.'/lib/';

  use shb7;
  use avt;

  use makescript;

# ---   *   ---   *   ---

my $PFLG='-m64';
my $DFLG='';

my $root=arstd::parof(__FILE__);
my $M=retrieve(

  arstd::dirof(__FILE__).
  '/.avto-cache'

);

chdir shb7::set_root($root);
$M=makescript::nit($M);

# ---   *   ---   *   ---

print {*STDERR}
  $emit::std::ARTAG."upgrading $M->{fswat}\n";

$M->set_build_paths();
$M->update_generated();

my ($OBJS,$objblt)=
  $M->update_objects($DFLG,$PFLG);

$M->build_binaries($PFLG,$OBJS,$objblt);
$M->update_regular();

print {*STDERR}
  $emit::std::ARSEP."done\n\n";

EOF
;

# ---   *   ---   *   ---
# paste in the post-build hook

    if(length $C->{post_build}) {
      $FILE.=

      #"\n".
      '# ---   *   ---   *   ---'.
      "\n\n".

      "END {\n\n".

        'print "'.
        $emit::std::ARSEP.
        'running post-build hook... \n\n";'.

        $C->{post_build}.';'.

      "\n\n};".

      "\n\n".

      '# ---   *   ---   *   ---'.
      "\n\n"

      ;

    };

# ---   *   ---   *   ---

    print {$FH} $FILE;
    close $FH;

    `chmod +x "$avto_path"`;

  };
};

# ---   *   ---   *   ---
1; # ret
