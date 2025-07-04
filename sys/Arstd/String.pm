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
# lyeb,

# ---   *   ---   *   ---
# deps

package Arstd::String;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use List::Util qw(sum);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Array;

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
    comstrip
    vstr

    deref_clist

    descape
    popscape
    pushscape
    lenscape

    joinfilt

    $PL_CUT
    $PL_CUT_RE
    cutid

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.01.1;#b
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $STRIP_RE  => qr{^\s*|\s*$}x;
  Readonly our $NOBS_RE   => qr{\\(.)}x;

  Readonly our $ESCAPE_RE =>
    qr"\x{1B}\[[\?\d;]+[\w]"x;

  Readonly my $LINEWRAP_PROTO=>q{

  (?<mess>

    [^\n]{1,SZ_X} (?: (?: \n|\s) | $)
  | [^\n]{1,SZ_X} (?: .|$)

  )};

  # TODO: catch strings, maybe
  Readonly my $COMMENT_PROTO=>q[
    ([^\$COMCHAR]*) \$COMCHAR [^\n]* (?: \n|$ )

  ];

  Readonly our $CHARCON_DEF=>[

    qr{\\n}x   => "\n",
    qr{\\r}x   => "\r",
    qr{\\b}x   => "\b",

    qr{\\}x    => '\\',

    qr{\\e}x   => "\e",

  ];

  Readonly our $COLOR=>{

    op     => "\e[37;1m",
    num    => "\e[33;22m",
    warn   => "\e[33;1m",

    good   => "\e[34;22m",
    err    => "\e[31;22m",

    ctl    => "\e[35;1m",
    update => "\e[32;1m",
    ex     => "\e[36;1m",

    off    => "\e[0m",

  };


  Readonly our $CUT_FMAT=>q[;__%s_CUT_%i__?];
  Readonly our $CUT_RE=>qr{\;__\w+_CUT_\d+__\?};

  Readonly our $PL_CUT=>q[;__CUT__?];
  Readonly our $PL_CUT_RE=>qr{\;__CUT__\?};

# ---   *   ---   *   ---
# ^generate unique id for repl

sub cutid($s='N',$i=0) {

  my $fmat = $CUT_FMAT;
  my $out  = sprintf $fmat,$s,$i;

  my $re   = qr"\Q$out";

  return ($out,$re);

};

# ---   *   ---   *   ---
# ROM II

  Readonly my $BIN_DIGITS=>qr{[\:\.0-1]};
  Readonly my $OCT_DIGITS=>qr{[\:\.0-7]};
  Readonly my $HEX_DIGITS=>qr{[\:\.0-9A-F]};

# ---   *   ---   *   ---
# common string to integer transforms

sub stoi($x,$base,$filter=1) {

  state $tab={

    2  => {
      allow => $BIN_DIGITS,
      mul   => 1,

    },

    8  => {
      allow => $OCT_DIGITS,
      mul   => 3,

    },

    16 => {
      allow => $HEX_DIGITS,
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
  my @chars=reverse split $NULLSTR,$x;

  if($filter) {
    @chars=grep {$ARG=~ $allow} @chars;

  # ^nope, give undef if invalid chars
  # found in source
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

  state $hex=qr{
    ^(?:(?:0x|\$)($HEX_DIGITS))
  |  (?:($HEX_DIGITS)(?:h)$)

  }x;

  state $oct=qr{
    ^(?:(?:\\)($OCT_DIGITS))
  |  (?:($OCT_DIGITS)(?:o)$)

  }x;

  state $bin=qr{
    ^(?:(?:0b)($BIN_DIGITS))
  |  (?:($BIN_DIGITS)(?:b)$)

  }x;

  state $tab={
    $hex=>16,
    $oct=>8,
    $bin=>2,

  };

  my ($key)=grep {$s=~ $ARG} keys %$tab;

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

  $s=~ s[$ESCAPE_RE][]sxgm;
  return $s;

};

# ---   *   ---   *   ---
# ^get [escape=>position]

sub popscape($sref) {

  my @out=();

  while($$sref=~ s[($ESCAPE_RE)][]) {
    push @out,[$1,$-[0]];

  };

  return @out;

};

# ---   *   ---   *   ---
# ^undo

sub pushscape($sref,@ar) {

  my $out   = $NULLSTR;
  my $accum = 0;

  for my $ref(@ar) {

    my ($escape,$pos)=@$ref;

    my $head=substr $$sref,$accum,$pos-$accum;

    $out.=$head.$escape;

    $accum=$accum+(length $head);

  };

  $$sref=$out.substr $$sref,$accum,length $$sref;

};

# ---   *   ---   *   ---
# ^get length of ANSI escapes in str

sub lenscape($s) {
  my @ar=split $ESCAPE_RE,$s;
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

  my $re=$LINEWRAP_PROTO;$sz_x--;
  $re=~ s[$SZ_X_RE][$sz_x]x;$sz_x--;
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
  $$sref=join $NULLSTR,map {

    my $c=("\n" ne substr $ARG,-1)
      ? "\n"
      : $NULLSTR
      ;

    $ARG . $c;

  } resplit($sref,$re);

};

# ---   *   ---   *   ---
# ^adds ws padding on a
# per-line basis

sub lineident($sref,$x) {

  my $pad="\n" . (q[  ] x $x);

  $$sref=~ s[$NEWLINE_RE][$pad]sxmg;
  $$sref=(q[  ] x $x) . "$$sref";

};

# ---   *   ---   *   ---
# split string with a capturing regex,
# correcting common junk results

sub resplit($sref,$re) {

  my @out   = ();
  my @lines = split $re,$$sref;

  # strip trailing spaces
  map {
    $ARG=~ s[^\x{20}+|\x{20}+$][]
    if defined $ARG

  } @lines;

  # ^filter out blanks
  return grep {
    defined $ARG && length $ARG

  } @lines;

};

# ---   *   ---   *   ---
# wrap string in ansi color escapes

sub ansim($s,$id) {

  state $re=qr{tag$};

  if($id=~ s[$re][]) {
    return strtag($s,$id);

  };

  my $color=(defined $COLOR->{$id})
    ? $COLOR->{$id}
    : "\e[30;1m"
    ;

  return "$color$s\e[0m";

};

# ---   *   ---   *   ---
# wraps word in <braces> with colors

sub strtag($s,$id=0) {

  state $beg=ansim('<','op');
  state $end=ansim('>','op');

  $id=(! exists $COLOR->{$id})
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
  state $tag_col   =

    ansim('<','op')
  . ansim('%s','good')

  . ansim('>','op')

  ;

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

  state $beg=$COLOR->{op};
  state $end=$COLOR->{off};


  my @custom_capt=();
  while($$sref=~ s[$custom][$PL_CUT]) {
    push @custom_capt,$1;

  };

  $$sref=~ s[$nscap_re][$beg$1$end]sxmg;
  $$sref=~ s[$brak_re][$beg$1$end]sxmg;

  while(@custom_capt) {
    my $x=shift @custom_capt;
    $$sref=~ s[$PL_CUT_RE][$x];

  };

  $$sref=~ s[$semi_re][$beg$1$end]sxmg;

};

# ---   *   ---   *   ---
# string has prefix

sub begswith($s,$prefix) {
  return (rindex $s,$prefix,0)==0;

};

# ---   *   ---   *   ---
# convert match of seq into char

sub charcon($sref,$table=undef) {

  $table//=$CHARCON_DEF;

  my @pats=Arstd::Array::nkeys($table);
  my @seqs=Arstd::Array::nvalues($table);

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

  $$sref=~ s[$NOBS_RE][$1]sxmg;

};

# ---   *   ---   *   ---
# remove outer whitespace

sub strip($sref) {
  return if ! defined $sref ||! defined $$sref;
  $$sref=~ s[$STRIP_RE][]sxmg;

};

# ---   *   ---   *   ---
# remove comments

sub comstrip($sref,$c='#') {

  state $tab={};

  # regenerate regex
  if(! exists $tab->{$c}) {
    $tab->{$c}=$COMMENT_PROTO;
    $tab->{$c}=~ s[\$COMCHAR][$c]sxmg;

    $tab->{$c}=qr{$tab->{$c}}x;

  };

  # ^apply
  my $re=$tab->{$c};
  $$sref=~ s[$re][$1\n]sxmg;

};

# ---   *   ---   *   ---
# force vstr to v0.00.0 format

sub vstr($in) {

  my $v=(sprintf 'v%vd',$in);
  my @v=split m[\.],$v;

  $v[1]='0'.$v[1] if length $v[1]==1;
  $v=join q[.],@v;

  return $v;

};

# ---   *   ---   *   ---
# gets array from arrayref
# or comma-separated string

sub deref_clist($list) {

  return (is_arrayref($list))
    ? @$list
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

