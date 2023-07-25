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
  use Storable qw(thaw freeze);
  use English qw(-no_match_vars);

  use List::Util qw(sum);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Bytes;
  use Arstd::Array;
  use Mach::Seg;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#b
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
  my %fields = @fields;

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

    name   => $name,
    attrs  => $attrs,

    fields => \@fields,
    sizes  => $sizes,
    total  => $total,

  };

  # ^put in icebox
  $class->_cstruc_tab()->{$name}=$cstruc;
  $class->_sizeof_tab()->{$name}=$total;

  return $cstruc;

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

    $offset+=$O{offset};
    $stride{$ARG}=$prev;

    $prev=$offset;

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

# ---   *   ---   *   ---
# debug out

sub prich($self,%O) {

  # defaults
  $O{errout}//=0;

  my $me=$NULLSTR;

  # detail struc
  my $seg  = $self->{-seg};
  my @info = (

    $self->{-type},"\n\n",

    (sprintf
      "%-8s \$%04X",
      'SIZE',$seg->{cap},

    ),"\n",

    "\n\n",

    "Segments:\n\n",

  );

  $me.=join $NULLSTR,@info;

  # ^detail fields
  my @keys=array_keys($self->{-div});
  for my $key(@keys) {

    my @bytes = $self->{$key}->to_bytes(64);
    my $fmat  = xe(\@bytes);

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

my $struc0=Mach::Struc->new(

  'Test',

  a=>'word',

  b=>'brad',
  c=>'wide',
  d=>'byte',
  e=>'byte',

);

my $struc1=Mach::Struc->new(

  'Not-Test',

  nest => 'Test',
  pad  => 'unit',

);

my $t1   = Mach::Struc->ice('Not-Test');
my $nest = $t1->{nest};

$t1->{pad}->set(str=>'HEY');
$nest->set(num=>$NULL);

#my @ar=$t1->to_bytes(64);
#$ar[1]=$NULL;
#
#$t1->from_bytes(\@ar,64);

#$t1->{nest}->set(str=>'HLOWRLD!');
#$t1->{pad}->set (str=>'BYEWRLD!');

$t1->prich();
$t1->{-seg}->prich();

# ---   *   ---   *   ---
1; # ret
