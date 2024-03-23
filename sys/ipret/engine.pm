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
  use Type;
  use Bpack;

  use parent 'ipret::component';

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

  # invoke instruction
  my $ret=$self->invoke(
    $type,$ins->{idx},@values

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
# interpret instruction array

sub run($self,@program) {
  map {$self->step($ARG)} @program;

};

# ---   *   ---   *   ---
1; # ret
