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

  use peso::fndmtl;

# ---   *   ---   *   ---
# info

  our $VERSION=v3.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# read-only stuff

  use constant {

    ARTAG=>arstd::pretty_tag('AR'),
    ARSEP=>"\e[37;1m::\e[0m",

    BOXCHAR        => '.',
    CONFIG_DEFAULT => '#',

    # gcc switches

    OFLG           =>''.
      '-s -Os -fno-unwind-tables '.
      '-fno-asynchronous-unwind-tables '.
      '-ffast-math -fsingle-precision-constant '.
      '-fno-ident -fPIC ',

    LFLG           =>''.
      ' -flto -ffunction-sections '.
      '-fdata-sections -Wl,--gc-sections '.
      '-Wl,-fuse-ld=bfd ',

    GITHUB=>'https://github.com',

  };use constant {

    LYEB=>GITHUB.'/Liebranca',

  };

# ---   *   ---   *   ---
# global storage

  my %CACHE=(
    -ROOT       =>  '.',
    -INCLUDE    =>   [],
    -LIB        =>   [],

    -CONFIG_FIELDS =>[

      'BUILD','XCPY','LCPY','INCL',
      'LIBS','GENS','DEFS','XPRT',

      'NAME','SCAN',

    ],

    -CONFIG=>'',
    -SCAN=>'',
    -MODULES=>'',

    -POST_BUILD=>{},
    -PRE_BUILD=>{},

  );

# ---   *   ---   *   ---

sub root($new=undef) {

  if(defined $new) {
    $CACHE{-ROOT}=abs_path($new);

  };

  return $CACHE{-ROOT};

};

# ---   *   ---   *   ---

sub MODULES {return split ' ',$CACHE{-MODULES};};

# ---   *   ---   *   ---
# add to search path (include)

sub stinc(@args) {

  my $ref=$CACHE{-INCLUDE};
  for my $path(@args) {

    $path=~ s/\-I//;
    $path=abs_path(glob($path));

    push @$ref,$path;

  };

};

# ---   *   ---   *   ---
# add to search path (library)

sub stlib(@args) {

  my $ref=$CACHE{-LIB};
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
    $ref=$CACHE{-LIB};
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
    $ref=$CACHE{-INCLUDE};
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
      lvl=>ERROR,

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

  my $found=NULLSTR;

# ---   *   ---   *   ---

  for my $lbin(@lbins) {
    for my $ldir(@lsearch) {

      # .lib file found
      if(-e "$ldir/.$lbin") {
        my $ndeps.=(split "\n",
          `cat $ldir/.$lbin`

        )[0];chomp $ndeps;

        $ndeps=join q{|},(
          lang::ws_split(SPACE_RE,$ndeps)

        );

# ---   *   ---   *   ---

        # filter out the duplicates
        my @matches=grep(
          m/${ ndeps }/,
          lang::ws_split(SPACE_RE,$deps)

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
  my @lsearch=@{ $CACHE{-LIB} };

# ---   *   ---   *   ---

  while(1) {
    my @lbins=();

    $ndeps=~ s/^\s+//;

    # get search path(s)
    for my $mlib(split(SPACE_RE,$ndeps)) {

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
  $deps=join q{|},(split(SPACE_RE,$deps));

  # filter out the duplicates
  my @matches=grep(
    m/${ deps }/,split(SPACE_RE,$LIBS)

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

  my $c=BOXCHAR;
  my $version=

  ("$c"x 32)."\n".sprintf(
    "$c %-28s $c\n",$l1

  )."$c ".(' 'x 28)." $c\n".

  sprintf("$c %-28s $c\n$c %-28s $c\n",$l2,$l3).

  ("$c"x 32)."\n";

  return $version;

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

  # create file
  open my $FH,'>',
    $CACHE{-ROOT}.$dir.$fname.'.h' or die STRERR;

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
    ($is_arr,$type)=lang::ws_split(COLON_RE,$type);
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

  my ($ret,$args)=lang::ws_split(COLON_RE,$type);
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

  $s=~ s/unsigned\s/u/;
  return $s;

};


# ---   *   ---   *   ---
# looks at a single file for symbols

sub file_sbl($f) {

  my $found='';
  my $langname=lang::file_ext($f);

# ---   *   ---   *   ---
# read source file

  my $program=peso::rd::parse(
    lang->$langname,
    peso::rd::FILE,

    $f,

    use_plps=>0,

  );

  my $lang=$program->lang;

# ---   *   ---   *   ---
# iter through expressions

  for my $exp(@{$program->{cooked}}) {

    $exp=(split m/:__COOKED__:/,$exp)[1];

    # is exp a symbol declaration?
    my $tree=$lang->plps_match(

      'sbl_decl',$exp

    );

    # ^this means 'no'
    if(!$tree->{full}) {next;};

# ---   *   ---   *   ---
# decompose the tree

    my @specs=$tree->branch_values(
      peso::fndmtl::BRANCH_RE()->{spec}

    );

    my @types=$tree->branch_values(
      peso::fndmtl::BRANCH_RE()->{type}

    );

    my @indlvl=$tree->branch_values(
      peso::fndmtl::BRANCH_RE()->{indlvl}

    );

    my @names=$tree->branch_values(
      peso::fndmtl::BRANCH_RE()->{bare}

    );

# ---   *   ---   *   ---
# apply type conversions across the hierarchy

    for my $type(@types) {

      my $indlvl=shift @indlvl;
      my $spec=shift @specs;

      #if(!$indlvl) {$indlvl='';};

      $indlvl=join NULLSTR,
        (split COMMA_RE,$indlvl);

      $spec=(length $spec)
        ? "$spec "
        : ''
        ;

      $type=typecon($spec.$type.$indlvl);

    };

# ---   *   ---   *   ---
# naming for clarity

    my %func=(

      name=>shift @names,
      type=>shift @types,

    );

# ---   *   ---   *   ---
# save args

    my $match="$func{name} $func{type}";
    while(@types) {

      # again, naming for clarity
      my %arg=(

        name=>shift @names,
        type=>shift @types,

      );

      # is void
      if(!defined $arg{name}) {last;};

      # has type
      $match.=" $arg{type} $arg{name}";

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

  stinc($CACHE{-ROOT}."/$mod/");

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

  my $dst=$CACHE{-ROOT}."/lib/.$mod";
  my $deps=(split "\n",`cat $dst`)[0];

  open my $FH,'>',$dst or die STRERR;
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
  my $src=$CACHE{-ROOT}."/lib/.$mod";

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
      $line=~ s/${ CACHE{-ROOT} }//;

      $line= "${ CACHE{-ROOT} }/$line";

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
  use strict;
  use warnings;

  use FFI::Platypus;
  use FFI::CheckLib;

  use lib $ENV{'ARPATH'}.'/lib/';
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
    $CACHE{-ROOT}.$dir.$fname.'.pm' or die STRERR;

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
sub ctopl {

  my $FH=shift;
  my $soname=shift;
  my $sopath="$CACHE{-ROOT}/lib/lib$soname.so";
  my $so_gen=!(-e $sopath);

  my @libs=@{ $_[0] };shift;
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
  if($so_gen) {

    # recursively get dependencies
    my $O_LIBS='-l'.( join ' -l',@libs );
    stlib("$CACHE{-ROOT}/lib/");

    my $LIBS=avt::libexpand($O_LIBS);
    my $OBJS=join ' ',@o_files;

    # link
    my $call='gcc -shared'.q{ }.
      OFLG.q{ }.LFLG.q{ }.
      "-m64 $OBJS $LIBS -o $sopath";

    `$call`;

  };

# ---   *   ---   *   ---

  my $search=<<"EOF"

my \%CACHE=(
  -FFI=>undef,
  -NITTED=>0,

);

sub ffi {return \$CACHE{-FFI};};

sub nit {

  if(\$CACHE{-NITTED}) {return;};

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
  \$CACHE{-FFI}=\$ffi;

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

  my $nit='$CACHE{-NITTED}=1;';
  my $callnit

    ='(\&nit,sub {;})'.
    '[$CACHE{-NITTED}]->();';

  print $FH $tab."\n$nit\n};$callnit\n";

};

# ---   *   ---   *   ---
# in: filepaths dst,src
# extends one perl file with another

sub plext {

  my $dst_path=root.(shift);
  my $src_path=root.(shift);

  my $src=`cat $src_path`;
  $src=~ s/.+#:CUT;>\n//sg;

  my $dst=`cat $dst_path`;
  $dst=~ s/1; # ret\n//sg;

  $dst.=$src;
  open FH,'>',$dst_path or die STRERR;
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
    or die STRERR

  ;return $fh;

# ---   *   ---   *   ---
# ^restore

};sub erropen($fh) {
  open(STDERR,">$fh");

};

# ---   *   ---   *   ---

# arg=string any
# multi-byte ord
sub mord {
  my @s=split '',shift;
  my $seq=0;
  my $i=0;while(@s) {
    $seq|=ord(shift @s)<<$i;$i+=8;

  };return $seq;
};

# ^ for wide strings
sub wmord {
  my @s=split '',shift;
  my $seq=0;
  my $i=0;while(@s) {
    $seq|=ord(shift @s)<<$i;$i+=16;

  };return $seq;
};

# arg=int arr
# multi-byte chr
sub mchr {
  my @s=@_;

  for my $c(@s) {
    $c=chr($c)

  };return @s;
};

#in: two filepaths to compare
# Older Than; return a is older than b
sub ot {
  return !( (-M $_[0]) < (-M $_[1]) );

};

# ---   *   ---   *   ---

sub sqwrap {
  return "'".shift."'";

};

sub dqwrap {
  return '"'.shift.'"';

};

sub ex {

  my $name=shift @_;
  my $opts=shift @_;
  my $tail=shift @_;

  my @opts=@{ $opts };

  for(my $i=0;$i<@opts;$i++) {
    if(($opts[$i]=~ m/\s/)) {
      $opts[$i]=dqwrap $opts[$i];

    };
  };

  return `$ENV{'ARPATH'}/bin/$name @opts $tail`;

};

# ---   *   ---   *   ---

# in: filepath
# get name of file without the path
sub basename {
  my $name=shift;{
    my @tmp=split '/',$name;
    $name=$tmp[$#tmp];

  };return $name;
};

# ^ removes extension(s)
sub nxbasename {
  my $name=basename($_[0]);
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

sub reqin {

  my $path=shift;
  my @names=@_;

  my $s='push @INC,'."$path;\n";

  for my $name(@names) {
    $s.="require $name;\n";

  };return $s;

};

# ---   *   ---   *   ---

# in=string
# read comma-separated list
sub rcsl {

  my $in=shift;
  my @ar=();
  my $item='';

  my $is_list=0;

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

    # list close
    } elsif($is_list&2) {

      $item=~ s/\\\\\[//g;
      $item=~ s/\\\\\]//g;

      push @ar,[lang::ws_split(COMMA_RE,$item)];
      $item='';$is_list&=~3;

    # list opened
    } elsif($is_list) {
      $item.=',';

    };

  # append leftovers
  };if($item) {
    $item=~ s/\\\\\[//g;
    $item=~ s/\\\\\]//g;

    push @ar,[lang::ws_split(COMMA_RE,$item)];

  };return \@ar;

};

# ---   *   ---   *   ---
# path utils

# args=chkpath,name,repo-url,actions
# pulls what you need
sub depchk {
  my ($chkpath,$deps_ref)=@_;
  $chkpath=abs_path $chkpath;

  my @deps=@{ $deps_ref };
  my $old_cwd=abs_path getcwd();chdir $chkpath;

  while(@deps) {

    my ($name,$url,$act)=@{ shift @deps };

    # pull if dir not found in provided path
    if(!(-e $chkpath."/$name")) {
      `git clone $url`;

    # blank for now, use this for building extdeps
    };if($act) {
      ;

    };

  };chdir $old_cwd;

};

# ---   *   ---   *   ---

# args=path
# recursively list dirs and files in path
sub walk {

  my %dirs=();my $path=shift;

  # dissect recursive ls

  { my @ls=split "\n\n",`ls -FBR1 $path`;
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
      if(not defined $sub[1]) {next;};
      $sub[1]=~ s/^\s+|\s+$//;

# ---   *   ---   *   ---

      # filter out folders and headers
      my @tmp=split "\n",$sub[1];
      my @files=();

      while(@tmp) {
        my $entry=shift @tmp;
        if(($entry=~ m/\/|GNUmakefile|Makefile|makefile/)) {
          next;

        };push @files,$entry;

      };

      # dirs{folder}=ref(list of files)
      $dirs{ $sub[0] }=\@files;

    };

  };return (\%dirs);

};

# ---   *   ---   *   ---

# ensures trsh and bin exist, outs file/dir list
sub scan {

  my $module_list='';
  `echo -n '' > $CACHE{-ROOT}/.avto-modules`;

  # just ensure we have these standard paths
  if(!(-e "$CACHE{-ROOT}/bin")) {
    mkdir "$CACHE{-ROOT}/bin";

  };

  if(!(-e "$CACHE{-ROOT}/lib")) {
    mkdir "$CACHE{-ROOT}/lib";

  };

  if(!(-e "$CACHE{-ROOT}/include")) {
    mkdir "$CACHE{-ROOT}/include";

  };

  if(!(-e "$CACHE{-ROOT}/trashcan")) {
    mkdir "$CACHE{-ROOT}/trashcan";

  };open FH,'>',
      $CACHE{-ROOT}.'/.avto-modules' or  die STRERR;

# ---   *   ---   *   ---

  # iter provided names
  my @ar=split '<MOD>',$CACHE{-SCAN};
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

    $excluded//=NULLSTR;

    $excluded='('.(join q{|},
      'nytprof','docs','tests',
      lang::ws_split(COMMA_RE,$excluded)

    ).')';

    $excluded=qr{$excluded};

# ---   *   ---   *   ---

    my $trsh="$CACHE{-ROOT}/trashcan/$mod";
    my $modpath="$CACHE{-ROOT}/$mod";

    # ensure there is a trashcan
    if(!(-e $trsh)) {
      system 'mkdir',('-p',"$trsh");

    };

# ---   *   ---   *   ---

    # walk module path and capture sub count
    my %h=%{ walk($modpath) };
    my $len=(keys %h);

    my $list='';

    # paths/dir checks
    for my $sub (keys %h) {

      if(defined $excluded && $sub=~ m/$excluded/) {
        $len--;next;

      };

      # ensure directores exist
      my $tsub=$sub;
      $tsub=~ s/${ modpath }/${ trsh }/;

      if(!(-e $trsh)) {
        mkdir $tsub;

      };

      # capture file list
      my @files=@{ $h{$sub} };
      $list.="$sub ".(join ' ',@files)."\n";

# ---   *   ---   *   ---

    };print FH "$mod $len\n$list";
  };close FH;
};

# ---   *   ---   *   ---

# parse modules into hash
sub read_modules {

  my %h;{
    my @m=split "\n",`cat $CACHE{-ROOT}/.avto-modules`;

    # get parent name
    while(@m) {
      my ($key,$len)=lang::ws_split(SPACE_RE,shift @m);
      my @paths;

      # store submodules as references
      while($len--) {
        my @tmp=lang::ws_split(SPACE_RE,shift @m);
        push @paths,\@tmp;

      };

      # hash{parent}=( ($path,@files) );
      $h{$key}=\@paths;

    };
  };return \%h;

};

# ---   *   ---   *   ---

sub strconfig {

  my %config=%{ $_[0] };

  # ensure all needed fields are there
  for my $key(@{ $CACHE{-CONFIG_FIELDS} }) {
    if(!(exists $config{$key})) {
      $config{$key}=CONFIG_DEFAULT;

    };
  };

# ---   *   ---   *   ---
# sanitize input

  for my $key(keys %config) {

    if($key eq 'SCAN') {
      if($config{$key} eq CONFIG_DEFAULT) {
        $config{$key}='';

      };

    } else {
      $config{$key}=~ s/\s+//;

    };
  };

# ---   *   ---   *   ---
# append to scan list

  $CACHE{-MODULES}.=$config{'NAME'}.' ';
  $CACHE{-SCAN}.=$config{'NAME'}.'<MOD>';

  if(length $config{'SCAN'}) {
    $CACHE{-SCAN}.=$config{'SCAN'}.'<MOD>';

  };

# ---   *   ---   *   ---
# append to config

  $CACHE{-CONFIG}.=

    $config{'NAME' }.'<MOD>'.

    lang::lescap

    $config{'BUILD'}.' '.

    $config{'XCPY' }.' '.
    $config{'LCPY' }.' '.
    $config{'XPRT' }.' '.

    $config{'GENS' }.' '.
    $config{'LIBS' }.' '.
    $config{'INCL' }.' '.

    $config{'DEFS' }.' '.

  '<MOD>';

# ---   *   ---   *   ---
# save pre && post-build scripts if any

  if(exists $config{'PREB'}) {

    $CACHE{-PRE_BUILD}
    ->{$config{'NAME'}}
      =$config{'PREB'};

  } else {

    $CACHE{-PRE_BUILD}
    ->{$config{'NAME'}}
      ='';

  };

  if(exists $config{'POST'}) {

    $CACHE{-POST_BUILD}
    ->{$config{'NAME'}}
      =$config{'POST'};

  } else {

    $CACHE{-POST_BUILD}
    ->{$config{'NAME'}}
      ='';

  };

};

# ---   *   ---   *   ---
# create build config file

sub config {

  my @config=();
  my @ar=split '<MOD>',$CACHE{-CONFIG};

  open FH,'>',root."/.avto-config" or die STRERR;

  while(@ar) {
    my $mod=shift @ar;
    my $settings=shift @ar;

    print FH "$mod $settings\n";

  };close FH;

};

# ---   *   ---   *   ---
# TODO: take this out

sub getset {

  my $h=shift;
  my $key=shift;
  my $value=shift;

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

sub parsemmd {
  my $dep=shift;

  if(!(-e $dep)) {return [];};

  $dep=`cat $dep`;
  $dep=~ s/\\//g;
  $dep=~ s/\s/\,/g;
  $dep=~ s/.*\://;

  my @tmp=lang::ws_split(COMMA_RE,$dep);
  my @deps=();while(@tmp) {
    my $f=shift @tmp;
    if($f) {push @deps,$f;};

  };return \@deps;

};

# ---   *   ---   *   ---
# makes file list out of pcc .pmd files

sub parsepmd {

  my $dep=shift;
  my $out=[];

  if(!(-e $dep)) {goto TAIL};

  open my $FH,'<',$dep or croak STRERR;

  my $fname=readline $FH;
  my $depstr=readline $FH;

  close $FH;

  if(!defined $fname || !defined $depstr) {
    goto TAIL;

  };

  my @tmp=lang::ws_split(SPACE_RE,$depstr);
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

sub shpath {
  my $path=shift;
  $path=~ s/${ CACHE{-ROOT} }//;
  return $path;

};

my %maker_defaults=(

  FSWAT=>NULLSTR,
  LMODE=>NULLSTR,
  ROOT=>NULLSTR,
  MKWAT=>NULLSTR,

  BIN=>NULLSTR,
  MAIN=>NULLSTR,
  MLIB=>NULLSTR,
  ILIB=>NULLSTR,
  TRSH=>NULLSTR,
  LIBS=>NULLSTR,
  INCLUDES=>NULLSTR,
  SRCS=>[],
  XPRT=>[],
  OBJS=>[],
  GENS=>[],
  FCPY=>[],

);

# ---   *   ---   *   ---

sub new_maker(%attrs) {

  for my $key(keys %maker_defaults) {
    $attrs{$key}//=$maker_defaults{$key};

  };

# ---   *   ---   *   ---

  my $self=bless {

    FSWAT=>$attrs{FSWAT},
    LMODE=>$attrs{LMODE},
    ROOT=>$attrs{ROOT},
    MKWAT=>$attrs{MKWAT},

    BIN=>$attrs{BIN},
    MAIN=>$attrs{MAIN},
    MLIB=>$attrs{MLIB},
    ILIB=>$attrs{ILIB},
    TRSH=>$attrs{TRSH},
    LIBS=>$attrs{LIBS},
    INCLUDES=>$attrs{INCLUDES},
    SRCS=>$attrs{SRCS},
    XPRT=>$attrs{XPRT},
    OBJS=>$attrs{OBJS},
    GENS=>$attrs{GENS},
    FCPY=>$attrs{FCPY},

  };

};

# ---   *   ---   *   ---

# emits builders
sub make {

  # add these directories to search path
  # ... but only if they exist, obviously

  my $root=$CACHE{-ROOT};

  my $base_lib=(-e "$root/lib")
    ? '-L./lib' : NULLSTR;

  my $base_include=(-e "$root/include")
    ? '-I./include' : NULLSTR;

  my $bind='./bin';
  my $libd='./lib';

# ---   *   ---   *   ---

  # fetch dir/file list
  my %modules=%{ read_modules($root) };

  # fetch config
  my @config=split "\n",
    `cat $root/.avto-config`;

  # now iter
  while(@config) {

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

    )=lang::ws_split(SPACE_RE,shift @config);

    my @paths=@{ $modules{$name} };

    open FH,'>',
      "$root/$name/avto" or croak STRERR;

    my $FILE=NULLSTR;

    $FILE.='#!/usr/bin/perl'."\n";

    # accumulate to these vars
    my @SRCS=();
    my @XPRT=();
    my @OBJS=();
    my @GENS=();
    my @DEFS=();
    my @FCPY=();

    my $src_rcees='';
    my $gens_rcees='';

# ---   *   ---   *   ---

    # write notice and vars
    $FILE.=note('IBN-3DILA','#');

# ---   *   ---   *   ---

$FILE.=

"\n\n".

'BEGIN {'."\n\n".
  $CACHE{-PRE_BUILD}->{$name}.';'.
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
;   $FILE.="  FSWAT=>\"$name\",\n";

    my ($lmode,$mkwat)=($build ne CONFIG_DEFAULT)
      ? lang::ws_split(COLON_RE,$build)
      : (NULLSTR,NULLSTR)
      ;

    if($lmode eq 'so') {
      $lmode='-shared ';

    } elsif($lmode ne 'ar') {
      $lmode=NULLSTR;

    };

    $FILE.="  LMODE=>'$lmode',\n";

    $FILE.='  ROOT=>avt::parof(__FILE__)'.",\n";

    $FILE.="  MKWAT=>\"$mkwat\",\n\n";
    $FILE.="  BIN=>\"$bind\",\n";

    if($mkwat) {

      if($lmode eq 'ar') {
        $FILE.="  MAIN=>\"$libd/lib$mkwat.a\",\n";
        $FILE.="  MLIB=>undef;\n";
        $FILE.="  ILIB=>\"$libd/.$mkwat\",\n";

      } elsif($lmode eq '-shared ') {
        $FILE.="  MAIN=>\"$libd/lib$mkwat.so\",\n";
        $FILE.="  MLIB=>undef,\n";
        $FILE.="  ILIB=>\"$libd/.$mkwat\",\n";

      } else {
        $FILE.="  MAIN=>\"$bind/$mkwat\",\n";
        $FILE.="  MLIB=>\"$libd/lib$mkwat.a\",\n";
        $FILE.="  ILIB=>\"$libd/.$mkwat\",\n";

      };

    } else {
      $FILE.="  MAIN=>undef,\n";
      $FILE.="  MLIB=>undef,\n";
      $FILE.="  ILIB=>undef,\n";

    };

    $FILE.="  TRSH=>'.".
      "/trashcan/$name',\n";

# ---   *   ---   *   ---

    # parse libs listing
    { my @libs=($libs ne CONFIG_DEFAULT)
      ? lang::ws_split(COMMA_RE,$libs)
      : ()
      ;

      for my $lib(@libs) {
        if((index $lib,q{/})>=0) {
          $lib='-L'.$lib;

        } else {
          $lib='-l'.$lib;

        };
      };

      $libs=$base_lib.q{ }.(
        join { },@libs

      );

      $FILE.="  LIBS=>\"$libs\",\n";

    };

# ---   *   ---   *   ---

    # parse includes
    $incl=($incl ne CONFIG_DEFAULT)
      ? q{-I./}.(join q{ -I./},
          (lang::ws_split(COMMA_RE,$incl))

        )

      : NULLSTR
      ;

    $incl=$base_include." $incl";
    $FILE.="  INCLUDES=>\"$incl -I".
      './'."\",\n\n";

# ---   *   ---   *   ---

    # get list copy list A
    $xcpy=($xcpy ne CONFIG_DEFAULT)
      ? join q{|},(lang::ws_split(COMMA_RE,$xcpy))
      : NULLSTR
      ;

    # get list copy list B
    $lcpy=($lcpy ne CONFIG_DEFAULT)
      ? join q{|},(lang::ws_split(COMMA_RE,$lcpy))
      : NULLSTR
      ;

    # get exports list
    $xprt=($xprt ne CONFIG_DEFAULT)
      ? join q{|},(lang::ws_split(COMMA_RE,$xprt))
      : NULLSTR
      ;

# ---   *   ---   *   ---

    # get generator list
    my $gens_src=NULLSTR;
    my %gens_res=();

    { my @tmp1=($gens ne CONFIG_DEFAULT)
      ? @{ rcsl($gens) }
      : ()
      ;

      while(@tmp1) {
        my @l=@{ shift @tmp1 };

        my ($res,$src)=
          lang::ws_split(COLON_RE,shift @l);

        $res=~ s/\\//g;
        @l=(@l) ? @l : ();

        $gens_res{$src}=[$res,\@l];

      };$gens_src=join q{|},(keys %gens_res);

    };

# ---   *   ---   *   ---

    while(@paths) {
      my @path=@{ shift @paths };
      my $mod=shift @path;
      my $trsh=NULLSTR;

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

      # copy these to bin
      if($xcpy) {

        my @matches=grep
          m/${ xcpy }/,@path;

        while(@matches) {
          my $match=shift @matches;

          if(!$xcpy) {last};

          # pop match+(\*|) from string
          # makes perfect sense to me ;>
          $xcpy=~ s/\|?${ match }\\\*\|?//;
          $match=~ s/\*//;$match=~ s/\\//g;

          push @FCPY,(
            "$mod/$match",
            "$bind/$match"

          );

        };
      };

# ---   *   ---   *   ---

      # copy these to lib
      if($lcpy) {

        my @matches=grep
          m/${ lcpy }/,@path;

        while(@matches) {
          my $match=shift @matches;

          if(!$lcpy) {last;};

          $lcpy=~ s/\|?${ match }\|?//;
          $match=~ s/\\//g;

          my $lmod=$mod;
          $lmod=~ s/${root}\/${name}//;
          $lmod.=($lmod) ? q{/} : NULLSTR;

          push @FCPY,(
            "$mod/$match",
            "$libd/$lmod$match"

          );

        };
      };


# ---   *   ---   *   ---

      # copy these to include
      if($xprt) {

        my @matches=grep
          m/${ xprt }/,@path;

        while(@matches) {
          my $match=shift @matches;

          if(!$xprt) {last};
          $xprt=~ s/\|?${ match }\|?//;
          $match=~ s/\\//g;

          push @XPRT,"$mod/$match";

        };
      };

# ---   *   ---   *   ---

      # make generator rules
      if($gens_src) {

        my @matches=grep
          m/${ gens_src }/,@path;

        while(@matches) {
          my $match=shift @matches;

          if(!$gens_src) {last};

          $gens_src=~ s/\|?${ match }\\\*\|?//;
          $match=~ s/\*//;

          my ($res,$srcs)=@{
            $gens_res{$match.'\*'}

          };

          push @GENS,(
            "$mod/$match",
            "$mod/$res",

            join(',',@$srcs)

          );

        };
      };

# ---   *   ---   *   ---
# get *.c files

      { my @matches=grep
          m/.\.c/,@path;

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
              "$libd$lmod/$match",
              "$trsh/$dep"

            );

          };
        };

      };
    };

# ---   *   ---   *   ---

    my $mkvars="  SRCS=>".
      strlist(\@SRCS,1,ident=>2).q{,}."\n";

    $mkvars.="\n  XPRT=>".
      strlist(\@XPRT,1,ident=>2).q{,}."\n";

    $mkvars.="\n  OBJS=>".
      strlist(\@OBJS,1,ident=>2).q{,}."\n";

    $mkvars.="\n  GENS=>".
      strlist(\@GENS,1,ident=>2).q{,}."\n";

    $mkvars.="\n  FCPY=>".
      strlist(\@FCPY,1,ident=>2).q{,}."\n";

    $FILE.="$mkvars\n\n);\n\n";

$FILE.=<<';;EOF'


# ---   *   ---   *   ---

avt::root $M->{ROOT};
chdir $M->{ROOT};

print {*STDERR}
  avt::ARTAG."upgrading $M->{FSWAT}\n";

$M->set_build_paths();
$M->update_generated();

my ($OBJS,$objblt)=$M->update_objects($DFLG,$PFLG);

$M->build_binaries($PFLG,$OBJS,$objblt);
$M->update_regular();

print {*STDERR}
  avt::ARSEP."done\n\n";

;;EOF
;
    print FH $FILE.

    #"\n".
    '# ---   *   ---   *   ---'.
    "\n\n".

    "END {\n\n".
      $CACHE{-POST_BUILD}->{$name}.';'.

    "\n\n};".

    "\n\n".

    '# ---   *   ---   *   ---'.
    "\n\n"

    ;

    close FH;`chmod +x "$CACHE{-ROOT}/$name/avto"`
  };
};

# ---   *   ---   *   ---

sub set_build_paths($M) {

  my @paths=();
  for my $inc(lang::ws_split(SPACE_RE,$M->{INCLUDES})) {
    if($inc eq "-I".root) {next;};

    push @paths,$inc;

  };

  stinc(@paths,q{.},'-I'.root."/$M->{FSWAT}");

};

# ---   *   ---   *   ---

sub update_generated($M) {

  my @GENS=@{$M->{GENS}};

  if(@GENS) {

    print {*STDERR}
      ARSEP."running generators\n";

  };

  # iter the list of generator scripts
  # ... and sources/dependencies for them
  while(@GENS) {

    my $gen=shift @GENS;
    my $res=shift @GENS;

    my @msrcs=lang::ws_split(
      COMMA_RE,shift @GENS

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
          my @srcs=@{ wfind($msrc) };
          while(@srcs) {
            my $src=shift @srcs;

            # found file is updated
            if(avt::ot($res,$src)) {
              $do_gen=1;last;

            };
          };if($do_gen) {last;};

# ---   *   ---   *   ---

        # look for specific file
        } else {
          $msrc=avt::ffind($msrc);
          if(!$msrc) {next;};

          # found file is updated
          if(avt::ot($res,$msrc)) {
            $do_gen=1;last;

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
      ARSEP."copying regular files\n";

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

    if(!$do_cpy) {$do_cpy=ot($cp,$og);};
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

  my $OBJS=NULLSTR;
  my $objblt=0;

  if(@SRCS) {

    print {*STDERR}
      ARSEP."rebuilding objects\n";

  };

# ---   *   ---   *   ---
# iter list of source files

  for(my ($i,$j)=(0,0);$i<@SRCS;$i++,$j+=2) {

    my $src=$SRCS[$i];

    my $obj=$OBJS[$j+0];
    my $mmd=$OBJS[$j+1];

    if($src=~ shwl::IS_PERLMOD) {

      $M->pcc($src,$obj,$mmd);
      next;

    };

    $OBJS.=$obj.q{ };
    my @deps=($src);

# ---   *   ---   *   ---
# look at *.d files for additional deps

    my $do_build=!(-e $obj);if($mmd) {
      @deps=@{ parsemmd $mmd };

    };

    # no missing deps
    static_depchk($src,\@deps);

    # make sure we need to update
    buildchk(\$do_build,$obj,\@deps);

# ---   *   ---   *   ---
# rebuild the object

    if($do_build) {

      print {*STDERR} shpath($src)."\n";
      my $asm=$obj;$asm=substr(
        $asm,0,(length $asm)-1

      );$asm.='asm';

      my $call=''.
        "gcc -MMD ".OFLG." ".
        "$INCLUDES $DFLG $PFLG ".
        "-Wa,-a=$asm -c $src -o $obj";`$call`;

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
      ARSEP.'compiling binary '.

      "\e[32;1m".
      (shpath $M->{MAIN}).

      "\e[0m\n";

# ---   *   ---   *   ---
# build mode is 'static library'

  if($M->{LMODE} eq 'ar') {
    my $call="ar -crs $M->{MAIN} $OBJS";
    `$call`;

    `echo "$M->{LIBS}" > $M->{ILIB}`;
    symscan($M->{FSWAT},@{$M->{XPRT}});

# ---   *   ---   *   ---
# otherwise it's executable or shared object

  } else {

    if(-e $M->{MAIN}) {
      `rm $M->{MAIN}`;

    };

# ---   *   ---   *   ---
# find any additional libraries we might
# need to link against

    my $LIBS=libexpand($M->{LIBS});

# ---   *   ---   *   ---
# build call is the exact same,
# only difference being the -shared flag

    my $call="gcc $M->{LMODE} ".
      (OFLG.q{ }.LFLG).q{ }.
       "$M->{INCLUDES} $PFLG $OBJS $LIBS ".
       " -o $M->{MAIN}";

#      `$call`;
#      `echo "$LIBS" > $M->{ILIB}`;

# ---   *   ---   *   ---
# for executables we spawn a shadow lib

    if($M->{LMODE} ne '-shared ') {
      $call="ar -crs $M->{MLIB} $OBJS";`$call`;

      `echo "$LIBS" > $M->{ILIB}`;
      symscan($M->{FSWAT},@{$M->{XPRT}});

    };

  }};

};

# ---   *   ---   *   ---

sub static_depchk($src,$deps) {

  for(my $x=0;$x<@$deps;$x++) {
    if($deps->[$x] && !(-e $deps->[$x])) {

      arstd::errout(

        "%s missing dependency %s\n",

        args=>[shpath($src),$deps->[$x]],
        lvl=>FATAL,

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
      if(ot($obj,$dep)) {
        $do_build=1;last;

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

    my $re=shwl::DEPS_RE;
    my $depstr;

    if($out=~ s/$re//sm) {
      $depstr=${^CAPTURE[0]};

    } else {
      croak "Can't fetch dependencies for $src";

    };

# ---   *   ---   *   ---

    for my $fname($obj,$pmd) {
      if(!(-e $fname)) {
        my $path=dirof($fname);
        `mkdir -p $path`;

      };
    };

# ---   *   ---   *   ---

    my $FH;
    open $FH,'+>',$obj or croak STRERR;
    print {$FH} $out;

    close $FH;

    open $FH,'+>',$pmd or croak STRERR;
    print {$FH} $depstr;

    close $FH;

  };

# ---   *   ---   *   ---

TAIL:
  return;

};

# ---   *   ---   *   ---
1; # ret
