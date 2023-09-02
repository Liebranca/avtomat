#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO GRAMMAR
# Recursive swan song
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::Array;
  use Arstd::String;
  use Arstd::Re;
  use Arstd::IO;
  use Arstd::PM;

  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang;
  use Grammar;

  use Grammar::peso::common;
  use Grammar::peso::value;
  use Grammar::peso::ops;
  use Grammar::peso::re;
  use Grammar::peso::eye;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.02.0;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # inherits from
  submerge(

    [qw(

      Grammar::peso::common
      Grammar::peso::value
      Grammar::peso::re

      Grammar::peso::ops

    )],

    xdeps=>1,
    subex=>qr{^throw_},

  );

# ---   *   ---   *   ---
# class attrs

  sub Frame_Vars($class) { return {

    -cdecl  => [],

    %{$PE_COMMON->Frame_Vars()},

  }};

  sub Shared_FVars($self) { return {
    %{Grammar::peso::eye::Shared_FVars($self)},

  }};

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    # imports
    %{$PE_COMMON->get_retab()},
    %{$PE_VALUE->get_retab()},
    %{$PE_OPS->get_retab()},
    %{$PE_RE->get_retab()},

  };

# ---   *   ---   *   ---
# rule imports

  ext_rules(

    $PE_COMMON,qw(

    clist lcom
    term nterm opt-nterm

    beg-curly end-curly
    fbeg-parens fend-parens

  ));

  ext_rules(

    $PE_VALUE,qw(

    bare seal bare-list
    sigil flg flg-list
    num

    value vlist opt-vlist

  ));

  ext_rules(

    $PE_OPS,qw(

    expr opt-expr invoke

  ));

  ext_rules($PE_RE,qw(re));

# ---   *   ---   *   ---
# buffered IO

  rule('%<sow-key=sow>');
  rule('%<reap-key=reap>');

  rule('<sow> sow-key invoke vlist');
  rule('<reap> reap-key invoke');

# ---   *   ---   *   ---
# ^post-parse

sub sow($self,$branch) {

  # convert {invoke} to plain value
  $self->invokes_solve($branch);

  # ^dissect tree
  my $lv    = $branch->{leaves};
  my $value = $lv->[1]->leaf_value(0);
  my @vlist = $lv->[2]->branch_values();

  $branch->{value}={

    fd    => $value,
    vlist => \@vlist,

    const => [],

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^bind values

sub sow_opz($self,$branch) {

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

    ($st->{fd},$st->{buff})=$mach->fd_solve(
      $st->{const_fd}->deref()

    );

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
    $fd=$self->deref($st->{fd})->{raw};
    $mach->sow($fd,$s);

  };

};

# ---   *   ---   *   ---
# ^similar story, flushes buffer writes

sub reap($self,$branch) {

  # convert {invoke} to plain value
  $self->invokes_solve($branch);

  # ^dissect tree
  my $lv=$branch->{leaves};
  my $fd=$lv->[1]->leaf_value(0);

  $branch->{value}={fd=>$fd};
  $branch->clear();

};

# ---   *   ---   *   ---
# ^binding

sub reap_opz($self,$branch) {
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
    $fd=$self->deref($st->{fd})->{raw};
    $mach->reap($fd);

  };

};

# ---   *   ---   *   ---
# groups

  # default F
  rule('|<bltn> &clip sow reap');
  rule('|<cdef> &clip def redef undef');

  # non-terminated
  rule('|<meta> &clip lcom');

  # ^else
  rule(q[

    |<needs-term-list>
    &clip

    header hier sdef
    wed cdef lis

    re io ptr-decl

    switch jmp rept bltn

  ]);

  rule(q[

    <needs-term>
    &clip

    needs-term-list term

  ]);

# ---   *   ---   *   ---
# ^generate parser tree

  our @CORE=qw(meta needs-term);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
# test

  my $src=$ARGV[0];
  $src//='lps/peso.rom';

  my $prog=($src=~qr{\.rom$})
    ? orc($src)
    : $src
    ;

  return if ! $src;

  $prog =~ m[([\S\s]+)\s*STOP]x;
  $prog = ${^CAPTURE[0]};

  my $ice=Grammar::peso->parse($prog);

#  $ice->{p3}->prich();
  $ice->{mach}->{scope}->prich();


#  $ice->run(
#
#    entry=>1,
#    keepx=>1,
#
#    input=>[
#
#      'hey',
#
#    ],
#
#  );

# ---   *   ---   *   ---
1; # ret
