#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M MEM
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

package A9M::mem;

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

  our $VERSION = v0.00.4;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) { return {

    segtab => [],


    -autoload => [qw(mkseg getseg)],

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
# make generic label

sub mklabel($self) {

  my $cnt    = \$self->{__anoncnt};
     $$cnt //= 0;

  my $out = "S$self->{segid}:L$$cnt";
  $$cnt++;

  return $out;

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
# ^fetch

sub getseg($class,$frame,$idex) {

  my $segtab = $frame->{segtab};
  my $seg    = $segtab->[$idex];

  return (defined $seg) ? $seg : null ;

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
  $self->{root}   = $self;
  $self->{mcid}   = $O{mcid};
  $self->{mccls}  = $O{mccls};
  $self->{segid}  = $frame->mkseg($self);

  $self->{buf}    = $NULLSTR;
  $self->{ptr}    = 0x00;
  $self->{size}   = 0x00;
  $self->{absloc} = undef;


  # make namespace
  my $inner_frame = Tree->get_frame($O{mcid});
  $self->{inner} = Tree::new(
    'Tree',$inner_frame,undef,$O{label}

  );


  # root-only attrs!
  $self->{__absloc_recalc} = 0;
  $self->{__total_size}    = 0x00;


  return $self;

};

# ---   *   ---   *   ---
# ^make from ice

sub new($self,$size,$label=undef) {


  # defaults
  $label //= $self->mklabel();


  # make child
  my $buf = zeropad $size;
  my $ice = Tree::new(
    (ref $self),$self->{frame},$self,$label

  );

  my $inner = $self->{inner}->inew($label);


  # ^set spec attrs
  $ice->{root}   = $self->{root};
  $ice->{mcid}   = $self->{mcid};
  $ice->{mccls}  = $self->{mccls};
  $ice->{segid}  = $self->{frame}->mkseg($ice);

  $ice->{buf}    = $buf;
  $ice->{ptr}    = 0x00;
  $ice->{size}   = $size;
  $ice->{inner}  = $inner;
  $ice->{absloc} = undef;

  # mark for update!
  $self->{root}->{__absloc_recalc}=1;


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
  $self->{buf}    = $buf;
  $self->{ptr}    = $ptr;
  $self->{size}   = $size;

  # mark for update!
  my $root=$self->{root};
  $root->{__absloc_recalc} |= $step != 0;


  return $size;

};

# ---   *   ---   *   ---
# read value at pos

sub load($self,$type,$addr=undef) {

  # can read this many bytes?
  $self->inbounds(\$type,\$addr)
  or return null;


  # read from buf and give
  return $self->dload($type,$addr);

};

# ---   *   ---   *   ---
# write value at pos

sub store($self,$type,$value,$addr=undef) {

  # can write this many bytes?
  $self->inbounds(\$type,\$addr)
  or return null;


  # write to buf and give bytes written
  return $self->dstore($type,$value,$addr);

};

# ---   *   ---   *   ---
# ^bypass checks!

sub dload($self,$type,$addr) {
  my $b=bunpack $type,$self->{buf},$addr;
  return $b->{ct}->[0];

};

sub dstore($self,$type,$value,$addr) {

  my $b=bpack $type,$value;
  substr $self->{buf},$addr,$b->{len},$b->{ct};

  return $b->{len};

};

# ---   *   ---   *   ---
# get host machine

sub getmc($self) {

  my $class = $self->{mccls};
  my $mc    = $class->ice($self->{mcid});

  return $mc;

};

# ---   *   ---   *   ---
# get ptr implementation in use
# by host machine

sub get_ptr_bk($self) {

  my $class  = $self->{mccls};
  my $ptrcls = $class->getbk(
    $self->{mcid},'ptr'

  );


  return $ptrcls;

};

# ---   *   ---   *   ---
# ^run defaults method for
# said implementation

sub ptr_defnit($self,$O) {

  my $class=$self->get_ptr_bk();

  $class->defnit($O);
  $O->{label} //= $self->mklabel();


  return $class;

};

# ---   *   ---   *   ---
# wraps: make value

sub lvalue($self,$value,%O) {


  # set defaults
  my $class=$self->ptr_defnit(\%O);

  # value fit in loc?
  $self->inbounds(\$O{type},\$O{addr})
  or return null;


  # make ice
  my $ptr=$class->new(

    %O,

    mcid  => $self->{mcid},
    segid => $self->{segid},

  );

  # ^save to namespace
  $self->{inner}->force_set(
    $ptr,$ptr->{label}

  );

  # ^set value and give
  $ptr->store($value);


  return $ptr;

};

# ---   *   ---   *   ---
# ^wraps: make value ref

sub ptr($self,$to,%O) {


  # set defaults
  my $class=$self->get_ptr_bk();
  $O{ptr_t}     //= 'ptr';
  $O{store_at}  //= 0x00;
  $O{label}     //= $self->mklabel();


  # get ctx
  my $type  = $to->{type};
  my $other = $to->getseg();


  # validate ptr type
  $O{ptr_t}=typefet $O{ptr_t}
  or return badtype;

  # ^validate *complete* type
  my $complete=
    "$type->{name} "
  . "$O{ptr_t}->{name}"
  ;

  $O{ptr_t}=typefet $complete
  or return null;


  # ^does the pointer itself fit in memory?
  $self->inbounds(\$O{ptr_t},\$O{store_at})
  or return null;


  # make new lvalue
  my $ptr=$class->new(

    %O,

    addr  => $O{store_at},
    type  => $type,

    mcid  => $other->{mcid},
    segid => $other->{segid},

  );


  # encode segment:offset
  my $mc   = $self->getmc();
  my $ptrv = $mc->encode_ptr(
    $other,$to->{addr}

  );

  # ^encoding error?
  return null if $ptrv eq null;


  # ^all OK, save to namespace
  $self->{inner}->force_set(
    $ptr,$ptr->{label}

  );

  # ^set value and give
  $ptr->store($ptrv);


  return $ptr;

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
# calcs the absolute offset
# of every segment in the
# hierarchy

sub absloc($self) {


  # no need to recalc?
  my $old=$self;
  $self=$self->{root};

  return $self->{__total_size}
  if ! $self->{__absloc_recalc};


  # recursive hierarchy walk!
  my $addr = 0x00;
  my @Q    = $self;

  while(@Q) {

    my $nd = shift @Q;

    # sizes of all previous equals
    # address of current
    $nd->{absloc}=$addr;
    $addr+=$nd->{size};


    unshift @Q,@{$nd->{leaves}};

  };


  # ^cache result and give
  $self->{__total_size}    = $addr;
  $self->{__absloc_recalc} = 0;


  return $old->{absloc};

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {

  # own defaults
  $O{depth} //= 0;
  $O{inner} //= 0;
  $O{outer} //= 1;

  # I/O defaults
  my $out=ioprocin(\%O);

  # ^omit buff header
  $O{head}=0;


  # walk hierarchy
  my @Q=($self eq $self->{root})
    ? @{$self->{leaves}}
    : $self
    ;

  while(@Q && $O{outer}) {


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


  $self->{inner}->prich()
  if $O{inner};


  return ioprocout(\%O);

};

# ---   *   ---   *   ---
1; # ret
