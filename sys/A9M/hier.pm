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

  our $VERSION = v0.00.4;#a
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

    used  => 0x00,
    var   => {
      -order => [],

    },

    io    => {

      map {

        $ARG=>{

          bias => 0x00,
          used => 0x00,

          var  => {-order=>[]},

        },

      } qw  (in out)

    },

    stk   => {-size=>0x00},

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
  my $inbias=$anima->regmask(qw(
    ar br cr dr sp sb
    ice ctx opt chan

  ));

  my $outbias=$anima->regmask(qw(
    er fr gr hr xp xs

  ));


  $self->{io}->{in}->{bias}  |= $inbias;
  $self->{io}->{out}->{bias} |= $outbias;


  return $self;

};

# ---   *   ---   *   ---
# wraps: scope to this block

sub set_scope($self) {


  # get ctx
  my $mc   = $self->getmc();
  my $nd   = $self->{node};

  my $vref = $nd->{vref};


  # get full path into namespace
  my $blk=$vref->{res};
  my ($name,@path)=$blk->fullpath;

  # ^set as current
  $mc->scope(@path,$name);


  return;

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
# decl input/output var

sub addio($self,$ins,$name) {


  # get ctx
  my $mc    = $self->getmc();
  my $main  = $mc->get_main();
  my $anima = $mc->{anima};


  # unpack
  my $key  = $ins;
     $ins  = 'out' if $key eq 'io';

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

    name        => $name,
    const_range => [],

    deps_for => [],
    decl     => -1,

    loc      => $idex,
    ptr      => undef,
    defv     => undef,

    loaded   => $key ne 'out',

  };


  # update bias and restore
  my $bit = 1 << $idex;

  $have->{used}    |= $bit;
  $have->{bias}    |= $bit;
  $anima->{almask}  = $old;


  # edge case: output eq input
  if($key eq 'io') {
    my $alt=$self->{io}->{in};
    $alt->{var}->{$name}=$dst->{$name};

  };


  # set and give
  push @{$dst->{-order}},$name;
  return;

};

# ---   *   ---   *   ---
# check existence of tmp value
# add if not found

sub chkvar($self,$name,$idex) {


  # skip on io var
  my $io=$self->{io};

  map {
    return $io->{$ARG}->{var}->{$name}
    if exists $io->{$ARG}->{var}->{$name};

  } qw(in out);


  # making new var?
  if(! exists $self->{var}->{$name}) {

    push @{$self->{var}->{-order}},$name;

    my $load=(! index $name,'%')
      ? 'const' : 0 ;

    $idex=0 if $load eq 'const';


    $self->{var}->{$name}={

      name        => $name,
      const_range => [
        [$idex,-1],

      ],

      deps_for => [],
      decl     => $idex,

      loc      => undef,
      ptr      => undef,
      defv     => undef,

      loaded   => $load,

    };


  # stepping on existing!
  } else {

    my $have = $self->{var}->{$name};
    my $cr   = $have->{const_range};
    my $beg  = $cr->[0];

    if($beg && $beg->[0] eq -1) {
      $beg->[0]=$idex;

    } elsif(! $beg) {
      push @$cr,[$idex,-1];

    };

    $have->{decl}=$idex
    if $have->{decl} < 0;

  };


  return $self->{var}->{$name};

};

# ---   *   ---   *   ---
# manages inter-value relationships

sub depvar($self,$var,$depname,$idex) {


  # fetch source
  my $dep=$self->chkvar($depname,$idex);

  # adjust constant status
  my $cr=\$var->{const_range};

  if(

     $var->{loaded} ne 'const'
  && defined $$cr->[-1]

  ) {

    my $ar=$$cr->[-1];

    $ar->[1]=$idex;

    if($ar->[0] eq $ar->[1]) {
      $$cr->[-1]=undef;
      @{$$cr}=grep {defined $ARG} @{$$cr};

    };

  };


  # register dependency
  push @{$dep->{deps_for}},[$var->{name},$idex];
  $cr=\$dep->{const_range};

  if(

     $dep->{loaded} ne 'const'
  && defined $$cr->[-1]

  ) {

    my $ar=$$cr->[-1];
    $ar->[1]=$idex;

    push @{$$cr},[$idex+1,-1];

  };


  return $dep;

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

sub varkeys($self,%O) {

  # defaults
  $O{io}     //= 0;
  $O{common} //= 1;

  # get lists of names
  my @out=($O{common})
    ? @{$self->{var}->{-order}}
    : ()
    ;


  # ^get io vars?
  push @out,map {
    @{$self->{io}->{$ARG}->{var}->{-order}};

  } ($O{io} eq 'all')
    ? qw(in out)
    : $O{io}

  if $O{io};


  return @out;

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
# place backup in register
# use defv if no backup!

sub load($self,$dst) {


  # get ctx
  my $mc    = $self->getmc();
  my $anima = $mc->{anima};

  # need to allocate register?
  if(! defined $dst->{loc}) {


    # setup allocation bias
    my $io   = $self->{io};
    my $bias = $io->{out}->{used};
    my $old  = $anima->{almask};

    $bias |= $io->{in}->{used};
    $bias |= $self->{used};


    # get free register
    $anima->{almask}=$bias;
    my $idex = $anima->alloci();
    my $bit  = 1 << $idex;

    # ^mark in use and restore
    $self->{used}    |= $bit;
    $dst->{loc}       = $anima->fetch($idex);

    $anima->{almask}  = $old;

say "ld $dst->{loc}->{label},[$dst->{name}]";


  };


  return;

};

# ---   *   ---   *   ---
# WIP: get name of value

sub vname($self,$var) {


  # have register?
  my $out=null;
  if($var->{type} eq 'r') {
    $out="\$$var->{reg}";

  # have alias?
  } else {

    $out   = $var->{imm_args}->[0];
    $out   = $out->{id}->[0];

    $out //= $var->{id}->[0];

  };


  # have immediate!
  if(! defined $out) {
    $out="\%$var->{imm}";

  };


  return $out;

};

# ---   *   ---   *   ---
1; # ret
