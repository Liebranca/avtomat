#!/usr/bin/perl
# ---   *   ---   *   ---
# AVTO MAKE
# selfex
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto::make;
  use v5.42.0;
  use strict;
  use warnings;

  use File::Copy qw(copy);
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Cwd qw(getcwd);
  use Style qw(null nop);
  use Chk qw(is_null is_blessref);
  use St qw(is_valid);
  use Log;

  use Arstd::String qw(catpath);
  use Arstd::Bin qw(owc moo);
  use Arstd::Array qw(nkeys nvalues);
  use Arstd::Path qw(basef dirof reqdir);
  use Arstd::throw;
  use Shb7::Path qw(root module);

  use lib "$ENV{ARPATH}/lib/";
  use avto::bk;
  use avto::bk::flat;
  use avto::bk::MAM;
  use avto::bk::CMAM;
  use avto::xs;
  use avto::olink;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.02.4';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub sandbox_name {return "avto::sandbox"};
sub sandbox {
  my $pkg="package ". sandbox_name();
  return eval("$pkg {@_}");
};


# ---   *   ---   *   ---
# entry point

sub build {
  my ($px,$sw)=@_;
  my $old=getcwd();
  chdir(module());
  update($px,$sw,'gen');
  update($px,$sw,'fcpy');

  my ($cnt,@obj)=update($px,$sw,'obj');

  build_binaries($px,$sw,@obj)
  if int(@obj) && ($cnt || $sw->{update});

  chdir($old);
  return 1;
};


# ---   *   ---   *   ---
# wrapper for each update method

sub update {
  my ($px,$sw,$which)=@_;

  # get && validate which method to run
  my $tab={
    gen => [
      \&upgen,
      "running generators",
      qw(gen),
    ],
    fcpy => [
      \&upfcpy,
      "copying regular files",
      qw(lcpy xcpy),
    ],
    obj => [
      \&upobj,
      "rebuilding objects",
      qw(flat CMAM MAM),
    ],
  };
  throw "avto: undefined update '$which'"
  if!   exists $tab->{$which};

  my ($fn,$mess,@key)=@{$tab->{$which}};

  # stop here if nothing to do
  my $need={};
  my $skip=1;
  for(@key) {
    my $src=($which eq $ARG)
      ? $px->{$which}
      : $px->{$ARG}
      ;
    if(is_valid("avto::bk",$src)) {
      $need->{$ARG} //= [];
      my @ar=$src->on_build($sw);
      $skip &=~ (int(@ar) > 0);

      push @{$need->{$ARG}},@ar;

    } else {
      $skip &=~ (int(@$src) > 0);
    };
  };
  return (0,()) if $skip &&! $sw->{update};

  # run method
  Log->step($mess);
  my ($ok,@out)=$fn->($px,$sw,$need);

  # add a blank line to the logs,
  # merely for the cute prints
  Log->line() if $ok;
  return ($ok,@out);
};


# ---   *   ---   *   ---
# ice for generator scripts

sub upgen {
  my ($px,$sw)=@_;

  my $ok=0;
  my @nk=nkeys($px->{gen});
  my @nv=nvalues($px->{gen});
  for my $i(0..$#nk) {
    my $dst=$nk[$i];
    my $src=$nv[$i];
    reqdir(dirof($dst));

    # only regenerate if need
    if($sw->{clean} || moo($dst,$src)) {
      avto::bk->log_fpath($dst);

      my $body=sandbox(@$src);
      throw "avto: cannot run generator "
      .     "for '$dst'"

      if!   defined $body;

      owc($dst,$body);
      ++$ok;
    };
  };
  return ($ok,());
};


# ---   *   ---   *   ---
# plain cp

sub upfcpy {
  my ($px,$sw)=@_;
  my ($lok,@lout)=upfcpy_impl($px,$sw,'lcpy');
  my ($xok,@xout)=upfcpy_impl($px,$sw,'xcpy');

  return ($lok || $xok,(@lout,@xout));
};
sub upfcpy_impl {
  my ($px,$sw,$which)=@_;

  my $ok=0;
  for(@{$px->{which}}) {
    my $src   = $ARG;
    my $fname = basef($src);

    my $dst=($which eq 'xcpy')
      ? catpath(root(),'bin',$fname)
      : catpath(root(),'lib',$fname)
      ;
    reqdir(dirof($dst));

    # only copy if need
    if($sw->{clean} || moo($dst,$src)) {
      avto::bk::log_fpath($src);
      copy($src,$dst);

      ++$ok;
    };
  };
  return ($ok,());
};


# ---   *   ---   *   ---
# re-run object file compilation

sub upobj {
  my ($px,$sw,$need)=@_;

  # iter backends
  # each holds it's own list of source files
  my $cnt  = 0;
  my @link = ();
  for(qw(flat CMAM MAM)) {
    my $out=$px->{$ARG}->build(
      $sw,
      @{$need->{$ARG}}
    );
    $cnt += $out->{updated};
    push @link,@{$out->{linkable}};
  };
  # save linkable files
  Log->line() if $cnt;
  return ($cnt,@link);
};


# ---   *   ---   *   ---
# the one we've been waiting for
#
# this sub only builds a new binary IF
# there is a target defined AND
# any objects have been updated

sub build_binaries($px,$sw,@obj) {
  olink($px,$sw,@obj);

  # for executables, we archive the objects too!
  if(! $sw->{static} &&! $sw->{shared}) {
    my $old=$sw->{output};
    $sw->{static}=1;
    $sw->{output}=$px->{bld}->{path}->{ar};

    olink($px,$sw,@obj);

    $sw->{static}=0;
    $sw->{output}=$old;
  };
  # generate bindings to compiled objects
  # that were marked for export
  my @xprt=@{$px->{xprt}};
  if(@xprt) {
    Log->fupdate(
      $px->{bld}->{name},
      "compiling shwl for"
    );
    my $shwl=avto::xs::mkshwl(
      $px->{name},
      $px->{bld}->{path}->{sl},
      $sw->{lib},
      @xprt
    );
    my $old=chdir(root());
    avto::xs::build(
      $shwl,
      $sw,
      $px->{bld}->{name},
      -f=>1,
    );
    chdir($old);
  };
  return;
};


# ---   *   ---   *   ---
1; # ret
