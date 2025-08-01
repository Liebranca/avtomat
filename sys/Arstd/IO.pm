#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD IO
# Reading and writting;
# formatting and printing
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Arstd::IO;
  use v5.42.0;
  use strict;
  use warnings;

  use lib "$ENV{ARPATH}/lib/";
  use AR sys=>qw(
    use Arstd::String::(cat);

  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.1';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# sets default options
# for an I/O F

sub procin($O) {
  my @bufio=();

  $O->{errout} //= 0;
  $O->{mute}   //= 0;
  $O->{-bufio} //= \@bufio;


  return $O->{-bufio};

};


# ---   *   ---   *   ---
# ^handles output!

sub procout($O) {

  # cat buf
  my $out=cat @{$O->{-bufio}};

  # skip print?
  return $out if $O->{mute};

  # ^nope, fto and write
  my $fh=($O->{errout})
    ? *STDERR
    : *STDOUT
    ;

  return say {$fh} $out;

};


# ---   *   ---   *   ---
1; # ret
