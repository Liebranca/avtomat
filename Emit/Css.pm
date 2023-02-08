#!/usr/bin/perl
# ---   *   ---   *   ---
# EMIT CSS
# Utils for printing
# style sheets
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Emit::Css;

  use v5.36.0;
  use strict;
  use warnings;

  use version;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Array;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Emit::Std;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# scope {} shorthands

sub isert_class($c) {
  return "$c {\n";

};

sub isert_break($brk,$limit=0) {

  my $type=(!$limit)
      ? 'max-width'
      : 'min-width'
      ;

  return '@media only screen and '.
    "($type: ${brk}px) {\n\n";

};

sub isert_close($n=0) {
  return "\n".(q[  ] x $n)."}\n\n";

};

# ---   *   ---   *   ---
# ^puts values inside

sub isert_props(@data) {

  my $out    = $NULLSTR;

  my @keys   = array_keys(\@data);
  my @values = array_values(\@data);

  # walk the props
  my $i=0;
  for my $key(@keys) {

    # shift on array (see: by_break)
    my $value=$values[$i++];
    $value=(is_arrayref($value))
      ? (shift @$value)
      : $value
      ;

    $out .= "  $key\: $value;\n";

  };

  return $out;

};

# ---   *   ---   *   ---
# sets properties in order of breakpoints
#
# @data fmat as such:
#
#   say by_break([360,412],
#
#     q[*]=>[
#       q[font-size] => [qw(9px 18px)],
#       q[width]     => [qw(50% 100%)],
#
#     ],
#
#   );
#
# ^sets font-size and width for 360, then 412
# values are shifted from the prop array

sub by_break($brkp,@data) {

  my $out     = $NULLSTR;

  my @classes = array_keys(\@data);
  my @props   = array_values(\@data);

  # walk the breakpoint list
  my $j=0;
  while(@$brkp) {

    # open scope 0
    my $brk  = shift @$brkp;
    $out    .= isert_break($brk,$j++);

    # paste each class for each brk
    my $i=0;
    for my $c(@classes) {

      my $propl=$props[$i++];

      # open scope 1,
      # dump property list
      $out    .= q[  ].isert_class($c);
      my $raw  = isert_props(@$propl);

      # format props
      my $idented=$NULLSTR;
      for my $line(split "\n",$raw) {
        $idented.=q[  ]."$line\n";

      };

      # close level 1
      $out .= $idented;
      $out .= isert_close(1);

    };

    # close level 0
    $out .= isert_close();

  };

  return $out;

};

# ---   *   ---   *   ---
1; # ret
