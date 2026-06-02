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
  use Style qw(null);
  use Chk qw(is_null);
  use Log;

  use Arstd::String qw(catpath);
  use Arstd::throw;

  use lib "$ENV{ARPATH}/lib/";
  use avto::bk;
  use avto::xs;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.02.1';
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
  update($px,$sw,'gen');
  update($px,$sw,'fcpy');

  my @obj=update($px,$sw,'obj');

  return 1;
};

# TODO discarding px->{bld}->{path}
#      based on mode
#
#  my $tab={
#    so => ['ar','ex'],
#    ar => ['so','ex'],
#    ex => ['so'],
#  };


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
      \&upfcpy,
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
    my $src=$px->{$which};
    if($src->isa('avto::bk')) {
      $need->{$ARG} //= [];
      push @{$need->{$ARG}},$src->on_build($sw);

    } else {
      $skip &=~ int(@$src);
    };
  };
  return (0,()) if $skip;

  # run method
  Log->step($mess);
  my ($ok,@out)=$fn->($px,$sw);

  # add a blank line to the logs,
  # merely for the cute prints
  Log->line() if $ok;
  return @out;
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

      my $body=sandbox($src);
      throw "avto: cannot run generator "
      .     "for '$dst'"

      if!   defined $body;

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

sub upobj_impl {
  my $bfiles=[];
  my $objblt=0;

  # skip if nothing to build
  my ($self)=@_;
  return $objblt if! $self->get_build_files();

  Log->step("rebuilding objects");

  # iter backends
  # each holds it's own list of source files
  for(qw(flat cmam mam)) {
    my ($cnt,@link)=
      $self->{$ARG}->build($self->{bld});

    $objblt+=$cnt;
    push @$bfiles,@link;
  };

  # save linkable files
  $self->{bld}->push_files(@$bfiles);
  Log->line() if $objblt;

  return $objblt;
};


# ---   *   ---   *   ---
# the one we've been waiting for
#
# this sub only builds a new binary IF
# there is a target defined AND
# any objects have been updated

sub build_binaries($self,$objblt) {
  my @calls = ();
  my @libs  = ();

  my @objs  = map {
    $ARG->{obj}

  } @{$self->{bld}->{file}};

  @libs=@{$self->{bld}->{lib}};

  if($self->{main}
  && (($objblt || $self->{clean}) && @objs)) {
    my $rel=$self->{main};
    relto_root($rel);
    Log->fupdate($rel,'compiling binary');


    # build mode is 'static library'
    if($self->{lmode} eq 'ar') {
      push @calls,[
        qw(ar -crs),
        $self->{main},@objs
      ];

    # otherwise it's executable or shared object
    } else {
      if(-f $self->{main}) {
        unlink $self->{main};
      };

      # for executables we spawn a shadow lib
      if($self->{lmode} ne '-shared ') {
        push @calls,[
          qw(ar -crs),
          $self->{mlib},@objs
        ];
      };

      olink($self->{bld});
    };

  };


  # run build calls and make symbol tables
  for my $call(@calls) {
    filter($call);
    system {$call->[0]} @$call;
  };

  # generate bindings to compiled objects
  # that were marked for export
  my @xprt=@{$self->{xprt}};
  if(@libs && $self->{ilib} && @xprt) {
    Log->fupdate(
      $self->{mkwat},
      'compiling shwl for'
    );

    my $shwl=avto::xs::mkshwl(
      $self->{fswat},
      $self->{ilib},
      \@libs,
      @xprt
    );
    avto::xs::build(
      $shwl,
      $self->{bld},
      $self->{mkwat},
      -f=>1,
    );
  };

  return;
};


# ---   *   ---   *   ---
1; # ret
