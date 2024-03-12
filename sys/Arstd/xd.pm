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
# lyeb,

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

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::IO;
  use Arstd::PM;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.8;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get input

sub from_file($fpath,%O) {

  # defaults
  $O{order} //= ':>';

  # read and give
  my $body = orc($fpath);
  draw($body,%O);

};

# ---   *   ---   *   ---
# goes through bytestr and
# prints out repr

sub draw($body,%O) {

  # own defaults
  $O{head}  //= 1;
  $O{order} //= '<:';

  # I/O defaults
  my $out=ioprocin(\%O);


  # walk bytes
  my $k=15;

  while(length $body) {

    # get next chunk
    my $line=substr $body,0,16,$NULLSTR;

    # setup line
    my ($i,$j,$h)=(0,0,0);

    my $sl   = $NULLSTR;
    my $sr   = $NULLSTR;

    my $diff = 0;

    # ^split chunk
    my @bytes=split $NULLSTR,$line;

    # ^pad to 16
    if(@bytes < 16) {
      $diff=16-@bytes;
      push @bytes,("\x{00}") x $diff;

    };


    # char to num
    map {

      $ARG=ord $ARG;

      # can print?
      if($ARG < 0x7E && 0x20 <= $ARG) {
        $sr.=chr $ARG;

      # else put dot
      } else {
        $sr.='.';

      };

    } @bytes;


    # shuffle byte ordering?
    if($O{order} eq '<:') {

      @bytes=(

        (reverse @bytes[ 4.. 7]),
        (reverse @bytes[ 0.. 3]),

        (reverse @bytes[12..15]),
        (reverse @bytes[ 8..11]),

      );

    };


    # walk chunk
    map {


      # add byte to mem line
      $sl .= sprintf "%02X",$ARG;

      # go next
      $i++;
      $j++;
      $h++;


      # space every 4th
      if($i > 3) {
        $i   = 0;
        $sl .= ' ';

      };

      # ^reset every 16th
      if($h > 15) {
        $j=$h=0;

      # ^put separator every 8th
      } elsif($j >  7) {
        $j   = 0;
        $sl .= ': ';

      };


    } @bytes;


    # add blank every (cache)line
    # and another every 4th
    $k+=1;


    # notify of "incomplete" xword
    if($diff && $k > 16) {

      push @$out,"\n",
        sprintf "+%01X\n",$diff

      if $diff && $O{head} == 1;


    # ^out xword
    } else {

      push @$out,"\n\n",
        sprintf "\$%04X $O{order}\n",($k-16) >> 4

      if ! ($k % 16) && $O{head} != 0;

      push @$out,,"\n" if ! ($k %  4);

      $O{head}=2;

    };


    # out (human)line
    push @$out,' ',$sl,'| ',$sr,"\n";

  };

  push @$out,"\n";


  return ioprocout(\%O);

};

# ---   *   ---   *   ---
# AR/IMP:
#
# * runs draw with provided
#   input if run as executable
#
# * if imported as a module,
#   it aliases 'draw' to 'xd'
#   and adds it to the calling
#   module's namespace

sub import($class,@req) {

  return IMP(

    $class,

    \&ON_USE,
    \&ON_EXE,

    @req

  );

};

# ---   *   ---   *   ---
# ^imported as exec via arperl

sub ON_EXE($class,$input=undef,@args) {


  # have input?
  my $src=(defined $input)
    ? $input
    : die "xd: no input"
    ;


  # clear null
  @args=grep {$ARG} @args;

  # reading from file?
  if(is_filepath($src)) {
    from_file($src,@args)

  # ^nope, direct
  } else {
    draw($src,@args)

  };

};

# ---   *   ---   *   ---
# ^imported as module via use

sub ON_USE($class,$from,@nullarg) {

  *xd=*draw;

  submerge(

    ['Arstd::xd'],

    main  => $from,
    subok => qr{^xd$},

  );

  return;

};

# ---   *   ---   *   ---
1; # ret
