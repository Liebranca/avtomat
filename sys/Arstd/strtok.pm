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

  use Arstd::String qw(to_char linecnt);
  use Arstd::seq qw(token seqtok);


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    strtok
    strarmut
    strarvoid
    strarex

    unstrtok
    rmstrtok
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.5a';
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
  my $out={};
  while($st->{i} < int(@{$st->{ar}})) {
    my $skip=0;
    for my $seq(@{$st->{syx}}) {
      # we want to tell the caller of this F
      # whether any sequences where found!
      $out->{$seq->{type}} //= 0;

      if(my $j=findseq($st,$seq)) {
        $st->{i} += $j;
        $skip     = 1;

        ++$out->{$seq->{type}};

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

  # give info on which sequences where hit!
  return $out;
};


# ---   *   ---   *   ---
# ^undo

sub unstrtok {
  return 0 if is_null($_[0]);
  my $ar=$_[1];
  my $re=Arstd::seq::tok_re($_[2],$_[3]);

  while($_[0]=~ $re) {
    my $idex=$+{idex};
    my $s=$ar->[$idex];

    $_[0]=~ s[$re][$s];
  };

  return ! is_null($_[0]);
};

sub rmstrtok {
  return 0 if is_null($_[0]);
  my $re=Arstd::seq::tok_re($_[2],$_[3]);

  $_[0]=~ s[$re][ ]g;

  return ! is_null($_[0]);
};


# ---   *   ---   *   ---
# given a tokenized string,
# get the indices of all tokens
# that match a given type

sub fet {
  my ($ar,$s,$type)=@_;
  my $re  = Arstd::seq::tok_re($type);
  my @out = ();

  while($s=~ s[$re][]) {
    push @out,$+{idex};
  };
  return @out;
};


# ---   *   ---   *   ---
# ^same thing, but also gets line number

sub fetln {
  my ($ar,$s,$type)=@_;
  my $re  = Arstd::seq::tok_re($type);
  my @out = ();

  # we add a newline after the substitution
  # so as to ensure each call to linecnt
  # returns a higher number than the last
  my $nl="\n";
  while($s=~ s[$re][$nl]) {
    my $idex  = $+{idex};
    my $pos   = $-[0];
    my $chunk = substr($s,0,$pos);
    my $ln    = linecnt($chunk);

    push @out,[$+{idex},$ln];
  };
  return @out;
};


# ---   *   ---   *   ---
# given a tokenized string and the index of
# a token, *mutate* the token into a
# different type
#
# we use this chiefly within preprocessors,
# when a line expands into code!
#
# the mutation makes it so that code doesn't
# get re-interpreted as a preprocessor directive

sub strarmut {
  my ($ar,$sref,$i,$t,$v)=@_;

  my $re  = Arstd::seq::tok_re(null()=>$i);
  my $tok = token($t=>$i);

  $$sref=~ s[$re][$tok];
  $ar->[$i]=$v;

  return;
};


# ---   *   ---   *   ---
# voids a token, so that whenever the string
# is untokenized it won't expand into anything

sub strarvoid {
  my ($ar,$sref,$i,$t)=@_;
  $t //= "null";

  return strarmut($ar,$sref,$i,$t,null());
};


# ---   *   ---   *   ---
# expands a token, then voids it
# (optionally) sets its value as well

sub strarex {
  my ($ar,$sref,$i,$v)=@_;

  $ar->[$i]=$v if defined $v;
  unstrtok($$sref,$ar,null()=>$i);
  strarvoid($ar,$sref,$i);

  return;
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
