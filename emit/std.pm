#!/usr/bin/perl
# ---   *   ---   *   ---
# EMIT STD
# common code output tools
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb
# ---   *   ---   *   ---

# deps
package emit::std;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use Storable;

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;
  use shb7;

# ---   *   ---   *   ---
# ROM

  Readonly our $ARTAG=>arstd::pretty_tag('AR');
  Readonly our $ARSEP=>"\e[37;1m::\e[0m";

  Readonly our $ON_NO_AUTHOR=>'ANON-DEV';

  Readonly my $BOXCHAR=>'.';

# ---   *   ---   *   ---
# generates a notice on top of generated files

sub note($author,$ch) {

  my $t=`date +%Y`;chomp $t;

# ---   *   ---   *   ---


  my $note=<<"EOF"
$ch ---   *   ---   *   ---
$ch LIBRE BOILERPASTE
$ch GENERATED BY AR/AVTOMAT
$ch
$ch LICENSED UNDER GNU GPL3
$ch BE A BRO AND INHERIT
$ch
$ch COPYLEFT $author $t
$ch ---   *   ---   *   ---
EOF


# ---   *   ---   *   ---

; return $note;

};

# ---   *   ---   *   ---
# generates program info

sub version($name,$version,$author) {

  my $l1=$name.q{ v}.$version;
  my $l2='Copyleft '.$author.q{ }.`date +%Y`;
  my $l3='Licensed under GNU GPL3';

  chomp $l2;

# ---   *   ---   *   ---

  return arstd::box_fstrout(

    "$l1\n\n$l2\n$l3",

    fill=>$BOXCHAR,
    no_print=>1,

  );

};

# ---   *   ---   *   ---
# in: path to add to PATH, names to include
# returns a perl snippet as a string to be eval'd

sub reqin($path,@names) {

  my $s='push @INC,'."$path;\n";

  for my $name(@names) {
    $s.="require $name;\n";

  };

  return $s;

};

# ---   *   ---   *   ---
1; # ret
