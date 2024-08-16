#!/usr/bin/perl
# ---   *   ---   *   ---
# XLATE
# Code translator
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package xlate;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use ipret;
  use Mint qw(mount);

  use Arstd::PM;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,$src,%O) {

  # defaults
  $O{lang} //= 'fasm';

  my $lang=$O{lang};
  delete $O{lang};


  # get interpreter
  my $main=(is_filepath "$src.gz")
    ? mount $src
    : ipret::crux $src,%O
    ;


  # make ice and give
  my $self=bless {
    main=>$main,
    lang=>undef,

  },$class;

  my $pkg="$class\::$lang";
  cloadi $pkg;

  $self->{lang}=$pkg->new($main);


  return $self;

};

# ---   *   ---   *   ---
# ~

sub run($self) {


  # get ctx
  my $main  = $self->{main};
  my $xmode = $main->{xmode};
  my $mc    = $main->{mc};
  my $anima = $mc->{anima};

  my $rip   = $anima->{rip};
  my $enc   = $main->{encoder};
  my $lang  = $self->{lang};
  my $root  = $main->{tree};


  # put header
  my @out=$lang->open_boiler();


  # filter out virtual data
  my @Q  = ();
  my @NQ = @{$root->{leaves}};

  while(@NQ) {

    my $nd   = shift @NQ;
    my $vref = $nd->{vref};

    my $deep = 1;


    # have virtual block?
    $deep *=! (

        St::is_valid('rd::vref',$vref)

    &&  $vref->{type} eq 'HIER'
    &&  $vref->{res}->{virtual}

    );


    # recurse if non-virtual!
    if($deep) {
      push    @Q,$nd;
      unshift @NQ,@{$nd->{leaves}};

    };

  };


  # get assembly queue
  @Q=map {

    my $uid  = $ARG->absidex;
    my $have = $enc->{Q}->{asm};

    (defined $have->[$uid])
      ? [$ARG,$have->[$uid]] : () ;

  } @Q;


  # get executable block
  my $non  = $mc->{astab}->{non};
  my $code = $non->{leaves}->[-1];

  $rip->store(0x00,deref=>0);
  $rip->{chan}=$code->{iced};


  # read/decode/translate
  push @out,map {

    my ($branch,$data)=@$ARG;

    $main->{l2}->{branch}=$branch;
    $lang->step($data);

  } @Q;

  return join "\n",@out;

};

# ---   *   ---   *   ---
1; # ret
