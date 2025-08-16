#!/usr/bin/perl
# ---   *   ---   *   ---
# CMAM
# whatever MAM does...
# but better ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package CMAM;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_file);
  use Arstd::String qw(to_char has_prefix);
  use Arstd::Bin qw(ot moo orc owc);
  use Arstd::Path qw(extwap extof);
  use Arstd::throw;

  use lib "$ENV{ARPATH}/lib/";
  use CMAM::static;
  use CMAM::parse qw(blkparse);
  use CMAM::macro;
  use CMAM::sandbox;
  use CMAM::emit;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw();


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.7a';
  our $AUTHOR  = 'IBN-3DILA';

  sub errsafe {return 1};


# ---   *   ---   *   ---
# entry point

sub run {
  restart();

  my $O    = {c=>0,h=>0,l=>0,g=>0};
  my @file = grep {
    rdargv($O,$ARG)

  # expand asterisks, dots and tildes...
  } map {
    (! has_prefix($ARG,'-'))
      ? (glob($ARG))
      : ($ARG)
      ;

  } @ARGV;


  take(@file);
  if($O->{h}) {
    mkhed($ARG) for @file;
  };

  check($O,@file);

  return;
};


# ---   *   ---   *   ---
# reads switches
#
# [0]: mem ptr  ; state hashref
# [1]: byte ptr ; argument
#
# [<]: bool ; true if not a switch

sub rdargv {
  my $re=qr{^\-(.+)};
  return 1 if ! ($_[1]=~ $re);

  # allow for multiple switches to be
  # included in the same item
  #
  # order not important; -hcl == -chl == -lch
  my $key=$1;
  map {
    throw "Unrecognized switch '$ARG'"
    if ! exists $_[0]->{$ARG};

    $_[0]->{$ARG}=1;

  } to_char $key;

  return 0;
};


# ---   *   ---   *   ---
# validate input
#
# [0]: byte pptr ; file list

sub take {
  throw "No files to syntax-check" if ! @_;
  for(@_) {
    throw "Invalid file: '$ARG'"
    if ! is_file $ARG;

  };

  return;
};


# ---   *   ---   *   ---
# generates header file
#
# [0]: byte ptr ; filename

sub mkhed {

#  # first off, we check whether making a
#  # header is actually necessary
#  #
#  # if a header was passed, that's already a 'no'
#  return if 'h' eq extof $_[0];
#
#  # ^second check is whether a header was already
#  # ^generated for this source file
  my $dst="$_[0]";
  extwap $dst,'h';
#
#  # if the header is missing, or the source has
#  # been updated, then we want to regenerate it
#  #
#  # else we stop here
#  return if ! moo($dst,$_[0]);
#  say "  making header $dst";


  # patterns used
  my $typedef_re = qr{\n\s*typedef\s+};
  my $public_re  = qr{\n\s*public\s+};

  # these keywords tell us that we want to
  # include the block in the resulting header!
  my $blk_except_re=qr{(?:
    struct|const|enum|CX|static

  )\s+}x;

  my $blk_inline_re=qr{(?:
    inline|IX|CIX

  )\s+}x;


  # read file and pass through block parser
  my $body=orc $_[0];
  blkparse($body);

  # dbout
  use Arstd::String qw(gsplit);
  $body=join "\n",gsplit($body,qr"\n");
  say "\n________\n\n",$body,"\n________\n";
  CMAM::emit::pm();

  exit;
  return;
};


# ---   *   ---   *   ---
# get guard name for file
#
# [0]: byte ptr ; filename
# [<]: byte ptr ; guard name (new string)

sub guardof {
  my $re  = qr{[\./]};
  my $out = "$_[0]";
  extwap $out,'h';

  $out=uc $out;
  $out=~ s[$re][_]smg;

  return "__${out}__";
};


# ---   *   ---   *   ---
# get line to summon gcc with
#
# [0]: mem  ptr ; switches
# [<]: byte ptr ; new string with command
#
# [*]: const

sub gcc {
  my $out='gcc -I./ -fpermissive -w';

  $out .= ' -fsyntax-only' if ! $_[0]->{c};
  $out .= ' -g' if ! $_[0]->{g};

  return $out;
};


# ---   *   ---   *   ---
# pass file through gcc
#
# [0]: mem ptr   ; switches
# [1]: byte pptr ; file list

sub check {
  my $O   = shift;
  my $gcc = gcc $O;

  # compile and/or link?
  if($O->{c} || $O->{l}) {
    if($O->{c}) {
      for(@_) {
        my $dst="$ARG";
        extwap $dst,'o';
        say "  $dst";
        my $out=`$gcc -O3 -c $ARG -o $dst`;
        throw $out if ! is_null $out;
      };
    };

    if($O->{l}) {
      my $obj=join ' ',map  {
        my $dst="$ARG";
        extwap $dst,'o';

        $dst;

      } @_;

      my $out=`gcc $obj -o ./a.out`;
      throw $out if ! is_null $out;
    };

    return;
  };

  # ^just checking syntax!
  for(@_) {
    my $out=`$gcc $ARG`;
    throw $out if ! is_null $out;
  };

  return;
};


# ---   *   ---   *   ---
# triggers reset of global state,
# then sets symbol table to builtins only

sub restart {
  CMAM::static::restart();
  my $tab=CMAM::static::cmamdef();

  $tab->{package} = \&CMAM::macro::setpkg;
  $tab->{use}     = \&CMAM::sandbox::usepkg;
  $tab->{macro}   = \&CMAM::macro::macro;

  return;
};


# ---   *   ---   *   ---
# all together now!

run;


# ---   *   ---   *   ---
1; # ret
