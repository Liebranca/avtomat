#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M PTR
# Memory reference
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::ptr;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use List::Util qw(max);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;
  use Fmat;

  use Arstd::IO;

  use parent 'A9M::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => {

    type   => $Type::DEFAULT,
    label  => null,

    ptr_t  => undef,

    chan   => undef,
    segid  => 0x00,
    addr   => 0x00,
    size   => 0,

    mcid   => 0,
    mccls  => null,

    field  => [],
    segcls => undef,

  },

};

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {


  # defaults
  $class->defnit(\%O);
  $O{segcls} //= caller;


  # make ice
  my $self = bless \%O,$class;

  # get segment and machine
  my $seg = $self->getseg();
  my $mc  = $seg->getmc();

  $self->{mccls} = ref $mc;
  $self->{mcid}  = $mc->{iced};


  # identify size in memory
  $self->{size}  = ($self->{ptr_t})
    ? sizeof $self->{ptr_t}
    : sizeof $self->{type}
    ;

  # ^inherit segment attrs
  $self->set_uattrs_from($seg);


  return $self;

};

# ---   *   ---   *   ---
# give type if single indirection level
# else give pointer type

sub get_type($self) {

  return (defined $self->{ptr_t})
    ? $self->{ptr_t}
    : $self->{type}
    ;

};

# ---   *   ---   *   ---
# makes child nodes for each
# structure field

sub struclay($self,$par) {


  # get ctx
  my $seg   = $self->getseg();
  my $struc = $self->{type};
  my $addr  = $self->{addr};

  # unpack
  my $elem_t = $struc->{struc_t};
  my $elem_n = $struc->{struc_i};
  my $layout = $struc->{layout};


  # walk structure fields
  my $idex=0;
  map {


    # get field data
    my $cnt  = $ARG;
    my $name = $elem_n->[$idex];
    my $type = typefet $elem_t->[$idex++];


    # walk field layout
    map {


      # single elem or array?
      my $label=($cnt > 1)
        ? "$name\[$ARG]"
        : $name
        ;


      # field is a ptr?
      my $ice=undef;

      if(Type->is_ptr($type)) {

        $ice=$seg->ptr(

          $self,

          par      => $par,
          type     => (derefof $type),

          store_at => $addr,

          ptr_t    => $type,
          label    => $label,


        );

      # ^nope, plain value
      } else {

        $ice=$seg->lvalue(

          0x00,

          par    => $par,
          type   => $type,

          addr   => $addr,
          label  => $label,

        );

      };


      # save and go next
      push @{$self->{field}},$ice;
      $addr += $type->{sizeof};


    } 0..$cnt-1;

  } @$layout;


  return;


};

# ---   *   ---   *   ---
# get container for value

sub getseg($self) {

  my $class = $self->{segcls};
  my $idex  = $self->{segid};
  my $frame = $class->get_frame($self->{mcid});

  return $frame->ice($idex);

};

# ---   *   ---   *   ---
# ^get namespace tree node

sub get_node($self) {

  my $seg  = $self->getseg();
  my $mc   = $seg->getmc();

  my @path = split $mc->{pathsep},$self->{label};

  my ($have,@loc)=
    $mc->get_node($path[-1]);

  ($have,@loc)=
    $mc->get_node(@path)

  if ! $have;


  return $have;

};

# ---   *   ---   *   ---
# get ptr path in namespace

sub ances_list($self,%O) {
  my $seg=$self->getseg();
  return $seg->ances_list(%O);

};

sub fullpath($self) {

  my $seg  = $self->getseg();
  my $mc   = $seg->getmc();

  my @base = $seg->ances_list;
  my @par  = split $mc->{pathsep},$self->{label};

  my $name = pop @par;

  pop @base

  if ($base[-1] && $par[0])
  && ($base[-1] eq $par[0]);

  return $name,@base,@par;

};

# ---   *   ---   *   ---
# wraps

sub decl($self,@args) {

  my $nd  = $self->get_node();
  my $seg = $nd->{parent}->{mem};

  return $seg->decl(@args);

};

# ---   *   ---   *   ---
# pointing to read-only memory?

sub is_rom($self) {

  return ! (
    $self->{writeable}
  | $self->{executable}

  );

};

# ---   *   ---   *   ---
# interprets value as an addr

sub read_ptr($self) {

  # get ctx
  my $seg = $self->getseg();
  my $mc  = $seg->getmc();

  if(! defined $self->{ptr_t}) {
    return ($seg,$self->{addr});

  };


  # get saved addr
  my $ptrv=$seg->dload(
    $self->{ptr_t},
    $self->{addr}

  );


  # ^unroll and give
  my $chan=$seg->{frame}->ice(
    $self->{chan}

  );

  return ($chan,$ptrv);

};

# ---   *   ---   *   ---
# procs structures before a write

sub stvproc($self,$value) {


  return $value
  if ! @{$self->{type}->{struc_t}};


  if(is_hashref $value) {
    return [Bpack::unlay $self->{type},$value];

  } elsif(is_arrayref $value) {
    return [Bpack::layas $self->{type},$value];

  } else {
    return $value;

  };

};

# ---   *   ---   *   ---
# put value

sub store($self,$value,%O) {


  # defaults
  $O{deref} //= 1;

  # dst vars
  my $seg;
  my $off;


  # write at [value]?
  if($O{deref} && $self->{ptr_t}) {
    ($seg,$off)=$self->read_ptr();
    return null if ! length $seg;

  # ^nope, use own addr
  } else {

    $value=$self->stvproc($value);

    $seg=$self->getseg();
    $off=$self->{addr};

  };


  # value passed is instance?
  my $class=ref $self;

  $value=$value->as_ptr
  if $class->is_valid($value);


  # give bytes written
  my $size=$seg->dstore(

    $self->{type},
    $value,

    $off,

  );

  $self->{size}=$size;
  return $size;

};

# ---   *   ---   *   ---
# ^fetch

sub load($self,%O) {

  # defaults
  $O{deref} //= 1;

  # src vars
  my $seg;
  my $off;


  # read from [value]?
  if($O{deref} && $self->{ptr_t}) {
    ($seg,$off)=$self->read_ptr();
    return null if ! length $seg;


  # ^nope, use own addr
  } else {
    $seg=$self->getseg();
    $off=$self->{addr};

  };


  # fetch and give
  $seg->dload($self->{type},$off);

};

# ---   *   ---   *   ---
# wraps: load from struc field

sub loadf($self,$name) {

  my $seg=$self->getseg();

  return $seg->loadf(
    $self->{type},$name,
    $self->{addr}

  );

};

# ---   *   ---   *   ---
# wraps: store at struc field

sub storef($self,$name,$value) {

  my $seg=$self->getseg();

  return $seg->storef(
    $self->{type},
    $name,

    $self->stvproc($value),
    $self->{addr},

  );

};

# ---   *   ---   *   ---
# get absolute address of pointer

sub absloc($self,%O) {


  # defaults
  $O{deref} //= 1;

  # get ctx
  my $off=$self->{addr};
  my $seg=$self->getseg();

  # use addrof [value]?
  if($O{deref} && $O{ptr_t}) {
    ($seg,$off)=$self->read_ptr();

  };


  # give segment base plus relative
  return $seg->absloc() + $off;


};

sub update_absloc($self) {
  return $self->absloc();

};

# ---   *   ---   *   ---
# encode to binary

sub mint($self) {

  # get super
  my @out=A9M::layer::mint($self);

  # get base attrs
  push @out,map {
    $ARG=>$self->{$ARG};

  } qw(

    addr
    size

    label
    field
    route

  );


  # indirection...
  my ($ptr_t,$chan,$ptrv)=(
    undef,undef,0x00,

  );

  if($self->{ptr_t}) {
    ($chan) = $self->read_ptr();
    $ptr_t  = $self->{ptr_t}->{name};

  };

  push @out,(

    type  => $self->{type}->{name},
    ptr_t => $ptr_t,

    seg   => $self->getseg(),
    chan  => $chan,

  );

  return @out;

};

# ---   *   ---   *   ---
# ^undo

sub unmint($class,$O) {

  my $self=A9M::layer::unmint($class,$O);

  map {
    $self->{$ARG}=$O->{$ARG}

  } qw(

    addr
    size

    label
    field

    ptr_t
    type

    seg
    chan

  );

  $self->{route}=$O->{route} if $O->{route};


  return $self;

};

# ---   *   ---   *   ---
# ^cleanup kick

sub REBORN($self) {

  $self->{ptr_t}=typefet $self->{ptr_t}
  if $self->{ptr_t};

  $self->{type}=typefet $self->{type};

  return;

};

# ---   *   ---   *   ---
# ^one more!

sub layer_restore($self) {


  # need to get segment ID?
  my $seg=$self->{seg}
  or return;


  # ^save and clear direct reference
  $self->{segid}  = $self->{seg}->{iced};
  $self->{segcls} = ref $self->{seg};

  delete $self->{seg};


  # same process for pointer
  $self->{chan}=$self->{chan}->{iced}
  if length $self->{chan};

  return;

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {


  # I/O defaults
  my $out=ioprocin(\%O);

  # own defaults
  $O{unroll}    //= 1;
  $O{struc}     //= 0;
  $O{field_pad} //= [0,0];


  # get value as a primitive
  my $type  = ($self->{ptr_t})
    ? $self->{ptr_t}
    : $self->{type}
    ;

  my $value = $self->load();

  my $pad   = 1 << ($type->{sizep2}+1);
     $pad   = 16 if $pad > 16;
     $pad   = "%0${pad}X";


  # have struc?
  my @struc = @{$type->{struc_t}};

  if(int @struc) {
    $value    = '()';
    $O{struc} = ++$O{struc};

  # have vector?
  } elsif(is_arrayref($value)) {

    my $mc   = $self->getmc();
    my $guts = $mc->{ISA}->{guts};

    my $fn   = $guts->flatten($type->{sizebs});


    $value =

      join ' ',
      map  {sprintf $pad,$ARG}

      $guts->opera($fn,$value);


  # have ptr?
  } elsif($self->{ptr_t}) {
    my $addr=$self->load(deref=>0);
    $value=0x00 if ! length $value;
    $value=sprintf "*$pad -> $pad",$addr,$value;


  # have decimals?
  } elsif(Type->is_real($type)) {
    $value=sprintf "%.4f",$value;


  # have string?
  } elsif(Type->is_str($type->{name})) {
    $value="\"$value\"";

  # plain value?
  } else {
    $value=sprintf $pad,$value;

  };


  # make struc repr
  if($O{unroll} && $O{struc}) {

    my ($padl,$padr)=@{$O{field_pad}};
    my $fmat="%-${padl}s [%04X] %-${padr}s";


    push @$out,(! @{$type->{struc_t}})


      # printing struc field
      ? sprintf "$fmat -> $value",

          $type->{name},
          $self->{addr},

          ".$self->{label}",


      # ^printing struc head
      : "$self->{label} "
      . "-> (struc $type->{name})"

      ;


    # recurse
    $O{struc}++;

    my $depth=($O{leaf})
      ? ${$O{leaf}}
      : 0
      ;

    $padl=max map {
      length "$ARG->{type}->{name}"

    } @{$self->{field}};

    $padr=max map {
      length "$ARG->{type}->{name}"

    } @{$self->{field}};

    $padl //= $O{field_pad}->[0];
    $padr //= $O{field_pad}->[1];


    map {


      my $branch = Tree::draws($depth+1,0);
      my $leaf   = $depth+1;

      push @$out,"\n$branch";


      $ARG->prich(

        %O,

        struc     => $O{struc},

        leaf      => \$leaf,
        mute      => 1,


        field_pad => [$padl,$padr],

      );


    } @{$self->{field}};


    push @$out,"\n",Tree::drawp($depth)
    if @{$self->{field}};

    ${$O{leaf}}=undef if $O{leaf};


  # make single-elem repr
  } else {

    push @$out,sprintf "[%04X] %s -> $value",
      $self->{addr},$type->{name};

  };


  # ^catp and give
  return ioprocout(\%O);

};

# ---   *   ---   *   ---
1; # ret
