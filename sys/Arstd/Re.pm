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
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::Re;
  use v5.42.0;
  use strict;
  use warnings;

  use English;
  use List::Util qw(max);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);
  use Arstd::String qw(cat to_char);
  use Arstd::Array qw(dupop nlsort);

  use parent 'St';


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(pekey eiths crepl);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.7';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

St::vconst {
  PESC_RE => qr{
    \$: \s* (?<on>[%/]?) \s*
    (?<body> (?: [^;] | ;[^>])+)

    \s* ;>

  }x,
};


# ---   *   ---   *   ---
# ~~

sub crepl($s,%O) {
  for my $key(keys %O) {
    my $re=qr{
      (?:\s*\#\s*)?
      (?:\b$key\b)
      (?:\s*\#\s*)?
    }x;
    $s=~ s[$re][$O{$key}]smg;
  };
  return $s;
};


# ---   *   ---   *   ---
# or patterns together

sub alt($ar,%O) {

  # defaults
  $O{capt}   //= 0;
  $O{bwrap}  //= 0;
  $O{insens} //= 0;
  $O{mkre}   //= 1;

  # optional proc
  if($O{insens} > 0) {
    @$ar=array_insens($ar);
    $O{insens}=0;
  };

  # make alternation
  my $out=join '|',grep {defined $ARG} @$ar;

  # ^run optional procs
  $out=capt($out,$O{capt},insens=>$O{insens});
  $out=bwrap($out,$O{bwrap}) if $O{bwrap};


  # compile regex?
  if($O{mkre}) {
    $out=($O{insens})
      ? qr{$out}xi
      : qr{$out}x
      ;

  };

  return $out;

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
  my $out=cat map {
    '[' . (lc $ARG)
        . (uc $ARG) .']'

  } to_char $s;

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
  my $re=qr{([

    \. \^ \$

    \( \[ \{
    \} \] \)

    \+ \- \*
    \? \/ \|

    \\ \# \@

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
  $O{mkre}   //= 1;

  my $out=null;
  my $beg='(';
  my $end=')';

  # make (?: non-capturing)
  if($name eq 0) {
    $beg .= '?:';

  # make (?<named> capture)
  } elsif($name) {

    $name=($name=~ m[^\d])
      ? 'capt'
      : $name
      ;

    $beg .= "?<$name>";

  };


  # handle insens posix re
  if($O{insens} > 0) {
    $pat=insens($pat);

  };


  # compile regex?
  $out="$beg$pat$end";

  if($O{mkre}) {

    $out=($O{insens})
      ? qr{$out}xi
      : qr{$out}x
      ;

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

sub bwrap($pat,$mode=1) {

  my $wrap=($mode ne 1)
    ? '(?:\b|_)'
    : '\b'
    ;

  return "$wrap$pat$wrap";

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
  $O{mkre}     //= 1;
  $O{opscape}  //= 0;
  $O{capt}     //= 0;
  $O{bwrap}    //= 0;
  $O{whole}    //= 0;
  $O{insens}   //= 0;
  $O{mod}      //= null;

  # make copy
  my @ar=@$ar;

  # force longest pattern first
  dupop(\@ar);
  nlsort(\@ar);

  # conditionally escape operators
  @ar=array_opscape(\@ar) if $O{opscape};

  # ^compose re
  my $out=alt(

    \@ar,

    insens => $O{insens},

    capt   => $O{capt},
    bwrap  => $O{bwrap},

    mkre   => 0,

  ) . $O{mod};


  # match whole string?
  $out="^$out\$" if $O{whole};

  # compile regex?
  if($O{mkre}) {

    $out=($O{insens})
      ? qr{$out}xi
      : qr{$out}x
      ;

  };

  return $out;

};


# ---   *   ---   *   ---
# ^shorthand for peso-style
# keyword arrays

sub pekey(@ar) {

  # defaults
  my %O=(

    opscape => 1,

    insens  => -1,
    bwrap   => -1,
    capt    => 1,

  );

  return eiths(\@ar,%O);

};


# ---   *   ---   *   ---
# ^anything BUT

sub npekey(@ar) {
  my $ex=pekey(@ar);
  return lkahead($ex,-1);

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
    ? null
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
  $O->{mod}   //= null;
  $O->{sigws} //= 0;
  $O->{kls}   //= 0;
  $O->{-x}    //= null;
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

  # make expr for negative match
  my $nslash="(?:\\\\{1,16}(?:$beg|$end))";
  my $ndelim="(?!$beg|$end)(?:.|\\s)";

  my $ex="(?:$nslash|$ndelim)+";


  # compose pattern
  my $out=

    $beg

  . "(?:$ex|(?R))*"

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
# ^posix-friendly version

sub posix_delim($beg,%O) {

  # defaults
  $O{end}       //= $beg;
  $O{multiline} //= 0;

  # spawn montrous posix-re version of
  # negative lookahead...
  my $allow=neg_lkahead(
    $O{end},
    multiline=>$O{multiline},
    uberscape=>1,

  );

  # ^escape delimiters and give
  $beg    = opscape($beg);
  $O{end} = opscape($O{end});

  my $out="($beg(($allow)*)$O{end})";
  return qr{$out}x;

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

  my @chars = split null,$end;
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
    : null
    ;


  # walk characters of string
  my @chars = split null,$s;

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
# halfway conversion of compiled
# perl regex to posix regex
#
# note this is only textual subst;
# posix re is *still* posix re
#
# [0]: byte str | re ; pattern to proc
# [<]: bool          ; string is null
#
# [!]: overwrites input string | re

sub qre2re {
  return 0 if is_null $_[0];
  my $body_re=qr{
    (?<body> [^\)]+ | (?R))*

  }x;

  my $inner_re=qr{
    \(\? (?: <\w+> | [:<=\!]+)

    $body_re

    \)

  }x;

  my $outer_re=qr{
    \(\?\^u (?:[xsmgi]*) :

    $body_re

    \)

  }x;

  while($_[0]=~ s[$outer_re][($+{body})]sxmg) {};
  while($_[0]=~ s[$inner_re][($+{body})]sxmg) {};

  return ! is_null $_[0];

};


# ---   *   ---   *   ---
1; # ret
