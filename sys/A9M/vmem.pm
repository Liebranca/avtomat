#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M VMEM
# All about words
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::vmem;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;
  use Bpack;

  use Arstd::xd;

  use parent 'Tree';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $INBOUNDS_ERR=>qr{(?:
    OOB | INVALID

  )}x;

# ---   *   ---   *   ---
# new addressing space

sub nas($class,%O) {

  # defaults
  $O{mcid}  //= 0;
  $O{label} //= 'non';

  # make/fetch container
  my $frame=$class->get_frame($O{mcid});


  # make generic ice
  my $self=Tree::new(
    $class,$frame,undef,$O{label}

  );

  # ^set spec attrs
  $self->{buf}  = $NULLSTR;
  $self->{ptr}  = 0x00;
  $self->{size} = 0x00;


  return $self;

};

# ---   *   ---   *   ---
# ^make from ice

sub new($self,$size,$label=undef) {

  # defaults
  $label //= 'ANON';


  # make child
  my $buf = pack "C[$size]",(0x00) x $size;
  my $ice = Tree::new(
    (ref $self),$self->{frame},$self,$label

  );

  # ^set spec attrs
  $ice->{buf}  = $buf;
  $ice->{ptr}  = 0x00;
  $ice->{size} = $size;


  return $ice;

};

# ---   *   ---   *   ---
# read value at pos

sub load($self,$type,$addr=undef) {

  # can read this many bytes?
  $type=$self->inbounds($type,\$addr);
  return $type if $type=~ $INBOUNDS_ERR;


  # read from buf and give
  my $b=bunpack $type,$self->{buf},$addr;
  return $b->{ct}->[0];

};

# ---   *   ---   *   ---
# write value at pos

sub store($self,$value,$type,$addr=undef) {

  # can write this many bytes?
  $type=$self->inbounds($type,\$addr);
  return $type if $type=~ $INBOUNDS_ERR;


  # write to buf
  my $b=bpack $type,$value;

  substr $self->{buf},$addr,$b->{len},$b->{ct};


  # give bytes written
  return $b->{len};

};

# ---   *   ---   *   ---
# catch OOB load/store

sub _inbounds($self,$type,$addr) {

  return

     $addr
  +  $type->{sizeof}

  <= length $self->{buf}

  ;

};

# ---   *   ---   *   ---
# ^public wraps

sub inbounds($self,$type,$addrref) {

  # default to ptr
  $$addrref //= $self->{ptr};

  # can read this many bytes?
  $type=typefet $type or return 'INVALID';

  return (! $self->_inbounds($type,$$addrref))
    ? 'OOB'
    : $type
    ;

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {
  return xd $self->{buf},%O;

};

# ---   *   ---   *   ---
# test

use Fmat;

my $CAS  = A9M::vmem->nas();
my $mem  = $CAS->new(0x10);

my $type = struc cvec=>q[
  word fa[3];
  word fb;

];


my $ar=$mem->load(cvec=>0x00);


$ar->{fa}->[1] = 0x2424;
$ar->{fb}      = 0x2121;


$mem->store($ar,cvec=>0x00);
$mem->prich();

# ---   *   ---   *   ---
1; # ret
