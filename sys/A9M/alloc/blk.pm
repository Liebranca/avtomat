#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M ALLOC:BLK
# Big old chunks
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::alloc::blk;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;
  use Bitformat;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  blk_t => (struc 'alloc.blk' => q{
    word stab;
    word loc;

  }),

  loc_t => (Bitformat 'alloc.loc' => (

    ezy => 5,
    pos => 5,
    lvl => 3,

  )),

};

# ---   *   ---   *   ---
# module kick

sub import($class) {
  $class->blk_t();
  return;

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$stab) {


  # get ctx
  my $alloc = $stab->{main};
  my $root  = $alloc->{mem};


  # get N pages
  my $size = $alloc->{page} << $stab->{lvl};
  my $dst  = $stab->{ptr};
  my $mem  = $root->new($size);

  # ^write to table
  my $head=$stab->{head};
  $head->storef('blk',$mem->{segid});


  # make ice and give
  my $self=bless {
    stab => $stab,
    mem  => $mem,

  },$class;


  return $self;

};

## ---   *   ---   *   ---
## writes sub-block header
#
#sub blk_write($self,$ctx) {
#
#
#  # unpack
#  my $stab  = $ctx->{stab};
#  my $data  = $ctx->{head};
#  my $mem   = $self->{mem};
#  my $frame = $mem->{frame};
#
#
#  # build sub-block header
#  my $blk   = $frame->getseg($data->{buf});
#  my $type  = $self->blk_t();
#
#  my $head  = Bpack::layas $type,(
#    $ctx->{stab_idex},
#    $self->pack_loc($ctx)
#
#  );
#
#  # remember block ;>
#  $ctx->{blk}=$blk;
#
#
#  # ^write
#  my $pow  = $ctx->{lvl} + $self->{pow};
#  my $addr = $ctx->{pos} << $pow;
#
#  $blk->store($type,$head,$addr);
#
#
#  # give beg of user memory!
#  return $blk->view(
#
#    $addr + $type->{sizeof},
#
#    ($ctx->{size} << $pow)
#  - $type->{sizeof}
#
#  );
#
#};

# ---   *   ---   *   ---
# bit-pack a blocks size
# and location

sub pack_loc($self,$ctx) {

  my $loc_t=$self->loc_t();

  return $loc_t->bor(
    ezy=>$ctx->{ezy},
    pos=>$ctx->{pos},
    lvl=>$ctx->{lvl},

  );

};

# ---   *   ---   *   ---
# ^undo

sub unpack_loc($self,$ctx,$loc) {

  my $loc_t = $self->loc_t();
  my %data  = $loc_t->from_value($loc);

  $ctx->{ezy}=$data{ezy};
  $ctx->{pos}=$data{pos};
  $ctx->{lvl}=$data{lvl};


  return;

};

# ---   *   ---   *   ---
# fit size in blk

sub fit($self,$main,$ctx) {


  # unpack
  my $data  = $ctx->{head};
  my $mask  = $data->{mask};

  my $mpart = $main->mpart_t();

  # enough space avail?
  my ($ezy,$pos)=$mpart->fit(
    \$mask,$ctx->{size}

  );

  return 0 if ! defined $ezy;


  # ^yes, update block
  $ctx->{ezy}=$ezy;
  $ctx->{pos}=$pos;

  my $view=$self->blk_write($ctx);

  # ^update subtable
  my $stab=$ctx->{stab};

  $data->{mask} |= $mask;
  $stab->store($data);


  return $view;


};

# ---   *   ---   *   ---
1; # ret
