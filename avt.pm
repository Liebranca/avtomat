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

  use Carp;
  use English qw(-no_match_vars);

  use Cwd qw(abs_path getcwd);
  use File::Spec;

  use lib $ENV{'ARPATH'}.'/lib/hacks';
  use shwl;

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;

  use lang;
  use langdefs::c;
  use langdefs::perl;
  use langdefs::peso;

  use peso::st;
  use peso::rd;

# ---   *   ---   *   ---
# info

  our $VERSION=v3.21.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    $ARTAG
    $ARSEP

    $GITHUB
    $LYEB

  );

# ---   *   ---   *   ---
# ROM

  Readonly our $ARTAG=>arstd::pretty_tag('AR');
  Readonly our $ARSEP=>"\e[37;1m::\e[0m";

  Readonly my $BOXCHAR=>'.';
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
    _root=>'.',
    _include=>[],
    _lib=>[],

    _config=>{},
    _scan=>[],
    _modules=>[],

    _post_build=>{},
    _pre_build=>{},

  );

# ---   *   ---   *   ---

sub root($new=undef) {

  if(defined $new) {
    $CACHE{_root}=abs_path($new);

  };

  return $CACHE{_root};

};

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
  for $path(@$ref,root) {
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
# in=pattern
# wildcard search

sub wfind {

  my $in=shift;

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
# default prints

# args=author,comment prefix
# generates a notice on top of generated files
sub note {

  my $author=shift;
  my $ch=shift;

  my $t=`date +%Y`;
  $t=substr $t,0,(length $t)-1;

  my $note=<<"EOF"
$ch ---   *   ---   *   ---
$ch LIBRE BOILERPASTE
$ch GENERATED BY AR/AVTOMAT
$ch
$ch LICENSED UNDER GNU GPL3
$ch BE A BRO AND INHERIT
$ch
$ch COPYLEFT $author $t
$ch ---   *   ---   *   ---
EOF

;return $note;

};

# args=name,version,author
# generates program info
sub version {
  my ($l1,$l2,$l3)=(
    shift.' v'.shift,
    'Copyleft '.shift.' '.`date +%Y`,
    'Licensed under GNU GPL3'

  );chomp $l2;

  my $c=$BOXCHAR;
  my $version=

  ("$c"x 32)."\n".sprintf(
    "$c %-28s $c\n",$l1

  )."$c ".(' 'x 28)." $c\n".

  sprintf("$c %-28s $c\n$c %-28s $c\n",$l2,$l3).

  ("$c"x 32)."\n";

  return $version;

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
  open my $FH,'>',
    $CACHE{_root}.$dir.$fname.'.py'
    or croak STRERR($fname);

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
  close $FH;

};

# ---   *   ---   *   ---

sub pytypecon($type) {

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

class $:soname;>:

  @classmethod
  def nit():
    self=cdll.LoadLibrary(
      ROOT+"lib$:soname;>.so"

    );

$:iter (

      x0=>[@names],
      x1=>[@rtypes],
      x2=>[@arg_types],

    )

      "    self.call_$x0=self.__getattr__".
      "('$x0');\n".

      "    self.call_$x0.restype=$x1;\n".
      "    self.call_$x0.argtypes=$x2;\n\n"

    ;>

    return self;

};

# ---   *   ---   *   ---

  my @names=();
  my @rtypes=();
  my @arg_types=();

  for my $o(keys %{$symtab{objects}}) {

    my $obj=$symtab{objects}->{$o};
    my $funcs=$obj->{functions};

    for my $fn_name(keys %$funcs) {

      my $fn=$funcs->{$fn_name};

      my $rtype=$fn->{type};
      $rtype=pytypecon($rtype);

      my @arg_names=keys %{$fn->{args}};
      my @args=values %{$fn->{args}};

      for my $type(@args) {
        $type=pytypecon($type);

      };

      push @names,$fn_name;
      push @rtypes,$rtype;

      push @arg_types,
        '['.(join q{,},@args).']';

    };

  };

# ---   *   ---   *   ---

  state $pesc=qr{

    \$:

    (?<body> (?:

      [^;] | ;[^>]

    )+)

    ;>

  }x;

  while($code=~ s/($pesc)/__CUT__/sm) {

    my $esc=$+{body};

    if(!($esc=~ s/^([^;\s]+)\s*//)) {

      arstd::errout(
        "Empty peso escape '%s'",

        args=>[$esc],
        lvl=>$FATAL,

      );

    };

    my $command=${^CAPTURE[0]};

# ---   *   ---   *   ---

    if($command eq 'iter') {

      $esc=~ s/(\([^\)]*\))\s+//xm;

      my %ht=eval(${^CAPTURE[0]}.q{;});
      my $run=$esc;

      my $repl=$NULLSTR;

      my $ar_cnt=int(keys %ht);

      my $loop_cond='while(';
      my $loop_head=$NULLSTR;
      my $loop_body='$repl.=eval($run);};';

# ---   *   ---   *   ---

      my $i=0;
      for my $key(keys %ht) {

        my $elem=q[@{].'$ht{'.$key.'}'.q[}];

        $loop_cond.=$elem;

        $i++;
        if($i<$ar_cnt) {
          $loop_cond.=q{&&};

        };

        $loop_head.=q{my $}."$key".q{=}.
          'shift '.$elem.';';

      };

      $loop_cond.=q[) {];

# ---   *   ---   *   ---

      eval($loop_cond.$loop_head.$loop_body);
      $code=~ s/__CUT__/$repl/sg;

# ---   *   ---   *   ---

    } else {

      my $var=eval(q{$}.$command);
      $code=~ s/__CUT__/$var/;

    };

  };

# ---   *   ---   *   ---

  print {$FH} "$code\n";

};

# ---   *   ---   *   ---
# C code emitter tools

# name=what your file is called
# x=1==end, 0==beg
# makes header guards
sub cboil_h {
  my $name=uc shift;
  my $x=shift;

  # header guard start
  if(!$x) {
    my $s=
'#ifndef __'.$name.'_H__'."\n".
'#define __'.$name.'_H__'."\n".
'#ifdef __cplusplus'."\n".
'extern "C" {'."\n".
'#endif'."\n"

  ;return $s;

  };my $s=
'#ifdef __cplusplus'."\n".
'};'."\n".
'#endif'."\n".
'#endif // __'.$name.'_H__'."\n"

  ;return $s;

# ---   *   ---   *   ---

# dir=where to save the file to
# fname=fname
# call=reference to a sub taking filehandle

# author=your name

# wraps sub in header boilerplate
};sub wrcboil_h {

  my $dir=shift;
  my $fname=shift;
  my $author=shift;
  my $call=shift;
  my $call_args=shift;

  my $path=$CACHE{_root}.$dir.$fname.'.h';

  # create file
  open my $FH,'>',$path
  or croak STRERR($path);

  # print a notice
  print $FH note($author,'//');

  # open boiler
  print $FH avt::cboil_h uc($fname),0;

  # write the code through the generator
  $call->($FH,@$call_args);

  # close boiler
  print $FH avt::cboil_h uc($fname),1;
  close $FH;

};

# ---   *   ---   *   ---

# mode=beg|nxt|end
# type=array|enum
# value=elem name
# dst=string

# array/enum generator helper
sub clist {

  my ($mode,$type,$value,$dst)=@{ $_[0] };

  # opening clause
  if(!$mode) {

    my $is_arr;
    ($is_arr,$type)=
      lang::ws_split($COLON_RE,$type);

    $is_arr=$is_arr eq 'arr';

    if($is_arr) {
      $dst.="static $type $value"."[]={\n";
      $type='';

    } else {
      $dst.="enum {\n";

    };$mode++;

# ---   *   ---   *   ---

  # list element
  } elsif($mode==1) {
    $dst.=" $value,\n";

  # closer
  } else {

    if(!$type) {
      $dst=substr $dst,0,(length $dst)-2;
      $dst.="\n\n};\n\n";

    } else {
      $dst.=" $type\n\n};\n\n";

    };

  };

  return [$mode,$type,$value,$dst];

};

# ---   *   ---   *   ---

# type=ret:args
# name=func name
# code=func contents
# dst=string

# function generator helper
sub cfunc {

  my ($type,$name,$code,$dst)=@{ $_[0] };

  my ($ret,$args)=
    lang::ws_split($COLON_RE,$type);

  $dst.="$ret $name($args) {\n$code\n};\n\n";

  return [$type,$name,$code,$dst];

};

# ---   *   ---   *   ---
# C reading

sub typecon {

  my $s=shift;
  my $i=0;

# ---   *   ---   *   ---
# TODO: handle type specifiers!
#
#   we're only handling unsigned right now...
#
#   for most uses that's OK but we might need
#   to take other specs into account, even
#   if just to remove them
#
# ---   *   ---   *   ---

  my @con=('string','wstring','int*');

  for my $t('char\*','wchar_t\*','void\*') {
    if($s=~ m/^${t}[\s|\*]?/) {
      $s=~ s/^${t}/${ con[$i] }/;

    };$s=~ s/\*+/\*/;

    $i++;

  };

  $s=~ s/unsigned\s+/u/;
  return $s;

};


# ---   *   ---   *   ---
# looks at a single file for symbols

sub file_sbl($f) {

  my $found='';
  my $langname=lang::file_ext($f);

  my $object={

    types=>{},

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

  my $lang=$rd->{lang};
  my $sbl_key=qr{^$lang->{sbl_key}$};

# ---   *   ---   *   ---
# iter through functions

  for my $sbl($tree->branches_in($sbl_key)) {

    my $id=$sbl->leaf_value(0);
    my $src=$rd->select_block($id);

    my $attrs=$src->{attrs};
    my $name=$src->{name};
    my $args=$src->{args};

    my $type=typecon($attrs);

    my $fn=$object->{functions}->{$name}={

      type=>$type,
      args=>{},

    };

# ---   *   ---   *   ---
# save args

    $args=~ s/$lang->{strip_re}//sg;
    $args=~ s/^\s*\(|\)\s*$//sg;

    my @args=split $COMMA_RE,$args;

    while(@args) {

      my $arg=shift @args;
      $arg=~ s/^\s+|\s+$//;

      my ($arg_attrs,$arg_name)=
        split $SPACE_RE,$arg;

      # is void
      if(!defined $arg_name) {
        $arg_name=$NULLSTR;

      };

      my $arg_type=typecon($arg_attrs);

      $fn->{args}->{$arg_name}=$arg_type;

# ---   *   ---   *   ---

    };

  };return $object;

};

# ---   *   ---   *   ---
# in:modname,[files]
# write symbol typedata (return,args) to shadow lib

sub symscan($mod,$dst,$deps,@fnames) {

  my $root=abs_path(root());
  stinc("$root/$mod/");

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

    $f=~ s/^${root}/./;
    my $o=$f;

    # point to equivalent object file
    $o=~ s/^\./trashcan/;
    $o=~ s/\.[\w|\d]*$/\.o/;

    $shwl->{objects}->{$o}=file_sbl($f);

  };

  store($shwl,$dst) or croak STRERR($dst);

};

# ---   *   ---   *   ---
# in:modname
# get symbol typedata from shadow lib

sub symrd($mod) {

  my $root=abs_path(root());
  my $src=$root."/lib/.$mod";

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

  my $root=abs_path(root());

  my $sopath="$root/lib/lib$soname.so";
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
    my $f=avt::symrd($lib);

    # so regen check
    if(!$so_gen) {
      $so_gen=ot($sopath,ffind('-l'.$lib));

    };

    # append
    for my $o(keys %{$f->{objects}}) {
      my $obj=$f->{objects}->{$o};
      $symtab{objects}->{"$root/$o"}=$obj;

    };

    push @{$symtab{deps}},$f->{deps};

  };

# ---   *   ---   *   ---
# generate so

  if($so_gen && !$no_regen) {

    # recursively get dependencies
    my $O_LIBS='-l'.( join ' -l',@libs );
    stlib("$CACHE{_root}/lib/");

    my $LIBS=avt::libexpand($O_LIBS);
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
  open my $FH,'>',
    $CACHE{_root}.$dir.$fname.'.pm'
    or croak STRERR($fname);

  # generate notice
  my $n=note($author,'#');

  # open boiler and subst notice
  my $op=avt::cplboil_pm uc($fname),0;
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

  my \$libfold=avt::dirof(__FILE__);

  my \$olderr=avt::errmute();
  my \$ffi=FFI::Platypus->new(api => 2);
  \$ffi->lib(
    "\$libfold/lib$soname.so"

  );

  avt::erropen(\$olderr);

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

  $dst_path=root().$dst_path;
  $src_path=root().$src_path;

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
# bash utils

# mute stderr
;;sub errmute {

  my $fh=readlink "/proc/self/fd/2";
  open STDERR,'>',
    File::Spec->devnull()

  # you guys kidding me
  or croak STRERR('/dev/null')

  ;return $fh;

# ---   *   ---   *   ---
# ^restore

};sub erropen($fh) {
  open STDERR,'>',$fh
  or croak STRERR($fh);

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

#in: two filepaths to compare
# Older Than; return a is older than b
sub ot($a,$b) {
  return !( (-M $a) < (-M $b) );

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
# in: filepath
# get name of file without the path

sub basename($name) {
  my @tmp=split '/',$name;
  $name=$tmp[$#tmp];

  return $name;

};

# ^ removes extension(s)
sub nxbasename($path) {
  my $name=basename($path);
  $name=~ s/\..*//;

  return $name;

};

# ^ get dir of filename...
# or directory's parent

sub dirof($path) {

  my @tmp=split('/',$path);
  $path=join('/',@tmp[0..($#tmp)-1]);

  return abs_path($path);

};

# ^ oh yes
sub parof($path) {
  return dirof(dirof($path));

};

# ---   *   ---   *   ---

sub relto($par,$to) {
  my $full="$par$to";
  return File::Spec->abs2rel($full,$par);

};

# ---   *   ---   *   ---
# in: path to add to PATH, names to include
# returns a perl snippet as a string to be eval'd

sub reqin($path,@names) {

  my $s='push @INC,'."$path;\n";

  for my $name(@names) {
    $s.="require $name;\n";

  };

  return $s;

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
  my $fpath=root().'/.avto-modules';

  # just ensure we have these standard paths
  for my $path(

    root().'/bin',
    root().'/lib',
    root().'/include',
    root().'/trashcan',

  ) {if(!(-e $path)) {mkdir $path}};

# ---   *   ---   *   ---
# iter provided names

  my @ar=@{$CACHE{_scan}};
  while(@ar) {

    my ($mod,$excluded)=split m[\s],shift @ar;

    if(defined $excluded) {

      # handle exclude flag short
      if($excluded=~ m/-x/) {
        $excluded=shift @ar;
        $excluded=~ s/-x\s*//;

      # handle exclude flag long
      } elsif($excluded=~
          m/\-\-exclude\=[\w|\d]*/

      ) {
        $excluded=shift @ar;
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

    my $trsh=root()."/trashcan/$mod";
    my $modpath=root()."/$mod";

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

  my $src=root().'/.avto-modules';

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

  my $root=root();

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
    $trsh="./trashcan/$name";

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
      $lmod=~ s[${root}/${name}][];
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

    root().q{/}.$C{name},
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

  my $src=root()."/.avto-config";
  my $config=$CACHE{_config};

  store($config,$src) or croak STRERR($src);

};

# ---   *   ---   *   ---
# ^reads it in

sub read_config() {

  my $src=root()."/.avto-config";
  my $config=retrieve($src)
  or croak STRERR($src);

};

# ---   *   ---   *   ---
# TODO: take this out

sub getset($h,$key,$value) {

  if(defined $value) {
    $h->{$key}=$value;

  };return $h->{$key};

};

# ---   *   ---   *   ---
# gives up social life for programming

sub strlist($ar,$make_ref,%opts) {

  # opt defaults
  $opts{ident}//=0;

# ---   *   ---   *   ---

  my @list=@$ar;
  my ($beg,$end)=($make_ref)
    ? ('[',']') : ('(',')');

  if(!@list) {return "$beg$end"};

# ---   *   ---   *   ---

  my $ident=q{ } x($opts{ident});

  my $i=0;
  for my $item(@list) {
    $item=($ident x 2).sqwrap($item);
    $item.=",\n";

  };

# ---   *   ---   *   ---

  return

    "$beg\n\n".
    ( join q{},@list ).

    "\n$ident$end"

  ;

};

# ---   *   ---   *   ---
# shortens pathname for sanity

sub shpath($path) {

  my $root=abs_path(root());

  $path=~ s[^${root}][];
  return $path;

};

# ---   *   ---   *   ---

# emits builders
sub make {

  my $root=$CACHE{_root};

  # fetch project data
  my $modules=read_modules();
  my $configs=read_config();

  # now iter
  for my $name(keys %$configs) {

    my $C=$configs->{$name};

    my $module=$modules->{$name};
    my $avto_path="$root/$name/avto";

    # build the makescript object
    my $M={};
    get_config_build($M,$C);
    get_config_paths($M,$C);
    get_config_files($M,$C,$module);

    # save it to disk
    my $cache_path="$root/$name/.avto-cache";

    store($M,$cache_path)
    or croak STRERR($cache_path);

# ---   *   ---   *   ---
# now dump the boiler

    open my $FH,'>',$avto_path
    or croak STRERR($avto_path);

    my $FILE=$NULLSTR;

    # write notice
    $FILE.='#!/usr/bin/perl'."\n";
    $FILE.=note('IBN-3DILA','#');

    # paste in the pre-build hook

    if(length $C->{pre_build}) {
      $FILE.=

      "\n\n".

      'INIT {'."\n\n".

        'print "'.
        $avt::ARSEP.
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

  use avt;
  use makescript;

# ---   *   ---   *   ---

my $PFLG='-m64';
my $DFLG='';

my $root=avt::parof(__FILE__);
my $M=retrieve(

  avt::dirof(__FILE__).
  '/.avto-cache'

);

chdir $root;

$M->{root}=$root;
$M->{trash}='./trashcan/'.$M->{fswat};

$M=makescript::nit($M);

# ---   *   ---   *   ---

print {*STDERR}
  $avt::ARTAG."upgrading $M->{fswat}\n";

$M->set_build_paths();
$M->update_generated();

my ($OBJS,$objblt)=
  $M->update_objects($DFLG,$PFLG);

$M->build_binaries($PFLG,$OBJS,$objblt);
$M->update_regular();

print {*STDERR}
  $avt::ARSEP."done\n\n";

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
        $avt::ARSEP.
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

    `chmod +x "$CACHE{_root}/$name/avto"`

  };
};

# ---   *   ---   *   ---
1; # ret
