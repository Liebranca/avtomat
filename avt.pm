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
  use strict;
  use warnings;

  use Cwd qw(abs_path getcwd);

  use lib $ENV{'ARPATH'}.'/lib/';
  use lang;

# ---   *   ---   *   ---
# info

  use constant {

    VERSION        => 2.0,
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

  };

# ---   *   ---   *   ---
# global storage

  my %CACHE=(
    -ROOT       =>  '.',
    -INCLUDE    =>   [],
    -LIB        =>   [],

    -CONFIG_FIELDS =>[

      'BUILD','XCPY','LCPY','INCL',
      'LIBS','GENS','DEFS','XPRT'

    ],

  );

sub root {
  if(@_) {$CACHE{-ROOT}=abs_path(shift);};
  return $CACHE{-ROOT};

};

# ---   *   ---   *   ---

# add to search path
sub stinc {

  my $path=shift @ARGV;

  $path=~ s/\-I//;

  $path=abs_path(glob($path));

  my $ref=$CACHE{-INCLUDE};

  push @$ref,$path;

};

# add to search path
sub stlib {

  my $path=shift @ARGV;

  $path=~ s/\-L//;

  $path=abs_path(glob($path));

  my $ref=$CACHE{-LIB};

  push @$ref,$path;

};

# ---   *   ---   *   ---

# in:filename
# sets search path and filelist accto filename
sub illnames {

  my $fname=shift;

  my @files=();
  my $ref;

  # point to lib on -l at strbeg
  if($fname=~ m/^\s*\-l/) {
    $ref=$CACHE{-LIB};
    $fname=~ s/^\s*\-l//;

    for my $i(0..1) {
      push @files,'lib'.$fname.( ('.so','.a')[$i] );

    };push @files,$fname;

  # common file search
  } else {
    $ref=$CACHE{-INCLUDE};
    #$fname=~ s/^\s*\-f//;

    push @files,$fname;

  };return [$ref,\@files];

};

# ---   *   ---   *   ---

# find file within search path
sub ffind {

  my $fname=shift;
  if(-e $fname) {return $fname;};

  my ($ref,@files);{
    my @ret=@{ illnames($fname) };
    $ref=$ret[0];@files=@{ $ret[1] };
    $fname=$files[$#files];

  };

# ---   *   ---   *   ---

  my $src=undef;
  my $path=undef;

  # iter search path
  for $path(@$ref) {
    if(!$path) {next;};

    # iter alt names
    for my $f(@files) {
      if(-e "$path/$f") {
        $src="$path/$f";last;

      };

    };if($src) {last;};
  };

# ---   *   ---   *   ---

  if(!$src) {
    print "Could not find $fname\n";
    return undef;

  };return $src;

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
sub libsearch {

  my @lbins=@{ $_[0] };
  my @lsearch=@{ $_[1] };

  my $deps=$_[2];
  my $found='';

  for my $lbin(@lbins) {
    for my $ldir(@lsearch) {

      # .lib file found
      if(-e "$ldir/.$lbin") {
        my $ndeps.=(split "\n",`cat $ldir/.$lbin`)[0];

        chomp $ndeps;
        $ndeps=join '|',(split ' ',$ndeps);

        # filter out the duplicates
        my @matches=grep(
          m/${ ndeps }/,
          split (' ',$deps)

        );while(@matches) {
          my $match=shift @matches;
          $ndeps=~ s/${ match }\|?//;

        };$ndeps=~ s/\|/ /g;
        $found.=' '.$ndeps.' ';last;

      };
    };

  };return $found;
};

# ---   *   ---   *   ---

# recursively appends lib dependencies to LIBS var
sub libexpand {

  my $LIBS=shift;
  my $ndeps=$LIBS;

  my $deps='';my $i=0;
  my @lsearch=@{ $CACHE{-LIB} };

  while(1) {
    my @lbins=();

    # get search path(s)
    for my $mlib(split ' ',$ndeps) {

      if((index $mlib,'-L')==0) {

        my $s=substr $mlib,2,length $mlib;
        my $lsearch=join ' ',@lsearch;

        if(!($lsearch=~ m/${ s }/)) {
          push @lsearch,$s;

        };next;

      };

      # append found libs to bin search
      $mlib=substr $mlib,2,length $mlib;
      push @lbins,$mlib;

    };

# ---   *   ---   *   ---

    # find dependencies of found libs
    $ndeps=libsearch(\@lbins,\@lsearch,$deps);

    # stop when none found
    if(!(length $ndeps)) {last;};

    # else append and start over
    $deps=$ndeps.' '.$deps;

  };

# ---   *   ---   *   ---

  # append deps to libs
  $deps=join '|',(split ' ',$deps);

  # filter out the duplicates
  my @matches=grep(
    m/${ deps }/,
    split (' ',$LIBS)

  );while(@matches) {
    my $match=shift @matches;
    $deps=~ s/${ match }\|?//;

  };$deps=~ s/\|/ /g;

  $LIBS.=' '.$deps.' ';
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
    $CACHE{-ROOT}.$dir.$fname.'.h' or die $!;

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
    ($is_arr,$type)=split ':',$type;
    $is_arr=$is_arr eq 'arr';

    if($is_arr) {
      $dst.="static const $type $value"."[]={\n";
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

  my ($ret,$args)=split ':',$type;
  $dst.="$ret $name($args) {\n$code\n};\n\n";

  return [$type,$name,$code,$dst];

};

# ---   *   ---   *   ---
# C reading

# in:modname,[files]
# write symbol typedata (return,args) to shadow lib
sub symscan {

  my $mod=shift;

  unshift @ARGV,$CACHE{-ROOT}."/$mod/";
  stinc();

  my @files=();

  { my @fnames=@{ $_[0] };shift;

    # iter filelist
    for my $fname(@fnames) {

      if( ($fname=~ m/\%/) ) {
        push @files,@{ wfind($fname) };

      } else {
        push @files,ffind($fname);

      };

    };
  };

# ---   *   ---   *   ---

  my $ctypes=lang::PROP(-CEE,-VARS)->[3]->[1]);
  $ctypes.='(\\**\\s*|\\s**\\**)';

  my $cnames=lang->$_LUN;

  # type(*) name
  my $p_type_name=''.

    '('.$ctypes.')\\s+'.
    '('.$cnames.'+)\\s*'

  ;

  # type(*) name,
  my $p_sing_args=''.

    '('.$ctypes.')\\s+'.
    '('.$cnames.'*)\\s*'

  ;

  # type name,...
  my $p_mult_args='(\\(.*\\))\\s*[\;\{]';

# ---   *   ---   *   ---

  my $dst=$CACHE{-ROOT}."/lib/.$mod";
  my $deps=(split "\n",`cat $dst`)[0];

  open my $FH,'>',$dst or die $!;

  print $FH "$deps\n";

# ---   *   ---   *   ---

  # iter through files
  for my $f(@files) {
    if(!$f) {next;};
    my $src=`cat $f`;

    # save filename
    print $FH "$f:\n";

    # strip /* ... */
    $src=~ s/\/\*.*\*\///sg;

    # strip // ... \n
    $src=~ s/\/\/.*\n//g;

    # iter through expressions
    for my $exp( split(';',$src) ) {

      $exp.=';';

      if( $exp=~
        m/${ p_type_name }${ p_mult_args }/s

      ) {

        $exp=~ s/${ p_type_name }//s;

        # get function return and name
        my $type=$1;
        my $name=$2;$type=~ s/\s*//sg;

        print $FH "$name $type";

# ---   *   ---   *   ---

        # if non void args
        if($exp=~ m/${ p_mult_args }/s) {
          $exp=~ s/${ p_mult_args }//s;
          my $args=$1;

          # iter through arguments
          while($args=~ m/${ p_sing_args }/s) {
            $args=~ s/${ p_sing_args }\,?//s;

            # get arg type and name
            $type=$1;
            $name=$2;$type=~ s/\s*//sg;

            my $item=($name)
              ? $type.' '.$name
              : $type
              ;

            print $FH " $item";

          };

# ---   *   ---   *   ---

        # debug, show me which forms dont match
        } else {
          print "\n!ERR $exp";

        };print $FH "\n";

      };
    };

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
      $line=~ s/\.[\w|\d]*/\.o/;
      $line=~ s/${ CACHE{-ROOT} }//;

      $line= "${ CACHE{-ROOT} }/trashcan/$line";

      push @{ $h{'files'} },$line;
      next;

    };

    # else is symbol data
    my @symbol=split ' ',$line;

    my $key=shift @symbol;
    my $ret=shift @symbol;

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
    $CACHE{-ROOT}.$dir.$fname.'.pm' or die $!;

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

  # make symbol table
  for my $lib(@libs) {
    %symtab=(%symtab,%{ avt::symrd($lib) });

    # so regen check
    if(!$so_gen) {
      $so_gen=avt::ot($lib,$sopath);

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
    unshift @ARGV,"$CACHE{-ROOT}/lib/";
    stlib();

    my $LIBS=avt::libexpand($O_LIBS);

    # filter out the deps
#    for my $lib(split ' ',$O_LIBS) {
#      $LIBS=~ s/${ O_LIBS }//;
#
#    };

    my $OBJS=join ' ',@o_files;

    # link
    my $call="gcc -shared ".
      (avt->OFLG.' '.avt->LFLG)." ".
      "-m64 $OBJS $LIBS -o $sopath";

    `$call`;

  };

# ---   *   ---   *   ---

  my $search=<<"EOF"

my \$libfold=__FILE__;{
  my \@tmp=split('/',\$libfold);
  \$libfold=join('/',\@tmp[0..(\$#tmp)-1]);
};

my \$ffi=FFI::Platypus->new(api => 1);
\$ffi->lib(
  "\$libfold/lib$soname.so"

);

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

  };print $FH $tab;

};

# ---   *   ---   *   ---
# bash utils

# arg=string any
# multi-byte ord
sub mord {
  my @s=split '',shift;
  my $seq=0;
  my $i=0;while(@s) {
    $seq|=ord(shift @s)<<$i;$i+=8;

  };return $seq;
};

#in: two filepaths to compare
# Older Than; return a is older than b
sub ot {
  return !((-M $_[0]) < (-M $_[1]));

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

      push @ar,[split ',',$item];
      $item='';$is_list&=~3;

    # list opened
    } elsif($is_list) {
      $item.=',';

    };

  # append leftovers
  };if($item) {
    $item=~ s/\\\\\[//g;
    $item=~ s/\\\\\]//g;

    push @ar,[split ',',$item];

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
      $CACHE{-ROOT}.'/.avto-modules' or  die $!;

# ---   *   ---   *   ---

  # iter provided names
  while(@_) {
    my $mod=shift;
    my $excluded;

    if($_[0]){

      # handle exclude flag short
      if($_[0] eq '-x') {
        shift;$excluded=shift;

      # handle exclude flag long
      } elsif($_[0]=~ m/\-\-exclude\=[\w|\d]*/) {
        $excluded=shift;$excluded=~ s/\-\-exclude\=//;

      };

      if($excluded) {
        $excluded=join '|',(split ',',$excluded);

      };

    };

    my $trsh="$CACHE{-ROOT}/trashcan/$mod";
    my $modpath="$CACHE{-ROOT}/$mod";

    # ensure there is a trashcan
    if(!(-e $trsh)) {
      system 'mkdir',('-p',"$trsh");

    };

# ---   *   ---   *   ---

    # walk module path and capture sub count
    my %h=%{ walk($modpath) };my $len=(keys %h);
    my $list='';

    # paths/dir checks
    for my $sub (keys %h) {

      if($excluded) {
        if(grep m/${ excluded }/,$sub) {
          $len--;next;

        };
      };

      # ensure directores exist
      my $tsub=$sub;$tsub=~ s/${ modpath }/${ trsh }/;
      if(!(-e $trsh)) {
        mkdir $tsub;

      };

      # capture file list
      my @files=@{ $h{$sub} };
      $list.="$sub @files\n";

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
      my ($key,$len)=split ' ',shift @m;
      my @paths;

      # store submodules as references
      while($len--) {
        my @tmp=split ' ',shift @m;
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

  for my $key(@{ $CACHE{-CONFIG_FIELDS} }) {
    if(!(exists $config{$key})) {
      $config{$key}=CONFIG_DEFAULT;

    };
  };

  return dqwrap(lang::lescap
    $config{'BUILD'}.' '.

    $config{'XCPY' }.' '.
    $config{'LCPY' }.' '.
    $config{'XPRT' }.' '.

    $config{'GENS' }.' '.
    $config{'LIBS' }.' '.
    $config{'INCL' }.' '.

    $config{'DEFS' }.' '

  );

};

# manages build config file
sub config {

  my %config;
  while(@_) {
    my $mod=shift @_;
    my $settings=shift @_;

    $config{$mod}=$settings;

  };

  # rewrite file
  open FH,'>',"$CACHE{-ROOT}/.avto-config" or die $!;
  for my $mod (keys %config) {
    print FH "$mod $config{$mod}\n"

  };close FH;

};

# ---   *   ---   *   ---

# gives up social life for programming
sub strlist {
  my @l=@{ $_[0] };

  if(!@l) {return '();'};
  for(my $x=0;$x<@l;$x++) {
    $l[$x]=sqwrap $l[$x];

  };return '('.( join ',',@l ).');';
};

# makes file list out of gcc .d files
sub parsemmd {
  my $dep=shift;

  if(!(-e $dep)) {return [];};

  $dep=`cat $dep`;
  $dep=~ s/\\//g;
  $dep=~ s/\s/\,/g;
  $dep=~ s/.*\://;

  my @tmp=split ',',$dep;
  my @deps=();while(@tmp) {
    my $f=shift @tmp;
    if($f) {push @deps,$f;};

  };return \@deps;

};

# shortens pathname for sanity
sub shpath {
  my $path=shift;
  $path=~ s/${ CACHE{-ROOT} }//;
  return $path;

};

# emits builders
sub make {

  # add these directories to search path
  # ... but only if they exist, obviously

  my $base_lib=(-e $CACHE{-ROOT}.'/lib')
    ? '-L'.$CACHE{-ROOT}.'/lib'
    : ''
    ;

  my $base_include=(-e $CACHE{-ROOT}.'/include')
    ? '-I'.$CACHE{-ROOT}.'/include'
    : ''
    ;

  my $bind=$CACHE{-ROOT}.'/bin';
  my $libd=$CACHE{-ROOT}.'/lib';

# ---   *   ---   *   ---

  # fetch dir/file list
  my %modules=%{ read_modules($CACHE{-ROOT}) };

  # fetch config
  my @config=split "\n",`cat $CACHE{-ROOT}/.avto-config`;

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

    )=split ' ',shift @config;
    my @paths=@{ $modules{$name} };

    open FH,'>',"$CACHE{-ROOT}/$name/avto" or die $!;
    my $FILE='';

    $FILE.='#!/usr/bin/perl'."\n";

    # accumulate to these vars
    my @SRCS=();
    my @XPRT=();
    my @OBJS=();
    my @GENS=();
    my @DEFS=();
    my @FCPY=();

    my $src_rcees='';
    my $post_build='';
    my $gens_rcees='';

# ---   *   ---   *   ---

    # write notice and vars
    $FILE.=note('IBN-3DILA','#');

    $FILE.=<<'EOF'
  use strict;
  use warnings;
  use lib $ENV{'ARPATH'}.'/lib/';
  use avt;

  my $PFLG='-m64';
  my $DFLG='';

EOF
;   $FILE.="\nmy \$FSWAT=\"$name\";\n";

    my ($lmode,$mkwat)=($build ne CONFIG_DEFAULT)
      ? split ':',$build
      : ('','')
      ;

    if($lmode eq 'so') {
      $lmode='-shared ';

    } elsif($lmode ne 'ar') {
      $lmode='';

    };

    $FILE.="my \$LMODE='$lmode';\n";

    $FILE.="my \$ROOT=\"$ENV{'ARPATH'}\";\n";
    $FILE.="my \$MKWAT=\"$mkwat\";\n\n";
    $FILE.="my \$BIN=\"$bind\";\n";

    if($mkwat) {

      if($lmode eq 'ar') {
        $FILE.="my \$MAIN=\"$libd/lib$mkwat.a\";\n";
        $FILE.="my \$MLIB=undef;\n";
        $FILE.="my \$ILIB=\"$libd/.$mkwat\";\n";

      } elsif($lmode eq '-shared ') {
        $FILE.="my \$MAIN=\"$libd/lib$mkwat.so\";\n";
        $FILE.="my \$MLIB=undef;\n";
        $FILE.="my \$ILIB=\"$libd/.$mkwat\";\n";

      } else {
        $FILE.="my \$MAIN=\"$bind/$mkwat\";\n";
        $FILE.="my \$MLIB=\"$libd/lib$mkwat.a\";\n";
        $FILE.="my \$ILIB=\"$libd/.$mkwat\";\n";

      };

    } else {
      $FILE.="my \$MAIN=undef;\n";
      $FILE.="my \$MLIB=undef;\n";
      $FILE.="my \$ILIB=undef;\n";

    };

    $FILE.="my \$TRSH=\"$ENV{'ARPATH'}".
      "/trashcan/$name\";\n";

# ---   *   ---   *   ---

    # parse libs listing
    { my @libs=($libs ne CONFIG_DEFAULT)
      ? split ',',$libs
      : ()
      ;

      for(my $x=0;$x<@libs;$x++) {
        if((index $libs[$x],'/')>=0) {
          $libs[$x]='-L'.$libs[$x];

        } else {
          $libs[$x]='-l'.$libs[$x];

        };
      };

      $libs=$base_lib.' '.(join ' ',@libs);
      $FILE.="my \$LIBS=\"$libs\";\n";

    };

# ---   *   ---   *   ---

    # parse includes
    $incl=($incl ne CONFIG_DEFAULT)
      ? '-I'.(join ' -I',(split ',',$incl))
      : ''
      ;

    $incl=$base_include." $incl";

    $FILE.="my \$INCLUDES=\"$incl -I\$ROOT\";\n";

# ---   *   ---   *   ---

    # get list copy list A
    $xcpy=($xcpy ne CONFIG_DEFAULT)
      ? join '|',(split ',',$xcpy)
      : ''
      ;

    # get list copy list B
    $lcpy=($lcpy ne CONFIG_DEFAULT)
      ? join '|',(split ',',$lcpy)
      : ''
      ;

    # get exports list
    $xprt=($xprt ne CONFIG_DEFAULT)
      ? join '|',(split ',',$xprt)
      : ''
      ;

# ---   *   ---   *   ---

    # get generator list
    my $gens_src='';
    my %gens_res=();
    { my @tmp1=($gens ne CONFIG_DEFAULT)
      ? @{ rcsl($gens) }
      : ()
      ;

      while(@tmp1) {
        my @l=@{ shift @tmp1 };

        my ($res,$src)=split ':',shift @l;
        $res=~ s/\\//g;

        @l=(@l) ? @l : ();

        $gens_res{$src}=[$res,\@l];

      };$gens_src=join '|',(keys %gens_res);

    };

# ---   *   ---   *   ---

    while(@paths) {
      my @path=@{ shift @paths };
      my $mod=shift @path;
      my $trsh='';

      if((index $mod,'/')==0) {
        $mod=substr $mod,1,length $mod;

      };

      # get path to
      ($mod,$trsh)=($mod eq '<main>')
        ? ($CACHE{-ROOT}."/$name",
          $CACHE{-ROOT}."/trashcan/$name")

        : ($CACHE{-ROOT}."/$name/$mod",
          $CACHE{-ROOT}."/trashcan/$name/$mod")
        ;

# ---   *   ---   *   ---

      # copy these to bin
      if($xcpy) { my @matches=grep m/${ xcpy }/,@path;
        while(@matches) {
          my $match=shift @matches;

          if(!$xcpy) {last;};

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
      if($lcpy) { my @matches=grep m/${ lcpy }/,@path;
        while(@matches) {
          my $match=shift @matches;

          if(!$lcpy) {last;};

          $lcpy=~ s/\|?${ match }\|?//;
          $match=~ s/\\//g;

          push @FCPY,(
            "$mod/$match",
            "$libd/$match"

          );

        };
      };


# ---   *   ---   *   ---

      # copy these to include
      if($xprt) { my @matches=grep m/${ xprt }/,@path;
        while(@matches) {
          my $match=shift @matches;

          if(!$xprt) {last;};
          $xprt=~ s/\|?${ match }\|?//;
          $match=~ s/\\//g;

          push @XPRT,"$mod/$match";

        };
      };

# ---   *   ---   *   ---

      # make generator rules
      if($gens_src) {
        my @matches=grep m/${ gens_src }/,@path;

        while(@matches) {
          my $match=shift @matches;

          if(!$gens_src) {last;};

          $gens_src=~ s/\|?${ match }\\\*\|?//;
          $match=~ s/\*//;

          my ($res,$srcs)=@{ $gens_res{$match.'\*'} };

          push @GENS,(
            "$mod/$match",
            "$mod/$res",

            join(',',@$srcs)

          );

        };
      };

# ---   *   ---   *   ---

      { my @matches=grep m/.\.c/,@path;
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
      };
    };

# ---   *   ---   *   ---

    my $mkvars="my \@SRCS=".( strlist \@SRCS );
    $mkvars.="\nmy \@XPRT=".( strlist \@XPRT );
    $mkvars.="\nmy \@OBJS=".( strlist \@OBJS );
    $mkvars.="\nmy \@GENS=".( strlist \@GENS );
    $mkvars.="\nmy \@FCPY=".( strlist \@FCPY );
    $FILE.="$mkvars\n";

    $FILE.=<<'EOF'

# ---   *   ---   *   ---

avt::root $ROOT;
chdir $ROOT;

for my $inc(split ' ',$INCLUDES) {
  if($inc eq "-I$ROOT") {next;};
  unshift @ARGV,$inc;avt::stinc();

};unshift @ARGV,'.';avt::stinc();
unshift @ARGV,"-I$ROOT/$FSWAT";avt::stinc();

while(@GENS) {

  my $gen=shift @GENS;
  my $res=shift @GENS;

  my @msrcs=split ',',shift @GENS;

  my $do_gen=!(-e $res);

  if(!$do_gen) {$do_gen=avt::ot($res,$gen);};
  if(!$do_gen) {
    while(@msrcs) {
      my $msrc=shift @msrcs;

      if($msrc=~ m/\%/) {
        my @srcs=@{ avt::wfind($msrc) };
        while(@srcs) {
          my $src=shift @srcs;
          if(avt::ot($res,$src)) {
            $do_gen=1;last;

          };
        };if($do_gen) {last;};

      } else {
        $msrc=avt::ffind($msrc);
        if(!$msrc) {next;};

        if(avt::ot($res,$msrc)) {
          $do_gen=1;last;

        };

      };
    };
  };

  if($do_gen) {
    print 'Regen '.( avt::shpath $gen )."\n";
    `$gen`;

  };

};

my $OBJS='';
for(my ($i,$j)=(0,0);$i<@SRCS;$i++,$j+=2) {

  my $src=$SRCS[$i];

  my $obj=$OBJS[$j+0];
  my $mmd=$OBJS[$j+1];

  $OBJS.=$obj.' ';

  my @deps=($src);

  my $do_build=!(-e $obj);if($mmd) {
    @deps=@{ avt::parsemmd $mmd };

  };for(my $x=0;$x<@deps;$x++) {
    if($deps[$x] && !(-e $deps[$x])) {
      print ''.( avt::shpath $src );
      print " missing dependency $deps[$x]\n";
      exit;

    };
  };

  if(!$do_build) {
    while(@deps) {
      my $dep=shift @deps;
      if(!(-e $dep)) {next;};
      if(avt::ot($obj,$dep)) {
        $do_build=1;last;

      };
    };
  };

  if($do_build) {

    print ''.( avt::shpath $src )."\n";
    my $asm=$obj;$asm=substr(
      $asm,0,(length $asm)-1

    );$asm.='asm';

    my $call=''.
      "gcc -MMD ".(avt->OFLG)." ".
      "$INCLUDES $DFLG $PFLG ".
      "-Wa,-a=$asm -c $src -o $obj";`$call`;

  };

};

if($LMODE eq 'ar') {
  my $call="ar -crs $MAIN $OBJS";`$call`;

  `echo "$LIBS" > $ILIB`;
  avt::symscan($FSWAT,\@XPRT);

} elsif($MAIN) {
  print ''.( avt::shpath $MAIN) ."\n";
  if(-e $MAIN) {`rm $MAIN`;};

    $LIBS=avt::libexpand($LIBS);

    my $call="gcc $LMODE ".
      (avt->OFLG.' '.avt->LFLG)." ".
       "$INCLUDES $PFLG $OBJS $LIBS -o $MAIN";

      `$call`;
      `echo "$LIBS" > $ILIB`;

    if($LMODE ne '-shared ') {
      $call="ar -crs $MLIB $OBJS";`$call`;

      `echo "$LIBS" > $ILIB`;
      avt::symscan($FSWAT,\@XPRT);

    };

};

while(@FCPY) {
  my $og=shift @FCPY;
  my $cp=shift @FCPY;

  my $do_cpy=!(-e $cp);

  if(!$do_cpy) {$do_cpy=avt::ot($cp,$og);};
  if($do_cpy) {`cp $og $cp`;};

};

EOF
;

    print FH $FILE;
    close FH;`chmod +x "$CACHE{-ROOT}/$name/avto"`
  };
};

# ---   *   ---   *   ---
1; # ret
