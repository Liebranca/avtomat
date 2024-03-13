#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M ALLOC
# avto:mem!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::alloc;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;
  use Bpack;
  use Warnme;

  use Arstd::Bytes;
  use Arstd::IO;
  use Arstd::PM;

  use parent 'A9M::component';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.5;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  # sub-module implementations
  mpart_t => 'A9M::alloc::mpart',
  stab_t  => 'A9M::alloc::stab',
  blk_t   => 'A9M::alloc::blk',

  ptr_t   => (typefet 'word'),


  # number of sub-tables
  lvlcnt => 0x02,

  # default alignment
  defbase => 'byte',


  # master partition table
  alloc_t => sub {


    my $class = $_[0];

    my $cnt   = $class->lvlcnt();
    my $ptr_t = $class->ptr_t();


    struc 'alloc' =>
      "$ptr_t->{name} lvl[$cnt]";

  },

};

# ---   *   ---   *   ---
# module kick

sub import($class) {

  $class->alloc_t();

  cloadi $class->mpart_t();
  cloadi $class->stab_t();
  cloadi $class->blk_t();


  return;

};

# ---   *   ---   *   ---
# recalc sizes accto base alignment

sub set_base($self,$base) {


  # validate in
  $base=typefet $base
  or return null;


  # ^save and re-run calcs
  $self->{base} = $base;

  $self->{page} = $base->{sizebs} ** 2;
  $self->{pow}  = $base->{sizep2}  * 2;


  return;

};

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {


  # defaults
  $O{mcid}  //= 0;
  $O{mccls} //= caller;
  $O{base}  //= $class->defbase();


  # make ice
  my $self   = bless \%O,$class;

  my $mc     = $self->getmc();
  my $memcls = $mc->{bk}->{mem};

  $self->set_base($O{base});

  # make table
  my $stab_t = $self->stab_t();
  $O{tab}    = $stab_t->new_frame(main=>$self);


  # make container
  my $type = $self->alloc_t();
  my $mem  = $memcls->mkroot(

    mcid  => $self->{mcid},
    mccls => $self->{mccls},

    label => 'ALLOC',
    size  => $type->{sizeof},

  );

  # ^struc as master table
  $mem->decl($type,'head',0x00);


  # save and give
  $self->{mem}=$mem;

  return $self;

};

# ---   *   ---   *   ---
# fetch/make block

sub alloc($self,$req) {


  # get ctx
  my $tab=$self->{tab};

  # get partition/aligned block size
  my $mpart_t=$self->mpart_t();
  my ($lvl,$size)=$mpart_t->getlvl($self,$req);

  return null if ! length $lvl;


  # get entry
  retry:my $stab=$tab->get_next($lvl);


#  # value packing
#  my $ctx={
#
#    stab   => $stab,
#    head   => $stab->load(),
#    stab_i => $stab_idex,
#
#    lvl    => $lvl,
#    ezy    => undef,
#    pos    => undef,
#
#    size   => $size,
#    blk    => undef,
#
#  };
#
#
#  # have enough space?
#  my $fit=$self->blkfit($ctx);
#
#  # ^nope, go next/make new
#  if(! $fit) {
#
#    my $data = $ctx->{head};
#
#    $addr    = $data->{next};
#    $base    = $stab->{addr};
#    $offset  = $ctx->{stab}->{addr};
#    $offset += sizeof 'word';
#
#    $stab_idex++;
#
#
#    goto retry;
#
#  };
#
#
#  # give mem slice
#  return $fit;

};

# ---   *   ---   *   ---
# ^undo

sub free($self,$blk) {


  # get ctx
  my $mem    = $self->{mem};
  my $memcls = ref $mem;
  my $frame  = $mem->{frame};

  my $type   = $self->blk_t();


  # fetch block from addr if
  # numerical repr passed
  if(! $memcls->is_valid($blk)) {
    $blk=$frame->getseg($blk);

  };


  # get sub-block header
  my ($base,$addr)=@{$blk->{__view}};
  my $head=$base->load(
    $type,$addr-$type->{sizeof}

  );


  my $ctx={};
  $self->unpack_loc($ctx,$head->{loc});

  use Fmat;
  fatdump(\$ctx);

  $base->prich();
  exit;

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {
  $self->{mem}->prich(%O,root=>1);

};

# ---   *   ---   *   ---
1; # ret
