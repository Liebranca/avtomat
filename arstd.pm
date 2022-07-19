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

  use Readonly;

  use Carp qw(croak longmess);

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

    test=>{},

  };

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    $O_RD
    $O_WR
    $O_EX

    $O_FILE
    $O_STR

  );

# ---   *   ---   *   ---
# ROM

  Readonly our $O_RD  =>0x0004;
  Readonly our $O_WR  =>0x0002;
  Readonly our $O_EX  =>0x0001;

  # just so we don't have to
  # -e(name) && -f(name) every single time
  Readonly our $O_FILE=>0x0008;
  Readonly our $O_STR =>0x0010;

# ---   *   ---   *   ---
# Test:: is weird

  Readonly my $AR_TEST_CMPTAB=>{

    'eq'=>sub($a,$b) {
      $$a//=$NULLSTR;
      $$b//=$NULLSTR;

      return $$a eq $$b;

    },

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

sub arrshf($ar,$idex) {

  my $max=@{$ar}-1;

  while($idex<$max) {
    $ar->[$idex+1]=$ar->[$idex];
    $idex++;

  };

  pop @{$ar};

};

sub arrfil($ar) {

  my $filtered=[];
  for my $x(@$ar) {

    if(defined $x) {
      push @$filtered,$x;

    };

  };

  @$ar=@$filtered;

};

# ---   *   ---   *   ---

sub hashcpy($src) {

  my $cpy={};
  for my $key(keys %$src) {
    $cpy->{$key}=$src->{$key};

  };

  return $cpy;

};

# ---   *   ---   *   ---

sub nyi($errme) {

  errout(
    "Not yet implemented: $errme\n",
    lvl=>$FATAL,

  );

};

# ---   *   ---   *   ---

sub orc($fname) {

  open my $FH,'<',$fname
  or croak STRERR($fname);

  read $FH,my $body,-s $FH;

  close $FH
  or croak STRERR($fname);

  return $body;

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
# does some barebones colorizing

sub color($s) {

  state $escape="\e[";
  state $cut='___C_U_T___';

  state $tag=qr{

    (?<= \xF7<\xDF)
    [^_\s]+
    (?= \xF7>\xDF)

  }x;

  state $num=qr{
    (?: 0x[0-9a-fA-F]+ L?)
  | ([0-9]* \.? [0-9]+ f?)

  }x;

  state $bare=qr{\b[^_\s]+\b}x;
  state $op=qr{(?:[^\s_A-Za-z0-9]|\\\\)}x;

# ---   *   ---   *   ---

  my @ops=();
  while($s=~ s/($op)/$cut/smx) {
    push @ops,$1;

  };

  for my $x(@ops) {
    $s=~ s/$cut/\xF7$x\xDF/;

  };

# ---   *   ---   *   ---

  my @tags=();
  while($s=~ s/($tag)/$cut/smx) {
    push @tags,$1;

  };

  for my $x(@tags) {
    $s=~ s/$cut/\xE4$x\xDF/;

  };

# ---   *   ---   *   ---

  my @bares=();
  while($s=~ s/($bare)/$cut/smx) {
    push @bares,$1;

  };

  for my $x(@bares) {
    $s=~ s/$cut/\xE2$x\xDF/;

  };

# ---   *   ---   *   ---

  my @nums=();
  while($s=~ s/($num)/$cut/smx) {
    push @nums,$1;

  };

  for my $x(@nums) {
    $s=~ s/$cut/\xE3$x\xDF/;

  };

# ---   *   ---   *   ---

  $s=~ s/\xE2/\e[32;22m/sgmx;
  $s=~ s/\xE3/\e[33;22m/sgmx;
  $s=~ s/\xE4/\e[34;22m/sgmx;
  $s=~ s/\xF7/\e[37;1m/sgmx;

  $s=~ s/\xDF/\e[0m/sgmx;

  return $s;

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
  $opt{pre_fmat}//=$NULLSTR;
  $opt{post_fmat}//=$NULLSTR;
  $opt{endtab}//=$NULLSTR;

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
    (join $NULLSTR,@format_lines).
    $opt{post_fmat},

    @{$opt{args}};

  return;

};

# ---   *   ---   *   ---

sub unit_test_start($name) {

  $CACHE->{test}->{current}

  =

  $CACHE->{test}->{$name}

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

  my $t=$CACHE->{test}->{current};

  my $tab="\e[37;1m\::\e[0m";
  my $status=$NULLSTR;

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

  $CACHE->{test}->{current}=undef;
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
  my $status=$NULLSTR;

  # used to recolor the format
  my $cfn=undef;

# ---   *   ---   *   ---
# failure

  if($AR_TEST_CMPTAB->{$cmp}->(\$a,\$b)) {
    $status='NO';
    $cfn=sub($f) {return "\e[31;22m$f\e[0m"};

# ---   *   ---   *   ---
# success

  } else {
    $status='OK';
    $cfn=sub($f) {return "\e[32;22m$f\e[0m"};

  };

# ---   *   ---   *   ---

  $CACHE->{test}->{current}->{passed}

  +=

  int($status eq 'OK')

  ;

  $CACHE->{test}->{current}->{total}+=1;

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
  $opt{lvl}//=$WARNING;

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

     $opt{lvl} eq $FATAL
  && !defined $CACHE->{test}->{current}

  ) {

    exit;

  } else {
    return;

  };

};

# ---   *   ---   *   ---
1; # ret
