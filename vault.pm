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
package vault;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use Cwd qw(abs_path);

  use Storable qw(freeze thaw);
  use Fcntl qw(SEEK_SET SEEK_CUR);

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;
  use shb7;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
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

# ---   *   ---   *   ---
# global state

  our $systems={-order=>[]};

# ---   *   ---   *   ---

sub import(@args) {

  my ($pkg,$fname,$line)=caller;
  if($pkg eq 'main') {goto TAIL};

# ---   *   ---   *   ---
# get topdir

  my $syskey=$args[-1];
  my $syspath=abs_path($ENV{$syskey});

  if($syspath ne $shb7::root) {
    $syspath=shb7::set_root($syspath);

    if(!exists $systems->{$syspath}) {
      $systems->{$syspath}={};
      push @{$systems->{-order}},$syspath;

    };

  };

# ---   *   ---   *   ---

  my $mod=shb7::module_of(
    abs_path($fname)

  );

  $fname=shb7::shpath(abs_path($fname));
  $fname=~ s/^${mod}//;

  my $modules=$systems->{$syspath};

  $modules->{$mod}//={};
  $modules->{$mod}->{$fname}//=[];

  push @{$modules->{$mod}->{$fname}},$pkg;

# ---   *   ---   *   ---

TAIL:
  return;

};

# ---   *   ---   *   ---

sub modsum() {

#  for my $path(keys %$systems) {
#
#    shb7::set_root($path);
#    my $modules=$systems->{$path};
#
#    for my $name(keys %$modules) {
#
#      my $table=shb7::walk($name,-r=>1);
#      $modules->{$name}=$table->[0]->{$name};
#
#    };
#
#  };

#  use pricher;
#  say {*STDERR} pricher::fatdump($systems);

};

END {modsum()};

# ---   *   ---   *   ---

#  my $f=shb7::shpath(abs_path(
#    './hacks/shwl.pm'
#
#  ));
#
#  my @keys=split m[/],$f;
#
#  my $o=$table;
#
#  while(@keys) {
#
#    my $key=shift @keys;
#
#    if(exists $o->[0]->{$key}) {
#      $o=$o->[0]->{$key};
#
#    };
#
#  };
#
#  return $o;

# ---   *   ---   *   ---

sub dafread($fname,@requested) {

  my $path=shb7::cache_file($fname);
  my $bytes=$NULLSTR;

# ---   *   ---   *   ---
# check file signature

  open my $FH,'<',$path or croak STRERR($path);
  read $FH,my $sig,length $DAFSIG;

  if($sig ne $DAFSIG) {
    arstd::errout(
      q{Bad DAF signature on file '%s'},

      args=>[$fname],
      lvl=>$FATAL,

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

  close $FH or croak STRERR($path);
  return @blocks;

};

# ---   *   ---   *   ---

sub dafwrite($fname,@blocks) {

  my ($idex_type,$idex_size)=@{$DAF_ISIZE};

  my @header=(

    (length $DAFSIG)      # signature

    + $idex_size          # number of elements
    + $idex_size          # first idex
    + $idex_size*@blocks  # idex per element

  );

  my $body=$NULLSTR;
  my $i=0;

  for my $block(@blocks) {

    $block=freeze($block);
    $body.=$block;

    push @header,$header[-1]+length $block;

  };

# ---   *   ---   *   ---

  unshift @header,int(@header);

  my $header=$DAFSIG.(
    pack ${idex_type}x@header,@header

  );

  arstd::owc(
    shb7::cache_file($fname),
    $header.$body

  );

};

# ---   *   ---   *   ---
1; # ret
