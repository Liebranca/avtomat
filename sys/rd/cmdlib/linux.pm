#!/usr/bin/perl
# ---   *   ---   *   ---
# LINUX
# Kernel talk
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::cmdlib::linux;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

  use rd::vref;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'rd::cmd';
  BEGIN {rd::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  calltab => {

    write => 0x01,
    exit  => 0x3C,

  },

  args_order => [0x4..0x9],

};

# ---   *   ---   *   ---
# generate syscall

sub oscall($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};


  # get F/arguments
  my ($args,$args_t)=
    $self->argtake_flat($branch);

  my ($fn)=(
    shift @$args,
    shift @$args_t,

  );


  # symbol name is subtree?
  my $name=undef;
  if(Tree->is_valid($fn)) {

    $name=$l1->xlate($fn->{value});
    $fn->flatten_branch();

    ($args,$args_t)=
      $self->argtake_flat($branch);


  # ^nope, plain token
  } else {
    $name=$l1->xlate($fn);

  };


  # get symbol name
  $name=($name->{type} eq 'STR')
    ? $name->{data}
    : $name->{spec}
    ;


  # ^validate
  $main->perr(

    "oscall [ctl]:%s not in linux table\n"
  . 'see: [goodtag]:%s',

    args => [$name,'rd::cmdlib::linux'],

  ) if ! exists $self->calltab->{$name};


  # enqueue loading of registers
  my $code = $self->calltab->{$name};
     $code  = $l1->tag(NUM=>$code);

  my @r    = @{$self->args_order};
  my @pass = ();

  $branch->clear();


  # generate instruction nodes
  map {

    my ($nd)=$branch->inew(
      $l1->tag(CMD=>'ld'),

    );


    $nd->{lineno} = $branch->{lineno};
    $nd->{cmdkey} = 'ld';
    $nd->{vref}   = rd::vref->new(
      type=>'TYPE',
      spec=>shift @$args_t,

    ) if int @$args_t;

    push @pass,$r[0];

    $nd->inew($l1->tag(REG => shift @r));

    (Tree->is_valid($ARG))
      ? $nd->pushlv($ARG)
      : $nd->inew($ARG)
      ;


  } @$args;


  # ^rax last ;>
  my $foot=$branch->inew(
    $l1->tag(CMD=>'ld')

  );

  $foot->{cmdkey} = 'ld';
  $foot->{lineno} = $branch->{lineno};

  $foot->inew($l1->tag(TYPE => 'dword'));
  $foot->inew($l1->tag(REG  => 0x00));
  $foot->inew($code);

  push @pass,0x00;


  # enqueue interrupt
  $foot=$branch->inew(
    $l1->tag(CMD=>'int')

  );

  $foot->{cmdkey} = 'int';


  # bat-proc instructions
  my @ins=$branch->flatten_branch();
  my $asm=$self->{frame}->fetch('asm-ins');

  map {$asm->{key}->{fn}->($asm,$ARG)} @ins;

  $foot->{vref}->{data}={
    code => $name,
    pass => \@pass,

  };

  return;

};

# ---   *   ---   *   ---
# add entry points

unrev cmdsub os => q(
  qlist args=();

) => \&oscall;

# ---   *   ---   *   ---
1; # ret
