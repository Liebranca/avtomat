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
package Arstd;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Carp qw(croak longmess);
  use Cwd qw(abs_path);

  use File::Spec;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.02.1;
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

sub building() {return exists $INC{'MAM.pm'}};

# ---   *   ---   *   ---
# mute stderr

sub errmute {

  my $fh=readlink "/proc/self/fd/2";
  open STDERR,'>',
    File::Spec->devnull()

  # you guys kidding me
  or croak strerr('/dev/null')

  ;

  return $fh;

};

# ---   *   ---   *   ---
# ^restore

sub erropen($fh) {
  open STDERR,'>',$fh
  or croak strerr($fh);

};

# ---   *   ---   *   ---
# in: filepath
# get name of file without the path

sub basename($path) {
  my @names=split m[/],$path;
  return $names[$#names];

};

# ^ removes extension(s)
sub nxbasename($path) {
  my $name=basename($path);
  $name=~ s/\..*$//;

  return $name;

};

# ^ get dir of filename...
# or directory's parent

sub dirof($path) {

  my @names=split(m[/],$path);
  $path=join('/',@names[0..($#names)-1]);

  return abs_path($path);

};

# ^ oh yes
sub parof($path) {
  return dirof(dirof($path));

};

# ---   *   ---   *   ---
# reverse of basename;
# gives first name in path

sub basedir($path) {
  my @names=split '/',$path;
  return $names[0];

};

# ---   *   ---   *   ---

sub relto($par,$to) {
  my $full="$par$to";
  return File::Spec->abs2rel($full,$par);

};

# ---   *   ---   *   ---
# find hashkeys in list
# returns matches ;>

sub lfind($search,$l) {
  return [grep {exists $search->{$ARG}} @$l];

};

# ---   *   ---   *   ---

sub invert_hash($h,%O) {

  # defaults
  $O{duplicate}//=0;

# ---   *   ---   *   ---

  if($O{duplicate}) {
    %$h=(%$h,reverse %$h);

  } else {
    %$h=reverse %$h;

  };

  return $h;

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
    lvl=>$AR_FATAL,

  );

};

# ---   *   ---   *   ---
# open,read,close

sub orc($fname) {

  open my $FH,'<',$fname
  or croak strerr($fname);

  read $FH,my $body,-s $FH;

  close $FH
  or croak strerr($fname);

  return $body;

};

# ---   *   ---   *   ---
# ^open,write,close

sub owc($fname,$bytes) {

  open my $FH,'+>',$fname
  or croak strerr($fname);

  my $wr=print {$FH} $bytes;

  close $FH
  or croak strerr($fname);

  return $wr*length $bytes;

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
# get terminal dimentions

sub ttysz_yx() {
  return (split qr{\s},`stty size`)

};

sub ttysz_xy() {
  return (reverse split qr{\s},`stty size`)

};

# ---   *   ---   *   ---
# split string at X characters

sub linewrap($sref,$sz_x,%opt) {

  state $re=qr{

    [^\n]{1,$sz_x}(?: [\s\n]|$)

  }x;

  # defaults
  $opt{add_newlines}//=1;

  if($opt{add_newlines}) {
    $$sref=~ s/($re)/$1\n/gsx;

  } else {
    $$sref=~ s/($re)/$1/gsx;

  };

};

# ---   *   ---   *   ---
# give back copy of string without ANSI escapes

sub descape($s) {

  state $escape="\e[";
  $s=~ s/$escape[\d;]+[\w\?]//;

  return $s;

};

# ---   *   ---   *   ---
# format string and output

sub fstrout($format,$tab,%opt) {

  # opt defaults
  $opt{args}//=[];
  $opt{errout}//=0;
  $opt{no_print}//=0;
  $opt{pre_fmat}//=$NULLSTR;
  $opt{post_fmat}//=$NULLSTR;
  $opt{endtab}//=$NULLSTR;

# ---   *   ---   *   ---
# dirty linewrap

  my @ttysz=ttysz_yx();
  $format=sprintf $format,@{$opt{args}};

  # get length without escapes
  my $desc_tab=descape($tab);
  my $tab_len=length $desc_tab;
  my $sz_x=$ttysz[1]-$tab_len-1;

  # use real length to wrap
  linewrap(\$format,$sz_x);

# ---   *   ---   *   ---
# apply tab to format

  my @format_lines=split m/\n/,$format;
  map {$ARG="$tab$_$opt{endtab}\n"} @format_lines;

# ---   *   ---   *   ---
# select filehandle

  my $FH=($opt{errout}) ? *STDERR : *STDOUT;

# ---   *   ---   *   ---
# spit it out

  my $out;

  if($opt{no_print}) {
    $out=
      $opt{pre_fmat}.
      (join $NULLSTR,@format_lines).
      $opt{post_fmat};

  } else {
    $out=print {$FH}

      $opt{pre_fmat},
      (join $NULLSTR,@format_lines),
      $opt{post_fmat},

    ;

  };

  return $out;

};

# ---   *   ---   *   ---
# box-format string and output

sub box_fstrout($format,%opt) {

  # opt defaults
  $opt{args}//=[];
  $opt{errout}//=0;
  $opt{no_print}//=0;
  $opt{pre_fmat}//=$NULLSTR;
  $opt{post_fmat}//=$NULLSTR;
  $opt{fill}//=q{*};

# ---   *   ---   *   ---
# dirty linewrap

  my $c=$opt{fill};

  my @ttysz=ttysz_yx();
  $format=sprintf $format,@{$opt{args}};

  # get length without escapes
  my $desc_c=descape($c);
  my $c_len=length $desc_c;
  my $sz_x=$ttysz[1]-($c_len*2)-3;

  # use real length to wrap
  linewrap(\$format,$sz_x,add_newlines=>0);

# ---   *   ---   *   ---
# box in the format

  my @format_lines=split m/\n/,$format;

  map

    {$ARG=sprintf "$c %-${sz_x}s $c\n",$ARG}
    @format_lines

  ;

  unshift @format_lines,
    ($c x ($ttysz[1]-1))."\n",
    sprintf "$c %-${sz_x}s $c\n",$NULLSTR;

  push @format_lines,
    (sprintf "$c %-${sz_x}s $c\n",$NULLSTR),
    ($c x ($ttysz[1]-1))."\n";

# ---   *   ---   *   ---
# select filehandle

  my $FH=($opt{errout}) ? *STDERR : *STDOUT;

# ---   *   ---   *   ---
# spit it out

  my $out;

  if($opt{no_print}) {
    $out=
      $opt{pre_fmat}.
      (join $NULLSTR,@format_lines).
      $opt{post_fmat};

  } else {
    $out=print {$FH}

      $opt{pre_fmat},
      (join $NULLSTR,@format_lines),
      $opt{post_fmat},

    ;

  };

  return $out;

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
  $opt{lvl}//=$AR_WARNING;

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

     $opt{lvl} eq $AR_FATAL
  && !defined $CACHE->{test}->{current}

  ) {

    exit;

  } else {
    return;

  };

};

# ---   *   ---   *   ---
1; # ret
