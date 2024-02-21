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
  use Fmat;

  use Arstd::String;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    ioprocin
    ioprocout

    fstrout
    box_fstrout

    errmute
    erropen

    errme
    errout
    errcaller
    nyi

    orc
    dorc

    owc

    csume
    rtate

  );

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.7;
  our $AUTHOR  = 'IBN-3DILA';

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
# sets default options
# for an I/O F

sub ioprocin($O) {

  my @bufio=();

  $O->{errout} //= 0;
  $O->{mute}   //= 0;
  $O->{-bufio} //= \@bufio;


  return $O->{-bufio};

};

# ---   *   ---   *   ---
# ^handles output!

sub ioprocout($O) {

  # cat buf
  my $out=join $NULLSTR,@{$O->{-bufio}};

  # write to tty?
  if(! $O->{mute}) {

    # select fto
    my $fh=($O->{errout})
      ? *STDERR
      : *STDOUT
      ;

    return say {$fh} $out;


  # ^nope, just give string
  } else {
    return $out;

  };

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

sub fstrout($fmat,$tab,%O) {

  # defaults
  $O{args}      //= [];

  $O{errout}    //= 0;
  $O{no_print}  //= 0;

  $O{pre_fmat}  //= $NULLSTR;
  $O{post_fmat} //= $NULLSTR;
  $O{endtab}    //= $NULLSTR;
  $O{nopad}     //= 0;

  my $out=$NULLSTR;

  # mark undefined
  map {$ARG //= '<null>'} @{$O{args}};


  # get line length
  my @ttysz    = ttysz_yx();
  my $desc_tab = Arstd::String::descape($tab);
  my $tab_len  = length $desc_tab;
  my $llen     = $ttysz[1]-$tab_len-1;

  # ^apply format
  my @lines=
    _fstrout_wrap($fmat,$llen,$O{args});

  map {
    $ARG="$tab$_$O{endtab}\n"

  } @lines;

  pop @lines if $O{nopad};

  # get final string
  $out=

    $O{pre_fmat}
  . (join $NULLSTR,@lines)

  . $O{post_fmat}
  ;


  # ^printing requested
  if(! $O{no_print}) {

    # select and spit
    my $fh=($O{errout})
      ? *STDERR
      : *STDOUT
      ;

    $out=print {$fh} $out;

  };

  return $out;

};

# ---   *   ---   *   ---
# applies linewrapping
# to a format string
#
# guts v

sub _fstrout_wrap($fmat,$len,$args) {

  # expand args
  my @args=Arstd::String::sansi(@$args);

  $fmat=
    sprintf Arstd::String::fsansi($fmat),@args;

  # ^use real length to wrap
  my @escapes=Arstd::String::popscape(\$fmat);
  Arstd::String::linewrap(\$fmat,$len);

  # ^then re-insert escapes!
  Arstd::String::pushscape(\$fmat,@escapes);

  # apply tab to format
  my @out=(
    (split $NEWLINE_RE,$fmat),
    $NULLSTR

  );

  return @out;

};

# ---   *   ---   *   ---
# box-format string and output

sub box_fstrout($fmat,%O) {

  # opt defaults
  $O{args}      //= [];

  $O{errout}    //= 0;
  $O{no_print}  //= 0;

  $O{pre_fmat}  //= $NULLSTR;
  $O{post_fmat} //= $NULLSTR;

  $O{fill}      //= q{*};

  my $out=$NULLSTR;

  # dirty linewrap
  my $c     = $O{fill};
  my @ttysz = ttysz_yx();

  # get length without escapes
  my $desc_c = Arstd::String::descape($c);
  my $c_len  = length $desc_c;
  my $llen   = $ttysz[1]-($c_len*2)-3;

  # ^apply format
  my @lines=
    _fstrout_wrap($fmat,$llen,$O{args});

  # ^box it in
  map {
    $ARG=sprintf "$c %-${llen}s $c\n",$ARG

  } @lines;

  # get final string
  unshift @lines,
    ($c x ($ttysz[1]-1))."\n",
    sprintf "$c %-${llen}s $c\n",$NULLSTR;

  push @lines,
    (sprintf "$c %-${llen}s $c\n",$NULLSTR),
    ($c x ($ttysz[1]-1))."\n";

  $out=

    $O{pre_fmat}
  . (join $NULLSTR,@lines)

  . $O{post_fmat}
  ;

  # ^printing requested
  if(! $O{no_print}) {

    # select and spit
    my $fh=($O{errout})
      ? *STDERR
      : *STDOUT
      ;

    $out=print {$fh} $out;

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
    ! (-d "$dir/$ARG/")
  &&! ($ARG=~ $excluded);

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
# short for "not yet implemented"
#
# the lazy way: halt execution
# and spit notice at placeholders

sub nyi($errme,$src=undef) {

  state $tab=
    Arstd::String::ansim('NYI:','err');

  $src //= (caller 1)[3];

  errout(

    "%s '%s' at <%s>\n",

    lvl  => $AR_FATAL,
    args => [$tab,$errme,$src],

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


  # add some colors c:
  $file //= '(%$)';

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

sub errme($format,%O) {

  my $tab="$O{lvl}#:!;>\e[0m ";

  fstrout(

    $format,
    $tab,

    %O,errout=>1,

  );

  return $tab;

};

# ---   *   ---   *   ---
# ^coupled with backtrace
# plus exit on fatal

sub errout($format,%O) {

  # defaults
  $O{args}  //= [];
  $O{calls} //= [];
  $O{lvl}   //= $AR_WARNING;
  $O{back}  //= 1;

  # print initial message
  my $tab=errme($format,%O);

  # exec calls
  my @calls=@{$O{calls}};

  while(@calls) {
    my $call=shift @calls;
    my $args=shift @calls;

    $call->(@$args);

  };


  # give backtrace?
  if($O{back}) {

    my $mess = longmess();

    $mess=join "\n", map {
      fmat_btrace

    } split $NEWLINE_RE,$mess;

    my $header=sprintf
      "$tab\e[33;1mBACKTRACE\e[0m\n\n".
      "%-21s%-21s%-12s\n",

      'Module',
      'File',
      'Line'

    ;

    print {*STDERR} "$header\n$mess\n\n";

  };


  # quit on fatal error that doesn't happen
  # during testing
  if(

     $O{lvl} eq $AR_FATAL
  && !$Testing

  ) {

    exit;

  } else {
    return;

  };

};

# ---   *   ---   *   ---
# ^gives caller info

sub errcaller(%O) {

  # defaults
  $O{depth}   //= 3;
  $O{fatdump} //= 0;
  $O{lvl}     //= $AR_FATAL;


  # get caller info
  my (@call) = (caller $O{depth});

  my $pkg    = $call[0];
  my $line   = $call[2];

  my $fn     = (! defined $call[3])
    ? '(non)'
    : $call[3]
    ;


  # ^prepare message
  my @text=(
    q[[ctl]:%s on [err]:%s, ]
  . q[[goodtag]:%s at line (:%u)] . "\n\n"

  );

  my @args=('IRUPT',$fn,$pkg,$line);


  # optionally provide an objdump
  if($O{fatdump}) {
    push @text,q[[warn]:%s];
    push @args,"FATDUMP";

  };


  # ^spit it out
  errme(

    (join $NULLSTR,@text),

    lvl   => $O{lvl},
    args  => \@args,

    nopad => 1,

  );

  say $NULLSTR;

  Fmat::fatdump(\$O{fatdump},errout=>1)
  if $O{fatdump};

};

# ---   *   ---   *   ---
1; # ret
