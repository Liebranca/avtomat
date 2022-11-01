#!/usr/bin/perl
# ---   *   ---   *   ---
# SHB7
# Shell utils
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb
# ---   *   ---   *   ---

# deps
package Shb7;

  use v5.36.0;
  use strict;
  use warnings;

  use Storable;
  use Readonly;

  use Cwd qw(abs_path getcwd);

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::Path;
  use Arstd::IO;

  use Tree::File;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.01.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  our $F_SLASH_END;
  our $DOT_BEG;

  my  $LIBF_RE=qr{^\-l}x;
  my  $LIBD_RE=qr{^\-L}x;

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

  Readonly our $FLATLFLG=>
    q{-flto -ffunction-sections}.q{ }.
    q{-fdata-sections -Wl,--gc-sections}.q{ }.
    q{-Wl,-fuse-ld=bfd}.q{ }.

    q{-Wl,--relax,-d}.q{ }.
    q{-Wl,--entry=_start}.q{ }.
    q{-no-pie -nostdlib}

  ;

# ---   *   ---   *   ---

BEGIN {

  $F_SLASH_END=qr{/$}x;
  $DOT_BEG=qr{^\.}x;

};

# ---   *   ---   *   ---
# global state

  our (

    $Root,
    $Cache,
    $Trash,
    $Config,
    $Mem,

    $Root_Re,

    $Lib,
    $Include,

  );

# ---   *   ---   *   ---
# ^setter

sub set_root($path) {
  $Root=abs_path(pathchk($path));

  if(!($Root=~ $F_SLASH_END)) {
    $Root.=q[/];

  };

  $Cache="$Root.cache/";
  $Trash="$Root.trash/";
  $Mem="$Root.mem/";
  $Config="$Root.config/";

  mkdir $Config if ! -e $Config;

  $Lib//=[];
  $Include//=[];

  $Lib->[0]="${Root}lib/";

  $Include->[0]=$Root;
  $Include->[1]="${Root}include/";

  $Root_Re=qr{^(?: $DOT_BEG /? | $Root)}x;

  return $Root;

};

# ---   *   ---   *   ---

sub pathchk($path) {

  my $cpy=glob($path);
  $cpy//=$path;

  if(!defined $cpy) {

    errout(

      q{Uninitialized path '%s'}."\n".

      q{cwd   %s}."\n".
      q{root  %s},

      args=>[$path,getcwd(),$Root],
      lvl=>$AR_FATAL,

    );

  };

# ---   *   ---   *   ---

  if( !(-e $cpy)
  &&  !(-e "$Root/$cpy")

  ) {

    errout(

      q{Invalid file or directory '%s'}."\n".

      q{cwd   %s}."\n".
      q{root  %s},

      args=>[$path,getcwd(),$Root],
      lvl=>$AR_FATAL,

    );

  };

  return $path;

};

# ---   *   ---   *   ---

BEGIN {

  set_root(
    abs_path($ENV{'ARPATH'})

  );

};

# ---   *   ---   *   ---
# these are just for readability
# we could add checks though...

sub file($path) {return $Root.$path};

sub dir($path=$NULLSTR) {
  return $Root.$path.q[/];

};

sub obj_file($path) {return $Trash.$path};

sub obj_dir($path=$NULLSTR) {
  return $Trash.$path.q[/];

};

sub config_file($path) {return $Config.$path};

sub config_dir($path) {
  return $Config.$path.q[/];

};

# ---   *   ---   *   ---
# shortcuts for making paths to main lib dir

sub lib($name=$NULLSTR) {return $Root."lib/$name"};
sub so($name) {return $Root."lib/lib$name.so"};

# ^idem, .cache dir
sub cache_file($name) {return $Cache.$name};
sub mem_file($name) {return $Mem.$name};

# ---   *   ---   *   ---
# gives object file path from source file path

sub obj_from_src($src,%O) {

  # default
  $O{use_trash}//=1;

  my $o=$src;

  if($O{use_trash}) {
    $o=~ s/$Root_Re/$Trash/;

  };

  $o=~ s/\.[\w|\d]*$/\.o/;

  return $o;

};

# ---   *   ---   *   ---
# gives path relative to current root

sub rel($path) {

#:!;> dirty way to do it without handling
#:!;> the obvious corner case of ..

  $path=~ s[$Root_Re][./];
  return $path;

};

# ---   *   ---   *   ---
# tells you which module within $Root a
# given file belongs to

sub module_of($file) {
  return based(shpath($file));

};

# ---   *   ---   *   ---
# shortens pathname for sanity

sub shpath($path) {
  $path=~ s[$Root_Re][];
  return $path;

};

# ---   *   ---   *   ---
# inspects a directory within root

sub walk($path,%O) {

  # defaults
  $O{-r}//=0;
  $O{-x}//=[];

# ---   *   ---   *   ---
# build exclusion re

  $O{-x}=join q{|},@{$O{-x}};
  if(length $O{-x}) {$O{-x}.=q{|}};

  $O{-x}.=q{
    nytprof | data | docs | tests | legacy

  | __pycache__

  };

  $O{-x}=qr{(?:$O{-x})}x;

# ---   *   ---   *   ---

  my $frame=Tree::File->new_frame();
  my $root_node=undef;

  $path=dir($path) if !(-d $path);

  my @pending=($path,undef);
  my $out=undef;

# ---   *   ---   *   ---
# prepend and open

  while(@pending) {

    $path=shift @pending;
    $root_node=shift @pending;

    my $dst=(!defined $root_node)
      ? $frame->nit($root_node,$path)
      : $root_node

      ;

    $out//=$dst;

    # errchk
    if(!(-d $path)) {

      errout(

        q{Is not a directory '%s'},

        args=>[$path],
        lvl=>$AR_FATAL,

      );

    };

# ---   *   ---   *   ---
# go through the entries

    opendir my $dir,$path or croak strerr($path);

    my @files=readdir $dir;

    my $key=basef($path);
    $dst->{$key}={};

# ---   *   ---   *   ---
# skip .dotted or excluded

    for my $f(@files) {
    next if $f=~ m[ $DOT_BEG | $O{-x}]x;

# ---   *   ---   *   ---
# filter out files from dirs

      if(-f "$path/$f") {
        $frame->nit($dst,$f);

      } elsif(($O{-r}) && (-d "$path$f/")) {
        unshift @pending,

          "$path$f/",
          $frame->nit($dst,"$f/")

        ;

      };

# ---   *   ---   *   ---

    };

    closedir $dir or croak strerr($path);

  };

  return $out;

};

# ---   *   ---   *   ---
#in: two filepaths to compare
# Older Than; return a is older than b

sub ot($a,$b) {
  return !( (-M $a) < (-M $b) );

};

# ^file not found or file needs update
sub missing_or_older($a,$b) {
  return !(-e $a) || ot($a,$b);

};

# ---   *   ---   *   ---
# loads a file if available
# else regenerates it from a sub

sub load_cache($name,$dst,$call,@args) {

  my ($pkg,$fname,$line)=(caller);
  my $path=cache_file($pkg.q{::}.$name);

  my $out={};

  if(Shb7::missing_or_older(
    $path,abs_path($fname))

  ) {

    print {*STDERR}

      'updated ',"\e[32;1m",
      shpath($path),

      "\e[0m\n"

    ;

    $out=$call->(@args);
    store($out,$path);

  } else {
    $out=retrieve($path);

  };

  $$dst=$out;

};

# ---   *   ---   *   ---
# add to search path (include)

sub stinc(@args) {

  for my $path(@args) {

    $path=~ s[^\s*\-I][];
    $path=abs_path(glob($path));

    push @$Include,$path;

  };

};

# ---   *   ---   *   ---
# add to search path (library)

sub stlib(@args) {

  for my $path(@args) {

    $path=~ s[^\s*\-L][];
    $path=abs_path(glob($path));

    push @$Lib,$path;

  };

  return;

};

# ---   *   ---   *   ---
# sets search path and filelist accto filename

sub illnames($fname) {

  my @files=();
  my $ref;

# ---   *   ---   *   ---
# point to lib on -l at strbeg

  if($fname=~ s/^\s*\-l//) {

    $ref=$Lib;

    for my $i(0..1) {
      push @files,'lib'.$fname.(
        ('.so','.a')[$i]

      );

    };

    push @files,$fname;

# ---   *   ---   *   ---
# common file search

  } else {
    $ref=$Include;
    push @files,$fname;

  };

  return [$ref,\@files];

};

# ---   *   ---   *   ---
# find file within search path

sub ffind($fname,@exts) {

  if(-e $fname) {return $fname};

  map {$ARG=".$ARG"} @exts;
  push @exts,$NULLSTR;

  my ($ref,@files);

  { my @ret=@{ illnames($fname) };

    $ref=$ret[0];@files=@{ $ret[1] };
    $fname=$files[$#files];

  };

# ---   *   ---   *   ---

  my $src=undef;
  my $path=undef;

  # iter search path
  for $path(@$ref,$Root) {

    # skip blanks
    next if !$path;

    # iter alt names
    for my $f(@files) {
    for my $ext(@exts) {

      if(-e "$path/$f$ext") {
        $src="$path/$f$ext";
        last;

      };

    }};

    # early exit on found
    last if defined $src;

  };

# ---   *   ---   *   ---
# catch no such file

  if(!defined $src) {

    pop @exts;
    my $ext_list=join q[,],@exts;

    if(length $ext_list) {
      $ext_list="(exts==$ext_list)";

    };

    errout(
      q[Could not find file '%s' in path %s],

      args=>[$fname,$ext_list],
      lvl=>$AR_ERROR,

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

    );

    my $end=substr(
      $pat,index($pat,'%')+1,
      length $pat

    );

    $beg="\Q$beg";
    $end="\Q$end";

    $pat=$beg.'%'.$end;

    # substitute %
    $pat=~ s/\%/[\\s\\S]*/;

  };

  $in=join '|',@patterns;
  $in=qr{$in}x;

# ---   *   ---   *   ---
# find files matching pattern

  my @ar=();

  # iter search path
  for my $path(@$ref) {

    my $tree=walk($path,-r=>1);

    for my $dir($tree->get_dir_list(
      full_path=>0,
      keep_root=>1,

    )) {

      my @files=$dir->get_file_list(
        full_path=>1,
        max_depth=>1,

      );

      push @ar,grep m[$in],@files;

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

    next if !length $lbin;

    for my $ldir(@lsearch) {

      # .lib file found
      if(-e "$ldir/.$lbin") {

        my $f=retrieve("$ldir/.$lbin")
        or croak strerr("$ldir/.$lbin");

        my $ndeps.=(defined $f->{deps})
          ? $f->{deps} : $NULLSTR;

        chomp $ndeps;
        $ndeps=join q{|},(split $SPACE_RE,$ndeps);

# ---   *   ---   *   ---

        # filter out the duplicates
        my @matches=grep(
          m/${ ndeps }/,
          (split $SPACE_RE,$deps)

        );

        while(@matches) {
          my $match=shift @matches;
          $ndeps=~ s/${ match }\|?//;

        };

        $ndeps=~ s/\|/ /g;
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
  my @lsearch=@$Lib;

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

  };

  $deps=~ s/\|/ /g;
  $LIBS.=q{ }.$deps.q{ };

  return $LIBS;

};

# ---   *   ---   *   ---
# get symbol typedata from shadow lib

sub symrd($mod) {

  my $src=lib(".$mod");

  my $out={};

  # existence check
  if(!(-e $src)) {
    print "Can't find shadow lib '$mod'\n";
    goto TAIL;

  };

  $out=retrieve($src) or croak strerr($src);

# ---   *   ---   *   ---

TAIL:
  return $out;

};

# ---   *   ---   *   ---

sub olink($objs,$name,%O) {

  # defaults
  $O{deps}   //= $NULLSTR;
  $O{libs}   //= $NULLSTR;
  $O{shared} //= $NULLSTR;

  $O{flat}   //= 0;
  $O{flags}  //= [];

  $O{shared}=q[-shared] if $O{shared};

  my @LPATH=();
  for my $lib(@$Lib) {
    push @LPATH,q{-L}.$lib;

  };

  my @OBJS=split $SPACE_RE,$objs;
  my @LIBS=split $SPACE_RE,$O{libs};
  my @DEPS=split $SPACE_RE,$O{deps};

  my @call=();

# ---   *   ---   *   ---
# find dependencies

  my @deps=();
  for my $lib(@LIBS) {

    # skip directories
    next if $lib=~ $LIBD_RE;

    my $path=$lib;

    # remove -l and get path to module
    $path=~ s[$LIBF_RE][];
    $path=dir($path);

    # retrieve build data if present
    if(-d $path) {

      my $M=retrieve($path.'/.avto-cache');

      push @deps,(split $SPACE_RE,
        libexpand($M->{libs})

      );

      push @deps,(split $SPACE_RE,$M->{incl});

    };

  };

  unshift @LIBS,@deps;

  for my $incl(reverse @$Include) {
    unshift @LIBS,q[-I].$incl;

  };

  array_filter(\@LIBS,sub {

     defined $ARG
  && 2<length $ARG

  });

# ---   *   ---   *   ---

  # using gcc
  if(!$O{flat}) {
    @call=(

      q(gcc),$O{shared},

      (split $SPACE_RE,$OFLG),
      (split $SPACE_RE,$LFLG),

      @{$O{flags}},
      q(-m64),

      @OBJS,@DEPS,@LPATH,@LIBS,
      q(-o), $name

    );

  # gcc, but fine-tuned
  } elsif($O{flat} eq '1/2') {

    @call=(

      q(gcc),$O{shared},
      (split $SPACE_RE,$FLATLFLG),

      q(-m64),

      @OBJS,@DEPS,@LPATH,@LIBS,
      q(-o), $name

    );

  # using ld ;>
  } else {

    @call=(

      q(ld.bfd),

      qw(--relax --omagic -d),
      qw(-e _start),

      qw(-m elf_x86_64),
      qw(--gc-sections),

      q(-o),$name,
      @OBJS,@LPATH,@LIBS

    );

  };

  # link
  array_filter(\@call);
  system {$call[0]} @call;

};

# ---   *   ---   *   ---
# rebuilds shared objects if need be

sub soregen($soname,$libs_ref,$no_regen=0) {

  my $sopath=so($soname);
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
      $symtab{objects}->{$Root.$o}=$obj;

    };

    push @{$symtab{deps}},$f->{deps};

  };

# ---   *   ---   *   ---
# generate so

  if($so_gen && !$no_regen) {

    # recursively get dependencies
    my $o_libs='-l'.( join ' -l',@libs );

    my $deps=join q{ },@{$symtab{deps}};

    my $libs=libexpand($o_libs);
    my $objs=join q{ },keys %{$symtab{objects}};

    olink(

      $objs,
      $sopath,

      deps=>$deps,
      libs=>$libs,

      shared=>1,

    );

  };

  return \%symtab;

};

# ---   *   ---   *   ---

sub sofetch($symtab) {

  my $tab={};

  for my $o(keys %{$symtab->{objects}}) {

    my $obj=$symtab->{objects}->{$o};
    my $funcs=$obj->{functions};

    my $ref=$tab->{$o}=[];

    for my $fn_name(keys %$funcs) {

      my $fn=$funcs->{$fn_name};
      my $rtype=$fn->{type};

      push @$ref,[$fn_name,$rtype,@{$fn->{args}}];

    };

  };

  return $tab;

};

# ---   *   ---   *   ---
1; # ret
