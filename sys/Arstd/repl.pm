#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD REPL
# Poor man's tokenizer
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::repl;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG $MATCH);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Arstd::seq qw(seqtok_push);
  use Arstd::strtok qw(strtok unstrtok);
  use Arstd::throw;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4a';
  our $AUTHOR  = 'IBN-3DILA';

  sub errsafe {return 1};


# ---   *   ---   *   ---
# default behavior; gives match exactly
#
# [0]: mem ptr  ; self
# [1]: word     ; idex
#
# [<]: byte ptr ; captured match

sub proto_undo_f {
  return $_[0]->{asis}->[$_[1]];
};


# ---   *   ---   *   ---
# cstruc
#
# [0]: byte ptr  ; class
# [1]: byte pptr ; (k=>v) options
#
# [<]: mem ptr ; new instance

sub new {
  state $uid=0;
  my ($class,%O)=@_;

  # catch bad param
  throw "$class requires a sequence and "
  .     "an input regex"

  if! exists $O{inre}
  ||! exists $O{seq};

  # force copy of sequence with unique type,
  # this allows us to identify tokens
  $O{seq}={
    %{$O{seq}},
    type=>$O{seq}->{type} . 'repl' . $uid++,
  };

  # set defaults
  $O{repv}  //= \&proto_undo_f;
  $O{undo}  //= \&proto_undo_f;
  $O{syx}   //= Arstd::strtok::defsyx();
  $O{outre} //= Arstd::seq::typed_tok_re(
    $O{seq}->{type}
  );

  # make ice and give
  my $self=bless {
    asis  => [],
    capt  => [],
    idex  => [],
    strar => [],
    ct    => [],

    %O,

  },$class;

  return $self;
};


# ---   *   ---   *   ---
# clears state
#
# [0]: mem ptr  ; self

sub clear {
  @{$_[0]->{$ARG}}=() for qw(
    asis capt idex strar ct
  );
  return;
};


# ---   *   ---   *   ---
# tokenizes input and picks which
# of the tokenized elements match
# the pattern we're looking for
#
# [0]: mem ptr  ; self
# [1]: byte ptr ; string
#
# [!]: overwrites input string

sub repl {
  # tokenize away any sequences in input
  # that are "in the way" of the main sequence
  my $self=shift;
  strtok($self->{strar},$_[0],syx=>$self->{syx});

  # *now* apply a second tokenization, looking
  # only for the main sequence!
  strtok($self->{ct},$_[0],syx=>[$self->{seq}]);

  # the result is that now all matches are
  # contained within the 'ct' array
  #
  # so now we walk this array and perform
  # the final regex check to extract the
  # data we need
  my $idex=-1;
  for(@{$self->{ct}}) {
    ++$idex;

    # make a copy to untokenize,
    # so as to perform the regex check
    my $cpy="$ARG";
    unstrtok($cpy,$self->{strar});

    # we skip any elements that do not
    # match our input pattern
    next if ! ($cpy=~ $self->{inre});

    # ^ and save the others; *these* are the
    #   ones we want to modify
    push @{$self->{asis}},$MATCH;
    push @{$self->{capt}},{%+};
    push @{$self->{idex}},$idex;
  };
  return;
};


# ---   *   ---   *   ---
# ^ applies function to picked matches
#   and undoes tokenization
#
# [0]: mem ptr  ; self
# [1]: byte ptr ; function id to call
# [2]: byte ptr ; string
#
# [!]: overwrites input string

sub proto_undo {
  my ($self,$fn)=(shift,shift);
  my $ct_idex=0;
  for my $tok_idex(@{$self->{idex}}) {
    # get modified contents of token
    my $ct=$self->{$fn}->($self,$ct_idex++);

    # ^ replace token in input with
    #   the modified value
    my $re=Arstd::seq::spec_tok_re(
      $self->{seq}->{type},
      $tok_idex
    );
    $_[0]=~ s[$re][$ct];
  };

  # now undo the tokenization we did during repl
  #
  # first we restore any matches within 'ct' that
  # did not match the pattern
  unstrtok(
    $_[0],
    $self->{ct},
    $self->{seq}->{type}
  );
  # ^and then we restore any other tokens
  unstrtok($_[0],$self->{strar});
  return;
};


# ---   *   ---   *   ---
# ^lis
#
# [0]: mem ptr  ; self
# [2]: byte ptr ; string
#
# [!]: overwrites input string

sub repv {$_[0]->proto_undo(repv=>$_[1])};
sub undo {$_[0]->proto_undo(undo=>$_[1])};


# ---   *   ---   *   ---
# immediately runs repl+repv
#
# [0]: mem ptr  ; self
# [2]: byte ptr ; string
#
# [!]: overwrites input string

sub proc {
  $_[0]->repl($_[1]);
  $_[0]->repv($_[1]);
  $_[0]->clear();

  return;
};


# ---   *   ---   *   ---
1; # ret
