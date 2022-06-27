#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD
# Protos used often
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package arstd;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use Carp qw(longmess);

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/';
  use style;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# fixes the horrendous 8-space indented,
# non line-wrapped, filename redundant,
# needlessly wide Carp backtrace

sub fmat_btrace {

  $ARG=~ s/line (\d+)//;
  my $line=${^CAPTURE[0]};
  $line="\e[33;22m$line\e[0m";

# ---   *   ---   *   ---
# isolate the file path

  my $bs=q{[/]};

  $ARG=~ s/.+called at //;
  $ARG=~ s{

    .+${bs}

    (\w+${bs}\w+[.]\w+)

    \s*[.]?

  } {:__CUT__:}x;

  my $path=${^CAPTURE[0]};
  if(defined $path) {
    $ARG=~ s/:__CUT__:.*/$path/;

  };

  my ($dir,$file)=split m{/},$ARG;

# ---   *   ---   *   ---
# add some colors c:

  my $s=sprintf
    "\e[35;1m%-21s\e[0m".
    "\e[34;22m%-21s\e[0m".
    '%-12s',

    $dir,
    $file,
    $line

  ;

  return $s;

};

# ---   *   ---   *   ---
# error prints

sub errout($format,%opt) {

  # opt defaults
  $opt{args}//=[];
  $opt{calls}//=[];
  $opt{lvl}//=WARNING;

# ---   *   ---   *   ---
# get args

  my @args=@{$opt{args}};

  printf {*STDERR}
    "\n$opt{lvl}#:!;> $format\e[0m",
    @{$opt{args}};

# ---   *   ---   *   ---
# exec calls

  my @calls=@{$opt{calls}};

  while(@calls) {
    my $call=shift @calls;
    my $args=shift @calls;

    $call->(@$args);

  };

# ---   *   ---   *   ---
# handle program exit

  if($opt{lvl} eq FATAL) {
    my $mess=longmess();

    $mess=join "\n",
      map {fmat_btrace}
      split m/\n/,$mess;

    my $header=sprintf
      "\e[31;1m#:!;> BACKTRACE\e[0m\n\n".
      "%-21s%-21s%-12s\n",

      'Module',
      'File',
      'Line'

    ;

    print {*STDERR}
      "$header\n$mess\n\n";

    exit;

  } else {
    return;

  };

};

# ---   *   ---   *   ---
1; # ret
