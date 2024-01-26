#!/usr/bin/perl
# ---   *   ---   *   ---
# XD
# Display heX
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
  use Arstd::IO;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.5;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get input

sub from_file($fpath) {
  my $body = orc($fpath);
  draw($fpath);

};

# ---   *   ---   *   ---
# when ran as executable

sub crux($input=undef) {

  # have input?
  my $src = defined $input
  or die "xd: no input";

  # ^select accto input type
  if(-f $src) {
    from_file($src)

  } else {
    draw($src)

  };


};

# ---   *   ---   *   ---
# goes through bytestr and
# prints out repr

sub draw($body) {

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
      push @bytes,("\x{00}")x$diff;

    };


    # walk chunk
    for my $b(@bytes) {

      # get char as a number
      my $x  = ord($b);
      $sl   .= sprintf "%02X",$x;

      # ^can we print it?
      if($x<0x7E && 0x20<$x) {
        $sr.=chr($x);

      # else put dot
      } else {
        $sr.='.';

      };

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

    };


    # add blank every (cache)line
    # and another every 4th
    $k+=1;


    if($diff && $k > 16) {
      say "\n",sprintf "+%01X",$diff if $diff;

    } else {

      say "\n\n",sprintf "\$%04X :>",($k-16) >> 4
      if ! ($k % 16);

      say $NULLSTR if ! ($k %  4);

    };

    # out (human)line
    say ' ',$sl,'| ',$sr;

  };

  say $NULLSTR;

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

  # imported as exec via arperl
  if( defined $req[0]
  &&  $req[0] eq '*crux'

  ) {

    return crux($req[1]);


  # imported as module via use
  } else {

    use Arstd::PM;
    *xd=*draw;

    submerge(

      ['Arstd::xd'],
      main  => caller,
      subok => qr{^xd$},

    );

  };

};

# ---   *   ---   *   ---
1; # ret
