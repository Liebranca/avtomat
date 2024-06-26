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

  our $VERSION = v0.00.1;#a
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


  # get assembly queue
  my $Q=[
    map {(is_arrayref $ARG) ? @$ARG : ()}
    @{$enc->exewrite_sort()}

  ];


  # put header
  my @out=$lang->open_boiler();


  # filter out virtual data
  my $virtual = 0;

  for my $data(@$Q) {

    my ($seg,$route,@req)=@$data;

    @req=map {

      my ($type,$ins,@args)=@$ARG;

      if(! $virtual && $ins eq 'data-decl') {
        my ($sym)=$mc->vrefsym($args[0]);
        $virtual=$sym->{virtual};

        ($virtual) ? () : $ARG ;

      } elsif($virtual && $ins eq 'ret') {
        $virtual=0;
        ();

      } else {
        ($virtual) ? () : $ARG ;

      };


    } @req;


    $data=(@req) ? [$seg,$route,@req] : [] ;

  };

  @$Q=grep {int @$ARG} @$Q;


  # get executable block
  my $non  = $mc->{astab}->{non};
  my $code = $non->{leaves}->[-1];

  $rip->store(0x00,deref=>0);
  $rip->{chan}=$code->{iced};


  # read/decode/translate
  push @out,map {$lang->step($ARG)} @$Q;

  return join "\n",@out;

};

# ---   *   ---   *   ---
1; # ret
