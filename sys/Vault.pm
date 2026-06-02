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
# NOTE
#
# 'client' refers to a specific
# project, identified by it's
# subdirectory within root
#
# all files within that project
# are registered under the same client

# ---   *   ---   *   ---
# deps

package Vault;
  use v5.42.0;
  use strict;
  use warnings;

  use Cwd qw(abs_path);
  use English qw($ARG);
  use Storable qw(store retrieve);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(
    is_null
    is_file
    is_hashref
    is_dir
  );

  use Arstd::String qw(catpath);
  use Arstd::Bin qw(moo);
  use Arstd::Path qw(
    reqdir
    dirof
    extwap
    extcl
    from_pkg
  );
  use Arstd::Array qw(dupop);
  use Arstd::Re qw(eiths);
  use Arstd::PM qw(lrcaller rcaller);
  use Arstd::throw;

  use Log;
  use St;

  use Shb7::Path qw(swap_root cachep relto_root);
  use Shb7::Find qw(ffind);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.5b';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub fext   {return 'cash'};
sub std_dir_re {
  return qr{(?:
    bin
  | lib

  | \.cache
  | \.trash

  | include

  )}x;
};


# ---   *   ---   *   ---
# global state

sub client {
  state $tab={};
  my ($class,$key)=@_;

  # give client from table?
  if($key) {
    throw "Vault: cannot fetch client '$key'"
    if!   exists $tab->{$key};

    return $tab->{$key};
  };

  # ^nope, give full table!
  return $tab;
};

sub pkg_to_client {
  state $tab={};
  my ($class,$pkg,$key)=@_;

  $tab->{$pkg} //= $class->client($key);

  return $tab->{$pkg};
};


# ---   *   ---   *   ---
# marks package as utilizing
# the cache directory

sub import {
  my ($class,$to_root,$key)=@_;
  my ($pkg,$file,$line)=lrcaller($class);

  # early exit when either:
  # * no package
  # * uninitialized args
  # * called from self,
  # * called from eval,
  # * invalid client key
  return if (! defined $to_root)
         || (! defined $key)
         || ($pkg  eq 'main')
         || ($pkg  eq $class)
         || ($pkg  =~ qr{^SyntaxCheck})
         || ($file =~ qr{\(eval \d+\)})
         || ($key  =~ $class->std_dir_re());

  # get absolute path to root directory
  my $root=abs_path(catpath(
    dirof($file,abs=>1),
    $to_root
  ));

  throw "Vault: invalid root directory <$root> "
  .     "passed in from '$file'"

  if!   is_dir($root);

  # nit client on first run
  $class->new($key,$root)
  if! exists $class->client()->{$key};

  return $class->pkg_to_client($pkg,$key);
};


# ---   *   ---   *   ---
# make ice for client

sub new {
  my ($class,$name,$root)=@_;
  my $out=bless {
    name   => $name,
    root   => $root,
    update => [],
    data   => {},

  },$class;

  $class->client()->{$name}=$out;
  return $out;
};


# ---   *   ---   *   ---
# for a package to request the
# client managing their stuff

sub mine {
  my ($class)=@_;
  my $pkg=rcaller($class);

  return $class->pkg_to_client($pkg);
};


# ---   *   ---   *   ---
# either executes a generator
# or loads whatever it generates

sub cached {
  my ($class,$key,$call,@args)=@_;

  my $pkg    = rcaller($class);
  my $client = $class->pkg_to_client($pkg);

  return $client->rof($pkg,$key,$call,@args);
};


# ---   *   ---   *   ---
# ^shorthand for omitting key

sub fcached {
  my ($class,$call,@args)=@_;

  my $pkg    = rcaller($class);
  my $client = $class->pkg_to_client($pkg);

  return $client->frof($pkg,null,$call,@args);
};


# ---   *   ---   *   ---
# regen or fetch

sub rof {
  my ($client,$pkg,$key,$call,@args)=@_;

  # get source file requesting this operation
  my $src=$pkg;
  from_pkg($src);

  # jump to client root and find cache dir
  my $back  = swap_root($client->{root});
  my $cache = $client->get_cached($pkg,$src,$key);
  my $out   = undef;

  # regen entry?
  if(is_null($cache->{data})
  || $cache->{rbld}) {
    # catch missing F
    throw "Vault: cannot regenerate object "
    .     "'$cache->{path}' -- no function to "
    .     "do so was provided"

    if    is_null($call);

    # ^run F and save result
    $out=$cache->{data}=$call->(@args);
    $client->schedup_impl(
      $cache->{path},
      $cache->{data}
    );

  # ^nope, give existing
  } else {
    $out=$cache->{data};
  };
  swap_root($back);
  return $out;
};


# ---   *   ---   *   ---
# get cached object

sub get_cached {
  my ($client,$pkg,$src,$key)=@_;

  my $dst  = $client->mykey_impl($pkg,$src,$key);
  my $rbld = moo($dst,$src);

  # ensure subdir exits for this entry
  reqdir(dirof($dst));

  # have existing?
  my $data=($client->loaded($dst))
    ? $client->{data}->{$dst}
    : $client->load($dst)
    ;

  # cleanup, pack and give
  return {
    rbld => $rbld,
    path => $dst,
    data => $data,
  };
};


# ---   *   ---   *   ---
# ^builds path to stored object

sub mykey {
  my ($client,$key)=@_;

  # make base of path from calling package
  my $pkg=rcaller(St::cpkg());
  my $src=$pkg;
  from_pkg($src);

  # find client if necessary
  if(! ref($client)) {
    $client=$client->pkg_to_client($pkg);
  };

  # ^then generate full cache key
  my $back = swap_root($client->{root});
  my $out  = $client->mykey_impl($pkg,$src,$key);

  # cleanup and give
  swap_root($back);
  return $out;
};
sub mykey_impl {
  my ($client,$pkg,$src,$key)=@_;

  extcl($src);
  my $fpath = catpath($src,$key);
  my $ext   = ($pkg->can('fext'))
    ? $pkg->fext()
    : $client->fext()
    ;

  relto_root($fpath);
  extwap($fpath,$ext);

  return cachep($fpath);
};


# ---   *   ---   *   ---
# (re)load a cached object

sub load {
  my ($client,$fpath)=@_;
  return null if! is_file($fpath);
  $client->{data}->{$fpath}=retrieve($fpath);

  return $client->{data}->{$fpath};
};


# ---   *   ---   *   ---
# get whether a cashed object has
# already been loaded

sub loaded {
  my ($client,$fpath)=@_;
  return is_file($fpath)
  &&     exists $client->{data}->{$fpath};
};


# ---   *   ---   *   ---
# register stash for update

sub schedup {
  my ($client,$key,$data)=@_;

  # make base of path from calling package
  my $pkg=rcaller(St::cpkg());
  my $src=$pkg;
  from_pkg($src);

  # find client if necessary
  if(! ref($client)) {
    $client=$client->pkg_to_client($pkg);
  };
  # ^then generate full cache key
  my $back = swap_root($client->{root});
     $key  = $client->mykey_impl($pkg,$src,$key);

  $client->schedup_impl($key,$data);

  # cleanup and give
  swap_root($back);
  return;
};
sub schedup_impl {
  my ($client,$fpath,$data)=@_;
  if(defined $data) {
    $client->{data}->{$fpath}=$data;

  } elsif(! defined $client->{data}->{$fpath}) {
    throw "Vault: cannot schedule update of"
    .     "key '$fpath' -- no matching value "
    .     "for client '$client->{name}'";
  };
  push @{$client->{update}},$fpath;

  return;
};


# ---   *   ---   *   ---
# retrieve file, if passed var *is* a file

sub fchk {
  my ($client,$var)=@_;
  my $out=(is_hashref($var))
    ? $var
    : undef
    ;

  # early ret
  return $out if defined $out;

  # validate input
  throw "Vault: non-scalar, non-hashref var "
  .     "'$var' passed to fchk"

  if    length ref $var;

  # ^fetch
  my $back = swap_root($client->{root});
  my $path = ffind($var);
  my $pkg  = rcaller(ref $client);

  throw "Vault: cannot find object '$var' "
  .     "for package '$pkg'";

  $out=retrieve($path);
  swap_root($back);

  return $out;
};


# ---   *   ---   *   ---
# write client package data to disk

sub client_update {
  my ($class)=@_;

  my @updated=$class->get_client_update();
  return if! @updated;
  Log->mprich(
    'AR/Vault',
    'updating client package cache'
  );
  # for each updated client...
  for(@updated) {
    my ($client,@fpath)=@$ARG;
    Log->dopen($client->{name});

    # save objects to disk
    my $back=swap_root($client->{root});
    for(@fpath) {
      my $rel=$ARG;
      relto_root($rel);
      Log->substep($rel);

      reqdir(dirof($ARG));
      store($client->{data}->{$ARG},$ARG);
    };
    swap_root($back);
  };
  Log->step('done');
  return;
};


# ---   *   ---   *   ---
# get list of updated trees

sub get_client_update {
  my ($class)=@_;
  my $tab=$class->client();

  return map {
    my $name   = $ARG;
    my $client = $tab->{$name};

    dupop($client->{update});
    my @out=@{$client->{update}};

    (@out) ? [$client=>@out] : () ;

  } keys %$tab;
};


# ---   *   ---   *   ---
# ensure that cached objects are saved
# to disk at end of execution

END {
  St::cpkg()->client_update();
};


# ---   *   ---   *   ---
1; # ret
