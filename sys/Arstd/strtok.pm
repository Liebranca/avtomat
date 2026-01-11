#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD STRTOK
# tokenizes strings
# (inside your strings!)
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::strtok;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);

  use Arstd::String qw(to_char);
  use Arstd::seq qw(seqtok);


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    strtok
    unstrtok
    rmstrtok
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.3a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# entry point
#
# [0]: byte pptr ; array to save token contents to
# [1]: byte ptr  ; string to process
# [2]: byte pptr ; options
#
# [!]: overwrites input string

sub strtok {
  my $dst  = shift;
  my $sref = \$_[0];
  shift;

  my %O=@_;

  $O{syx} //= defsyx();

  my $st={
    out  => null,
    tok  => null,
    syx  => $O{syx},
    ar   => [to_char($$sref)],
    i    => 0,
    dst  => $dst,
  };

  while($st->{i} < int(@{$st->{ar}})) {
    my $skip=0;
    for my $seq(@{$st->{syx}}) {
      if(my $j=findseq($st,$seq)) {
        $st->{i} += $j;
        $skip     = 1;

        last;
      };
    };
    next if $skip;

    $st->{tok} .= $st->{ar}->[$st->{i}++];
  };

  # save whatever was left on the token
  # then overwrite the input string
  $st->{out} .= $st->{tok};
  $$sref      = $st->{out};

  return;
};


# ---   *   ---   *   ---
# ^undo

sub unstrtok {
  return 0 if is_null($_[0]);
  my $ar=$_[1];
  my $re=(! is_null($_[2]))
    ? Arstd::seq::typed_tok_re($_[2])
    : Arstd::seq::tok_re()
    ;

  while($_[0]=~ $re) {
    my $idex=$+{idex};
    my $s=$ar->[$idex];

    $_[0]=~ s[$re][$s];
  };

  return ! is_null($_[0]);
};

sub rmstrtok {
  return 0 if is_null($_[0]);
  my $re=(! is_null($_[2]))
    ? Arstd::seq::typed_tok_re($_[2])
    : Arstd::seq::tok_re()
    ;

  $_[0]=~ s[$re][ ]g;

  return ! is_null($_[0]);
};


# ---   *   ---   *   ---
# given a tokenized string,
# get the indices of all tokens
# that match a given type

sub fet {
  my ($ar,$s,$type)=@_;
  my $re  = Arstd::seq::typed_tok_re($type);
  my @out = ();

  while($s=~ s[$re][]) {
    push @out,$+{idex}
  };
  return @out;
};


# ---   *   ---   *   ---
# checks for tokenizable sequence

sub findseq($st,$seq) {
  my ($j,$tok)=seqtok(
    $seq,
    $st->{dst},
    $st->{i},
    $st->{ar},
  );

  # nothing found
  return 0 if ! $j;

  # sequence found, so flush buffer
  $st->{out} .= $st->{tok};
  $st->{tok}  = null;

  # cat token to output -- if it's null,
  # then this does nothing ;>
  $st->{out} .= $tok;
  return $j;
};


# ---   *   ---   *   ---
# ^default sequences used

sub defsyx {
  return [
    # comments
    Arstd::seq::com()->{pline},

    # strings
    Arstd::seq::str()->{dquote},
    Arstd::seq::str()->{squote},
    Arstd::seq::str()->{backtick},

    # preprocessor
    Arstd::seq::pproc()->{peso},
  ];
};


# ---   *   ---   *   ---
1; # ret
