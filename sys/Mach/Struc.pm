#!/usr/bin/perl
# ---   *   ---   *   ---
# MACH STRUC(-ture)
# Labels on a segment
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mach::Struc;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use List::Util qw(min);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Bytes;
  use Arstd::Array;
  use Arstd::IO;
  use Arstd::PM;

  use Mach::Seg;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {return {

    -autoload=>[qw()],

  }};

# ---   *   ---   *   ---
# GBL

  our $Icebox={};
  our $Cstruc={};

  our $Sizeof={%$PESZ};

# ---   *   ---   *   ---
# get table of instance arrays

sub _icebox_tab($class) {
  no strict 'refs';
  return ${"$class\::Icebox"};

};

# ---   *   ---   *   ---
# get table of constructors

sub _cstruc_tab($class) {
  no strict 'refs';
  return ${"$class\::Cstruc"};

};

# ---   *   ---   *   ---
# get table of type sizes for class

sub _sizeof_tab($class) {
  no strict 'refs';
  return ${"$class\::Sizeof"};

};

# ---   *   ---   *   ---
# ^fetch

sub sizeof($class,$key) {

  my $tab=$class->_sizeof_tab();

  errout(

    q[Invalid type '%s'],

    lvl  => $AR_FATAL,
    args => [$key],

  ) unless exists $tab->{$key};

  return $tab->{$key};

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$name,@fields) {

  # redecl guard
  errout(

    q[Redeclaration of type '%s'],

    lvl  => $AR_FATAL,
    args => [$name],

  ) unless ! exists $Icebox->{$name};

  # make tab from array
  my %methods = $class->split_fields(\@fields);
  my %fields  = @fields;

  # ^pop special flags
  my $attrs   = $fields{-attrs};
     $attrs //= [];

  delete $fields{-attrs};
  @fields=grep {$ARG ne '-attrs'} @fields;

  # ^walk
  my ($sizes,$total)=
    $class->calc_size(\%fields,\@fields);

  # ^make icewraps
  my $cstruc={

    name    => $name,
    attrs   => $attrs,

    methods => \%methods,
    fields  => \@fields,

    sizes   => $sizes,
    total   => $total,

  };

  # ^put in icebox
  $class->_cstruc_tab()->{$name}=$cstruc;
  $class->_sizeof_tab()->{$name}=$total;

  return $cstruc;

};

# ---   *   ---   *   ---
# separates methods from
# struc fields

sub split_fields($class,$ar) {

  my %out  = ();
  my @move = ();

  my $i=0;map {

    my $value=$ar->[$i+1];

    if(is_coderef($value)) {
      $out{$ARG}=$value;

    } else {
      push @move,$ARG=>$value;

    };

    $i+=2;

  } array_keys($ar);

  @$ar=@move;
  return %out;

};

# ---   *   ---   *   ---
# ^invokes methods of struc

sub AUTOLOAD($self,@args) {

  our $AUTOLOAD;

  my $key    = $AUTOLOAD;
  my $class  = ref $self;

  # abort if dstruc
  return if ! autoload_prologue(\$key);

  my $tab    = $class->_cstruc_tab();
  my $cstruc = $tab->{$self->{-type}};

  # abort if method not found
  my $fn=$cstruc->{methods}->{$key}
  or throw_bad_autoload($self->{-type},$key);

  return $fn->($self,@args);

};

# ---   *   ---   *   ---
# get total size of struc

sub calc_size($class,$h,$ar) {

  my $offset = 0;
  my $total  = 0;
  my $size   = 0;

  # ^walk individual size of field types
  my $tab={map {

    $offset  = $total;
    $size    = $class->sizeof($h->{$ARG});
    $total  += $size;

    $ARG    => [$offset,$size];

  } array_keys($ar)};

  return $tab,$total;

};

# ---   *   ---   *   ---
# make copy of struc for usage

sub ice($class,$name,%O) {

  my $icebox = $class->_icebox_tab();
  my $tab    = $class->_cstruc_tab();
  my $cstruc = $tab->{$name};

  # ^run constructor
  my ($seg,$div,$labels)=
    $class->calc_segment($cstruc,%O);

  # ^make ice
  my $self=bless {

    -seg    => $seg,
    -type   => $name,
    -fields => [keys %$labels],
    -attrs  => [@{$cstruc->{attrs}}],

    -div    => $div,

    %$labels,

  },$class;

  # ^store
  $icebox->{$name}//=[];
  push @{$icebox->{$name}},$self;

  return $self;

};

# ---   *   ---   *   ---
# make new segment and apply
# recursive subdivisions

sub calc_segment($class,$cstruc,%O) {

  # defaults
  $O{offset} //= 0;


  my $seg;

  # make new segment if none provided
  if(! exists $O{segref}) {
    $seg=Mach::Seg->new($cstruc->{total})

  # ^else point
  } else {

    $seg=$O{segref}->point(
      $O{offset},
      $cstruc->{total}

    );

  };

  # ^subdivide
  my @names  = array_keys($cstruc->{fields});

  my %stride = ();
  my $prev   = 0;

  my $div=[map {

    # adjust offsets into seg
    my ($offset,$width)=
      @{$cstruc->{sizes}->{$ARG}};

    $stride{$ARG}=$offset+$prev;
    $prev+=$offset;

    # from [name => type]
    # to   [name => ptr]
    $ARG=>$seg->put_label(
      $ARG,$offset,$width

    );

  } @names];

  my $labels={@$div};

  # make tab from array
  my %fields=@{$cstruc->{fields}};

  # ^recurse
  for my $key(@names) {

    # skip primitives
    my $type=$fields{$key};
    next if exists $PESZ->{$type};

    # copy sub-segments of a sub-struc
    $labels->{$key}=$class->ice(

      $type,

      segref=>$seg,
      offset=>$stride{$key},

    );

  };

  return $seg,$div,$labels;

};

# ---   *   ---   *   ---
# partial, manual beq from Mach::Seg
#
# done so sub-structures can
# be treated as segments

sub to_bytes($self,@args) {
  return $self->{-seg}->to_bytes(@args);

};

sub from_bytes($self,@args) {
  $self->{-seg}->from_bytes(@args);

};

sub set($self,%O) {
  $self->{-seg}->set(%O);

};

sub iof($self) {
  return $self->{-seg}->iof();

};

# ---   *   ---   *   ---
# debug out

sub prich($self,%O) {

  # defaults
  $O{errout}//=0;

  # get ctx
  my $class  = ref $self;
  my $tab    = $class->_cstruc_tab();
  my $cstruc = $tab->{$self->{-type}};
  my $sizes  = $cstruc->{sizes};

  # detail fields
  my @keys = array_keys($self->{-div});
  my $me   = $NULLSTR;

  for my $key(@keys) {

    my $width = min(8,$sizes->{$key}->[1]);
    my $cpl   = int(16/$width);
    my $ice   =  $self->{$key};

    my @bytes = reverse $ice->to_bytes($width*8);
    my $fmat  = xe(

      \@bytes,

      word=>$width,
      line=>$cpl

    );

    $me.=".$key\n$fmat\n\n";

  };

  # select and spit
  my $fh=($O{errout})
    ? *STDERR
    : *STDOUT
    ;

  say {$fh} $me;

};

# ---   *   ---   *   ---
# test

Mach::Struc->new(

  'reg8',

  a=>'byte'

);

Mach::Struc->new(

  'reg16',

  low  => 'byte',
  high => 'byte',

);

Mach::Struc->new(

  'reg32',

  low  => 'reg16',
  high => 'reg16',

);

Mach::Struc->new(

  'reg64',

  low  => 'reg32',
  high => 'reg32',

);

# ---   *   ---   *   ---

Mach::Struc->new(

  'seg-ptr',

  loc  => 'reg64',
  addr => 'reg64',

  cpy => sub ($self,$other) {

    my ($loc,$addr)=$other->iof();

    $self->{loc}->set(num=>$loc);
    $self->{addr}->set(num=>$addr);

  },

  deref => sub ($self) {

    my ($loc,$addr)=$self->to_bytes(64);

    my $class = ref $self->{-seg};
    my $frame = $class->get_frame($loc);
    my $out   = $frame->{-icebox}->[$addr];

    return $out;

  },

);


# ---   *   ---   *   ---

Mach::Struc->new(

  'Test',

  xs => 'seg-ptr',

);

# ---   *   ---   *   ---

my $ptr=Mach::Struc->ice('Test');
my $mem=Mach::Seg->new(0x20);

say $mem;
$ptr->{xs}->cpy($mem);
say $ptr->{xs}->deref();

$ptr->{xs}->prich();
$ptr->prich();

# ---   *   ---   *   ---
1; # ret
