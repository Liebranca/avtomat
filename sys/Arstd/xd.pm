#!/usr/bin/perl
# ---   *   ---   *   ---
# XD
# heX Dump
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# NOTE:
#
# printing out hexdumps is
# done through standard utils
# most of the time...
#
# so why did I write this?
# because the standard is weird!
#
# every other bin for this task
# thinks tying bytes per line to
# terminal size is cute or something
#
# as well as not showing me the
# entire file because some section
# is only padding
#
# *very* interesting functionality...
# that i never asked for!
#
# and it's always on by default. you guys
# sure know your stuffs don't chu? ;>


# ---   *   ---   *   ---
# deps

package Arstd::xd;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_file);

  use Arstd::String qw(cat to_char gstrip);
  use Arstd::Bin qw(orc);
  use Arstd::throw;
  use Arstd::IO qw(io_procin io_procout);


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(xd);


# ---   *   ---   *   ---
# info

  our $VERSION = "v0.01.1";
  our $AUTHOR  = "IBN-3DILA";
  sub errsafe {return 1};


# ---   *   ---   *   ---
# entry point

sub xd {
  return null if! int(grep {! is_null($ARG)} @_);

  # get args and clear blanks
  my ($src,@args)=@_;
  ($src,@args)=($src,gstrip(@args));

  # reading from file?
  if(is_file($src)) {
    return from_file($src,@args);
  };
  # ^nope, direct
  return draw($src,@args);
};


# ---   *   ---   *   ---
# get input

sub from_file($fpath,%O) {
  # defaults
  $O{order} //= ":>";

  # read and give
  my $body=orc($fpath);
  return draw($body,%O);
};


# ---   *   ---   *   ---
# goes through bytestr and
# prints out repr

sub draw($body,%O) {
  # own defaults
  $O{head}  //= 1;
  $O{order} //= "<:";

  # I/O defaults
  my $out=io_procin(\%O);

  # walk bytes
  my $k=15;
  while(length $body) {
    # get next chunk
    my $line=substr($body,0,16,null);

    # setup line
    my ($i,$j,$h)=(0,0,0);
    my $sl   = null;
    my $sr   = null;
    my $diff = 0;

    # ^split chunk
    my @bytes=to_char($line);

    # ^pad to 16
    if(@bytes < 16) {
      $diff=16-int(@bytes);
      push @bytes,(("\x{00}") x $diff);
    };
    # char to num
    my @sr=();
    for(@bytes) {
      $ARG=ord($ARG);

      # put printable char
      $sr .= ($ARG <= 0x7E && 0x20 <= $ARG)
        ? chr($ARG)
        : "."
        ;

      if($i == 7) {
        $sr=reverse $sr;
        push @sr,$sr;
        $sr = null;
        $i  = 0;

      } else {++$i};
    };
    $sr = cat(@sr);
    $i  = 0;

    # shuffle byte ordering?
    if($O{order} eq ":>") {
      @bytes=(
        (reverse @bytes[ 4.. 7]),
        (reverse @bytes[ 0.. 3]),
        (reverse @bytes[12..15]),
        (reverse @bytes[ 8..11]),
      );
    };
    # walk chunk
    for(@bytes) {
      # add byte to mem line
      $sl .= sprintf "%02X",$ARG;

      # go next
      ++$i;
      ++$j;
      ++$h;

      # space every 4th
      if($i > 3) {
        $i   = 0;
        $sl .= " ";
      };
      # ^reset every 16th
      if($h > 15) {
        $j=$h=0;

      # ^put separator every 8th
      } elsif($j >  7) {
        $j   = 0;
        $sl .= ": ";
      };
    };
    # add blank every (cache)line
    # and another every 4th
    ++$k;

    # out page
    if((! ($k % 16)) && $O{head} != 0) {
      push @$out,sprintf(
        "\n\n\$%04X $O{order}\n",
        ($k-16) >> 4
      );
    };
    push @$out,"\n" if ! ($k % 4);
    $O{head}=2;

    # out (human)line
    push @$out," $sl| $sr\n";
  };
  # spit out and give
  push @$out,"\n";
  return io_procout(\%O);
};


# ---   *   ---   *   ---
1; # ret
