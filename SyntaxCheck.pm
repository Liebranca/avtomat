#!/usr/bin/perl
# ---   *   ---   *   ---
# SYNTAX CHECK
# perl -c
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package SyntaxCheck;
  use v5.42.0;
  use strict;
  use warnings;

  use Cwd qw(getcwd);
  use Carp qw(croak);
  use English qw($ARG $ERRNO $EVAL_ERROR);

  use lib "$ENV{ARPATH}/lib/";
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_file);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# shorten path

sub shpath {
  my $path = $_[0];
  my $re   = qr{/+};
  my $root = getcwd;

  $path =~ s[$re][/];

  $root =  qr{/*$root/*};
  $path =~ s[$root][];

  return $path;

};


# ---   *   ---   *   ---
# this is for catching syntax check warnings

my @SyntaxError;
sub head {
  @SyntaxError=();
  $SIG{'__WARN__'}=sub {
    push @SyntaxError,$_[0];
    return;

  };

  return;

};


# ---   *   ---   *   ---
# ^closer

sub foot($fname,$body) {
  push @SyntaxError,$EVAL_ERROR
  if ! is_null $EVAL_ERROR;

  if(@SyntaxError) {

    # remove duplicate messages
    my %tmp=map {$ARG=>1} @SyntaxError;
    @SyntaxError=map {
      ($tmp{$ARG}-- == 1)
        ? $ARG
        : ()
        ;

    } keys %tmp;

    # color/formating constants
    my $nl    = "\n";
    my $namec = "\e[32;1m";
    my $nocol = "\e[0m";
    my $numc  = "\e[33;21m";
    my $cbeg  = "\n\n\e[36;1m```\n";
    my $cend  = "\n\n```\e[0m\n\n";

    # put in the short form of the filename
    my $re    = qr{\(eval\s\d+\)};
    my $short = shpath $fname;

    $ARG=~ s[$re][$short]smg for @SyntaxError;


    # reformat error messages
    for(@SyntaxError) {
      $re=qr{
        at   \s (?<name> .+)    \s
        line \s (?<num> \d+) , \s
        near \s "

      }x;

      # we're just adding color to the filename,
      # line number and code here
      $ARG =~ s[$re][\b:${nl}at $namec$+{name}$nocol line $numc$+{num}$cbeg]smg;
      $re  =  qr{"\n};
      $ARG =~ s[$re][$cend]smg;

    };

    # spit it out!
    croak "\n",@SyntaxError,"\n\b";

  };


  return;

};


# ---   *   ---   *   ---
# entry point

sub run($fname,$body) {
  head;

  eval $body;
  foot $fname,$body;

  return;

};


# ---   *   ---   *   ---
1; # ret
