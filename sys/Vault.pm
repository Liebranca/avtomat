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

  use Arstd::String;
  use Arstd::Path;
  use Arstd::IO;

  use Tree;
  use Queue;

  use Shb7;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.3;#b
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

# ---   *   ---   *   ---

sub import($class,@args) {

  my ($pkgname,$file,$line)=caller;
  my $modname=Shb7::modof(abs_path($file));

  goto SKIP if($modname=~ $Std_Dirs);

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

# ---   *   ---   *   ---

SKIP:
  return;

};

# ---   *   ---   *   ---

sub check_module($name,$exclude=[]) {

  my $syspath=$Shb7::Path::Root;
  my $frame=$Systems->{$syspath};

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

sub px_file($name) {
  return Shb7::cache("$name$PX_EXT");

};

# ---   *   ---   *   ---

sub module_tree($name,$excluded=[]) {

  my $syspath=$Shb7::Path::Root;
  my $frame=$Systems->{$syspath};

  $Needs_Update->{$name}=[];

  my $modf=px_file($name);
  my $newf=0;

  # load existing
  if(-f $modf) {

    my $mod=retrieve($modf);
    $frame->{-roots}->{$name}=$mod;


  # generate
  } else {

    $frame->{-roots}->{$name}=
      Shb7::walk($name,-r=>1,-x=>$excluded);

    $newf=1;

  };

# ---   *   ---   *   ---
# checksum the tree
# new result will be saved if there's changes

  my $table=$frame->{-roots}->{$name};

  $Needs_Update->{$name}=$table->get_cksum();
  push @{$Needs_Update->{$name}},1 if $newf;

  return $table;

};

# ---   *   ---   *   ---

sub update_notify($name) {

  say {*STDERR}

    "\e[37;1m::\e[0m",

    "updated \e[32;1m",
    $name,

    "\e[0m"

  ;

};

# ---   *   ---   *   ---
# dump trees to cache

END {

  for my $syspath(keys %$Systems) {

    my $frame=$Systems->{$syspath};
    for my $modname(keys %{$frame->{-roots}}) {

      #$frame->{-roots}->{$modname}->prich();

      my $updated=$Needs_Update->{$modname};

      next if $modname=~ m[\.trash];
      next unless @$updated;

      # save tree to disk
      my $modf=Shb7::cache(
        "$modname$PX_EXT"

      );

      my $mod=$frame->{-roots}->{$modname};
      store($mod,$modf);

      update_notify($modname);

    };

  };

};

# ---   *   ---   *   ---
# ^similar, cached objects

END {

  for my $file(keys %{$Cache_Regen}) {
    store($Cache_Regen->{$file},$file);
    update_notify($file);

  };

};

# ---   *   ---   *   ---
# either executes a generator
# or loads whatever it generates

sub cached($key,$call,@args) {

  my ($pkgname,$file,$line)=caller;
  my $modname=Shb7::modof(abs_path($file));

  my $out=undef;

  # get path
  $file=Shb7::shpath($file);
  $file=~ s[$modname/?][];
  $file.= q[.st];

  my $path = Shb7::cache($file);
  my $dir  = dirof($path);

  my $rbld =

     Shb7::moo($path,$file)
  or exists $Cache_Regen->{$path}
  ;

  # get entry or make new
  -e $dir or `mkdir -p $dir`;

  my $h=(-f $path)
    ? retrieve($path)
    : $Cache_Regen->{$path}
    ;

  $h//={};

  # regenerate and update
  if(! exists $h->{$key} or $rbld) {
    $out=$h->{$key}=$call->(@args);
    $Cache_Regen->{$path}=$h;

  # ^fetch existing
  } else {
    $out=$h->{$key};

  };

  return $out;

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
1; # ret
