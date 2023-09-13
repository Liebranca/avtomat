#!/usr/bin/perl
# ---   *   ---   *   ---
# MACH x86_64
# Helps me think in aramaic
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mach::x86_64;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Fmat;

  use Arstd::Array;
  use Arstd::Int;
  use Arstd::Re;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $REGISTERS=>{
    arg=>[qw(rdi rsi rdx r10 r8 r9)],
    stk=>[qw(rbx r11 r12 r13 r14 r15 rcx)],
    ret=>[qw(rax)],

  };

# ---   *   ---   *   ---
# cstruc

sub new($class) {

  my $self=bless {

    cur  => undef,
    tab  => {},

    size => 0,

  },$class;

};

# ---   *   ---   *   ---
# get listing of used/avail
# registers, guts v

sub _get_avail($self,$ar,$avail) {

  my @out=();

  # make note of used registers
  while(@$avail && @$ar) {

    push @out,
       (shift @$avail)
    => (shift @$ar)->{c_data_id}
    ;

  };

  # ^stack-allocate if we run
  # out of registers
  while(@$ar) {

    my $v     = shift @$ar;

    my $width = $v->get_bwidth();
    my $pos   = int_align($self->{size},$width);

    my $id    = $v->set_fasm_lis($self->{size});

    push @out,$id=>$v->{c_data_id};

    $self->{size}=$pos+$width;

  };


  # ^give used
  return @out;

};

# ---   *   ---   *   ---
# ^get registers used by blk
# iface v

sub get_avail($self,$dst,$key,$ar) {

  my @avail = (@{$REGISTERS->{$key}},@$dst);
  my @used  = $self->_get_avail(
    $ar,\@avail

  );

  @$dst=@avail;

  return (

    $key       => \@used,
    "${key}_s" => [],

  );

};

# ---   *   ---   *   ---
# ^combo

sub get_avail_all($self,$dst,%O) {

  return map {
    $self->get_avail($dst,$ARG,$O{$ARG}),

  } qw(arg stk ret);

};

# ---   *   ---   *   ---
# make new frame

sub new_blk($self,$name,%O) {

  # defaults
  $O{arg} //= [];
  $O{stk} //= [];
  $O{ret} //= [];


  # get calling frame
  my $old   = $self->{reg}->[-1];
  my @avail = ();


  # ^make tables
  my $reg={

    $self->get_avail_all(\@avail,%O),

    avail    => \@avail,
    using    => [],

    using_re => $NO_MATCH,
    xtab     => {},

  };


  # ^get full list of
  # registers in use
  @{$reg->{using}}=map {
    @{$reg->{$ARG}}

  } qw(arg stk ret);

  # ^as regex
  $reg->{using_re}=re_eiths(
    [array_keys($reg->{using})]

  ) if @{$reg->{using}};


  # add to table and give
  $self->{tab}->{$name} = $reg;
  $self->{cur}          = $reg;

  return $reg;

};

# ---   *   ---   *   ---
# ^set X to cur

sub set_blk($self,$name) {
  $self->{cur}=$self->{tab}->{$name}
  if exists $self->{tab}->{$name};

};

# ---   *   ---   *   ---
# get overlap in used registers

sub get_used_by($self,$name) {

  my $cur=$self->{cur};
  my $old=$self->{tab}->{$name};

  throw_no_blk($name) if ! $old;


  return map {
    my $re=$old->{using_re};
    grep {$ARG=~ $re} @{$cur->{$ARG}};

  } qw(arg stk ret);

};

# ---   *   ---   *   ---
# ^give code for save/restore

sub save_used_by($self,$name) {

  my @used=$self->get_used_by($name);


  my $save=join "\n",map {
    "push $ARG"

  } @used;

  my $load=join "\n",map {
    "pop $ARG"

  } reverse @used;


  return ("$save\n","$load\n");

};

# ---   *   ---   *   ---
# ^give code for passing args

sub pass_args($self,$name,@values) {

  my $cur=$self->{cur};
  my $old=$self->{tab}->{$name};

  throw_no_blk($name) if ! $old;


  my $args=$old->{arg};

  throw_arg_cnt($name)
  if int(@values) < int(@$args);


  my @out=map {

    my $src=$values[$ARG];
    my $dst=$args->[$ARG];

    "mov $dst,$src";

  } 0..@$args-1;


  return join "\n",@out,"\n";

};

# ---   *   ---   *   ---
# ^errme

sub throw_no_blk($name) {

  errout(

    q[Invalid block name '%s'],

    lvl  => $AR_FATAL,
    args => [$name],

  );

};

# ---   *   ---   *   ---
1; # ret
