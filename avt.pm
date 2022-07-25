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

  our $VERSION=v3.21.0;
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

  Readonly my $BIND='./bin';
  Readonly my $LIBD='./lib';

# ---   *   ---   *   ---
# gcc switches

  Readonly my $OFLG=>
    q{-s -Os -fno-unwind-tables}.q{ }.
    q{-fno-asynchronous-unwind-tables}.q{ }.
    q{-ffast-math -fsingle-precision-constant}.q{ }.
    q{-fno-ident -fPIC}

  ;

  Readonly my $LFLG=>
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

    _config=>[],
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

sub MODULES {return split ' ',$CACHE{_modules};};

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

        my @ar=split m[\n],`cat $ldir/.$lbin`;

        my $ndeps.=(defined $ar[0])
          ? $ar[0] : $NULLSTR;

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

  for my $fn_name(keys %symtab) {

    my $data=$symtab{$fn_name};

    my $rtype=shift @$data;
    my $arg_types=shift @$data;
    my $arg_names=shift @$data;

    $rtype=pytypecon($rtype);

    for my $type(@$arg_types) {
      $type=pytypecon($type);

    };

    push @names,$fn_name;
    push @rtypes,$rtype;

    push @arg_types,
      '['.(join q{,},@$arg_types).']';

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
# iter through expressions

  for my $sbl($tree->branches_in($sbl_key)) {

    my $id=$sbl->leaf_value(0);
    my $src=$rd->select_block($id);

    my $attrs=$src->{attrs};
    my $name=$src->{name};
    my $args=$src->{args};

    my $type=typecon($attrs);

# ---   *   ---   *   ---
# save args

    my $match="$name $type";

    $args=~ s/$lang->{strip_re}//sg;
    $args=~ s/^\s*\(|\)\s*$//sg;

    my @args=split $COMMA_RE,$args;

    while(@args) {

      my $arg=shift @args;
      $arg=~ s/^\s+|\s+$//;

      my ($arg_attrs,$arg_name)=
        split $SPACE_RE,$arg;

      # is void
      if(!defined $arg_name) {last};

      my $arg_type=typecon($arg_attrs);

      # has type
      $match.=" $arg_type $arg_name";

# ---   *   ---   *   ---
# append results

    };$match=~ s/\s+/ /sg;
    $found.="$match\n";

  };return $found;
};

# ---   *   ---   *   ---
# in:modname,[files]
# write symbol typedata (return,args) to shadow lib

sub symscan($mod,@fnames) {

  stinc($CACHE{_root}."/$mod/");

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

  my $dst=$CACHE{_root}."/lib/.$mod";
  my $deps=(split "\n",`cat $dst`)[0];

  open my $FH,'>',$dst or croak STRERR($dst);
  print $FH "$deps\n";

# ---   *   ---   *   ---
# iter through files

  for my $f(@files) {
    if(!$f) {next;};

    # save filename
    print $FH "$f:\n";
    print $FH file_sbl($f);

  };close $FH;

};

# ---   *   ---   *   ---

# in:modname
# get symbol typedata from shadow lib
sub symrd {

  my $mod=shift;
  my $src=$CACHE{_root}."/lib/.$mod";

  # existence check
  if(!(-e $src)) {
    print "Can't find $mod shadow lib\n";
    return undef;

  };

  # read lib and discard deps
  my @symbols=split "\n",`cat $src`;
  shift @symbols;

# ---   *   ---   *   ---

  # iter symbols
  my %h=('files'=>[]);while(@symbols) {

    my $line=shift @symbols;

    # entry is filename
    if($line=~ m/.*\:/) {
      $line=~ s/\://;

      # transform into path to equivalent object file
      $line=~ s/^\./trashcan/;
      $line=~ s/\.[\w|\d]*$/\.o/;
      $line=~ s/${ CACHE{_root} }//;

      $line= "${ CACHE{_root} }/$line";

      push @{ $h{'files'} },$line;
      next;

    };

    # is symbol data
    my @symbol=split(' ',$line);

    my $key=shift @symbol;
    if(!(defined $key)) {next;};

    my $ret=shift @symbol;
    $ret=(!(defined $ret)) ? 'void' : $ret;

    # h[symbol_name]=return type,(types),(names)
    if(@symbol) {
      $h{$key}=[$ret,[],[]];

    # void arguments
    } else {
      $h{$key}=[$ret,['void'],['']];

    };

    my $ref0=@{ $h{$key} }[1];
    my $ref1=@{ $h{$key} }[2];

    # iter through args
    while(@symbol) {
      my $arg_type=shift @symbol;
      my $arg_name=shift @symbol;

      push @$ref0,$arg_type;
      push @$ref1,$arg_name;

    };

  };return \%h;

};

# ---   *   ---   *   ---
# rebuilds shared objects if need be

sub soregen($soname,$libs_ref,$no_regen=0) {

  my $sopath="$CACHE{_root}/lib/lib$soname.so";
  my $so_gen=!(-e $sopath);

  my @libs=@{$libs_ref};
  my %symtab=();

# ---   *   ---   *   ---

  # make symbol table
  for my $lib(@libs) {
    %symtab=(%symtab,%{ avt::symrd($lib) });

    # so regen check
    if(!$so_gen) {
      $so_gen=ot($sopath,ffind('-l'.$lib));

    };

  };

  # get object file list
  my @o_files=@{ $symtab{'files'} };
  delete $symtab{'files'};

# ---   *   ---   *   ---

  # generate so
  if($so_gen && !$no_regen) {

    # recursively get dependencies
    my $O_LIBS='-l'.( join ' -l',@libs );
    stlib("$CACHE{_root}/lib/");

    my $LIBS=avt::libexpand($O_LIBS);
    my $OBJS=join ' ',@o_files;

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
;print $FH $search;

# ---   *   ---   *   ---

  # attach symbols from table
  my $tab='';
  for my $name(keys %symtab) {

    my $ar=@{ $symtab{$name} }[1];
    for my $s(@$ar) {
      $s=sqwrap($s);

    };

    my $arg_types='['.( join(
      ',',@$ar

    )).']';$tab.=''.
      "my \$$name=\'$name\';\n".

      '$ffi->attach('.
      "\$$name,".
      "$arg_types,".
      "'$symtab{$name}->[0]');\n\n";

  };

  my $nit='$CACHE{nitted}=1;';
  my $callnit

    ='(\&nit,$NOOP)'.
    '[$CACHE{nitted}]->();';

  print $FH $tab."\n$nit\n};$callnit\n";

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

# in=string
# read comma-separated list
sub rcsl($in) {

  my @ar=();
  my $item='';

  my $is_list=0;

# ---   *   ---   *   ---
# get sub up to comma

  while($in) {

    my $s=substr $in,0,(index $in,',');
    $item.=$s;

    # on [item,item] format
    if((index $s,'[')>=0) {
      $is_list|=1;

    } elsif((index $s,']')>=0) {
      $is_list|=2;

    };

    # clear s(,)
    $in=~ s/[\,]?//;
    $in=substr $in,(length $s)+1,length $in;

# ---   *   ---   *   ---
# appending

    if(!$is_list) {
      push @ar,[$item];
      $item='';

# ---   *   ---   *   ---
# list close

    } elsif($is_list&2) {

      $item=~ s/\\\\\[//g;
      $item=~ s/\\\\\]//g;

      push @ar,[lang::ws_split($COMMA_RE,$item)];

      $item=$NULLSTR;
      $is_list&=~3;

# ---   *   ---   *   ---
# list opened

    } elsif($is_list) {
      $item.=',';

    };

# ---   *   ---   *   ---
# append leftovers

  };

  if($item) {
    $item=~ s/\\\\\[//g;
    $item=~ s/\\\\\]//g;

    push @ar,[lang::ws_split($COMMA_RE,$item)];

  };

  return \@ar;

};

# ---   *   ---   *   ---
# path utils

# args=chkpath,name,repo-url,actions
# pulls what you need

sub depchk($chkpath,$deps) {

  $chkpath=abs_path($chkpath);

  my @deps=@{ $deps_ref };
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

  my $module_list='';
  my $fpath=root().'/.avto-modules';

  # just ensure we have these standard paths
  for my $path(

    root().'/bin',
    root().'/lib',
    root().'/include'
    root().'/trashcan'

  ) {if(!(-e $path)) {mkdir $path}};

# ---   *   ---   *   ---
# iter provided names

  my @ar=@{$CACHE{_scan}};
  while(@ar) {

    my $mod=shift @ar;
    my $excluded=undef;

    if(defined $ar[0]) {

      # handle exclude flag short
      if($ar[0]=~ m/-x/) {
        $excluded=shift @ar;
        $excluded=~ s/-x\s*//;

      # handle exclude flag long
      } elsif($ar[0]=~
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

    # walk module path and capture sub count
    my %h=%{ walk($modpath) };
    my $list={};

    # paths/dir checks
    for my $dir (keys %h) {

      if( defined $excluded
      &&  $dir=~ m/$excluded/

      ) {next};

      # ensure directores exist
      my $tsub=$trsh.$dir;
      $tdir=~ s[<main>][/];

      if(!(-e $tdir)) {
        `mkdir -p $tdir`;

      };

      # capture file list
      $list->{$dir}=$h{$dir};

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
      lang::ws_split($COLON_RE,$build);

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

  $M->{libs}=$LIBD.q{ }.(
    join q{ },@{$config->{libs}}

  );

  $incl=$INCD.q{ }.$incl;
  $M->{include}=$INCD.q{ -I./ }.(
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

sub get_config_files($M,$config) {

  $M->{xcpy}=[];
  $M->{lcpy}=[];
  $M->{xprt}=[];
  $M->{gens}=[];

# ---   *   ---   *   ---

  my @$matches=lfind($config->{gens},$files)

  while(@$matches) {

    my $match=shift @$matches;
    my ($outfile,$srcs)=@{
      $config->{gens}->{$match}

    };

    delete $config->{gens}->{$match};
    $match=~ s[\*][];

    push @{$M->{gens}},(
      "$mod/$match",
      "$mod/$outfile",

      (join q{,},@$srcs)

    );

  };

# ---   *   ---   *   ---

  my $matches=lfind($config->{xcpy},$files);

  while(@$matches) {

    my $match=shift @$matches;
    delete $config->{xcpy}->{$match};

    $match=~ s[\*][];
    $match=~ s[\\][]g;

    push @{$M->{xcpy}},(
      "$mod/$match",
      "$BIND/$match"

    );

  };

# ---   *   ---   *   ---

  my $matches=lfind($config->{lcpy},$files);

  while(@$matches) {
    my $match=shift @$matches;
    delete $config->{lcpy}->{$match};

    $match=~ s[\\][]g;

    my $lmod=$mod;
    $lmod=~ s[${root}/${name}][];
    $lmod.=($lmod) ? q{/} : $NULLSTR;

    push @{$M->{lcpy}},(
      "$mod/$match",
      "$LIBD/$lmod$match"

    );

  };

# ---   *   ---   *   ---

  my $matches=lfind($config->{xprt},$file);

  while(@$matches) {
    my $match=shift @$matches;
    delete $config->{xprt}->{$match};

    $match=~ s/\\//g;
    push @{$M->{xprt}},"$match";

  };

};

# ---   *   ---   *   ---
# registers module configuration

sub set_config(%C) {

  state $sep_re=lang::ws_split_re(q{,});
  state $list_to_hash=>qr{(?:

    lcpy
  | xcpy
  | xprt

  )}x;

# ---   *   ---   *   ---

  $modules=$CACHE{_modules};
  $scan=$CACHE{_scan};

  # ensure all needed fields are there
  for my $key(@{ $CACHE{_config_fields} }) {
    if(!(exists $C{$key})) {
      $C{$key}=$CONFIG_DEFAULT;

    };
  };

# ---   *   ---   *   ---
# sanitize input

  for my $key(keys %C) {

    if($key eq 'scan') {
      if($C{$key} eq $CONFIG_DEFAULT) {
        $C{$key}=$NULLSTR;

      };

    } else {
      $C{$key}=~ s/\s+//;

    };

# ---   *   ---   *   ---
# convert file lists to hashes

    if($key=~ $list_to_hash) {

      if(length $C{$key}) {
        $C{$key}={
          map {$ARG=>1} @{$C{$key}}

        };

      } else {
        $C{$key}={};

      };

    };

# ---   *   ---   *   ---
# run dependency checks

  };

  depchk(

    root().q{/}.$C{name},
    $C{deps};

  ) if $C{deps} ne $CONFIG_DEFAULT;

# ---   *   ---   *   ---
# prepare the libs && includes

  for my $lib(@{$C->{libs}}) {
    if((index $lib,q{/})>=0) {
      $lib=q{-L}.$lib;

    } else {
      $lib=q{-l}.$lib;

    };
  };

  for my $include(@{$C->{incl}}) {
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

  for my $outfile(keys $C{gens}) {

    my $srcs=$C{gens}->{$outfile};
    my $exec=shift @$srcs;

    for my $src(@$srcs) {
      $gens->{$src}=$exec;

    };

    $gens{$exec}=[$outfile,\@srcs];

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
# makes file list out of gcc .d files

sub parsemmd($dep) {

  my $out=[];
  if(!(-e $dep)) {goto TAIL};

  $dep=arstd::orc($dep);
  $dep=~ s/\\//g;
  $dep=~ s/\s/\,/g;
  $dep=~ s/.*\://;

# ---   *   ---   *   ---

  my @tmp=lang::ws_split($COMMA_RE,$dep);
  my @deps=();

  while(@tmp) {
    my $f=shift @tmp;
    if($f) {push @deps,$f;};

  };

# ---   *   ---   *   ---

  $out=\@deps;

TAIL:
  return $out;

};

# ---   *   ---   *   ---
# makes file list out of pcc .pmd files

sub parsepmd {

  my $dep=shift;
  my $out=[];

  if(!(-e $dep)) {goto TAIL};

  open my $FH,'<',$dep or croak STRERR($dep);

  my $fname=readline $FH;
  my $depstr=readline $FH;

  close $FH;

  if(!defined $fname || !defined $depstr) {
    goto TAIL;

  };

  my @tmp=lang::ws_split($SPACE_RE,$depstr);
  my @deps=();

  while(@tmp) {
    my $f=shift @tmp;
    if($f) {push @deps,$f};

  };

# ---   *   ---   *   ---

  $out=\@deps;

TAIL:
  return $out;

};

# ---   *   ---   *   ---
# shortens pathname for sanity

sub shpath($path) {

  $path=~ s/${ CACHE{_root} }//;
  return $path;

};

# ---   *   ---   *   ---

# emits builders
sub make {

  my $root=$CACHE{_root};

# ---   *   ---   *   ---

  # fetch project data
  my $modules=read_modules();
  my $config=read_config();

  # now iter
  for my $C(keys %$config) {

    my (
      $name,
      $build,

      $xcpy,
      $lcpy,
      $xprt,

      $gens,
      $libs,
      $incl,

      $defs

    )=lang::ws_split($SPACE_RE,shift @config);

    my @paths=@{ $modules{$name} };

    my $avto_path="$root/$name/avto";

    open my $FH,'>',$avto_path
    or croak STRERR($avto_path);

    my $FILE=$NULLSTR;

    $FILE.='#!/usr/bin/perl'."\n";

    # accumulate to these vars
    my @SRCS=();
    my @OBJS=();
    my @GENS=();

    my $src_rcees='';
    my $gens_rcees='';

# ---   *   ---   *   ---

    # write notice and vars
    $FILE.=note('IBN-3DILA','#');

# ---   *   ---   *   ---

$FILE.=

"\n\n".

'BEGIN {'."\n\n".
  $CACHE{_pre_build}->{$name}.';'.
  "\n\n".

"};\n";

    $FILE.=<<'EOF'

# ---   *   ---   *   ---
#deps

  use 5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use avt;

# ---   *   ---   *   ---

my $PFLG='-m64';
my $DFLG='';

# ---   *   ---   *   ---

my $M=avt::new_maker(

EOF
;

# ---   *   ---   *   ---

    while(@paths) {
      my @path=@{ shift @paths };
      my $mod=shift @path;
      my $trsh=$NULLSTR;

      my $modname=$mod;

      if((index $mod,q{/})==0) {
        $mod=substr $mod,1,length $mod;

      };

      # get path to
      ($mod,$trsh)=($mod eq '<main>')
        ? ("./$name","./trashcan/$name")
        : ("./$name/$mod","./trashcan/$name/$mod")
        ;

# ---   *   ---   *   ---
# get *.c files

      { my $ext=qr{\.c$};

        my @matches=grep
          m/${ext}/,@path;

        if(@matches) {

          while(@matches) {
            my $match=shift @matches;
            $match=~ s/\\//g;

            my $ob=$match;$ob=(substr $ob,0,
              (length $ob)-1).'o';

            my $dep=$match;$dep=(substr $dep,0,
              (length $dep)-1).'d';

            push @SRCS,"$mod/$match";

            push @OBJS,(
              "$trsh/$ob",
              "$trsh/$dep"

            );

          };
        };

# ---   *   ---   *   ---
# get *.pm files

      };{

        my @matches=grep
          m/.\.pm/,@path;

        if(@matches) {

          while(@matches) {
            my $match=shift @matches;
            $match=~ s/\\//g;

            my $dep=$match;
            $dep.='d';

            push @SRCS,"$mod/$match";

            my $lmod=$mod;
            $lmod=~ s/[.]\/${name}//;

            push @OBJS,(
              "$LIBD$lmod/$match",
              "$trsh/$dep"

            );

          };
        };

      };
    };

# ---   *   ---   *   ---

$FILE.=<<';;EOF'


# ---   *   ---   *   ---

avt::root $M->{ROOT};
chdir $M->{ROOT};

print {*STDERR}
  $avt::ARTAG."upgrading $M->{FSWAT}\n";

$M->set_build_paths();
$M->update_generated();

my ($OBJS,$objblt)=$M->update_objects($DFLG,$PFLG);

$M->build_binaries($PFLG,$OBJS,$objblt);
$M->update_regular();

print {*STDERR}
  $avt::ARSEP."done\n\n";

;;EOF
;
    print $FH $FILE.

    #"\n".
    '# ---   *   ---   *   ---'.
    "\n\n".

    "END {\n\n".
      $CACHE{_post_build}->{$name}.';'.

    "\n\n};".

    "\n\n".

    '# ---   *   ---   *   ---'.
    "\n\n"

    ;

    close $FH;
    `chmod +x "$CACHE{_root}/$name/avto"`

  };
};

# ---   *   ---   *   ---

sub set_build_paths($M) {

  my @paths=();
  for my $inc(lang::ws_split(
    $SPACE_RE,$M->{INCLUDES})

  ) {

    if($inc eq "-I".root) {next};
    push @paths,$inc;

  };

  stinc(@paths,q{.},'-I'.root."/$M->{FSWAT}");

};

# ---   *   ---   *   ---

package makescript;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use English qw(-no_match_vars);

  use Cwd qw(abs_path getcwd);

  use lib $ENV{'ARPATH'}.'/lib/hacks';
  use shwl;

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;

  use lang;
  use avt;

# ---   *   ---   *   ---

sub nit(%attrs) {

  # something something run on ./avto
  $M->{root}=avt::parof(__FILE__);
  $M->{trash}='./trashcan/'.$M->{fswat};

};

# ---   *   ---   *   ---

sub update_generated($M) {

  my @GENS=@{$M->{GENS}};

  if(@GENS) {

    print {*STDERR}
      $ARSEP."running generators\n";

  };

  # iter the list of generator scripts
  # ... and sources/dependencies for them
  while(@GENS) {

    my $gen=shift @GENS;
    my $res=shift @GENS;

    my @msrcs=lang::ws_split(
      $COMMA_RE,shift @GENS

    );

# ---   *   ---   *   ---
# make sure we don't need to update

    my $do_gen=!(-e $res);
    if(!$do_gen) {$do_gen=ot($res,$gen);};

# ---   *   ---   *   ---
# make damn sure we don't need to update

    if(!$do_gen) {
      while(@msrcs) {
        my $msrc=shift @msrcs;

        # look for wildcard
        if($msrc=~ m/\%/) {
          my @srcs=@{ avt::wfind($msrc) };
          while(@srcs) {
            my $src=shift @srcs;

            # found file is updated
            if(avt::ot($res,$src)) {
              $do_gen=1;last;

            };
          };if($do_gen) {last};

# ---   *   ---   *   ---

        # look for specific file
        } else {
          $msrc=avt::ffind($msrc);
          if(!$msrc) {next};

          # found file is updated
          if(avt::ot($res,$msrc)) {
            $do_gen=1;
            last;

          };

        };
      };
    };

# ---   *   ---   *   ---
# run the generator script

    if($do_gen) {

      print {*STDERR}
        shpath($gen)."\n";

      `$gen`;

    };

  };
};

# ---   *   ---   *   ---

sub update_regular($M) {

  my @FCPY=@{$M->{FCPY}};

  if(@FCPY) {

    print {*STDERR}
      $ARSEP."copying regular files\n";

  };

  while(@FCPY) {
    my $og=shift @FCPY;
    my $cp=shift @FCPY;

    my @ar=split '/',$cp;
    my $base_path=join '/',@ar[0..$#ar-1];

    if(!(-e $base_path)) {
      `mkdir -p $base_path`;

    };

    my $do_cpy=!(-e $cp);

    if(!$do_cpy) {$do_cpy=avt::ot($cp,$og);};
    if($do_cpy) {

      print {*STDERR} "$og\n";
      `cp $og $cp`;

    };

  };

};

# ---   *   ---   *   ---

sub update_objects($M,$DFLG,$PFLG) {

  my @SRCS=@{$M->{SRCS}};
  my @OBJS=@{$M->{OBJS}};

  my $INCLUDES=$M->{INCLUDES};

  my $OBJS=$NULLSTR;
  my $objblt=0;

  if(@SRCS) {

    print {*STDERR}
      $ARSEP."rebuilding objects\n";

  };

# ---   *   ---   *   ---
# iter list of source files

  for(my ($i,$j)=(0,0);$i<@SRCS;$i++,$j+=2) {

    my $src=$SRCS[$i];

    my $obj=$OBJS[$j+0];
    my $mmd=$OBJS[$j+1];

    if($src=~ lang->perl->{ext}) {
      $M->pcc($src,$obj,$mmd);
      next;

    };

    $OBJS.=$obj.q{ };
    my @deps=($src);

# ---   *   ---   *   ---
# look at *.d files for additional deps

    my $do_build=!(-e $obj);
    if($mmd) {
      @deps=@{parsemmd($mmd)};

    };

    # no missing deps
    static_depchk($src,\@deps);

    # make sure we need to update
    buildchk(\$do_build,$obj,\@deps);

# ---   *   ---   *   ---
# rebuild the object

    if($do_build) {

      print {*STDERR} avt::shpath($src)."\n";
      my $asm=$obj;$asm=substr(
        $asm,0,(length $asm)-1

      );$asm.='asm';

      my $call=''.
        "gcc -MMD $OFLG ".
        "$INCLUDES $DFLG $PFLG ".
        "-Wa,-a=$asm -c $src -o $obj";

      `$call`;

      $objblt++;

    };

# ---   *   ---   *   ---
# return string containing list of objects
# + the count of objects built

  };

  return $OBJS,$objblt;

};

# ---   *   ---   *   ---
# the one we've been waiting for

sub build_binaries($M,$PFLG,$OBJS,$objblt) {

# ---   *   ---   *   ---
# this sub only builds a new binary IF
# there is a target defined AND
# any objects have been updated

  if($M->{MAIN} && $objblt) {

    print {*STDERR }
      $ARSEP.'compiling binary '.

      "\e[32;1m".
      avt::shpath($M->{MAIN}).

      "\e[0m\n";

# ---   *   ---   *   ---
# build mode is 'static library'

  if($M->{LMODE} eq 'ar') {
    my $call="ar -crs $M->{MAIN} $OBJS";
    `$call`;

    `echo "$M->{LIBS}" > $M->{ILIB}`;
    avt::symscan($M->{FSWAT},@{$M->{XPRT}});

# ---   *   ---   *   ---
# otherwise it's executable or shared object

  } else {

    if(-e $M->{MAIN}) {
      `rm $M->{MAIN}`;

    };

# ---   *   ---   *   ---
# find any additional libraries we might
# need to link against

    my $LIBS=avt::libexpand($M->{LIBS});

# ---   *   ---   *   ---
# build call is the exact same,
# only difference being the -shared flag

    my $call="gcc $M->{LMODE} ".
      "$OFLG $LFLG ".
      "$M->{INCLUDES} $PFLG $OBJS $LIBS ".
      " -o $M->{MAIN}";

#      `$call`;
#      `echo "$LIBS" > $M->{ILIB}`;

# ---   *   ---   *   ---
# for executables we spawn a shadow lib

    if($M->{LMODE} ne '-shared ') {
      $call="ar -crs $M->{MLIB} $OBJS";`$call`;

      `echo "$LIBS" > $M->{ILIB}`;
      avt::symscan($M->{FSWAT},@{$M->{XPRT}});

    };

  }};

};

# ---   *   ---   *   ---

sub static_depchk($src,$deps) {

  for(my $x=0;$x<@$deps;$x++) {
    if($deps->[$x] && !(-e $deps->[$x])) {

      arstd::errout(

        "%s missing dependency %s\n",

        args=>[avt::shpath($src),$deps->[$x]],
        lvl=>$FATAL,

      );
    };
  };
};

# ---   *   ---   *   ---

sub buildchk($do_build,$obj,$deps) {

  if(!$$do_build) {
    while(@$deps) {
      my $dep=shift @$deps;
      if(!(-e $dep)) {next};

      # found dep is updated
      if(avt::ot($obj,$dep)) {
        $$do_build=1;
        last;

      };
    };
  };
};

# ---   *   ---   *   ---
# 0-800-Call MAM

sub pcc($M,$src,$obj,$pmd) {

  if($src=~ m[MAM\.pm]) {
    goto TAIL;

  };

  my @deps=($src);

# ---   *   ---   *   ---
# look at *.d files for additional deps

  my $do_build=!(-e $obj);

  if($pmd) {
    @deps=@{parsepmd($pmd)};

  };

  # no missing deps
  static_depchk($src,\@deps);

  # make sure we need to update
  buildchk(\$do_build,$obj,\@deps);

# ---   *   ---   *   ---

  if($do_build) {

    print {*STDERR} "$src\n";

    my $ex=
      "perl".q{ }.

      "-I$ENV{ARPATH}/avtomat/".q{ }.
      "-I$ENV{ARPATH}/avtomat/hacks".q{ }.
      "-I$ENV{ARPATH}/avtomat/peso".q{ }.
      "-I$ENV{ARPATH}/avtomat/langdefs".q{ }.

      "-I$ENV{ARPATH}/$M->{FSWAT}".q{ }.
      "$M->{INCLUDES}".q{ }.

      "-MMAM=-md,--rap,--module=$M->{FSWAT}".q{ }.

      "$src";

    my $out=`$ex 2> $ENV{ARPATH}/avtomat/.errlog`;

    if(!length $out) {
      my $log=`cat $ENV{ARPATH}/avtomat/.errlog`;
      print {*STDERR} "$log\n";

    };

# ---   *   ---   *   ---

    my $re=$shwl::DEPS_RE;
    my $depstr;

    if($out=~ s/$re//sm) {
      $depstr=${^CAPTURE[0]};

    } else {
      croak "Can't fetch dependencies for $src";

    };

# ---   *   ---   *   ---

    for my $fname($obj,$pmd) {
      if(!(-e $fname)) {
        my $path=avt::dirof($fname);
        `mkdir -p $path`;

      };
    };

# ---   *   ---   *   ---

    my $FH;

    open $FH,'+>',$pmd or croak STRERR($pmd);
    print {$FH} $depstr;

    close $FH;

    open $FH,'+>',$obj or croak STRERR($obj);
    print {$FH} $out;

    close $FH;

  };

# ---   *   ---   *   ---

TAIL:
  return;

};

# ---   *   ---   *   ---
1; # ret

