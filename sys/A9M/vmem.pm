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
  use Arstd::IO;

  use parent 'Tree';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) { return {

    segtab => [],


    -autoload => [qw(mkseg)],

  }};


  Readonly my $INBOUNDS_ERR=>qr{(?:
    OOB | INVALID

  )}x;

# ---   *   ---   *   ---
# adds zeroes to buf

sub zeropad($size) {
  pack "C[$size]",(0x00) x $size;

};

# ---   *   ---   *   ---
# writes ice to segment table

sub mkseg($class,$frame,$ice) {

  my $segtab = $frame->{segtab};
  my $id     = @$segtab;

  push @$segtab,$ice;


  return $id;

};

# ---   *   ---   *   ---
# new addressing space

sub mkroot($class,%O) {

  # defaults
  $O{mcid}   //= 0;
  $O{mccls}  //= caller;
  $O{label}  //= 'non';

  # make/fetch container
  my $frame=$class->get_frame($O{mcid});


  # make generic ice
  my $self=Tree::new(
    $class,$frame,undef,$O{label}

  );

  # ^set spec attrs
  $self->{root}  = $self;
  $self->{mcid}  = $O{mcid};
  $self->{mccls} = $O{mccls};
  $self->{seg}   = $frame->mkseg($self);

  $self->{buf}   = $NULLSTR;
  $self->{ptr}   = 0x00;
  $self->{size}  = 0x00;


  return $self;

};

# ---   *   ---   *   ---
# ^make from ice

sub new($self,$size,$label=undef) {

  # defaults
  $label //= 'ANON';


  # make child
  my $buf = zeropad $size;
  my $ice = Tree::new(
    (ref $self),$self->{frame},$self,$label

  );

  # ^set spec attrs
  $ice->{root}  = $self->{root};
  $ice->{mcid}  = $self->{mcid};
  $ice->{mccls} = $self->{mccls};
  $ice->{seg}   = $self->{frame}->mkseg($ice);

  $ice->{buf}   = $buf;
  $ice->{ptr}   = 0x00;
  $ice->{size}  = $size;


  return $ice;

};

# ---   *   ---   *   ---
# grow or shrink block

sub brk($self,$step) {


  # get ctx
  my $buf  = $self->{buf};
  my $ptr  = $self->{ptr};
  my $size = $self->{size};


  # add bytes to buffer?
  if($step > 0) {
    $buf .= zeropad $step;

  # ^nope, discard!
  } elsif($step < 0) {
    $buf=substr $buf,0,$size+$step,null;

  };


  # ^adjust size accordingly
  $size = length $buf;
  $ptr  = $ptr * ($size > $ptr);

  # overwrite and give new size
  $self->{buf}  = $buf;
  $self->{ptr}  = $ptr;
  $self->{size} = $size;


  return $size;

};

# ---   *   ---   *   ---
# read value at pos

sub load($self,$type,$addr=undef) {

  # can read this many bytes?
  $self->inbounds(\$type,\$addr)
  or return null;


  # read from buf and give
  my $b=bunpack $type,$self->{buf},$addr;
  return $b->{ct}->[0];

};

# ---   *   ---   *   ---
# write value at pos

sub store($self,$type,$value,$addr=undef) {

  # can write this many bytes?
  $self->inbounds(\$type,\$addr)
  or return null;


  # write to buf
  my $b=bpack $type,$value;

  substr $self->{buf},$addr,$b->{len},$b->{ct};


  # give bytes written
  return $b->{len};

};

# ---   *   ---   *   ---
# make memref

sub ptr($self,$ptr_t,$addr) {

  # no ptr type specified?
  if(! Type->is_ptr($ptr_t)) {

    $ptr_t=typefet $ptr_t
    or return badtype;

    $ptr_t="$ptr_t->{name} ptr";

  };

  # ^validate
  $self->inbounds(\$ptr_t,\$addr)
  or return null;

  # valid for deref?
  my $type=derefof $ptr_t
  or return null;


  # ^give size/seg/offset
  return [

    $type,

    $self->{seg},
    $addr

  ];

};

# ---   *   ---   *   ---
# catch OOB addresses

sub _inbounds($self,$type,$addr) {

  return

     $addr
  +  $type->{sizeof}

  <= length $self->{buf}

  ;

};

# ---   *   ---   *   ---
# ^public wraps

sub inbounds($self,$typeref,$addrref) {

  # default to ptr
  $$addrref //= $self->{ptr};

  # can read this many bytes?
  $$typeref=typefet $$typeref or return null;


  return (! $self->_inbounds($$typeref,$$addrref))
    ? null
    : 1
    ;

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {

  # own defaults
  $O{depth} //= 0;

  # I/O defaults
  my $out=ioprocin(\%O);

  # ^omit buff header
  $O{head}=0;


  # walk hierarchy
  my @Q=($self eq $self->{root})
    ? @{$self->{leaves}}
    : $self
    ;

  while(@Q) {


    # handle end of branch
    my $nd=shift @Q;
    if(! $nd) {
      last if ! $O{depth}--;
      next;

    };


    # put header?
    $O{head} = $nd->{value} eq 'ANON';

    push @$out,"$nd->{value}:\n"
    if ! $O{head};


    # give hexdump and go next
    xd      $nd->{buf},%O,mute=>1;
    unshift @Q,@{$nd->{leaves}},0;

  };


  return ioprocout(\%O);

};

# ---   *   ---   *   ---
# test

#use Fmat;
#
#my $CAS  = A9M::vmem->mkroot();
#my $mem  = $CAS->new(0x10);
#
#my $type = struc cvec=>q[
#  word fa[3];
#  word fb;
#
#];
#
#
#my $ar=$mem->load(cvec=>0x00);
#
#
#$ar->{fa}->[1] = 0x2424;
#$ar->{fb}      = 0x2121;
#
#
#$mem->store($ar,cvec=>0x00);
#$mem->prich();

# ---   *   ---   *   ---
1; # ret
