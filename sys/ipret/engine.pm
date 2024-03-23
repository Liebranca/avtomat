#!/usr/bin/perl
# ---   *   ---   *   ---
# IPRET:ENGINE
# I'm running things!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package ipret::engine;

  use v5.36.0;
  use strict;
  use warnings;

  use Storable;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;
  use Bpack;

  use parent 'rd::component';

# ---   *   ---   *   ---
# get value from descriptor

sub operand_value($self,$ins,$type) {

  map {

    my $o    = $data->{$ARG};
    my $imm  = exists $o->{imm};


    # memory deref?
    if($ins->{"load_$ARG"} &&! $imm) {

      $o->{seg}->load(
        $type,$o->{addr}

      );

    # ^immediate?
    } elsif($imm) {
      Bpack::layas($type,$o->{imm});

    # ^plain addr?
    } else {

      my $addr=
        $o->{seg}->absloc()+$o->{addr};

      Bpack::layas($type,$addr);

    };


  } qw(dst src)[0..$ins->{argcnt}-1];

};

# ---   *   ---   *   ---
# get instruction implementation
# and run it with given args

sub invoke($self,$type,$idx,@args) {


  # get ctx
  my $ISA    = $self->ISA;
  my $guts_t = $ISA->guts_t;
  my $tab    = $ISA->opcode_table;


  # get function assoc with id
  my $fn  = $tab->{exetab}->[$idx];
  my @src = (1 == $#args)
    ? ($args[1]) : () ;


  # ^build call array
  my $op   = $guts_t->$fn($type,@src);
  my @call = (@args)
    ? ($op,$args[0])
    : ($op)
    ;


  # invoke and give
  my @out=$guts_t->copera(@call);

  return \@out;

};

# ---   *   ---   *   ---
# execute next instruction
# in program

sub step($self,$data) {


  # unpack
  my $ezy  = $Type::MAKE::LIST->{ezy};
  my $ins  = $data->{ins};

  my $type = typefet $ezy->[$ins->{opsize}];


  # read operand values
  my @values=
    $self->operand_value($ins,$type);

  # execute instruction
  my $ret=$self->invoke(

    $type,
    $ins->{idx},

    @values

  );


  # save result?
  if($ins->{overwrite}) {

    my $dst=$data->{dst};

    $dst->{seg}->store(
      $type,$ret,$dst->{addr}

    );

  };


  return $ret;

};

# ---   *   ---   *   ---
# read and run program

sub exe($self,$program) {


  # get ctx
  my $main = $self->{main};
  my $mc   = $main->{mc};

  my $mem  = $mc->{bk}->{mem};
  my $enc  = $main->{encoder};


  # input needs decoding?
  if(! is_arrayref($program)) {


    # have executable segment?
    if($mem->is_valid($program)) {
      $program=$program->as_exe;

    };

    # decode binary
    $program=$enc->decode($program);

  };


  # run and give result
  map {$self->step($ARG)} @$program;

};

# ---   *   ---   *   ---
1; # ret
