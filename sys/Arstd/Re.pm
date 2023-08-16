#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD RE
# Regex factory
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Arstd::Re;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use List::Util qw(max);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Array;

  use Chk;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    re_alt
    re_capt
    re_dcapt
    re_bwrap

    re_insens
    re_opscape
    re_eiths
    re_pekey
    re_eaf

    re_nonscaped
    re_escaped

    re_lkback
    re_lkahead

    re_delim
    array_re_delim

    re_sursplit
    re_sursplit_new

    re_neg_lkahead
    re_lbeg

    qre2re

    $UNPRINT_RE

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.3;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# or patterns together

sub alt($ar,%O) {

  # defaults
  $O{capt}   //= 0;
  $O{bwrap}  //= 0;
  $O{insens} //= 0;

  # optional proc
  if($O{insens} > 0) {
    @$ar=array_insens($ar);
    $O{insens}=0;

  };

  # make alternation
  my $out=join '|',@$ar;

  # ^run optional procs
  $out=capt($out,$O{capt},insens=>$O{insens});
  $out=bwrap($out) if $O{bwrap};


  return qr{$out}x;

};

# ---   *   ---   *   ---
# make case-insensitive pattern
#
# one could do with just the
#  //i flag in perl, but in less
# sophisticated regex engines
# you do sometimes need this

sub insens($s,%O) {

  # defaults
  $O{mkre}//=0;

  # get [xX] for each char
  my $out=join $NULLSTR,map {

    '[' . (lc $ARG)
        . (uc $ARG) .']'

  } split $NULLSTR,$s;

  # conditionally compile
  $out=($O{mkre})
    ? qr{(?:$out)}x
    : "(?:$out)"
    ;

  return $out;

};

# ---   *   ---   *   ---
# ^bat

sub array_insens($ar) {
  return map {insens($ARG)} @$ar;

};

# ---   *   ---   *   ---
# escapes .^$([{}])+*?/|\: in pattern

sub opscape($s) {

  state $re=qr{([

    \. \^ \$

    \( \[ \{
    \} \] \)

    \+ \- \*
    \? \/ \|

    \\ \#

  ])}x;

  $s=~ s[$re][\\$1]g;

  return $s;

};

# ---   *   ---   *   ---
# ^bat

sub array_opscape($ar) {
  return map {opscape($ARG)} @$ar;

};

# ---   *   ---   *   ---
# makes capturing or non-capturing group

sub capt($pat,$name=0,%O) {

  # defaults
  $O{insens} //= 0;

  my $out=$NULLSTR;
  my $beg='(';
  my $end=')';

  # make (?: non-capturing)
  if($name eq 0) {
    $beg .= '?:';

  # make (?<named> capture)
  } elsif($name) {

    $name=($name =~ m[^\d])
      ? 'capt'
      : $name
      ;

    $beg .= "?<$name>";

  };

  # case-insenstive perl re
  if($O{insens} < 0) {
    $out=qr{$beg$pat$end}xi;

  # ^posix re
  } elsif($O{insens} > 0) {
    $pat=insens($pat);
    $out=qr{$beg$pat$end}x;

  } else {
    $out=qr{$beg$pat$end}x;

  };

  # ^give (pattern)
  return $out;

};

# ---   *   ---   *   ---
# get non-recursive <capt>
# between delimiters

sub dcapt($beg,$end,%O) {

  # defaults
  $O{capt} //= 'capt';


  # ^shorten subpatterns
  my $nslash = lkback('\\\\',-1);

  my $open   = capt("$nslash$beg");
  my $close  = capt("$nslash$end");

  my $body   = escaped(

    $end,

    capt => 0,
    mod  => '+',

  );

  # ^compose re
  my $out=

    $open . '\s*'
  . capt($body,$O{capt})

  . '\s*' . $end

  ;

  return qr{$out}x;

};

# ---   *   ---   *   ---
# wraps in word delimiter

sub bwrap($pat) {
  return '\b' . $pat . '\b';

};

# ---   *   ---   *   ---
# get next match of re

sub nxtok($s,$re) {
  $s=~ s[($re)][]sg;
  return $s;

};

# ---   *   ---   *   ---
# makes re to match elements in ar

sub eiths($ar,%O) {

  # defaults
  $O{opscape}  //= 0;
  $O{capt}     //= 0;
  $O{bwrap}    //= 0;
  $O{insens}   //= 0;
  $O{mod}      //= $NULLSTR;

  # make copy
  my @ar=@$ar;

  # force longest pattern first
  array_lsort(\@ar);

  # conditionally escape operators
  @ar=array_opscape(\@ar) if $O{opscape};

  # ^compose re
  my $out=alt(

    \@ar,

    insens => $O{insens},

    capt   => $O{capt},
    bwrap  => $O{bwrap},

  ) . $O{mod};

  return qr{$out}x;

};

# ---   *   ---   *   ---
# ^shorthand for peso-style
# keyword arrays

sub pekey(@ar) {

  # defaults
  my %O=(
    opscape => 1,
    insens  => 1,
    bwrap   => 1,

  );

  return eiths(\@ar,%O);

};

# ---   *   ---   *   ---
# matches everything after pattern
# up to newline, inclusive

sub eaf($pat,%O) {

  # defaults
  $O{opscape} //= 1;
  $O{capt}    //= 0;

  # optional procs
  $pat=opscape($pat) if $O{opscape};
  $O{opscape}=0;

  $pat=lbeg($pat,$O{lbeg})
  if exists $O{lbeg};

  return capt(
    $pat . '.*(?:\x0D?\x0A|$)',
    $O{capt}

  );

};

# ---   *   ---   *   ---
# pattern is preceded by blank
# or is beg of line

sub lbeg($pat,$mode,%O) {

  # defaults
  $O{opscape} //= 1;
  $O{capt}    //= 0;

  $pat=opscape($pat) if $O{opscape};

  # force beg of line
  if($mode > 0) {
    $pat='^'.$pat;

  # beg of line, allow whitespace
  } elsif($mode < 0) {
    $pat='^[\s|\n]*'.$pat;

  # ^either whitespace OR beg of line
  } else {

    $pat=
      '\s+' . $pat
    . '|^'  . $pat
    ;

  };

  return capt($pat,$O{capt});

};

# ---   *   ---   *   ---
# wraps pattern in positive
# or negative look ahead or behind

sub look($pat,%O) {

  # defaults
  $O{behind}   //= 0;
  $O{negative} //= 0;

  my $a=(! $O{behind})
    ? $NULLSTR
    : '<'
    ;

  my $b=($O{negative})
    ? '!'
    : '='
    ;

  return "(?${a}${b}" . "$pat)";

};

# ---   *   ---   *   ---
# ^sugar wraps

sub lkback($pat,$i) {
  return look($pat,behind=>1,negative=>$i<0);

};

sub lkahead($pat,$i) {
  return look($pat,behind=>0,negative=>$i<0);

};

# ---   *   ---   *   ---
# procs options for escaped/nonscaped

sub _escaping_prologue($sref,$O) {

  # defaults
  $O->{mod}   //= $NULLSTR;
  $O->{sigws} //= 0;
  $O->{kls}   //= 0;
  $O->{-x}    //= $NULLSTR;
  $O->{capt}  //= 0;


  # ^unsignificant space by default
  my $excl=($O->{sigws})
    ? "$$sref$O->{-x}"
    : "$$sref$O->{-x}\\s"
    ;

  # ^pattern is character class
  my $pat=($O->{kls})
    ? "[$$sref]"
    : $$sref
    ;

  return ($pat,$excl);

};

# ---   *   ---   *   ---
# match pattern only if it's
# not preceded by a \\\\ escape

sub nonscaped($s,%O) {

  my ($pat,$excl)=
    _escaping_prologue(\$s,\%O);


  my $out=lkback('\\\\',-1) . $pat;
     $out=capt($out,$O{capt});


  return qr~$out$O{mod}~x;

};

# ---   *   ---   *   ---
# ^iv, match \\\\ escaped pattern
#
# OR escaped excluded pattern
# OR anything that's not excluded...

sub escaped($s,%O) {

  my ($pat,$excl)=
    _escaping_prologue(\$s,\%O);

  my $out=

    "(?:\\\\[^$excl])"

  . "|[^$excl\\\\]"
  . "|(?:\\\\$pat)"

  ;

  $out=capt($out,$O{capt});

  return qr~$out$O{mod}~x;

};

# ---   *   ---   *   ---
# match all between delimiters
# works recursively

sub delim($beg,$end,%O) {

  # defaults
  $O{capt} //= 0;


  # escape input
  $beg="\Q$beg";
  $end="\Q$end";

  # compose pattern
  my $out=

    $beg

  . '(?:' . "[^$beg$end]+"
  . '|(?R))*'

  . $end
  ;


  return capt($out,$O{capt});

};

# ---   *   ---   *   ---
# ^generate compound pattern

sub array_delim($ar,%O) {
  return alt([map {delim(@$ARG)} @$ar],%O);

};

# ---   *   ---   *   ---
# lyeb@IBN-3DILA on Wed Feb 23 10:58:41 AM -03 2022:
#
# i apologize for writting this monster,
# but it had to be done
#
# it matches '\[end]' when '[beg] \[end] [end]'
# but it does NOT match when '[beg] \[end]'

sub uberscape($o_end) {

  my $end   = "\\\\".$o_end;

  my @chars = split $NULLSTR,$end;
  my $s     = opscape(shift @chars);
  my $re    = "[^$s$o_end]";

  # i don't remember why this works
  # and i don't want to find out!

  my $i=0;map {

    $ARG=($i<1)
      ? opscape($ARG . $o_end)
      : opscape($ARG)
      ;

    $re.='|' . $s . "[^$ARG]";
    $i++;

  } @chars;

  return "$end|$re";

};

# ---   *   ---   *   ---
# negative lookahead
# shame on posix regex II

sub neg_lkahead($s,%O) {

  # defaults
  $O{multiline} //= 0;
  $O{uberscape} //= 0;


  # contionally make primitive multi-line pattern
  my $carry=($O{multiline})
    ? '\\x0D\\x0A|'
    : $NULLSTR
    ;


  # walk characters of string
  my @chars = split $NULLSTR,$s;

  my $prev  = opscape(shift @chars);
  my $out   = $carry . "[^$prev\\\\]";


  # build alternation that will match
  # up to N chars of string if the
  # following character does not
  # match
  #
  # e.g. 'hey' becomes:
  #
  #   h[^e] | he[^y]
  #
  # escapes \\\\ always break the seq

  map {

    $$ARG  = opscape($ARG);

    $out  .= '|' . $prev . "[^$ARG\\\\]";
    $prev .= $ARG;

  } @chars;


  # conditionally apply primitive
  # delimiter escaping detection
  $out .=  '|' . uberscape(opscape($s))
  if $O{uberscape};;


  return $out;

};

# ---   *   ---   *   ---
# splits str at one pattern when
# surrounded by another
#
# gives list of split'd tokens

sub sursplit($pat,$s,%O) {

  # defaults
  $O{sur} //= '\s*';

  my $re=sursplit_new($pat,$O{sur});
  return split $re,$s;

};

# ---   *   ---   *   ---
# ^produces those kinds of regexes

sub sursplit_new($pat,$sur) {
  return qr{$sur$pat$sur}x;

};

# ---   *   ---   *   ---
# halfway conversion of compiled
# perl regex to posix regex
#
# note this is only textual subst;
# posix re is *still* posix re

sub qre2re($sref) {

  state $body_re=qr{
    (?<body> [^\)]+ | (?R))*

  }x;

  state $inner_re=qr{

    \(\? (?: <\w+> | [:<=\!]+)

    $body_re

    \)

  }x;

  state $outer_re=qr{

    \(\?\^u (?:[xsmg]*) :

    $body_re

    \)

  }x;

  while($$sref=~ s[$outer_re][($+{body})]sxmg) {};
  while($$sref=~ s[$inner_re][($+{body})]sxmg) {};

};

# ---   *   ---   *   ---
# exporter names

  *re_alt          = *alt;
  *re_capt         = *capt;
  *re_dcapt        = *dcapt;
  *re_bwrap        = *bwrap;

  *re_insens       = *insens;
  *re_opscape      = *opscape;
  *re_eiths        = *eiths;
  *re_pekey        = *pekey;
  *re_eaf          = *eaf;

  *re_nonscaped    = *nonscaped;
  *re_escaped      = *escaped;

  *re_lkback       = *lkback;
  *re_lkahead      = *lkahead;

  *re_delim        = *delim;
  *array_re_delim  = *array_delim;

  *re_sursplit     = *sursplit;
  *re_sursplit_new = *sursplit_new;

  *re_neg_lkahead  = *neg_lkahead;
  *re_lbeg         = *lbeg;

# ---   *   ---   *   ---
# ROM II

  Readonly our $UNPRINT_RE=>eiths([

    map {
      '\x{' . $ARG . '}'

    } (0x00..0x19),(0x7F..0xFF)

  ]);

# ---   *   ---   *   ---
1; # ret
