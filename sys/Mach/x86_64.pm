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

  use Tree;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#b
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
    tf   => Tree->new_frame(),

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

  my $tf    = $self->{tf};

  # ^make tables
  my $reg={

    $self->get_avail_all(\@avail,%O),

    sct      => {},
    sctk     => [],

    avail    => \@avail,
    using    => [],

    using_re => $NO_MATCH,
    xtab     => {},

    size     => 0,
    insroot  => $tf->nit(
      undef,"$name\::insroot"

    ),

  };


  # add to table and give
  $self->{tab}->{$name} = $reg;
  $self->{cur}          = $reg;

  $self->{cur}->{size}  = $self->{size};
  $self->{size}         = 0;

  $self->reset_using();

  return $reg;

};

# ---   *   ---   *   ---
# make re for finding used
# registers

sub reset_using($self) {

  my $cur=$self->{cur};

  # ^get full list of
  # registers in use
  @{$cur->{using}}=map {
    @{$cur->{$ARG}}

  } qw(arg stk ret sctk);

  # ^as regex
  $cur->{using_re}=re_eiths(
    [array_keys($cur->{using})]

  ) if @{$cur->{using}};

};

# ---   *   ---   *   ---
# ^set X to cur

sub set_blk($self,$name) {
  $self->{cur}=$self->{tab}->{$name}
  if exists $self->{tab}->{$name};

};

# ---   *   ---   *   ---
# allocate register

sub get_scratch($self) {

  my $cur=$self->{cur};
  my $out=shift @{$cur->{avail}};

  $cur->{sct}->{$out}=1;
  $cur->{sctk}=[keys %{$cur->{sct}}];

  $self->reset_using();

  return $out;

};

# ---   *   ---   *   ---
# ^give back

sub free_scratch($self,$name) {

  my $cur=$self->{cur};
  unshift @{$cur->{avail}},$name;

  delete $cur->{sct}->{$name};
  $cur->{sctk}=[keys %{$cur->{sct}}];

  $self->reset_using();

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
# ^used by cur

sub in_use($self,$name) {
  my $cur=$self->{cur};
  return int($name=~ $cur->{using_re});

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
# make new instruction branch

sub new_ins($self,$dst) {

  my $cur  = $self->{cur};
  my $root = $cur->{insroot};

  $root->init($dst);

};

# ---   *   ---   *   ---
# ^sub-branch

sub new_insblk($self,$dst) {

  my $cur  = $self->{cur};
  my $root = $cur->{insroot}->{leaves}->[-1];

  $root->init($dst);

};

# ---   *   ---   *   ---
# ^add instruction to top

sub push_insblk($self,$ins,@args) {

  my $cur  = $self->{cur};
  my $root = $cur->{insroot}->{leaves}->[-1];

  my $blk  = $root->{leaves}->[-1];
  my $top  = $blk->{leaves}->[-1];

  my $nd   = ($top && $top->{value} eq $ins)
    ? $top
    : $blk->init($ins)
    ;

  map  {$nd->init($ARG)}
  grep {$ARG} @args;

};

# ---   *   ---   *   ---
# ^debug out

sub prich_insblk($self) {

  my $cur  = $self->{cur};
  my $root = $cur->{insroot};

  $root->prich();
  exit;

};

# ---   *   ---   *   ---
1; # ret
