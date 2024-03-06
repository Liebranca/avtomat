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
  use Chk;
  use Bpack;
  use Warnme;

  use Arstd::Bytes;
  use Arstd::Int;
  use Arstd::xd;
  use Arstd::IO;

  use parent 'A9M::component';
  use parent 'Tree';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.9;#a
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

  my $out = "L$$cnt";
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

  $self->set_uattrs();


  # make namespace
  my $inner_frame = Tree->get_frame($O{mcid});
  $self->{inner}  = Tree::new(
    'Tree',$inner_frame,undef,$O{label}

  );

  $self->{inner}->{mem}=$self;


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

  # ^make namespace
  my $inner     = $self->{inner}->inew($label);
  $inner->{mem} = $ice;


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

  $ice->set_uattrs();

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
# grow block if requested size
# won't fit

sub brkfit($self,$n) {
  my $diff=($self->{ptr}+$n) - $self->{size};
  $self->brk($diff) if $diff > 0;

};

# ---   *   ---   *   ---
# align block to pow2

sub align($self,$n) {

  # forbid non-pow2 alignments
  return warn_pow2ali($n)
  if ! int_ispow($n,2);


  # grow block if need
  my $size=int_align($self->{size},$n);
  my $diff=$size-$self->{size};

  $self->brk($diff);

};

# ---   *   ---   *   ---
# ^errme

sub warn_pow2ali($n) {

  warnproc

    "invalid alignment: [num]:%u;"

  . "segments can only align to a "
  . "power of two.",


  args => [$n],
  give => null;

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
  $self->inbounds(\$type,\$addr,$value)
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


  # forbid external write to ROM
  my $mc=$self->getmc();

  return $self->warn_rom($type,$addr)

  if $self->{writeable} == 0
  && $self ne $mc->{scope}->{mem};


  # issue write!
  my $b=bpack $type,$value;
  substr $self->{buf},$addr,$b->{len},$b->{ct};

  return $b->{len};

};

# ---   *   ---   *   ---
# ^errme

sub warn_rom($self,$type,$addr) {

  $addr=sprintf '%X',
    $self->absloc() + $addr;

  warnproc

    "Issued write to ROM segment "
  . "([good]:%s at \$[num]:%s)",

    args => [$type->{name},$addr],
    give => 0x00;

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
  $O->{mccls} //= $self->{mccls};
  $O->{mcid}  //= $self->{mcid};


  return $class;

};

# ---   *   ---   *   ---
# wraps: make value

sub lvalue($self,$value,%O) {


  # set defaults
  my $class=$self->ptr_defnit(\%O);

  # value fit in loc?
  $self->inbounds(\$O{type},\$O{addr},$value)
  or return null;


  # make ice
  $O{ptr_t} = undef;
  my $ptr=$class->new(
    %O,segid=>$self->{segid},

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
  $O{mcid}      //= $self->{mcid};
  $O{mccls}     //= $self->{mccls};


  # get ctx
  my $type  = $to->{type};
  my $other = $to->getseg();


  # validate ptr type
  $O{ptr_t}=typefet $O{ptr_t}
  or return null;

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
  $ptr->store($ptrv,deref=>0);


  return $ptr;

};

# ---   *   ---   *   ---
# wraps: make lvalue or ptr
# depending on what is passed

sub infer($self,$value,%O) {

  my $class=$self->get_ptr_bk();

  ($class->is_valid($value))
    ? $self->ptr($value,%O,store_at=>$O{addr})
    : $self->lvalue($value,%O)
    ;

};

# ---   *   ---   *   ---
# wraps: value decl

sub decl($self,$type,$name,$value,%O) {


  # set cstruc vars
  $O{type}  = $type;
  $O{label} = $name;
  $O{addr}  = $self->{ptr};


  # need to grow?
  my $size  = sizeof $type;
  my $str_t = Type->is_str($type);

  my $cnt   = ($str_t) ? length $value : 1 ;

  $self->brkfit($size * $cnt);


  # make ice
  my $ptr=$self->infer($value,%O);
  return $ptr if ! length $ptr;


  # go next and give
  $self->{ptr} += $ptr->{len};
  return $ptr;

};

# ---   *   ---   *   ---
# catch OOB addresses

sub _inbounds($self,$type,$addr,$value=undef) {


  my $size = $type->{sizeof};
  my $cnt  = 1;


  # have string insertion?
  my ($str_t) = Type->is_str($type);
  if($str_t && $value) {

    $cnt=(is_arrayref $value)
      ? int    @$value
      : length $value
      ;

  };


  # false if bounds crossed
  return

     $addr
  +  $type->{sizeof} * $cnt

  <= length $self->{buf}

  ;

};

# ---   *   ---   *   ---
# ^public wraps

sub inbounds(

  $self,

  $typeref,
  $addrref,

  $value=undef

) {


  # default to ptr
  $$addrref //= $self->{ptr};

  # can read this many bytes?
  $$typeref=typefet $$typeref or return null;


  return (! $self->_inbounds(
    $$typeref,$$addrref,$value

  ))

    ? $self->warn_oob($$typeref,$$addrref)
    : 1
    ;

};

# ---   *   ---   *   ---
# ^errme

sub warn_oob($self,$type,$addr) {

  $addr=sprintf '%X',
    $self->absloc() + $addr;

  warnproc "OOB: [good]:%s at \$[num]:%s",

  args => [$type->{name},$addr],
  give => null;

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
# find across namespaces

sub search($self,$altref,@path) {


  # cat name to path
  my $tree = $self->{inner};

  # ^pop from namespace until
  # symbol is found
  while(@path) {
    last if $tree->has(@path,@$altref);
    pop @path;

  };


  return (@path,@$altref);

};

# ---   *   ---   *   ---
# get length of a C string
# if chars in 00-7E range
# else bogus

Readonly my $CSTR_MASK_Z0=>0x7F7F7F7F7F7F7F7F;
Readonly my $CSTR_MASK_Z1=>0x0101010101010101;
Readonly my $CSTR_MASK_Z2=>0x8080808080808080;

sub cstr_len($self,$addr=0) {


  # get buf/chunk sizes
  my $size  = $self->{size} - $addr;
  my @type  = typeof $size;

  # ^get slice
  my $raw   = $self->{buf};
     $raw   = substr $raw,$addr,$size;
     $raw   = "$raw";


  # read chunks until null found
  my $len  = 0;
  my $xlen = 0;

  while(@type) {

    # read next chunk
    my $fmat = shift @type;
    my $word = bunpacksu $fmat,\$raw;
       $word = $word->{ct}->[0];


    # black magic
    $xlen  = 0;

    $word ^= $CSTR_MASK_Z0;
    $word += $CSTR_MASK_Z1;
    $word &= $CSTR_MASK_Z2;

    goto bot if ! $word;


    # add idex of first null byte
    $xlen   = (bitscanf $word);
    $xlen >>= 3;

    $len   += $xlen;

    last;


    # ^no null, add sizeof
    bot:
    $len += sizeof $fmat;

  };


  return $len-1;

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


  $self->{inner}->prich(

    %O,

    mute  => 1,
    -x    => qr{^ANIMA$},

  ) if $O{inner};


  return ioprocout(\%O);

};

# ---   *   ---   *   ---
1; # ret
