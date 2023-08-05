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

    re_insens
    re_opscape
    re_eiths
    re_eaf

    re_nonscaped

    re_delim
    array_re_delim

    re_sursplit
    re_sursplit_new

    re_neg_lkahead
    re_lbeg

    qre_or

  );

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# or patterns together

sub qre_or($ar,%O) {

  # defaults
  $O{capt} //= 0;

  my $capt=(! $O{capt})
    ? q[?:]
    : $NULLSTR
    ;

  my $out = "($capt".(
    join '|',@$ar

  ).')';

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
# makes re to match elements in ar

sub eiths($ar,%O) {

  # defaults
  $O{escape} //= 0;
  $O{bwrap}  //= 0;
  $O{insens} //= 0;
  $O{mod}    //= $NULLSTR;

  # make copy
  my @ar=@$ar;

  # force longest pattern first
  array_lsort(\@ar);

  # conditional processing
  @ar=array_insens(\@ar) if $O{insens};
  @ar=array_opscape(\@ar) if $O{escape};

  # () or \b()\b
  my $beg=($O{bwrap}) ? '\b(?:' : '(?:';
  my $end=($O{bwrap}) ? ')\b'   : ')';


  # give alternation re
  my $out=join q[|],@ar;

  return qr{
    $beg $out $O{mod} $end

  }x;

};

# ---   *   ---   *   ---
# matches everything after pattern
# up to newline, inclusive

sub eaf($pat,%O) {

  $O{escape} //= 1;
  $O{lbeg}   //= 0;

  $pat=opscape($pat) if $O{escape};

  if($O{lbeg} > 0) {
    $pat='^'.$pat;

  } elsif($O{lbeg} < 0) {
    $pat='^[\s|\n]*'.$pat;

  };

  return qr{(

    $pat

    .*

    (\x0D?\x0A|$)

  )}x;

};

# ---   *   ---   *   ---
# pattern is preceded by blank
# or is beg of line

sub lbeg($pat,%O) {

  # defaults
  $O{escape}=1;

  $pat=opscape($pat) if $O{escape};

  return
    '(\s+' . $pat
  . '|^'   . $pat

  . ')'
  ;

};

# ---   *   ---   *   ---
# match pattern only if it's
# not preceded by a \\\\ escape

sub nonscaped($s,%O) {

  # defaults
  $O{iv}    //= 0;
  $O{mod}   //= $NULLSTR;
  $O{sigws} //= 0;
  $O{kls}   //= 0;
  $O{-x}    //= $NULLSTR;


  # ^unsignificant space by default
  my $c=($O{sigws})
    ? "$s$O{-x}"
    : "$s$O{-x}\\s"
    ;

  # ^pattern is character class
  $s=($O{kls})
    ? "[$s]"
    : $s
    ;


  # optionally match everything BUT pattern
  my $out=($O{iv})
    ? "((\\\\[^$c]) | [^$c\\\\] | (\\\\ $s))"
    : "((?!< \\\\ ) $s)"
    ;

  return qr~$out$O{mod}~x;

};

# ---   *   ---   *   ---
# match all between delimiters
# works recursively

sub delim($beg,$end,%O) {

  # defaults
  $O{mkre} //= 0;


  # escape input
  $beg="\Q$beg";
  $end="\Q$end";

  # compose pattern
  my $out=
    "(?: $beg"
  .   "(?: [^$beg$end]+ | (?R))*"

  . "$end)"
  ;


  return ($O{mkre}) ? qr{$out}x : $out;

};

# ---   *   ---   *   ---
# ^generate compound pattern

sub array_delim($ar,%O) {
  return qre_or([map {delim(@$ARG)} @$ar],%O);

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
# exporter names

  *re_insens       = *insens;
  *re_opscape      = *opscape;
  *re_eiths        = *eiths;
  *re_eaf          = *eaf;

  *re_nonscaped    = *nonscaped;

  *re_delim        = *delim;
  *array_re_delim  = *array_delim;

  *re_sursplit     = *sursplit;
  *re_sursplit_new = *sursplit_new;

  *re_neg_lkahead  = *neg_lkahead;
  *re_lbeg         = *lbeg;

# ---   *   ---   *   ---
1; # ret
