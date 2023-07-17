#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD IO
# Reading and writting;
# formatting and printing
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Arstd::IO;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp qw(croak longmess);
  use Readonly;

  use English qw(-no_match_vars);

  use File::Spec;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::String;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    fstrout
    box_fstrout

    errmute
    erropen

    errout
    nyi

    orc
    dorc

    owc

    csume
    rtate

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.3;#a
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $FMAT_SIZE=>{

    'Q' => 8, 'L' => 4,
    'q' => 8, 'l' => 4,

    'S' => 2, 'C' => 1,
    's' => 2, 'c' => 1,

    'V' => 4, 'A' => 1,
    'v' => 2, 'a' => 1,

    'f' => 4,

  };

  Readonly our $FMAT_RE=>qr{
    (?<type> [aAvVqQlLsScCf])
    (?<cnt>  \d*)

  }x;

# ---   *   ---   *   ---
# GBL

  our $Testing=0;

# ---   *   ---   *   ---
# get terminal dimentions

sub ttysz_yx() {
  return (split qr{\s},`stty size`);

};

sub ttysz_xy() {
  return (reverse split qr{\s},`stty size`);

};

# ---   *   ---   *   ---
# mute stderr

sub errmute() {

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
  my $desc_tab=Arstd::String::descape($tab);
  my $tab_len=length $desc_tab;
  my $sz_x=$ttysz[1]-$tab_len-1;

  # use real length to wrap
  Arstd::String::linewrap(\$format,$sz_x);

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
  my $desc_c=Arstd::String::descape($c);
  my $c_len=length $desc_c;
  my $sz_x=$ttysz[1]-($c_len*2)-3;

  # use real length to wrap
  Arstd::String::linewrap(
    \$format,$sz_x,add_newlines=>1

  );

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
# open,read,close

sub orc($fname) {

  open my $FH,'<',$fname
  or errout(strerr($fname),lvl=>$AR_FATAL);

  read $FH,my $body,-s $FH;

  close $FH
  or croak strerr($fname);

  return $body;

};

# ---   *   ---   *   ---
# directory open,read,close

sub dorc($path,$excluded=$NO_MATCH) {

  my @out=();
  goto TAIL if ! -d $path;

  opendir my $dir,$path
  or errout(strerr($path),lvl=>$AR_FATAL);

  @out=grep {
    !($ARG=~ $excluded)

  } readdir $dir;

  closedir $dir
  or croak strerr($path);

TAIL:
  return @out;

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
# get pack/unpack format
# element width in bytes

sub fmat_size($fmat) {

  my $out=0;

  while($fmat=~ s[$FMAT_RE][]) {

    my $type = $+{type};
    my $cnt  = (! length $+{cnt})
      ? 1
      : $+{cnt}
      ;

    my $sz   = $FMAT_SIZE->{$type};

    $out+=$sz*$cnt;

  };

  return $out;

};

# ---   *   ---   *   ---
# consume
#
# cut bytes from string
# push to array

sub csume($sref,$dst,@fmat) {

  map {
    push @$dst,unpack $ARG,$$sref;
    $$sref=substr $$sref,fmat_size($ARG);

  } @fmat;

};

# ---   *   ---   *   ---
# ^iv, regurgitate
#
# cat bytes to string
# pop from array

sub rtate($sref,$values,@fmat) {

  map {
    $$sref.=pack $ARG,(shift @$values);

  } @fmat;

};

# ---   *   ---   *   ---

sub nyi($errme) {

  errout(
    "Not yet implemented: $errme\n",
    lvl=>$AR_FATAL,

  );

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
  && !$Testing

  ) {

    exit;

  } else {
    return;

  };

};

# ---   *   ---   *   ---
1; # ret
