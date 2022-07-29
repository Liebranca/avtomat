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

  use lib $ENV{'ARPATH'}.'/lib/';
  use Storable qw(freeze thaw);

  use style;
  use arstd;
  use shb7;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  our $DAFSIG=pack 'C'x16,
    0x24,0x24,0x24,0x24,
    0xDE,0xAD,0xBE,0xA7,
    0x24,0x24,0x24,0x24,
    0x71,0xEB,0xDA,0xF0

  ;

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

  my ($isize,$header,$block);

  read $FH,$isize,4;
  $isize=unpack 'L',$isize;

  read $FH,$header,$isize*4;
  my @header=unpack 'L'x$isize,$header;

# ---   *   ---   *   ---
# fetch requested

  my @blocks=();

  for my $idex(@requested) {

    my $start=$header[$idex+0];
    my $ahead=$header[$idex+1];

    my $size=$ahead-$start;

    read $FH,$block,$size;
    seek $FH,$size,1;

    push @blocks,thaw($block);

  };

# ---   *   ---   *   ---

  close $FH or croak STRERR($path);
  return @blocks;

};

# ---   *   ---   *   ---

sub dafwrite($fname,@blocks) {

  my @header=(4+4+length $DAFSIG);
  my $body=$NULLSTR;

  for my $block(@blocks) {

    $block=freeze($block);
    $body.=$block;

    say $header[-1];
    say length $block;

    push @header,$header[-1]+length $block;

  };

# ---   *   ---   *   ---

  unshift @header,int(@header);

  my $header=$DAFSIG.(
    pack 'L'x@header,@header

  );

  arstd::owc(
    shb7::cache_file($fname),
    $header.$body

  );

};

# ---   *   ---   *   ---
1; # ret
