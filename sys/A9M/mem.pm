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

  our $VERSION = v0.02.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  # keys for segment types
  ftypetab => {

    0b101 => 'code',
    0b011 => 'data',
    0b001 => 'rodata',

    0b000 => 'non',

  },

};

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


  # get id of addressing space
  my $mc=$self->getmc();
  $self->{as} = int keys %{$mc->{astab}};


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
  my $buf   = $self->{buf};

  # ^validate
  return null
  if $addr+$len > length $$buf;


  # generate and set label
  $label //= $self->mklabel();
  $ice->{value} .= "[$label]";


  # setattrs
  $ice->{buf}    = \substr $$buf,$addr,$len;
  $ice->{size}   = $len;
  $ice->{root}   = $self;

  $ice->{__view} = [$self,$addr];


  # register instance and give
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
# set view back to top of
# referenced segment

sub reset_view_addr($self) {

  my $view = $self->{__view};
  my $base = $view->[0];

  $self->{size} = 0x00;
  $view->[1]    = $base->{ptr};

  return;

};

# ---   *   ---   *   ---
# ^adjust pointed buffer!

sub update_view_buf($self,$brk) {

  my ($base,$addr)=
    @{$self->{__view}};

  my $buf=$base->{buf};


  $self->{size} += $brk;
  $self->{buf}   = \substr $$buf,
    $addr,$self->{size};

  return;

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

  # discard bytes?
  } elsif($step < 0) {

    my $total=$size+$step;

    $$buf=($total > 0)
      ? substr $$buf,0,$total,null
      : null
      ;

  };


  # ^adjust size accordingly
  $size = length $$buf;
  $ptr  = $ptr * ($size > $ptr);

  # overwrite and give new size
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

  return (length $b)
    ? $b->{ct}->[0]
    : $self->warn_oob($type,$addr,'load')
    ;

};

sub dstore($self,$type,$value,$addr) {


  # forbid external write to ROM
  my $mc=$self->getmc();

  return $self->warn_rom($type,$addr)

  if ! $self->{writeable}

  && defined $mc->{scope}
  && defined $mc->{scope}->{mem}
  && defined $mc->{segtop}

  && $self ne $mc->{scope}->{mem}
  && $self ne $mc->{segtop};


  # issue write!
  my $b=bpack $type,$value;
  substr ${$self->{buf}},$addr,$b->{len},$b->{ct};

  return $b->{len};

};

# ---   *   ---   *   ---
# ^errmes

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
  $O->{mccls}   = $self->{mccls};
  $O->{mcid}    = $self->{mcid};


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

  my $post  = ! $isptr && exists $O{ptr_t};

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

  return $old->{absloc}

  if  defined $old->{absloc}
  &&! $self->{__absloc_recalc};


  # node is a slice ref, it does not
  # count towards total!
  if($old->{__view}) {
    my ($base,$off)=@{$old->{__view}};
    $old->{absloc}=$base->absloc+$off;

    return $old->{absloc};

  };


  # recursive hierarchy walk!
  my $mc   = $self->getmc();
  my $addr = ($self->{as})
    ? $mc->astab_loc($self->{as})
    : 0x00
    ;

  my @Q    = $self;

  while(@Q) {

    my $nd = shift @Q;

    # virtual memory doesn't count!
    if($nd->{virtual}) {
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
# ^force recalc

sub update_absloc($self) {

  my $root=$self->{root};
  $root->{__absloc_recalc}=1;

  return $self->absloc;

};

# ---   *   ---   *   ---
# map segment flags to key

sub flagkey($self) {

  my $mc  = $self->getmc();
  my $flg = $mc->{bk}->{flags};

  my $key=($self ne $self->{root})
    ? $flg->as_int($self) & 0x7
    : 0x00
    ;

  return $self->ftypetab->{$key};

};

# ---   *   ---   *   ---
# join segments in tree that
# have the same flags

sub flatten($self,%O) {


  # walked/pending
  my $have = {};
  my @Q    = $self->{root};


  # walk
  while(@Q) {


    # get segment and keys
    my $seg = shift @Q;
    my $key = $seg->flagkey;


    # keep first segment with a given
    # configuration of set keys
    if(! exists $have->{$key}) {
      $have->{$key} = $seg;
      $seg->{ptr}   = 0x00;

    # ^write to first ;>
    } else {

      my $dst=$have->{$key};

      ${$dst->{buf}} .= ${$seg->{buf}};
      $dst->{size}   += $seg->{size};

      $seg->discard();

    };


    # queue children
    unshift @Q,@{$seg->{leaves}};


  };

  return $have;

};

# ---   *   ---   *   ---
# ^combine multiple trees

sub merge($self,@seg) {


  # build table from base
  my @image    = ();
  my @data     = ();

  my $root     = $self;
  my $inner    = $root->{inner};

  my $tab      = $root->flatten();
  $root->{ptr} = 0x00;


  # push sub-segments to table
  map {

    # walk sub-segments by type
    my  $stab=$ARG->flatten();
    map {


      # get new/previous
      my $flat  = $stab->{$ARG};
      my $seg   = $tab->{$ARG};

      my $inner = $flat->{inner};


      # no previous?
      if(! $seg) {
        $tab->{$ARG}=$flat;
        $root->pushlv($flat);

        $seg=$flat;


      # append to previous!
      } else {
        ${$seg->{buf}} .= ${$flat->{buf}};
        $seg->{size}   += $flat->{size};

      };


      # remember offset and go next
      $inner->{vref} = [$ARG,$seg->{ptr}];
      $seg->{ptr}    = $seg->{size};

      # redirect segment to new
      $flat->{root}  = $root;
      $flat->{vref}  = $seg;


    } keys %$stab;


    # adjust pointers
    my ($ptr,@path)=
      $ARG->on_inner_move($root);

    push @data,@$ptr;
    push @image,@path;


    # merge namespaces
    $root->{inner}->pushlv(
      $ARG->{inner}

    );


  } @seg;


  # rename sub-segments by type
  map  {

    my $seg=$tab->{$ARG};

    $seg->{value} = $ARG;
    $seg->{as}    = undef;

    $seg->update_absloc();


  } grep {
    defined $tab->{$ARG}

  } qw(non rodata data code);


  # move pointers and locate old paths
  $self->migrate($tab,@data);
  $self->mount(@image);


  return;

};

# ---   *   ---   *   ---
# walks namespace and prepares
# a list of nodes that require
# adjustments

sub on_inner_move($self,$tab) {


  # get ctx
  my $ptrcls=$self->get_ptr_bk();


  # walk namespace
  my @Q   = $self->{inner};
  my @RQ  = ();

  my @out = ();


  while(@Q) {

    # recurse
    my $nd=shift @Q;
    unshift @Q,@{$nd->{leaves}};

    # filter pointers from pathname
    ($ptrcls->is_valid($nd->{value}))

      # pointers get corrected
      ? unshift @RQ,$nd

      # save pathname to build image
      : push @out,$self->inner_fakeseg($nd)
      ;

  };


  return \@RQ,@out;

};

# ---   *   ---   *   ---
# moves pointers after a
# flattening of the memory!

sub migrate($self,$tab,@Q) {


  # get ctx
  my $walked = {};
  my $frame  = $self->{frame};


  # walk pointers in reverse
  for my $nd(@Q) {


    # avoid repeats
    next if exists $walked->{$nd->{value}};


    # deref
    my $ptr=$nd->{value};
    my $old=$ptr->getseg();


    # get adjustment value
    my $vref=$nd->{vref};

    while(

    !  defined $vref
    && defined $nd->{parent}

    ) {

      $nd   = $nd->{parent};
      $vref = $nd->{vref};

    };


    # ignore if none found!
    next if ! defined $vref;

    my ($key,$off)=@$vref;


    # adjust base segment and address
    $ptr->{segid}    = $tab->{$key}->{iced};
    $ptr->{addr}    += $off;

    $walked->{$ptr}  = 1;


    # adjust ref segment?
    if(defined $ptr->{chan}) {


      # get segment and type
      my $seg=$frame->ice($ptr->{chan});
         $key=$seg->flagkey;

      # ^points to root?
      my $dst   = ($key ne 'non')
        ? $self->haslv($key)
        : $self
        ;


      $ptr->{chan}=$dst->{iced};

    };

  };


  return;

};

# ---   *   ---   *   ---
# gives the illusion of segmented
# memory on a flat model by
# handing you named slices

sub inner_fakeseg($self,$nd) {


  # skip invalid
  return () if ! defined $nd->{vref};


  # else give descriptor
  # slice will be generated later!

  my $mem=$nd->{mem};

  return {

    type => $nd->{vref}->[0],
    path => [$nd->ances_list],

    addr => $nd->{vref}->[1],
    size => $mem->{size},

    seg  => $mem,

  };


};

# ---   *   ---   *   ---
# ^trick the namespace into
# thinking it's still segmented

sub mount($self,@image) {


  map {

    my $src   = $ARG;
    my $nroot = $src->{type} ne $self->{value};

    my $dst   = ($nroot)
      ? $self->haslv($src->{type})
      : $self
      ;

    my @path = @{$src->{path}};
    my $out  = $dst->view(
      $src->{addr},
      $src->{size},

      join '::',@path

    );

    unshift @path,$dst->{value}
    if $nroot;


    $self->{inner}->force_set($out,@path)
    if ! $self->{inner}->haslv(@path);

    $out->{mem}=$dst;
    $src->{seg}->{route}=$out;


  } @image;

  return;

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
# encode to binary

sub mint($self) {


  # get super
  my @out=(
    Tree::mint($self),
    A9M::layer::mint($self),

  );


  # get base attrs
  push @out,map {
    $ARG=>$self->{$ARG}

  } qw(size inner);


  # have segment ref?
  if($self->{__view}) {
    push @out,__view=>$self->{__view};

  # have segment!
  } else {
    push @out,buf=>${$self->{buf}};

  };

  return @out;

};

# ---   *   ---   *   ---
# ^undo

sub unmint($class,$O) {

  my $self=Tree::unmint($class,$O);
     $self=A9M::layer::unmint($class,$self);


  $self->{ptr}    = 0x00;
  $self->{buf}    = $O->{buf};
  $self->{inner}  = $O->{inner};

  $self->{__view} = $O->{__view};

  return $self;

};

# ---   *   ---   *   ---
# ^cleanup

sub REBORN($self) {


  # run super
  Tree::REBORN($self);
  A9M::layer::REBORN($self);

  my $buf=$self->{buf};
  $self->{buf}=\$buf;


  # locate root node
  ($self->{root})=$self->root();


  # link segment to namespace
  if($self eq $self->{root}) {

    my @Q=$self;
    while(@Q) {

      my $nd=shift @Q;
      unshift @Q,@{$nd->{leaves}};

      $nd->{inner}->{mem}=$nd;

    };

  };


  # have segment ref?
  if($self->{__view}) {

    my $size=$self->{size};
    $self->{size}=0;

    $self->update_view_buf($size);

  };


  $self->{frame}->icemake($self);
  return;

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {

  # own defaults
  $O{depth} //= 0;
  $O{inner} //= 0;
  $O{outer} //= 1;
  $O{root}  //= 0;
  $O{loc}   //= 0;
  $O{locsz} //= 0;

  $O{head}  //= 1;

  # I/O defaults
  my $out=ioprocin(\%O);


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


    # show location/location && size?
    my $loc=($O{locsz} || $O{loc})

      ? ($O{locsz})

        ? sprintf "[%04X-%04X] ",
            $nd->absloc,$nd->{size}

        : sprintf "[%04X] ",$nd->absloc

      : null

      ;


    # put header?
    my $head=
       $O{head}
    && $nd->{value} ne 'ANON';

    push @$out,"$loc$nd->{value}:\n"
    if $head;

    # ^put hexdump
    xd ${$nd->{buf}},%O,head=>0,mute=>1;


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
