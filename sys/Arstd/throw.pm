#!/usr/bin/perl
# ---   *   ---   *   ---
# THROW
# ... your hands in the air!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::throw;
  use v5.42.0;
  use strict;
  use warnings;

  use File::Spec;
  use English qw(
    $ARG
    $MATCH
    $ERRNO
    $EVAL_ERROR

  );

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null codefind);
  use Arstd::String qw(cat strip);
  use Arstd::ansi;


# ---   *   ---   *   ---
# adds to your namespace...
# well, what do you think? ;>

  use Exporter 'import';
  our @EXPORT=qw(throw);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.1a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# no croak
#
# [0]: byte ptr ; message/info (defaults to null)
# [1]: byte ptr ; culprit (defaults to &culprit)
# [2]: mem  ptr ; errme array
#
# [*]: the last two arguments are meant for
#      system stuff, specifically the syntax
#      check wrapper and other packages that
#      have to trap warn/die signals
#
#      user code _probably_ shouldn't need them
#
#
# [!]: does _not_ throw if the array is empty
#
# [!]: overwrites culprit when throwing;
#      this shouldn't matter as program then ends
#
# [!]: culprit is only needed when you are
#      reporting errors from inside an eval block

sub throw {

  # these builtin vars give us further errors;
  # sometimes they are repeats, sometimes not
  #
  # anyway, we put them first as they are
  # generally more detailed than just
  # "syntax error", and any duplicates that
  # come after that will be discarded
  # (see below...)

  if (! is_null($ERRNO) &&! is_null($_[0])) {
    unshift @{$_[2]},"$ERRNO: $_[0]";

  } elsif(! is_null($ERRNO)) {
    unshift @{$_[2]},$ERRNO;

  # [*] info is not builtin, obviously
  #     but if it was passed, then we care about it
  } elsif(! is_null($_[0])) {
    unshift @{$_[2]},$_[0];

  };

  unshift @{$_[2]},$EVAL_ERROR
  if $EVAL_ERROR;


  # ^after checking those vars,
  # ^see if there are actually any errors
  #
  # resume program if no errors to show!

  return if ! int @{$_[2]};

  # OK, we have an error
  # put notice with culprit at end of array
  push @{$_[2]},culprit();

  # we need to identify filepaths in
  # a few places here...
  my $file_re=Chk::path_chars;
     $file_re=qr{($file_re\.$file_re)};

  # default to culprit if none passed
  #
  # this is just to have a culprit
  # to point at, scapegoat style
  #
  # _must_ have a file to blame!

  if(! defined $_[1]) {
    $_[2]->[-1]=~ $file_re;
    $_[1]=$1;

  };


  # remove duplicate messages
  #
  # or rather, messages addressing the
  # exact same line
  #
  # this _generally_ means it's the same
  # error reported more than once, but
  # it some cases it _may_ fail (not sure)

  my $line_re=qr{
    at   \s (?<name> .+) \s
    line \s (?<num> \d+)

  }x;

  # the order is preserved (keys would kill it)
  my @order=();
  my %tmp=map {
    $ARG=~ $line_re;
    push @order,$MATCH;

    # the line is hash key
    #
    # this makes it so errors on the same
    # line will not be reported twice

    $MATCH=>[1,$ARG];

  } @{$_[2]};

  # ^walk back through the hash and retrieve
  # ^a single errme for each line!
  @{$_[2]}=map {
    ($tmp{$ARG}->[0]-- == 1)
      ? $tmp{$ARG}->[1]
      : ()
      ;

  } @order;


  # color/formating constants
  my $nl    = "\n";
  my $namec = "\e[32;1m";
  my $nocol = "\e[0m";
  my $numc  = "\e[33;21m";
  my $cbeg  = "\n\n\e[36;1m```\n";
  my $cend  = "\n\n```\e[0m\n\n";

  # patterns we use
  my $end_re  = qr{"\n};
  my $eval_re = qr{\(eval\s\d+\)};
  my $str_re  = qr{((?:"[^\"]*")|(?:'[^\']*'))};

  # there's different line formats we use, accto
  # which pattern the message matches
  #
  # they are all very similar though...
  my @line_re=(
    qr{$line_re,\snear\s"},
    qr{$line_re\.},

  );

  # shorten culprit for sanity
  shpath($_[1]);


  # reformat error messages
  for(@{$_[2]}) {

    # detect if a filename is used;
    # if so, shorten it
    if($ARG=~ $file_re) {
      my $have=$1;
      shpath($have);

      $ARG=~ s[$file_re][$namec$have$nocol]smg;

    };

    # put in short form of culprit
    #
    # else it says (eval #number), which is
    # very unhelpful

    $ARG=~ s[$eval_re][$_[1]]smg;


    # we're just adding color to the filename,
    # line number and code here
    if(($ARG=~ $end_re) && ($ARG=~ $line_re[0])) {
      my $me=cat(
        "\n${nl}at $+{name} ",
        "line $numc$+{num}$cbeg",

      );

      $ARG=~ s[${line_re[0]}][$me]smg;
      $ARG=~ s[$end_re][$cend]smg;

    # ^second pattern is more or less the
    # ^same thing, except it doesn't have the
    # ", near (codestr)" bit
    } elsif($ARG=~ s[${line_re[1]}][]) {
      my $me=cat(
        "at $namec$+{name}$nocol ",
        "line $numc$+{num}$nocol",

      );

      $ARG .= "$me";

    };


    # put quoted text in cyan, just because
    # it's what i do in the editor ;>
    $ARG=~ s[$str_re][\e\[36;1m$1$nocol]smg;

    # finally, remove newline at end
    # we'll add one ourselves ;>
    chomp $ARG;

  };


  # spit it out!
  strip $_[2]->[-1];
  die "\n",join("\n",@{$_[2]}),"\n\n";

};


# ---   *   ---   *   ---
# identifies _likely_ source of error;
# gives "at [file] line [num]" for it
#
# this is determined by packages having
# an argless &errsafe F, and if they do,
# the return value of it being non-zero
#
# [<] byte ptr ; new string

sub culprit {
  my $i    = 0;
  my $safe = {'Arstd::throw'=>1};
  my $out  = undef;

  # we drop the first frame as it's
  # going to be throw itself
  my @frame=bt();
  shift @frame;

  # the frame after that is whomever called
  # throw, so that gets dropped too
  #
  # we keep a reference to it in case no
  # other culprit can be found
  #
  # also, we mark it as 'safe' so that
  # calls from that package won't get picked up
  my $default=shift @frame;
  $safe->{$default->[0]}=1;


  # now walk the remaining frames
  for(@frame) {

    # skip packages marked safe
    my ($pkg,$fname,$lineno,$subroutine)=@$ARG;
    next if exists $safe->{$pkg};

    # can this package be trusted?
    my $fn=codefind $pkg,'errsafe';
    $safe->{$pkg}=$fn->() if ! is_null $fn;

    ($out)=($ARG),last
    if ! exists $safe->{$pkg} ||! $safe->{$pkg};

  };

  # ^set default if no culprit found ;>
  $out //= $default;


  # make pretty print for out
  return cat(
    Arstd::ansi::m('::','op'),
    Arstd::ansi::m('throw','ctl'),
    Arstd::ansi::m(),

    " at $out->[1] line $out->[2].",

  );

};


# ---   *   ---   *   ---
# get backtrace
#
# [<] mem* ; new array
#
# [*] out format is [pkg,fname,lineno,subroutine];
#     further info is included, but we don't
#     use it; is that cheaper than grepping?
#
#     dunno!

sub bt {
  my @out   = ();
  my $depth = 0;
  while(++$depth) {
    last if ! defined caller $depth;
    push @out,[(caller $depth)];

  };

  return @out;

};


# ---   *   ---   *   ---
# shorten path
#
# [0]: byte ptr ; path
# [<]: bool     ; path is not null
#
# [!]: overwrites input path
#
# TODO: move this somewhere else
#       (Arstd::Path maybe?)

sub shpath {
  return 0 if is_null $_[0];

  $_[0]=File::Spec->abs2rel($_[0]);

  my $re=qr{/+};
  $_[0]=~ s[$re][/];

  return ! is_null $_[0];

};


# ---   *   ---   *   ---
1; # ret
