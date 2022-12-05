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
  use Arstd::IO;

  use Tree;
  use Queue;

  use Shb7;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.2;
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

  my $Systems={};
  our $Needs_Update={};

# ---   *   ---   *   ---

sub import(@args) {

  my ($pkgname,$file,$line)=caller;
  my $modname=Shb7::modof(abs_path($file));

  goto SKIP if($modname=~ $Std_Dirs);

  my $syskey=$args[-1];
  my $syspath=Shb7::set_root($ENV{$syskey});

  # init project
  if(!exists $Systems->{$syspath}) {
    $Systems->{$syspath}=
     Tree->new_frame();

  };

  # init modules in project
  my $frame=$Systems->{$syspath};
  if(!exists $frame->{-roots}->{$modname}) {
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

  if(!exists $frame->{-roots}->{$name}) {

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
# dump trees to cache

END {

  for my $syspath(keys %$Systems) {

    my $frame=$Systems->{$syspath};
    for my $modname(keys %{$frame->{-roots}}) {

      #$frame->{-roots}->{$modname}->prich();

      my $updated=$Needs_Update->{$modname};

      next if $modname=~ m[\.trash];
      next unless @$updated;

# ---   *   ---   *   ---
# update objects in daf

      ;

# ---   *   ---   *   ---
# save tree to disk

      say {*STDERR}

        "\e[37;1m::\e[0m",

        "updated \e[32;1m",
        $modname,

        "\e[0m"

      ;

      my $modf=Shb7::cache(
        "$modname$PX_EXT"

      );

      my $mod=$frame->{-roots}->{$modname};
      store($mod,$modf);

    };

  };

};

# ---   *   ---   *   ---
# either executes a generator
# or loads whatever it generates

sub cached($key,$ptr,$call,@args) {

  my ($pkgname,$file,$line)=caller;
  my $modname=Shb7::modof(abs_path($file));

  goto SKIP if($modname=~ $Std_Dirs);

# ---   *   ---   *   ---
# get branch object belongs to

  my $frame=$Systems->{$Shb7::Root};
  my $mod=$frame->{-roots}->{$modname};

  my $pkg=$mod->branch_from_path(
    Shb7::shpath(abs_path($file)),
    root=>$Shb7::Root,

  );

# ---   *   ---   *   ---
# get object in tree

  my @objects=@{$pkg->{objects}};
  my %h=@objects;

  if(!exists $h{$key}) {
    push @objects,$key=>1;

  };

# ---   *   ---   *   ---

SKIP:

  if(!defined $$ptr) {
    $$ptr=$call->(@args);

  };

  return $$ptr;

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
1; # ret
