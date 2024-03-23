#!/usr/bin/perl
# ---   *   ---   *   ---
# VAULT
# Keeps your stuff
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Vault;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use Cwd qw(abs_path);

  use English qw(-no_match_vars);

  use Storable qw(store retrieve freeze thaw);
  use Fcntl qw(SEEK_SET SEEK_CUR);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Array;
  use Arstd::String;
  use Arstd::Path;
  use Arstd::IO;

  use Arstd::WLog;

  use Tree;
  use Queue;

  use Shb7;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.7;#b
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  my Readonly $DAFSIG=pack 'C'x16,
    0x24,0x24,0x24,0x24,
    0xDE,0xAD,0xBE,0xA7,
    0x24,0x24,0x24,0x24,
    0x71,0xEB,0xDA,0xF0

  ;

  my Readonly $DAF_ISIZE=['L'=>4];
  my Readonly $DAF_EXT='.daf';

  my Readonly $PX_EXT='.px';

  my Readonly $Std_Dirs=qr{(?:

    bin
  | lib

  | \.cache
  | \.trash

  | include

  )}x;

# ---   *   ---   *   ---
# global state

  my  $Systems      = {};

  our $Needs_Update = {};
  our $Cache_Regen  = {};
  our $File_Deps    = {};

# ---   *   ---   *   ---
# marks package as utilizing
# the cache directory

sub import($class,@args) {


  my ($pkgname,$file,$line)=caller;
  my $modname=Shb7::modof(abs_path($file));

  return if($modname=~ $Std_Dirs);


  my $syskey=(defined $args[-1])
    ? $args[-1]
    : 'ARPATH'
    ;

  croak (sprintf

    q[Invalid syskey <%s> passed in ] .
    q[to Vault from %s],

    $syskey,$file,

  ) unless $ENV{$syskey};

  my $syspath=Shb7::set_root($ENV{$syskey})
  if $ENV{$syskey} ne $Shb7::Path::Root;


  # init project
  if(! exists $Systems->{$syspath}) {
    $Systems->{$syspath}=
     Tree->new_frame();

  };

  # init modules in project
  my $frame=$Systems->{$syspath};
  if(! exists $frame->{-roots}->{$modname}) {
    module_tree($modname);

  };


  return;

};

# ---   *   ---   *   ---
# ^gets module tree of registered

sub check_module($name,$exclude=[]) {

  my $syspath = $Shb7::Path::Root;
  my $frame   = $Systems->{$syspath};

  $Systems->{$syspath}//={};

  my $table;

  if(! exists $frame->{-roots}->{$name}) {
    $table=module_tree($name,$exclude);
    $frame->{-roots}->{$name}=$table;

  } else {
    $table=$frame->{-roots}->{$name};

  };

  return $table;

};

# ---   *   ---   *   ---
# ^finds a project cache file

sub px_file($name) {
  return Shb7::cache("$name$PX_EXT");

};

# ---   *   ---   *   ---
# creates file tree for
# a module, used for building

sub module_tree($name,$excluded=[]) {

  my $syspath = $Shb7::Path::Root;
  my $frame   = $Systems->{$syspath};

  $Needs_Update->{$name}=[];

  my $modf=px_file($name);
  my $newf=0;

  # load existing
  if(-f $modf) {

    my $mod=retrieve($modf);
    $frame->{-roots}->{$name}=$mod;


  # generate
  } else {

    my $path =  "$syspath/$name/";
       $path =~ s[$FSLASH_RE+][/]sxmg;

    $frame->{-roots}->{$name}=Shb7::walk(

      $path,

      -r=>1,
      -x=>$excluded,

    );

    $newf=1;

  };


  # checksum the tree
  # new result will be saved if there's changes
  my $table=$frame->{-roots}->{$name};

  $Needs_Update->{$name}=$table->get_cksum();
  push @{$Needs_Update->{$name}},1 if $newf;


  return $table;

};

# ---   *   ---   *   ---
# get list of updated trees

sub get_module_update() {

  my @out=();

  for my $syspath(keys %$Systems) {

    my $frame=$Systems->{$syspath};
    for my $modname(keys %{$frame->{-roots}}) {

      my $updated=$Needs_Update->{$modname};

      next if $modname=~ m[\.trash];
      next unless @$updated;

      push @out,[$modname,$frame];

    };

  };

  return @out;

};

# ---   *   ---   *   ---
# dump trees to cache

END {

  my @updated=get_module_update();

  $WLog->mprich(
    'AR/Vault',
    'updating module cache'

  ) if @updated && $WLog;


  for my $ref(@updated) {

    my ($modname,$frame)=@$ref;

    # save tree to disk
    my $modf=Shb7::cache(
      "$modname$PX_EXT"

    );

    my $mod=$frame->{-roots}->{$modname};
    store($mod,$modf);

    $WLog->fupdate($modname);

  };


  $WLog->line() if @updated;

};

# ---   *   ---   *   ---
# ^similar, cached objects

END {

  my $done=int(%{$Cache_Regen});

  $WLog->mprich(
    'AR/Vault',
    'updating object cache'

  ) if $done && $WLog;


  for my $file(keys %{$Cache_Regen}) {
    store($Cache_Regen->{$file},$file);
    $WLog->fupdate($file) if $WLog;

  };


  $WLog->line() if $done && $WLog;

};

# ---   *   ---   *   ---
# get object needs update
#
# forces make/regen of
# cache sub directory

sub cached_dir($file) {

  my $path = cashof($file);
  my $dir  = dirof($path);

  my $rbld = Shb7::moo($path,$file)
  or exists $Cache_Regen->{$path};

  # get entry or make new
  -e $dir or `mkdir -p $dir`;


  # have existing?
  my $data=(-f $path)
    ? retrieve($path)
    : $Cache_Regen->{$path}
    ;

  $data //= undef;


  # check deps
  my $deps   = $File_Deps->{$file};
     $deps //= [];

  map {$rbld |= Shb7::moo($path,$ARG)} @$deps;


  # pack and give
  return {

    rbld => $rbld,
    path => $path,
    data => $data,

  };

};

# ---   *   ---   *   ---
# regen or fetch

sub rof($file,$key,$call,@args) {

  # get ctx
  my $cache = cached_dir($file);
  my $data  = $cache->{data};

  my $out   = undef;


  # regen entry?
  if(

  !  exists $data->{$key}
  || $cache->{rbld}

  ) {

    $out=$data->{$key}=$call->(@args);
    cashreg($cache->{path},$data);

  # ^nope, fetch existing
  } else {
    $out=$data->{$key};

  };

  return $out;

};

# ---   *   ---   *   ---
# ^keyless variant

sub frof($file,$call,@args) {


  # get ctx
  my $cache = cached_dir($file);
  my $data  = $cache->{data};

  my $out   = undef;


  # regen entry?
  if(

  !  defined $data
  || $cache->{rbld}

  ) {

    $out=$data=$call->(@args);
    cashreg($cache->{path},$data);

  # ^nope, fetch existing
  } else {
    $out=$data;

  };

  return $out;

};

# ---   *   ---   *   ---
# mark file as a dependency

sub depson(@list) {


  # get/nit handle to module deps
  my $file = (caller)[1];
  my $vref = \$File_Deps->{$file};

  $$vref //= [];


  # validate input
  map {-f $ARG or croak "$ARG: $!"} @list;

  # ^push to module deps
  push @{$$vref},map {abs_path $ARG} @list;
  array_dupop $$vref;


};

# ---   *   ---   *   ---
# either executes a generator
# or loads whatever it generates

sub cached($key,$call,@args) {
  my $file=(caller)[1];
  return rof $file,$key,$call,@args;

};

# ---   *   ---   *   ---
# ^key *IS* file

sub fcached($file,$call,@args) {
  return frof $file,$call,@args;

};

# ---   *   ---   *   ---
# ^builds path to stash

sub cashof($file) {

  my $modname=
    Shb7::modof(abs_path($file));

  $file=Shb7::shpath($file);
  $file=~ s[$modname/?][];
  $file.= q[.st];

  return Shb7::cache($file);

};

# ---   *   ---   *   ---
# ^register stash for update

sub cashreg($path,$h) {
  $Cache_Regen->{$path}=$h;

};

# ---   *   ---   *   ---
# read dark archive files

sub dafread($fname,@requested) {

  my $path=Shb7::cache($fname.$DAF_EXT);
  my $bytes=$NULLSTR;

# ---   *   ---   *   ---
# check file signature

  open my $FH,'<',$path or croak strerr($path);
  read $FH,my $sig,length $DAFSIG;

  if($sig ne $DAFSIG) {
    errout(
      q{Bad DAF signature on cache file '%s'},

      args=>[$fname],
      lvl=>$AR_FATAL,

    );

  };

# ---   *   ---   *   ---
# read indices header

  my ($idex_type,$idex_size)=@{$DAF_ISIZE};
  my ($isize,$header);

  read $FH,$isize,$idex_size;
  $isize=unpack $idex_type,$isize;

  read $FH,$header,$isize*$idex_size;

  my @header=unpack
    ${idex_type}x$isize,
    $header;

# ---   *   ---   *   ---
# fetch requested

  my @blocks=();
  my $adjust=$requested[0] ne 0;

  while(@requested) {
    my @sizes=();
    my $sizesum=0;

# ---   *   ---   *   ---
# handle successive reads in one go

FETCH_NEXT:
    my $idex=shift @requested;

    my $start=$header[$idex+0];
    my $ahead=$header[$idex+1];

    if($adjust) {
      seek $FH,$start,SEEK_SET;
      $adjust=0;

    };

    push @sizes,$ahead-$start;
    $sizesum+=$sizes[-1];

    if(@requested
    && $requested[0]==$idex+1

    ) {goto FETCH_NEXT};

# ---   *   ---   *   ---
# read whole chunk and split individual blocks

    my ($chunk,$block);
    read $FH,$chunk,$sizesum;

    for my $size(@sizes) {
      $block=substr $chunk,0,$size;
      $chunk=~ s/^${block}//;

      push @blocks,thaw($block);

    };

    $adjust=1;

  };

# ---   *   ---   *   ---

  close $FH or croak strerr($path);
  return @blocks;

};

# ---   *   ---   *   ---
# saves serialized perl objects to disk

sub dafwrite($fname,@blocks) {

  my ($idex_type,$idex_size)=@{$DAF_ISIZE};

  my @header=(

    (length $DAFSIG)      # signature

    + $idex_size          # number of elements
    + $idex_size          # first idex
    + $idex_size*@blocks  # idex per element

  );

# ---   *   ---   *   ---
# serialize objects as one big chunk

  my $body=$NULLSTR;
  my $i=0;

  for my $block(@blocks) {

    $block=freeze($block);
    $body.=$block;

    push @header,$header[-1]+length $block;

  };

# ---   *   ---   *   ---
# write to file

  unshift @header,int(@header);

  my $header=$DAFSIG.(
    pack ${idex_type}x@header,@header

  );

  owc(
    Shb7::cache($fname.$DAF_EXT),
    $header.$body

  );

};

# ---   *   ---   *   ---
# retrieve file if passed var
# is a valid path

sub fchk($var) {

  my $out=(is_hashref($var))
    ? $var
    : undef
    ;

  # early ret
  goto SKIP if $out;

# ---   *   ---   *   ---

  # validate input
  ! length ref $var or errout(

    q[Non-scalar, non-hashref var ] .
    q[passed in to fchk],

    lvl => $AR_FATAL,

  );

  # ^fetch
  my $path=Shb7::ffind($var) or croak;
  $out=retrieve($path);

# ---   *   ---   *   ---

SKIP:
  return $out;

};

# ---   *   ---   *   ---
# selfex

sub deepcpy($o) {
  return thaw(freeze($o));

};

# ---   *   ---   *   ---
1; # ret
