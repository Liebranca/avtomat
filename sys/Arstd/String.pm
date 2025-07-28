#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD STRING
# Quick utils
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::String;
  use v5.42.0;
  use strict;
  use warnings;

  use English;
  use List::Util qw(sum);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style;
  use Chk;

  use Arstd::Array;
  use parent 'St';


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    stoi
    hstoi
    ostoi
    bstoi
    sstoi

    descape

    linewrap
    lineident

    ansim
    strtag
    sansi
    fsansi

    sqwrap
    dqwrap

    begswith
    charcon
    nobs

    strip
    gstrip

    deref_clist

    descape
    popscape
    pushscape
    lenscape

    joinfilt

  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.2';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

my $PKG=__PACKAGE__;
St::vconst {

  STRIP_RE  => qr{^\s*|\s*$}x,
  NOBS_RE   => qr{\\(.)}x,

  ESCAPE_RE => qr"\x{1B}\[[\?\d;]+[\w]"x,

  LINEWRAP_PROTO=>q{

  (?<mess>

    [^\n]{1,SZ_X} (?: (?: \n|\s) | $)
  | [^\n]{1,SZ_X} (?: .|$)

  )},

  CHARCON_DEF=>[

    qr{\\n}x   => "\n",
    qr{\\r}x   => "\r",
    qr{\\b}x   => "\b",

    qr{\\}x    => '\\',

    qr{\\e}x   => "\e",

  ],

  COLOR=>{

    op     => "\e[37;1m",
    num    => "\e[33;22m",
    warn   => "\e[33;1m",

    good   => "\e[34;22m",
    err    => "\e[31;22m",

    ctl    => "\e[35;1m",
    update => "\e[32;1m",
    ex     => "\e[36;1m",

    off    => "\e[0m",

  },

  BIN_DIGITS => qr{[\:\.0-1]},
  OCT_DIGITS => qr{[\:\.0-7]},
  DEC_DIGITS => qr{[\:\.0-9]},
  HEX_DIGITS => qr{[\:\.0-9A-F]},

  HEXNUM_RE => sub {
    my $digits=$_[0]->HEX_DIGITS;
    return qr{(?:
      (?:(?:(?:\b0x)|\$)($digits+)(?:[L]?))
    | (?:($digits+)(?:h))

    )\b}x;

  },

  DECNUM_RE => sub {
    my $digits=$_[0]->DEC_DIGITS;
    return qr{\b(?:(?:[v]?)($digits+)(?:[f]?))\b}x;

  },

  OCTNUM_RE => sub {
    my $digits=$_[0]->OCT_DIGITS;
    return qr{\b(?:
      (?:(?:\\)($digits+))
    | (?:($digits+)(?:o))

    )\b}x;

  },

  BINNUM_RE => sub {
    my $digits=$_[0]->BIN_DIGITS;
    return qr{\b(?:
      (?:(?:0b)($digits+))
    | (?:($digits+)(?:b))

    )\b}x;

  },

};


# ---   *   ---   *   ---
# common string to integer transforms

sub stoi($x,$base,$filter=1) {

  state $tab={

    2  => {
      allow => $PKG->BIN_DIGITS,
      mul   => 1,

    },

    8  => {
      allow => $PKG->OCT_DIGITS,
      mul   => 3,

    },

    16 => {
      allow => $PKG->HEX_DIGITS,
      mul   => 4,

    },

  };


  # ^get ctx
  my $mode  = $tab->{$base}
  or throw_stoi_base($base);

  my $allow = $mode->{allow};
  my $mul   = $mode->{mul};

  # ^get negative
  my $sign=1;

  if(begswith($x,'-')) {
    $x    = substr $x,1,(length $x)-1;
    $sign = -1;

  };

  # filter invalid chars accto base?
  my @chars=reverse split null,$x;

  if($filter) {
    @chars=grep {$ARG=~ $allow} @chars;

  # ^nope, give undef if invalid chars
  # ^found in source
  } else {
    my @tmp=grep {$ARG=~ $allow} @chars;
    return undef if int @tmp < int @chars;

    @chars=@tmp;

  };


  # accumulate to
  my $r=0;
  my $i=0;

  # walk chars in str
  map {

    # fraction part
    if($ARG=~ $DOT_RE) {

      my $bit = 1 << ($i * $mul);

      $r *= 1/$bit;
      $i  = 0;

    # ':' separator ignored
    } elsif($ARG=~ $COLON_RE) {

    # ^integer part
    } else {

      my $v=ord($ARG);

      $v -= ($v > 0x39) ? 55 : 0x30;
      $r += $v << ($i * $mul);

      $i++;

    };

  } @chars;


  return $r*$sign;

};


# ---   *   ---   *   ---
# ^errme

sub throw_stoi_base($base) {

  my $fn=(caller 2)[3];

  errout(

    q[Invalid base (:%u) for [ctl]:%s] . "\n"
  . q[passed from [errtag]:%s],

    lvl  => $AR_FATAL,
    args => [$base,'stoi',$fn],

  );

};


# ---   *   ---   *   ---
# ^sugar

sub hstoi($x) {stoi($x,16)};
sub ostoi($x) {stoi($x,8)};
sub bstoi($x) {stoi($x,2)};


# ---   *   ---   *   ---
# ^infer base from string

sub sstoi($s,$filter=1) {

  my $tab={
    ($PKG->HEXNUM_RE) => 16,
    ($PKG->OCTNUM_RE) => 8,
    ($PKG->BINNUM_RE) => 2,

  };

  my ($key)=grep {$s=~ m[^$ARG$]} keys %$tab;

  # give conversion if valid
  if(defined $key) {
    $s=~ s[$key][$1]sxmg;
    return stoi($s,$tab->{$key},$filter);

  # else give back input if it's a number!
  } else {
    return ($s=~ qr{^[\d\.]+$})
      ? $s
      : undef
      ;

  };

};


# ---   *   ---   *   ---
# give back copy of string without ANSI escapes

sub descape($s) {

  $s=~ s[$PKG->ESCAPE_RE][]sxgm;
  return $s;

};


# ---   *   ---   *   ---
# ^get [escape=>position]

sub popscape($sref) {
  my @out=();
  while($$sref=~ s[($PKG->ESCAPE_RE)][]) {
    push @out,[$1,$-[0]];

  };

  return @out;

};


# ---   *   ---   *   ---
# ^undo

sub pushscape($sref,@ar) {

  my $out   = null;
  my $accum = 0;

  for my $ref(@ar) {
    my ($escape,$pos)=@$ref;
    my $head=substr $$sref,$accum,$pos-$accum;

    $out.=$head.$escape;
    $accum=$accum+(length $head);

  };

  $$sref=$out.substr $$sref,$accum,length $$sref;
  return;

};


# ---   *   ---   *   ---
# ^get length of ANSI escapes in str

sub lenscape($s) {
  my @ar=split $PKG->ESCAPE_RE,$s;
  return sum(map {length $ARG} @ar);

};


# ---   *   ---   *   ---
# wrap string in quotes

sub sqwrap($s) {return "'$s'"};
sub dqwrap($s) {return "\"$s\""};


# ---   *   ---   *   ---
# builds regex for linewrapping

sub __make_linewrap_re($sz_x) {

  state $SZ_X_RE=qr{SZ_X}x;

  my $re=$PKG->LINEWRAP_PROTO;
  $sz_x--;

  $re=~ s[$SZ_X_RE][$sz_x]x;
  $sz_x--;

  $re=~ s[$SZ_X_RE][$sz_x]x;


  return qr{$re}x;

};


# ---   *   ---   *   ---
# split string at X characters

sub linewrap($sref,$sz_x) {

  state $last_re=undef;
  state $last_sz=undef;

  # ^re-use last re if identical
  my $re=(defined $last_re && $sz_x==$last_sz)
    ? $last_re
    : __make_linewrap_re($sz_x)
    ;

  $last_re=$re;
  $last_sz=$sz_x;

  # ^cut
  $$sref=join null,map {

    my $c=("\n" ne substr $ARG,-1)
      ? "\n"
      : null
      ;

    $ARG . $c;

  } resplit($sref,$re);

  return;

};


# ---   *   ---   *   ---
# ^adds ws padding on a
# per-line basis

sub lineident($sref,$x) {
  my $pad="\n" . (q[  ] x $x);
  $$sref=~ s[$NEWLINE_RE][$pad]sxmg;
  $$sref=(q[  ] x $x) . "$$sref";

  return;

};


# ---   *   ---   *   ---
# split string with a capturing regex,
# then filter out result

sub resplit($sref,$re) {
  return grep {
    if (defined $ARG) {strip(\$ARG);$ARG}
    else {0};

  } split $re,$$sref;

};


# ---   *   ---   *   ---
# wrap string in ansi color escapes

sub ansim($s,$id) {

  state $re=qr{tag$};

  if($id=~ s[$re][]) {
    return strtag($s,$id);

  };

  my $color=(defined $PKG->COLOR->{$id})
    ? $PKG->COLOR->{$id}
    : "\e[30;1m"
    ;

  return "$color$s\e[0m";

};


# ---   *   ---   *   ---
# wraps word in <braces> with colors

sub strtag($s,$id=0) {

  my $beg=ansim('<','op');
  my $end=ansim('>','op');

  $id=(! exists $PKG->COLOR->{$id})
    ? ('good','err')[$id]
    : $id
    ;

  my $color=ansim($s,$id);

  return "$beg$color$end";

};


# ---   *   ---   *   ---
# applies common color scheme to
# specific patterns inside a format

sub fsansi($fmat) {

  state $dqstr_re  = qr{"%s"}x;
  state $dqstr_col = ansim('"%s"','ex');

  state $sqstr_re  = qr{'%s'}x;
  state $sqstr_col = ansim("'%s'",'ex');

  state $tag_re    = qr{<%s>}x;
  state $tag_col   = (
    ansim('<','op')
  . ansim('%s','good')

  . ansim('>','op')

  );

  state $custom_re_col=qr{
    \[ (?<col> \w+) \] :

  }x;

  state $custom_re_tok=qr{
    (?<tok> %[\-\d]*[suifXB])

  }x;

  state $custom_re=qr{
    $custom_re_col
    $custom_re_tok

  }x;

  state $num_re=qr{
    \(: $custom_re_tok \)

  }x;

  $fmat=~ s[$dqstr_re][$dqstr_col]sxmg;
  $fmat=~ s[$sqstr_re][$sqstr_col]sxmg;
  $fmat=~ s[$tag_re][$tag_col]sxmg;

  sansi_ops(\$fmat);

  # color embedded in format
  while($fmat=~ $custom_re) {

    my $col=$+{col};
    my $tok=$+{tok};

    $col=ansim($tok,$col);

    $fmat=~ s[$custom_re][$col];

  };

  while($fmat=~ $num_re) {

    my $col='num';
    my $tok=$+{tok};

    $col=ansim($tok,$col);

    $fmat=~ s[$num_re][$col];

  };

  return $fmat;

};


# ---   *   ---   *   ---
# ^similar, applies color to strarr

sub sansi(@ar) {

  state $path_re=qr{(
    (?: \w+ :: \w+)+

  )}x;

  state $dcolon=ansim('::','op');

  my @path=();

  map {

    if($ARG=~ m[$path_re]sxmg) {

      $ARG=~ s{(\w+)}{\x1B[34;22m$1\x1B[0m}sxmg;
      $ARG=~ s[$DCOLON_RE][$dcolon]sxmg;

    };

  } @ar;

  return @ar;

};


# ---   *   ---   *   ---
# ^adds color to operators

sub sansi_ops($sref) {

  state $short_escape_re=qr"

    \x{1B} \[

    [\?\d;]{0,64}
    [^\w0]? [\w]

  "x;

  # bracket not preceded by escape
  state $brak_re=qr"
    (?<! \x{1B})
    ( \[ | \] )

  "x;

  state $custom=qr{(\[\w{1,16}\]:)};

  # ^semi/quest
  state $semi_re=qr{

    (?<!
      \x{1B} \[
      [\?\d;]{1,64}

    ) ([\?;])

  }x;

  state $allowed=qr{
    [ \! ,\.:\^ \{\} \= \(\) \+\*\-\/ \\ \$ \@ ]+

  }x;

  state $nscap_re = qr{
    (?<! $short_escape_re)
    (\s* (?: %% | $allowed))

  }x;

  state $beg=$PKG->COLOR->{op};
  state $end=$PKG->COLOR->{off};


#  my @custom_capt=();
#  while($$sref=~ s[$custom][$PL_CUT]) {
#    push @custom_capt,$1;
#
#  };
#
#  $$sref=~ s[$nscap_re][$beg$1$end]sxmg;
#  $$sref=~ s[$brak_re][$beg$1$end]sxmg;
#
#  map {
#    $$sref=~ s[$PL_CUT_RE][$ARG];
#
#  } @custom_capt;

  $$sref=~ s[$semi_re][$beg$1$end]sxmg;
  return;

};


# ---   *   ---   *   ---
# string has prefix

sub begswith($s,$prefix) {
  return 0 == rindex $s,$prefix,0;

};


# ---   *   ---   *   ---
# convert match of seq into char

sub charcon($sref,$table=undef) {

  $table//=$PKG->CHARCON_DEF;

  my @pats=array_nkeys($table);
  my @seqs=array_nvalues($table);

  while(@pats && @seqs) {
    my $pat=shift @pats;
    my $seq=shift @seqs;

    $$sref=~ s[$pat][$seq]sxmg;

  };


  return;

};


# ---   *   ---   *   ---
# hides the backslash in \[char]

sub nobs($sref) {
  $$sref=~ s[$PKG->NOBS_RE][$1]sxmg;
  return;

};


# ---   *   ---   *   ---
# remove outer whitespace

sub strip($sref) {
  return if ! defined $sref ||! defined $$sref;
  $$sref=~ s[$PKG->STRIP_RE][]sxmg;

  return;

};

sub gstrip(@ar) {
  return grep {

     strip   \$ARG;

     defined  $ARG
  && length   $ARG;

  } @ar;

};


# ---   *   ---   *   ---
# gets array from arrayref
# or comma-separated string

sub deref_clist($list) {
  return (is_arrayref $list)
    ? (@$list)
    : (split $COMMA_RE,$list)
    ;

};


# ---   *   ---   *   ---
# join grepped

sub joinfilt($char,@args) {
  return join $char,grep {length $ARG} @args;

};


# ---   *   ---   *   ---
1; # ret

