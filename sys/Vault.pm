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
  use Arstd;

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

# ---   *   ---   *   ---
# global state

  my $systems={};
  my $needs_update={};

# ---   *   ---   *   ---

sub import(@args) {

  my ($pkgname,$file,$line)=caller;
  my $modname=Shb7::module_of(abs_path($file));

  my $syskey=$args[-1];
  my $syspath=Shb7::set_root($ENV{$syskey});

  if(!exists $systems->{$syspath}) {
    $systems->{$syspath}=
     Tree->new_frame();

  };

  my $frame=$systems->{$syspath};

# ---   *   ---   *   ---
# load existing module tree

  if(!exists $frame->{roots}->{$modname}) {

    $needs_update->{$modname}=[];

    my $modf=Shb7::cache_file("$modname$PX_EXT");

    if(-f $modf) {

      my $mod=retrieve($modf);
      $frame->{roots}->{$modname}=$mod;

      goto TAIL;

# ---   *   ---   *   ---
# build/append to tree

    } else {

      $frame->{roots}->{$modname}=
        $frame->nit(undef,$modname);

    };

# ---   *   ---   *   ---

  };

  my $mod=$frame->{roots}->{$modname};

  if($pkgname eq 'main') {
    $pkgname=Shb7::shpath(abs_path($file));

  };

  my $pkg=$mod->branch_in(
    qr{^$pkgname$},
    max_depth=>1

  );

  if(!defined $pkg) {
    $pkg=$frame->nit($mod,$pkgname);

  };

# ---   *   ---   *   ---

TAIL:
  return;

};

# ---   *   ---   *   ---
# dump trees to cache

END {

  for my $syspath(keys %$systems) {

    my $frame=$systems->{$syspath};
    for my $modname(keys %{$frame->{roots}}) {

      my $updated=$needs_update->{$modname};
      next unless @$updated;

# ---   *   ---   *   ---
# update objects in daf

      ;

# ---   *   ---   *   ---
# save tree to disk

      say "updated \e[32;1m",$modname,"\e[0m\n";

      my $modf=Shb7::cache_file(
        "$modname$PX_EXT"

      );

      my $mod=$frame->{roots}->{$modname};
      store($mod,$modf);

    };

  };

};

# ---   *   ---   *   ---
# either executes a generator
# or loads whatever it generates

sub cached($key,$ptr,$call,@args) {

  my ($pkgname,$file,$line)=caller;
  my $modname=Shb7::module_of(abs_path($file));

  $key.=q{:};
  my $stamp=-M $file;

# ---   *   ---   *   ---
# get branch object belongs to

  my $frame=$systems->{$Shb7::Root};
  my $mod=$frame->{roots}->{$modname};

  my $pkg=$mod->branch_in(
    qr{^$pkgname$}x,
    max_depth=>1

  );

# ---   *   ---   *   ---
# get object in tree

  my $node=$pkg->branch_in(qr{^$key}x);

  if(!$node) {
    $node=$frame->nit($pkg,$key.$stamp);

  };

  my $mdate=(split $COLON_RE,
    $node->{value})[-1];

  if($mdate > $stamp) {
    $node->{value}=$key.$stamp;

    push @{$needs_update->{$modname}},
      $pkg->absidex($node);

  };

  $mod->prich();

};

# ---   *   ---   *   ---

sub table_files($path,$modname) {

  use Fmat;

  my @files=();

  my $table=$systems->{$path};
  my $module=$table->{$modname};

  my @keys=grep

    {$module->{$ARG}}
    keys %$module

  ;

# ---   *   ---   *   ---

  while(@keys) {

    my $key=shift @keys;

    my $child=$module->{$key};
    say fatdump($child);

    push @keys,grep

      {$child->{$ARG}}
      keys %$child

    ;

  };

# ---   *   ---   *   ---

  exit;

};

# ---   *   ---   *   ---

sub modsum() {

  for my $path(keys %$systems) {

    Shb7::set_root($path);
    my $modules=$systems->{$path};

    for my $name(keys %{$modules->{roots}}) {

      my $table=Shb7::walk($name,-r=>1);

      my @submodules=$table->get_dir_list();
      map {print "$ARG\n"} @submodules;

    };

#    my $files=join q{ },
#      table_files($path,'avtomat');
#
#    my $sum=`cksum $files`;
#    say $sum;

  };

};

# ---   *   ---   *   ---
# read dark archive files

sub dafread($fname,@requested) {

  my $path=Shb7::cache_file($fname.$DAF_EXT);
  my $bytes=$NULLSTR;

# ---   *   ---   *   ---
# check file signature

  open my $FH,'<',$path or croak strerr($path);
  read $FH,my $sig,length $DAFSIG;

  if($sig ne $DAFSIG) {
    Arstd::errout(
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

  Arstd::owc(
    Shb7::cache_file($fname.$DAF_EXT),
    $header.$body

  );

};

# ---   *   ---   *   ---
1; # ret
