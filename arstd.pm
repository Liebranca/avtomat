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

  use Scalar::Util qw(blessed);

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/';
  use style;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# global state

my $CACHE={

  -TEST=>{},

};

# ---   *   ---   *   ---

sub valid($obj) {
  my $kind=(caller)[0];
  return blessed($obj) && $obj->isa($kind);

};

# ---   *   ---   *   ---

sub expand_path($src,$dst) {

  my @ar;
  if(length ref $src) {@ar=(@{$src})}
  else {@ar=($src)};

  while(@ar) {
    my $path=shift @ar;
    if(-f $path) {unshift @$dst,$path;next};

    my @tmp=split m/\s+/,`ls $path`;

    unshift @$dst,(map {$path.q{/}.$ARG} @tmp);

  };

};

# ---   *   ---   *   ---
# wraps word in tags with cute colors

sub pretty_tag($s) {
  return sprintf
    "\e[37;1m<\e[0m".
    "\e[34;22m%s\e[0m".
    "\e[37;1m>\e[0m",$s

  ;

};

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

sub fstrout($format,$tab,%opt) {

  # opt defaults
  $opt{args}//=[];
  $opt{errout}//=0;
  $opt{pre_fmat}//=NULLSTR;
  $opt{post_fmat}//=NULLSTR;
  $opt{endtab}//=NULLSTR;

# ---   *   ---   *   ---
# apply tab to format

  my @format_lines=split m/\n/,$format;
  map {$_="$tab$_$opt{endtab}\n"} @format_lines;

# ---   *   ---   *   ---
# select filehandle

  my $FH=($opt{errout}) ? *STDERR : *STDOUT;

# ---   *   ---   *   ---
# spit it out

  printf {$FH}

    $opt{pre_fmat}.
    (join NULLSTR,@format_lines).
    $opt{post_fmat},

    @{$opt{args}};

  return;

};

# ---   *   ---   *   ---
# comparison table because Test is weird

use constant CMPTAB=>{

  'eq'=>sub($a,$b) {
    $$a//=NULLSTR;
    $$b//=NULLSTR;

    return $$a eq $$b;

  },

};

# ---   *   ---   *   ---

sub unit_test_start($name) {

  $CACHE->{-TEST}->{current}

  =

  $CACHE->{-TEST}->{$name}

  ={

    id=>$name,

    passed=>0,
    total=>0,

  };

# ---   *   ---   *   ---

  my $tab="\e[37;1m\::\e[0m";

  my $format=
    "Test unit ".
    "\e[36;1m'%s'\e[0m"

  ;

  fstrout(
    $format,$tab,

    args=>[$name],
    pre_fmat=>"\n",
    post_fmat=>"\n",

  );

  return;

};

# ---   *   ---   *   ---

sub unit_test_passed() {

  my $t=$CACHE->{-TEST}->{current};

  my $tab="\e[37;1m\::\e[0m";
  my $status=NULLSTR;

  my $format=

    "\e[33;22m%i\e[0m".
    "\e[37;1m/\e[0m".
    "\e[33;22m%i\e[0m ".

    "checks passed\n".

    "Status: %s"

  ;

# ---   *   ---   *   ---

  if($t->{passed} != $t->{total}) {
    $status="\e[31;22mFAILURE\e[0m";

  } else {
    $status="\e[32;22mSUCCESS\e[0m";

  };

# ---   *   ---   *   ---
# spit out results to log

  fstrout(
    $format,$tab,

    args=>[$t->{passed},$t->{total},$status],
    pre_fmat=>"\n",
    post_fmat=>"\n",

  );

  $CACHE->{-TEST}->{current}=undef;
  return $t->{passed} == $t->{total};

};

# ---   *   ---   *   ---
# report check results

sub test($cmp,$a,$b,%opt) {

  # opt defaults
  $opt{name}//='unnamed';

# ---   *   ---   *   ---

  my $tab=sprintf
    "\e[37;1m<\e[0m".
    "\e[34;22m%s\e[0m".
    "\e[37;1m>\e[0m ",

    'test',

  ;

  my $endtab=sprintf

    "\e[37;1m(\e[0m".

    "\e[34;22m%s\e[0m".
    "\e[37;1m::\e[0m".
    "\e[33;22m%s\e[0m".

    "\e[37;1m)\e[0m",

    (caller)[1],(caller)[2]

  ;

# ---   *   ---   *   ---

  # placeholders
  my $format="%-21s %-2s ";
  my $status=NULLSTR;

  # used to recolor the format
  my $cfn=undef;

# ---   *   ---   *   ---
# failure

  if(!CMPTAB->{$cmp}->(\$a,\$b)) {
    $status='NO';
    $cfn=sub($f) {return "\e[31;22m$f\e[0m"};

# ---   *   ---   *   ---
# success

  } else {
    $status='OK';
    $cfn=sub($f) {return "\e[32;22m$f\e[0m"};

  };

# ---   *   ---   *   ---

  $CACHE->{-TEST}->{current}->{passed}

  +=

  int($status eq 'OK')

  ;

  $CACHE->{-TEST}->{current}->{total}+=1;

# ---   *   ---   *   ---

  fstrout(
    $format,$tab,
    args=>[$opt{name},$cfn->($status)],

    endtab=>$endtab,

  );

  return;

};

# ---   *   ---   *   ---
# error prints

sub errout($format,%opt) {

  # opt defaults
  $opt{args}//=[];
  $opt{calls}//=[];
  $opt{lvl}//=WARNING;

# ---   *   ---   *   ---
# print initial message

  my $tab="$opt{lvl}#:!;>\e[0m ";

  fstrout(
    $format,$tab,
    args=>$opt{args},
    errout=>1,
    pre_fmat=>"\n",

  );


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


  my $mess=longmess();

  $mess=join "\n",
    map {fmat_btrace}
    split m/\n/,$mess;

  my $header=sprintf
    "$tab\e[33;1mBACKTRACE\e[0m\n\n".
    "%-21s%-21s%-12s\n",

    'Module',
    'File',
    'Line'

  ;

  print {*STDERR}
    "$header\n$mess\n\n";

# ---   *   ---   *   ---
# quit on fatal error that doesn't happen
# during testing

  if(

     $opt{lvl} eq FATAL
  && !defined $CACHE->{-TEST}->{current}

  ) {

    exit;

  } else {
    return;

  };

};

# ---   *   ---   *   ---
1; # ret
