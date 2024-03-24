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

  use parent 'A9M::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.7;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  # sub-module implementations
  mpart_t => 'A9M::alloc::mpart',
  stab_t  => 'A9M::alloc::stab',

  blk_t   => sub {

    my $class  = $_[0];
    my $stab_t = $class->stab_t();

    $stab_t->blk_t();

  },


  # you must be *this* wide to be a pointer!
  ptr_t => (typefet 'word'),

  # number of sub-tables
  lvlcnt => 0x02,

  # default alignment
  defbase => 'word',


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
  my $stab_t=$self->stab_t();
  $self->{tab}=$stab_t->new_frame(main=>$self);

  # ^initialize
  my $blocks=$self->{tab}->{blocks};
  $blocks->{main}=$self;


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

  my $tab = $self->{tab};
  my $ptr = $tab->fit($req);

  return $ptr;

};

# ---   *   ---   *   ---
# ^undo

sub free($self,$ptr) {


  # get ctx
  my $root = $self->{mem};
  my $tab  = $self->{tab};


  # get block header
  my $blocks=$tab->{blocks};

  my ($have,$base,$addr)=
    $blocks->head_from($ptr);


  # mark fred
  my $size=$tab->release($have,$addr);
  $blocks->clear($base,$addr);


  return ($base,$addr,$size);

};

# ---   *   ---   *   ---
# ^a bit of both ;>

sub realloc($self,$ptr,$req) {


  # mark as fred and get new
  my ($old,$addr,$size)=
    $self->free($ptr);

  my $new=$self->alloc($req);

  return null if ! $new;


  # get addr of new block
  my ($base,$off)=
    $new->get_addr();

  my $head_sz=sizeof 'alloc.blk';

  $off -= $head_sz;


  # ^need to move data?
  if($base != $old || $addr != $off) {

    my $data=$old->view(

      $addr + $head_sz,
      $size

    );


    $new->copy($data);

  };


  return $new;

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {
  $self->{mem}->prich(%O,root=>1);

};

# ---   *   ---   *   ---
1; # ret
