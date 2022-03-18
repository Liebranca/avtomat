#!/usr/bin/perl
# ---   *   ---   *   ---
# BLOCK
# Makes perl reps of peso objects
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package peso::block;
  use strict;
  use warnings;

# ---   *   ---   *   ---

sub nit {

  my $self=shift;
  my $name=shift;

  my $blk=bless {

    -NAME=>$name,
    -ELEMS=>{},

  },'peso::block';

  if($self) {
    $self->elems->{$name}=$blk;

  };

  return $blk;

};

# ---   *   ---   *   ---

# getters
sub name {return (shift)->{-NAME};};
sub elems {return (shift)->{-ELEMS};};

# ---   *   ---   *   ---



# ---   *   ---   *   ---
1; # ret
