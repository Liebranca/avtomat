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

  use English qw(-no_match_vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;
  use Bpack;

  use Arstd::xd;

  use parent 'Tree';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

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
  my $size=$self->inbounds($type,\$addr);
  return $size if $size eq 'OOB';


  # read from buf
  my $bytes = substr $self->{buf},$addr,$size;

  # ^make num from bytes
  my $fmat  = packof($type);
  my @out   = unpack $fmat,$bytes;

  return (@out == 1)
    ? $out[0]
    : @out
    ;

};

# ---   *   ---   *   ---
# write value at pos

sub store($self,$value,$type,$addr=undef) {

  # can write this many bytes?
  my $size=$self->inbounds($type,\$addr);
  return $size if $size eq 'OOB';


  # make bytes from value
  my $fmat  = packof($type);
  my $bytes = (is_arrayref($value))
    ? pack $fmat,@$value
    : pack $fmat,$value
    ;

  # ^write to buf
  substr $self->{buf},$addr,$size,$bytes;


  return;

};

# ---   *   ---   *   ---
# catch OOB load/store

sub _inbounds($self,$size,$addr) {
  return $addr+$size <= length $self->{buf};

};

# ---   *   ---   *   ---
# ^public wraps

sub inbounds($self,$type,$addrref) {

  # default to ptr
  $$addrref //= $self->{ptr};

  # can read this many bytes?
  my $size=sizeof($type);

  return (! $self->_inbounds($size,$$addrref))
    ? 'OOB'
    : $size
    ;

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {
  return xd($self->{buf},%O);

};

# ---   *   ---   *   ---
# test

my $CAS=A9M::vmem->nas();
my $mem=$CAS->new(0x10);

$mem->store([0x2424,0x2424],xword=>0x00);
my @v=$mem->load(xword=>0x00);

$v[0] &=~ 0x2020;

$mem->store(\@v,xword=>0x00);
$mem->prich();

# ---   *   ---   *   ---
1; # ret
