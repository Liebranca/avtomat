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
# lib,

# ---   *   ---   *   ---
# deps

package Vault;
  use v5.42.0;
  use strict;
  use warnings;

  use Cwd qw(abs_path);

  use English qw($ARG);

  use Storable qw(store retrieve freeze thaw);
  use Fcntl qw(SEEK_SET SEEK_CUR);

  use lib "$ENV{ARPATH}/lib/";
  use AR sys=>qw(
    use Style::(null);
    use Chk::(is_null is_hashref is_dir);
    lis Arstd::Array::(dupop);
  );

  use Arstd::Bin qw(moo);
  use Arstd::Path qw(reqdir dirof);
  use Arstd::Re qw(eiths);
  use Arstd::throw;

  use Log;

  use Tree;
  use Tree::File;
  use Shb7::Path qw(
    root
    swap_root
    cachep
    modof
  );
  use Shb7::Find qw(ffind);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.2b';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

my $PKG=__PACKAGE__;
St::vconst {
  PX_EXT=>'.px',
  STD_DIR_RE=>qr{(?:

    bin
  | lib

  | \.cache
  | \.trash

  | include

  )}x,
};


# ---   *   ---   *   ---
# global state

sub module {
  state $out={};
  return ($_[0] && exists $out->{$_[0]})
    ? $out->{$_[0]}
    : $out
    ;
};

sub regen {
  state $out={};
  return $out;
};

sub fdeps {
  state $out={};
  return $out;
};


# ---   *   ---   *   ---
# makes ice if needed
#
# [0]: byte ptr  | class
# [1]: byte ptr  | module key
# [2]: byte ptr  | module root
#
# [3]: byte pptr | list of dirs that are
#                  excluded from search path
#
# [4]: bool      | force tree recalc

sub req {
  my $self=module()->{$_[1]}//=bless {
    key    => $_[1],
    root   => $_[2],
    tree   => null,
    update => [],

  },$_[0];

  $_[3]//=[];
  $_[4]//=0;
  $self->make_tree($_[3],$_[4])
  if is_null($self->{tree}) || $_[4];

  return $self;
};


# ---   *   ---   *   ---
# marks package as utilizing
# the cache directory

sub import {
  my ($class,$to_root,$key)=@_;
  my ($pkgname,$file,$line)=caller;

  # early exit when either:
  # * called from self,
  # * called from eval,
  # * invalid module key
  return if (
     ($pkgname eq 'Vault')
  || ($file =~ qr{\(eval \d+\)})
  || ($key  =~ $PKG->STD_DIR_RE)
  );

  # get absolute path to root directory
  my $root=abs_path(
    dirof(abs_path($file))
  . "/$to_root"
  );

  throw sprintf(
    q[Invalid root directory <%s> passed in ] .
    q[to Vault from %s],

    $root,$file,

  ) unless is_dir($root);

  # nit module on first run
  $class->req($key,$root);
  return;
};


# ---   *   ---   *   ---
# make file tree for  a module,
# used for building

sub make_tree($self,$excluded=[],$recalc=0) {
  my $root = swap_root($self->{root});

  my $modf = $self->px_file();
  my $newf = (-f $modf) ? 0 : 1;

  # load existing?
  if(! $newf &&! $recalc) {
    $self->{tree}=retrieve($modf);

  # ^nope, (re)generate!
  } else {
    my $fslash_re =  qr{/+};
    my $path      =  "$root/$self->{key}/";
       $path      =~ s[$fslash_re][/]smg;

    my $tree=Tree::File->new($path);
    $tree->expand(
      -r=>1,
      -x=>eiths($excluded),
    );
    $self->{tree}=$tree;
  };

  # checksum the tree
  # new result will be saved if there's changes
  my $diff=int $self->{tree}->get_cksum_diff();
  push @{$self->{update}},$diff;

  # cleanup and give
  swap_root();
  return $self->{tree};
};


# ---   *   ---   *   ---
# ^finds a project cache file

sub px_file($self) {
  my $name=(ref $self)
    ? $self->{key}
    : $self
    ;
  return cachep("$name" . $PKG->PX_EXT);
};


# ---   *   ---   *   ---
# get list of updated trees

sub get_module_update() {
  my @out=();
  my $reg=module();

  for my $name(keys %$reg) {
    my $mod=$reg->{$name};

    next if $mod->{root}=~ m[\.trash];
    next unless int grep {$ARG} @{$mod->{update}};

    push @out,$name;
  };

  return @out;
};


# ---   *   ---   *   ---
# dump trees to cache

END {
  my @updated=get_module_update();
  Log->mprich(
    'AR/Vault',
    'updating module cache'

  ) if @updated;

  for my $name(@updated) {
    Log->fupdate($name);

    my $self=module($name);
    swap_root($self->{root});

    # save tree to disk
    my $modf=cachep("$name" . $PKG->PX_EXT);
    store($self->{tree},$modf);

    swap_root();
  };
};


# ---   *   ---   *   ---
# ^similar, cached objects

END {
  my $regen = regen();
  my $done  = int(%$regen);
  Log->mprich(
    'AR/Vault',
    'updating object cache'

  ) if $done;

  for my $file(keys %$regen) {
    Log->fupdate($file);
    store($regen->{$file},$file);
  };
};


# ---   *   ---   *   ---
# get object needs update
#
# forces make/regen of
# cache sub directory

sub cached_dir($self,$file) {
  my $root  = swap_root($self->{root});

  my $path  = cashof($file);
  my $dir   = dirof($path);

  my $regen = regen();
  my $rbld  = (
     moo($path,$file)
  || exists $regen->{$path}
  );

  # get entry or make new
  reqdir($dir);


  # have existing?
  my $data=(-f $path)
    ? retrieve($path)
    : $regen->{$path}
    ;

  # check deps
  my $deps   = fdeps()->{$file};
     $deps //= [];

  map {$rbld |= moo($path,$ARG)} @$deps;

  # cleanup, pack and give
  swap_root();
  return {
    rbld => $rbld,
    path => $path,
    data => $data,
  };
};


# ---   *   ---   *   ---
# ^builds path to stash

sub cashof($file) {
  relto_root($file);
  $file.='.st';

  return cachep($file);
};


# ---   *   ---   *   ---
# regen or fetch

sub rof($self,$file,$key,$call,@args) {
  # get ctx
  my $root  = swap_root($self->{root});
  my $cache = $self->cached_dir($file);
  my $data  = $cache->{data};
  my $out   = undef;

  # regen entry?
  if(! exists $data->{$key} || $cache->{rbld}) {
    $out=$data->{$key}=$call->(@args);
    cashreg($cache->{path},$data);

  # ^nope, fetch existing
  } else {
    $out=$data->{$key};
  };

  swap_root();
  return $out;
};


# ---   *   ---   *   ---
# ^register stash for update

sub cashreg($path,$h) {
  regen()->{$path}=$h;
  return;
};


# ---   *   ---   *   ---
# ^keyless variant of rof

sub frof($self,$file,$call,@args) {
  # get ctx
  my $root  = swap_root($self->{root});
  my $cache = $self->cached_dir($file);
  my $data  = $cache->{data};
  my $out   = undef;

  # regen entry?
  if(defined $data || $cache->{rbld}) {
    $out=$data=$call->(@args);
    cashreg($cache->{path},$data);

  # ^nope, fetch existing
  } else {
    $out=$data;
  };

  swap_root();
  return $out;
};


# ---   *   ---   *   ---
# mark file as a dependency

sub depson(@list) {
  # get/nit handle to package deps
  my $file = (caller)[1];
  my $vref = \fdeps()->{$file};

  $$vref //= [];

  # validate input
  map {-f $ARG or throw "$ARG: $!"} @list;

  # ^push to module deps
  push @{$$vref},map {abs_path $ARG} @list;
  dupop($$vref);

  return;
};


# ---   *   ---   *   ---
# either executes a generator
# or loads whatever it generates

sub cached($self,$key,$call,@args) {
  my $file=(caller)[1];
  return $self->rof($file,$key,$call,@args);
};


# ---   *   ---   *   ---
# ^key *IS* file

sub fcached($self,$file,$call,@args) {
  return $self->frof($file,$call,@args);
};


# ---   *   ---   *   ---
# retrieve file if passed var
# is a valid path

sub fchk($self,$var) {
  my $out=(is_hashref $var)
    ? $var
    : undef
    ;

  # early ret
  goto skip if $out;

  # validate input
  ! length ref $var or throw(
    q[Non-scalar, non-hashref var ] .
    q[passed in to fchk]
  );

  # ^fetch
  my $root=swap_root($self->{root});
  my $path=ffind($var)
  or throw "Cannot find object '$var'";

  $out=retrieve($path);
  swap_root();

  skip:
  return $out;
};


# ---   *   ---   *   ---
# selfex

sub deepcpy($o) {
  return thaw(freeze($o));
};


# ---   *   ---   *   ---
1; # ret
