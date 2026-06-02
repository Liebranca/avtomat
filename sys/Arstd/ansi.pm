#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD ANSI
# For when you gotta ESCAPE
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::ansi;
  use v5.42.0;
  use strict;
  use warnings;

  use Term::ReadKey qw(GetTerminalSize);
  use List::Util qw(sum);
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/";
  use Style qw(null);
  use Chk qw(is_null);
  use Arstd::String qw(
    cat
    gsplit
    fgsplit
    recaptsu
    decaptsu
  );


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(ttysz);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.6';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# used for matching ansi escapes!
#
# [*] const
# [<] byte ptr

sub escape_re {qr"\x{1B}\[[\?\d;]+[\w]"};


# ---   *   ---   *   ---
# get terminal size in chars
#
# [<] word ptr ; term [x,y] sz (new array)

sub ttysz {
  my ($x,$y)=GetTerminalSize();
  return ($x,$y);
};


# ---   *   ---   *   ---
# prepend string with ansi color escapes
#
# [0]: byte ptr ; string
# [1]: byte ptr ; color id (defaults to off)
#
# [<]: byte ptr ; new string
#
# [*]: when (string || id) == null,
#      it just turns off previous color

sub m {
  my $tab={
    op     => "\e[0;37;1m",
    num    => "\e[0;33;22m",
    warn   => "\e[0;33;1m",
    good   => "\e[0;34;22m",
    err    => "\e[0;31;22m",
    ctl    => "\e[0;35;1m",
    update => "\e[0;32;1m",
    ex     => "\e[0;36;1m",
    off    => "\e[0m",
  };

  return $tab->{off} if is_null($_[0]);


  # ^fetch and set
  $_[1]//='off';
  my $color=(exists $tab->{$_[1]})
    ? $tab->{$_[1]}
    : $tab->{off}
    ;

  return "$color$_[0]";
};


# ---   *   ---   *   ---
# ^same, wraps

sub mwrap {
  return &m(@_) . &m();
};


# ---   *   ---   *   ---
#
# [0]: byte ptr ; string (defaults to stirr null)
# [1]: byte ptr ; color id (defaults to off)
#
# [<]: byte ptr ; new string

sub mop {
  my ($s,$id)=@_;
  return null if is_null($s);

  my $re_str  = '\s_[:alnum:]';
  my $nopr_re = qr{([$re_str]+)};
  my $opr_re  = qr{([^$re_str]+)};
  my @path    = fgsplit($s,qr{$nopr_re|$opr_re});

  for(@path) {
    if($ARG=~ $opr_re) {
      $ARG=&m($ARG,'op');

    } else {
      $ARG=&m($ARG,$id);
    };
  };
  return cat(@path,&m());
};


# ---   *   ---   *   ---
# wraps word in <braces> with colors
#
# [0]: byte ptr ; string (defaults to stirr null)
# [1]: byte ptr ; color id (defaults to good)
#
# [<]: byte ptr ; new string

sub mtag {
  $_[0]//='null';
  $_[1]//='good';

  return &mop("<$_[0]>",$_[1]);
};


# ---   *   ---   *   ---
# remove ansi escapes from string
#
# [0]: byte ptr ; string
# [<]: bool     ; string is not null
#
# [!]: overwrites input string

sub descape {
  return 0 if is_null $_[0];
  my $re=escape_re;

  $_[0]=~ s[$re][]sxgm;
  return ! is_null $_[0];
};


# ---   *   ---   *   ---
# ^undoable; gets [escape=>position]
#
# [0]: byte ptr ; string
# [<]: mem  ptr ; new [esc=>pos] array
#
# [!]: overwrites input string
# [*]: liswrap for recaptsu

sub popscape {
  return recaptsu $_[0],escape_re;
};


# ---   *   ---   *   ---
# ^undo
#
# [0]: byte ptr ; string
# [1]: mem  ptr ; [esc=>pos] array
#
# [<]: nihil ; decaptsu gives nothing
#
# [!]: overwrites input string
# [*]: liswrap for decaptsu

sub pushscape {
  return decaptsu @_;
};


# ---   *   ---   *   ---
# ^get length of ansi escapes in str
#
# [0]: byte ptr ; string
# [<]: word     ; length

sub lenscape {
  my $re=escape_re;
     $re=qr{($re)};

  my @ar=fgsplit($_[0],$re);
  return sum(map {length $ARG} @ar);
};


# ---   *   ---   *   ---
1; # ret
