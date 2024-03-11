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

  use parent 'A9M::component';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  lvl_t  => (struc 'alloc.lvl' => q{

    ptr ahead;

  }),

  head_t => (struc 'alloc.head' => q{

    ptr lvl[8];

  }),

};

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  # defaults
  $O{mcid}  = 0;
  $O{mccls} = caller;


  # make ice
  my $self   = bless \%O,$class;

  my $mc     = $self->getmc();
  my $memcls = $mc->{bk}->{mem};


  # make container
  my $type = $self->head_t();
  my $mem  = $memcls->mkroot(

    mcid  => $self->{mcid},
    mccls => $self->{mccls},

    label => 'ALLOC',
    size  => $type->{sizeof},

  );

  $mem->decl(
    $type,'head',$mem->load($type)

  );


  # save and give
  $self->{mem}=$mem;

  return $self;

};

# ---   *   ---   *   ---
# ~

sub take($self,$from) {

  $self->{mem}->prich();
  exit;

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {
  $self->{mem}->prich(%O,root=>1);

};

# ---   *   ---   *   ---
1; # ret
