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
package Emit::Std;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use Storable;

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::String;
  use Arstd::Path;
  use Arstd::IO;

  use Shb7;

# ---   *   ---   *   ---
# ROM

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

  return box_fstrout(

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

sub outf($emitter,$f,%O) {

  my $path=Shb7::file($f);
  my $pkg=caller;

  $O{author}//=eval(q{$}.$pkg.q{::AUTHOR});

  open my $FH,'+>',$path
  or croak strerr($path);

  $emitter=q{Emit::}.$emitter;

  print {$FH} $emitter->codewrap(
    nxbasef($f),%O

  );

  close $FH or croak strerr($path);

};

# ---   *   ---   *   ---
1; # ret
