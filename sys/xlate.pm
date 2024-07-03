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
  my $Q=[grep {defined $ARG} @{$enc->{Q}->{asm}}];

  # put header
  my @out=$lang->open_boiler();


  # filter out virtual data
  my $virtual = 0;
  my $end     = 0;
  my $i       = 0;

  for my $data(@$Q) {

    my ($seg,$route,@req)=@$data;

    @req=map {

      my ($type,$ins,@args)=@$ARG;


      # stepped on virtual block?
      if(! $virtual && $ins eq 'data-decl') {

        my ($sym)=$mc->vrefsym($args[0]);
        $virtual=$sym->{virtual};

        $end=$sym->{p3ptr}->next_leaf;
        $end=(defined $end)
          ? $end->absidex
          : -1
          ;

        ($virtual) ? () : $ARG ;


      # ^stepping out of virtual block?
      } elsif($virtual && $i eq $end) {
        $virtual=0;
        ();


      # ^keep values if not inside virtual!
      } else {
        ($virtual) ? () : $ARG ;

      };


    } @req;


    $i++;
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
