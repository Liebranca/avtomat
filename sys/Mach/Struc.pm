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

  our $VERSION = v0.00.1;#b
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
  my %fields=@fields;

  # ^walk
  my ($sizes,$total)=
    $class->calc_size(\%fields,\@fields);

  # ^make icewraps
  my $cstruc={

    name   => $name,

    fields => \%fields,
    sizes  => $sizes,
    total  => $total,

  };

  # ^put in icebox
  $class->_cstruc_tab()->{$name}=$cstruc;
  $class->_sizeof_tab()->{$name}=$total;

  return $class->ice($name);

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

sub ice($class,$name) {

  my $icebox = $class->_icebox_tab();
  my $tab    = $class->_cstruc_tab();
  my $cstruc = $tab->{$name};

  # ^run constructor
  my ($seg,$labels)=
    $class->calc_segment($cstruc);

  # ^make ice
  my $self=bless {

    q[$SEG]    => $seg,
    q[$TYPE]   => $name,
    q[$FIELDS] => [keys %$labels],

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

sub calc_segment($class,$cstruc) {

  my $icebox=$class->_icebox_tab();

  # make new segment
  my $seg=Mach::Seg->new($cstruc->{total});

  # ^subdivide
  my $labels={map {

    # from [name => type]
    # to   [name => ptr]
    $ARG=>$seg->put_label(
      $ARG,@{$cstruc->{sizes}->{$ARG}}

    ),

  } keys %{$cstruc->{sizes}}};

  # ^recurse
  for my $key(keys %{$cstruc->{fields}}) {

    my $ptr  = $labels->{$key};
    my $type = $cstruc->{fields}->{$key};

    # skip primitives
    next if exists $PESZ->{$key};

    # copy sub-segments of a sub-struc
    my $base = $icebox->{$type}->[0];
    my $info = $base->{q[$SEG]};

    $ptr->copy_labels($info);

  };

  return $seg,$labels;

};

# ---   *   ---   *   ---
# debug out

sub prich($self,%O) {

  # defaults
  $O{errout}//=0;

  # detail fields
  my $me=$NULLSTR;

  for my $key(@{$self->{q[$FIELDS]}}) {

    my @bytes = $self->{$key}->to_bytes();
    my $fmat  = xe(\@bytes);

    say "$key\n$fmat\n";

  };

  # ^raw block as footer
  say "\n<".$self->{q[$TYPE]}.'>';
  $self->{q[$SEG]}->prich();

  # select
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

my $t1=Mach::Struc->ice('Not-Test');
my $nest=$t1->{nest}->{tab};

$nest->{a}->set(str=>'HLOWRLD!');
$nest->{b}->set(num=>0x7E7F0000);

$t1->prich();

# ---   *   ---   *   ---
1; # ret
