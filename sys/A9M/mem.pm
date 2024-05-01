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
  use Icebox;
  use Warnme;

  use Arstd::Bytes;
  use Arstd::Int;
  use Arstd::xd;
  use Arstd::IO;
  use Arstd::PM;

  use parent 'Tree';
  use parent 'A9M::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.7;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM


St::vstatic {};


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
# new addressing space

sub mkroot($class,%O) {

  # defaults
  $O{mcid}   //= 0;
  $O{mccls}  //= caller;
  $O{label}  //= 'non';
  $O{size}   //= 0x00;


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
  $frame->icemake($self);

  $self->{buf}    = \zeropad $O{size};
  $self->{ptr}    = 0x00;
  $self->{size}   = $O{size};
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

  # hidden var ;>
  $self->{__view} = undef;


  return $self;

};

# ---   *   ---   *   ---
# ^make from ice

sub new($self,$size=0x00,$label=undef) {


  # defaults
  $label //= $self->mklabel();


  # make child
  my $buf = \zeropad $size;
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
  $self->{frame}->icemake($ice);

  $ice->{buf}    = $buf;
  $ice->{ptr}    = 0x00;
  $ice->{size}   = $size;
  $ice->{inner}  = $inner;
  $ice->{absloc} = undef;

  $ice->set_uattrs();

  # mark for update!
  $self->{root}->{__absloc_recalc}=1;

  # hidden var ;>
  $self->{__view} = undef;


  return $ice;

};

# ---   *   ---   *   ---
# make reference to a section
# of a block

sub view($self,$addr,$len,$label=undef) {


  # get ctx
  my $class = ref $self;
  my $ice   = bless {%$self},$class;
  my $buf   = $ice->{buf};

  # ^validate
  return null
  if $addr+$len > length $$buf;


  # generate and set label
  $label //= $self->mklabel();
  $ice->{value} .= "[$label]";


  # setattrs and give
  $ice->{buf}    = \substr $$buf,$addr,$len;
  $ice->{size}   = $len;

  $ice->{__view} = [$self,$addr];
  $ice->{absloc} = $self->absloc() + $addr;

  $self->{frame}->icemake($ice);


  return $ice;

};

# ---   *   ---   *   ---
# ^get addr of view!

sub get_addr($self) {
  my $view=$self->{__view};
  return (! $view) ? ($self,0) : @$view ;

};

# ---   *   ---   *   ---
# copy contents from other

sub copy($self,$other,$size=undef) {


  # default to copying the whole thing
  my $ptr    = 0;
     $size //= $other->{size};


  # ^go at it in chunks!
  map {

    my $bytes=$other->load($ARG,$ptr);
    $self->store($ARG,$bytes,$ptr);

    $ptr += sizeof $ARG;

  } typeof $size;


};

# ---   *   ---   *   ---
# zero-flood block

sub clear($self,$type=null,$addr=0x00) {

  # sized clear?
  if(length $type) {
    $self->store($type,0,$addr);

  # ^nope, whole buf!
  } else {

    my $buf  = $self->{buf};
    my $size = $self->{size};

    substr $$buf,0,$size,zeropad $size;

  };

  $self->{ptr}=0;

  return;

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
    $$buf .= zeropad $step;

  # ^nope, discard!
  } elsif($step < 0) {
    $$buf=substr $$buf,0,$size+$step,null;

  };


  # ^adjust size accordingly
  $size = length $$buf;
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

sub align($self,$align_t) {


  # convert typename to size if need
  my $n=(! ($align_t=~ $NUM_RE))
    ? sizeof $align_t
    : $align_t
    ;

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
# shrink block to ptr
# then apply alignment

sub tighten($self,$align_t) {

  my $diff=$self->{ptr}-$self->{size};

  $self->brk($diff);
  $self->align($align_t);

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
  my $b=bunpack $type,${$self->{buf}},$addr;
  return $b->{ct}->[0];

};

sub dstore($self,$type,$value,$addr) {


  # forbid external write to ROM
  my $mc=$self->getmc();

  return $self->warn_rom($type,$addr)

  if ! $self->{writeable}

  && $self ne $mc->{scope}->{mem}
  && $self ne $mc->{segtop};


  # issue write!
  my $b=bpack $type,$value;
  substr ${$self->{buf}},$addr,$b->{len},$b->{ct};

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
# read struc field

sub loadf($self,$struc,$field,$base=0) {

  my ($type,$idex)=strucf $struc,$field;
  my $off=$struc->{struc_off}->[$idex];

  return $self->load($type,$base+$off)

};

# ---   *   ---   *   ---
# read struc field

sub storef($self,$struc,$field,$value,$base=0) {

  my ($type,$idex)=strucf $struc,$field;
  my $off=$struc->{struc_off}->[$idex];

  return $self->store($type,$value,$base+$off)

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
    %O,segid=>$self->{iced},

  );

  # ^save to namespace
  my $par=($O{par})
    ? $O{par}
    : $self->{inner}
    ;

  $par->force_set($ptr,$ptr->{label});

  my $node=$par->{'*fetch'};

  $node->{-skipio} = 1;
  $node->{mem}     = $ptr;


  # recurse to copy structure layout if need
  $ptr->struclay($par->{'*fetch'})
  if @{$O{type}->{struc_t}};

  # set value and give
  $value=[Bpack::unlay $O{type},$value]
  if is_hashref $value;

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
  my $type  = ($O{type})
    ? $O{type}
    : $to->{type}
    ;

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

    segid => $self->{iced},
    chan  => $other->{iced},

  );


  # save to namespace
  my $par=($O{par})
    ? $O{par}
    : $self->{inner}
    ;

  $par->force_set($ptr,$ptr->{label});

  my $node=$par->{'*fetch'};

  $node->{-skipio} = 1;
  $node->{mem}     = $ptr;

  # ^set value and give
  $ptr->store($to->{addr},deref=>0);


  return $ptr;

};

# ---   *   ---   *   ---
# wraps: make lvalue or ptr
# depending on what is passed

sub infer($self,$value,%O) {

  my $class = $self->get_ptr_bk();
  my $isptr = $class->is_valid($value);

  my $post  = ! $isptr && $O{ptr_t};


  my $ptr=($isptr)
    ? $self->ptr($value,%O,store_at=>$O{addr})
    : $self->lvalue($value,%O)
    ;

  $ptr->{ptr_t}=$O{ptr_t} if $post;
  return $ptr;

};

# ---   *   ---   *   ---
# wraps: value decl

sub decl($self,$type,$name,$value,%O) {


  # set cstruc vars
  $O{type}    = $type;
  $O{label}   = $name;

  $O{addr}  //= $self->{ptr};


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

  <= length ${$self->{buf}}

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

  # who's calling?
  my $fn=St::cf 2,1;


  # default to ptr
  $$addrref //= $self->{ptr};

  # can read this many bytes?
  $$typeref=typefet $$typeref or return null;


  return (! $self->_inbounds(
    $$typeref,$$addrref,$value

  ))

    ? $self->warn_oob($$typeref,$$addrref,$fn)
    : 1
    ;

};

# ---   *   ---   *   ---
# ^errme

sub warn_oob($self,$type,$addr,$fn) {


  my $name=$self->ances(join_char=>'.');

  $addr=sprintf '%X',
    $self->absloc() + $addr;


  warnproc

    "$name [op]:%s [err]:%s\n"
  . "[ctl]:%s [good]:%s at \$[num]:%s",

  args => [

    '->','OOB',
    $fn,$type->{name},$addr,

  ],


  give => null;

};

# ---   *   ---   *   ---
# wraps for catch

sub as_exe($self) {

  return ($self->{executable})
    ? ${$self->{buf}}
    : $self->warn_exe
    ;

};

# ---   *   ---   *   ---
# ^errme

sub warn_exe($self) {

  my $name=$self->ances(join_char=>'.');

  warnproc

    "[op]:%s $name: "
  . "not an executable segment",

  args => ['() ->*'],
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


    # node is a slice ref, it does not
    # count towards total!
    if($nd->{__view}) {
      my ($base,$off)=@{$nd->{__view}};
      $nd->{absloc}=$base->{absloc}+$off;


    # virtual memory doesn't count!
    } elsif($nd->{virtual}) {
      $nd->{absloc}=0x00;

    # sizes of all previous equals
    # address of current
    } else {
      $nd->{absloc}=$addr;
      $addr+=$nd->{size};

    };


    unshift @Q,@{$nd->{leaves}};

  };


  # ^cache result and give
  $self->{__total_size}    = $addr;
  $self->{__absloc_recalc} = 0;


  return $old->{absloc};

};

# ---   *   ---   *   ---
# find across namespaces

sub search($self,$name,@path) {


  # get ctx
  my $mc   = $self->getmc();
  my $sep  = $mc->{pathsep};
  my $tree = $self->{inner};

  # cat name to path
  my @alt  = split $sep,$name;

  # ^pop from namespace until
  # symbol is found
  while(1) {
    last if $tree->has(@path,@alt);
    last if ! pop @path;

  };


  # give path; found returned implicitly
  $self->{'*fetch'}=
    $tree->{'*fetch'}->leaf_value(0)

  if defined $tree->{'*fetch'};


  return (@path,@alt);

};

# ---   *   ---   *   ---
# ^shorthand for getting value

sub deref($self,$name,@path) {
  $self->search($name,@path);
  return $self->{'*fetch'};

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
  my $raw   = ${$self->{buf}};
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
  $O{root}  //= 0;

  # I/O defaults
  my $out=ioprocin(\%O);

  # ^omit buff header
  $O{head}=0;


  # depth reset
  my $limit=$O{depth};
  my $depth=0;

  # walk hierarchy
  my @Q=($self eq $self->{root} &&! $O{root})
    ? @{$self->{leaves}}
    : $self
    ;

  while(@Q && $O{outer}) {


    # handle end of branch
    my $nd=shift @Q;
    if(! $nd) {
      $depth--;
      next;

    };


    # put header?
    $O{head} = $nd->{value} eq 'ANON';

    push @$out,"$nd->{value}:\n"
    if ! $O{head};

    # ^put hexdump
    xd ${$nd->{buf}},%O,mute=>1;


    # recurse branch until limit
    my @lv=@{$nd->{leaves}};

    unshift @Q,@lv,0 if $depth < $limit;
    $depth += 0 < int @lv;

  };


  $self->{inner}->prich(%O,mute=>1)
  if $O{inner};


  return ioprocout(\%O);

};

# ---   *   ---   *   ---
1; # ret
