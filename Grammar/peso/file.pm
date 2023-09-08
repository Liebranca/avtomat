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

  our $VERSION = v0.00.4;#b
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
  fvars(
    'Grammar::peso::var',
    -fto=>1,

  );

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    q[fto-key]  => re_pekey(qw(fto)),
    q[sow-key]  => re_pekey(qw(sow)),
    q[reap-key] => re_pekey(qw(reap)),

  };

# ---   *   ---   *   ---
# parser rules

  rule('~<fto-key>');
  rule('~<sow-key>');
  rule('~<reap-key>');

  rule('$<fto> fto-key nterm term');
  rule('$<sow> sow-key nterm term');
  rule('$<reap> reap-key term');

  rule('|<file> &clip fto sow reap');

# ---   *   ---   *   ---
# ^post-parse file select

sub fto($self,$branch) {

  my ($type,$expr)=
    $self->rd_name_nterm($branch);

  $type=lc $type;
  $expr//=[];


  $branch->{value}={

    type => $type,
    expr => $expr->[0],

    fd   => undef,

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^bind

sub fto_ctx($self,$branch) {

  my $st   = $branch->{value};
  my $expr = $st->{expr};

  # save expr as solving F
  $st->{fd}=sub () {return $self->deref(
    $expr,key=>1

  )};

  $self->fto_walk($branch);

};

# ---   *   ---   *   ---
# ^step-on

sub fto_cl($self,$branch) {
  $self->fto_walk($branch);

};

sub fto_run($self,$branch) {
  $self->fto_walk($branch);

};

sub fto_walk($self,$branch) {

  state $tab={

    stdin  => 0,
    stdout => 1,
    stderr => 2,

  };


  # run expr
  my $st  = $branch->{value};

  my $key = $st->{fd}->();
  my $f   = $self->{frame};

  # ^reset
  $f->{-fto}=(exists $tab->{$key})
    ? $tab->{$key}
    : $key
    ;

};

# ---   *   ---   *   ---
# ^post-parse file write

sub sow($self,$branch) {

  my ($type,$vlist)=
    $self->rd_name_nterm($branch);

  $type=lc $type;
  $vlist//=[];


  # repack
  $branch->{value}={

    type  => $type,
    vlist => $vlist,

    const => [],

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^bind values

sub sow_walk($self,$branch) {

  my $st=$branch->{value};

# DEPRECATED
#  # get fd is const
#  $self->io_const_fd($st);

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
# DEPRECATED
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

#    my $x=$self->deref($ARG);

    my $c=(Mach::Value->is_valid($x))
      ? $x->rget()
      : $x
      ;


    $c//='[null]';
    $s.=$c;

    $i++;

  } @{$st->{vlist}};


  # TODO: const fd
  my $f  = $self->{frame};
  my $fd = $self->deref($f->{-fto})->get();

  $mach->sow($fd,$s);

};

# ---   *   ---   *   ---
# post-parse file flush

sub reap($self,$branch) {
  $branch->{value}='reap';
  $branch->clear();

};

# ---   *   ---   *   ---
# ^exec

sub reap_run($self,$branch) {

  my $mach = $self->{mach};

  # TODO: const fd
  my $f  = $self->{frame};
  my $fd = $self->deref($f->{-fto})->get();

  $mach->reap($fd);

};

# ---   *   ---   *   ---
# codestr for file select

sub fto_fasm_xlate($self,$branch) {
  $branch->{fasm_xlate}="[TODO: set fto]\n";

};

# ---   *   ---   *   ---
# codestr for file write

sub sow_fasm_xlate($self,$branch) {
  $branch->{fasm_xlate}="[TODO: fwrite]\n";

};

# ---   *   ---   *   ---
# make a parser tree

  our @CORE=qw(file);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
