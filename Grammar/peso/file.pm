#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO FILE
# Read, write, good stuff
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::file;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::String;
  use Arstd::Re;
  use Arstd::IO;
  use Arstd::PM;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Grammar;
  use Grammar::peso::std;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # beqs
  $PE_STD->use_common();
  $PE_STD->use_value();
  $PE_STD->use_ops();
  $PE_STD->use_eye();

  # class attrs
  fvars('Grammar::peso::common');

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    q[sow-key]  => re_pekey(qw(sow)),
    q[reap-key] => re_pekey(qw(reap)),

  };

# ---   *   ---   *   ---
# parser rules

  rule('~<sow-key>');
  rule('~<reap-key>');

  rule('$<sow> sow-key invoke vlist term');
  rule('$<reap> reap-key invoke term');

  rule('|<file> &clip sow reap');

# ---   *   ---   *   ---
# ^post-parse file write

sub sow($self,$branch) {

  # convert {invoke} to plain value
  $self->invokes_solve($branch);

  # ^dissect tree
  my $lv    = $branch->{leaves};
  my $fd    = $lv->[1]->leaf_value(0);
  my @vlist = $lv->[2]->branch_values();

  $fd=$self->{mach}->vice(
    'bare',raw=>$fd->get()->[0]

  );

  $branch->{value}={

    fd    => $fd,
    vlist => \@vlist,

    const => [],

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^bind values

sub sow_walk($self,$branch) {

  my $st=$branch->{value};

  # get fd is const
  $self->io_const_fd($st);

  # ^same for args
  @{$st->{const_vlist}}=map {
    $self->const_deref($ARG);

  } @{$st->{vlist}};

  my $i=0;map {

    $ARG=(defined $st->{const_vlist}->[$i++])
      ? undef
      : $ARG
      ;

  } @{$st->{vlist}};

};

# ---   *   ---   *   ---
# get file descriptor is const

sub io_const_fd($self,$st) {

  my $mach=$self->{mach};

  $st->{const_fd}=
    $self->const_deref($st->{fd});


  # ^it is, get handle
  if($st->{const_fd}) {

    my $fd=$self->deref($st->{const_fd}->get());

    ($st->{fd},$st->{buff})=
      $mach->fd_solve($fd->get());

  };

};

# ---   *   ---   *   ---
# ^exec

sub sow_run($self,$branch) {

  my $mach = $self->{mach};
  my $st   = $branch->{value};

  my @path = $mach->{scope}->path();

  # get message
  my $s=$NULLSTR;
  my $i=0;

  map {

    my $x=(! defined $ARG)
      ? $self->deref($st->{vlist}->[$i])
      : $ARG
      ;

    $s.=(Mach::Value->is_valid($x))
      ? $x->{raw}
      : $x
      ;

    $i++;

  } @{$st->{const_vlist}};

  # ^write to dst
  my ($fd,$buff);
  if($st->{const_fd}) {

    $fd   = $st->{fd};
    $buff = $st->{buff};

    $$buff.=$s;

  } else {
    $fd=$self->deref($st->{fd})->get();
    $mach->sow($fd,$s);

  };

};

# ---   *   ---   *   ---
# post-parse file flush

sub reap($self,$branch) {

  # convert {invoke} to plain value
  $self->invokes_solve($branch);

  # ^dissect tree
  my $lv=$branch->{leaves};
  my $fd=$lv->[1]->leaf_value(0);

  $fd=$self->{mach}->vice(
    'bare',raw=>$fd->get()->[0]

  );

  $branch->{value}={fd=>$fd};
  $branch->clear();

};

# ---   *   ---   *   ---
# ^binding

sub reap_walk($self,$branch) {
  my $st=$branch->{value};
  $self->io_const_fd($st);

};

# ---   *   ---   *   ---
# ^exec

sub reap_run($self,$branch) {

  my $mach = $self->{mach};
  my $st   = $branch->{value};

  # ^write to dst
  my ($fd,$buff);
  if($st->{const_fd}) {

    $fd   = $st->{fd};
    $buff = $st->{buff};

    print {$fd} $$buff;
    $fd->flush();

    $$buff=$NULLSTR;

  } else {
    $fd=$self->deref($st->{fd})->get();
    $mach->reap($fd);

  };

};

# ---   *   ---   *   ---
# make a parser tree

  our @CORE=qw(file);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
