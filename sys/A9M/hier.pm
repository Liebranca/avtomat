#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M HIER
# Put it in context
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::hier;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;

  use Arstd::IO;

  use parent 'A9M::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {

  DEFAULT => {

    name  => null,
    node  => undef,

    type  => 'blk',
    hist  => {},
    shist => [],
    endat => 0,

    Q     => {

      early  => [],
      late   => [],

      ribbon => [],

    },

    var   => {
      -order => [],

    },

    io    => {
      map {$ARG=>{bias=>0x00,var=>{-order=>[]}}}
      qw  (in out)

    },

    mcid  => 0,
    mccls => null,

  },


  typetab => {

    proc => [qw(const readable executable)],

  },

};

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  $class->defnit(\%O);

  my $self  = bless \%O,$class;
  my $flags = $class->typetab->{$self->{type}};

  $self->set_uattrs(

    (defined $flags)
      ? @$flags
      : ()
      ,

  );


  # get ctx
  my $mc    = $self->getmc();
  my $anima = $mc->{anima};

  # calculate initial register allocation bias
  my $bias=$anima->regmask(qw(ar br cr dr));
  $self->{io}->{in}->{bias} |= $bias;


  return $self;

};

# ---   *   ---   *   ---
# make/fetch point in hist

sub timeline($self,$uid,$data=undef) {

  # get ctx
  my $mc   = $self->getmc();
  my $hist = $self->{hist};

  # fetch, (set)?, give
  my $out = \$hist->{$uid};

  $$out=$mc->hierstruc($data)
  if defined $data;

  return $$out;

};

# ---   *   ---   *   ---
# add attr to obj

sub addattr($self,$name,$value) {
  $self->{$name}=$value;
  return;

};

# ---   *   ---   *   ---
# add method to execution queue

sub enqueue($self,$name,@args) {
  push @{$self->{Q}->{$name}},\@args;
  return;

};

# ---   *   ---   *   ---
# ~

sub addio($self,$opsz,$ins,$name) {


  # get ctx
  my $mc    = $self->getmc();
  my $main  = $mc->get_main();
  my $anima = $mc->{anima};


  # unpack
  my $have = $self->{io}->{$ins};
  my $dst  = $have->{var};


  # validate input
  $main->perr(

    "redecl of [good]:%s var '%s'\n"
  . "for [ctl]:%s '%s'",

    args=>[
      $ins,$name,
      $self->{type},$self->{name}

    ],

  ) if exists $dst->{$name};


  # setup allocation bias
  my $bias = $have->{bias};
  my $old  = $anima->{almask};

  $anima->{almask}=$bias;


  # allocate register
  my $idex=$anima->alloci();

  $dst->{$name}={

    const_range => [],

    deps_for => [],
    decl     => $idex,


    opsz => (
       defined $opsz
    && Type->is_valid($opsz)

    ) ? typefet $opsz
      : null
      ,

  };


  # update bias and restore
  $have->{bias}    |= 1 << $idex;
  $anima->{almask}  = $old;


  # set and give
  push @{$dst->{-order}},$name;
  return;

};

# ---   *   ---   *   ---
# check existence of tmp value
# add if not found

sub chkvar($self,$name,$idex) {

  if(! exists $self->{var}->{$name}) {

    push @{$self->{var}->{-order}},$name;

    $self->{var}->{$name}={

      const_range => [
        [$idex,-1],

      ],

      deps_for => [],
      decl     => $idex,

    };

  };


  return $self->{var}->{$name};

};

# ---   *   ---   *   ---
# manages inter-value relationships

sub depvar($self,$name,$depname,$idex) {


  # skip?
  return if ! exists $self->{var}->{$name};

  # fetch both values
  my $have = $self->{var}->{$name};
  my $dep  = $self->{var}->{$depname};


  # adjust constant status
  my $cr=\$have->{const_range};

  if(defined $$cr->[-1]) {

    my $ar=$$cr->[-1];

    $ar->[1]=$idex;

    if($ar->[0] eq $ar->[1]) {
      $$cr->[-1]=undef;
      @{$$cr}=grep {defined $ARG} @{$$cr};

    };

  };


  # register dependency
  push @{$dep->{deps_for}},[$name,$idex];
  $cr=\$dep->{const_range};

  if(defined $$cr->[-1]) {

    my $ar=$$cr->[-1];
    $ar->[1]=$idex-1;

    push @{$$cr},[$idex+1,-1];

  };

  return;

};

# ---   *   ---   *   ---
# replaces '-1' in ranges with
# the provided timeline end

sub endtime($self,$i) {

  $self->{endat}=$i;

  map {

    my $have = $self->{var}->{$ARG};
    my $cr   = \$have->{const_range};

    if(defined $$cr->[-1]) {

      my $ar=$$cr->[-1];

      $ar->[1]=$i
      if $ar->[1] eq -1;

      $ar->[0]=$i
      if $ar->[0] > $i;


      if($ar->[0] == $ar->[1]) {
        $$cr->[-1]=undef;
        @{$$cr}=grep {defined $ARG} @{$$cr};

      };

    };

  } $self->varkeys;


  return;

};

# ---   *   ---   *   ---
# check if a value write is
# entirely redundant

sub redvar($self,$name) {


  # get ctx
  my $mc   = $self->getmc();
  my $main = $mc->get_main();

  my $hist = $self->{shist};
  my $have = $self->{var}->{$name};

  # value not used elsewhere?
  $main->bperr(

    $hist->[$have->{decl}]
  ->{'asm-Q'}->[0],

    "redundant instruction; "
  . "value '%s' never used",

    args=>[$name],

  ) if ! int @{$have->{deps_for}};


  # walk points
  my $cr = $have->{const_range};
  my $i  = 0;

  map {

    my ($beg,$end)=@$ARG;
    my $point=$hist->[$end];

    my $over=(
       $self->is_overwrite($point)
    && $beg < $end

    );

    if($over) {

      my $early=$hist->[$beg];

      $main->bperr(

        $early->{'asm-Q'}->[0],

        "redundant instruction; "
      . "overwritten by [ctl]:%s at "
      . "line [num]:%u",

        args => [
          $point->{'asm-Q'}->[-1]->[1],
          $point->{'asm-Q'}->[0]->{lineno},

        ],

      );

    };

  } @$cr;


  return;

};

# ---   *   ---   *   ---
# get value is overwritten at
# an specific timeline point

sub is_overwrite($self,$point) {

  return (

      $point->{overwrite}
  &&! $point->{load_dst}

  );

};

# ---   *   ---   *   ---
# get names of all existing values

sub varkeys($self) {
  return @{$self->{var}->{-order}};

};

# ---   *   ---   *   ---
# sort nodes in history

sub sort_hist($self,$recalc=0) {


  # get ctx
  my $out = $self->{shist};
  my @uid = keys %{$self->{hist}};

  # skip if we don't need to recalculate
  my $ok=@$out == @uid;
  return $out if $ok &&! $recalc;


  # sort elements idex relative to root
  my $root = $self->{node};
  my @have = $root->find_uid(@uid);

  map {
    my $i=$ARG->relidex($root);
    $out->[$i]=$self->{hist}->{$ARG->{-uid}};

  } @have;


  # remove blanks and give
  @$out=grep {defined $ARG} @$out;
  return $out;

};

# ---   *   ---   *   ---
# WIP: value name conversion

sub vname($self,$name) {


  # have plain idex?
  if($name=~ $NUM_RE) {
    $name="\$$name";


  # have alias!
  } else {
    nyi "tmp value aliases";

  };


  return $name;

};

# ---   *   ---   *   ---
1; # ret
