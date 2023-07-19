#!/usr/bin/perl
# ---   *   ---   *   ---
# LANG
# Syntax wrangler
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---
#
# NOTE:
# Most of these regexes were taken from nanorc files!
# all I did was *manually* collect them to make this
# syntax file generator
#
# ^ this note is outdated ;>
# dirty regexes are at their own language files now
#
# ^^ more than outdated!
# almost none of the original regexes remain ;>
# still leaving this up for acknowledgement
#
# ---   *   ---   *   ---
# deps

package Lang;

  use lib $ENV{'ARPATH'}.'/lib/hacks/';
  use Shwl;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);
  use Carp;

  use List::Util qw( max );

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd;
  use Arstd::Array;

  use Chk;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(rmquotes);

# ---   *   ---   *   ---
# info

  our $VERSION=v1.02.5;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $OP_L=>0x01;
  Readonly our $OP_R=>0x02;
  Readonly our $OP_B=>0x04;
  Readonly our $OP_A=>0x08;

# ---   *   ---   *   ---
# value type flags

  Readonly my $VT_KEY=>0x01;
  Readonly my $VT_OPR=>0x02;
  Readonly my $VT_VAL=>0x04;
  Readonly my $VT_XPR=>0x08;

  Readonly my $VT_TYPE=>0x0100|$VT_KEY;
  Readonly my $VT_SPEC=>0x0200|$VT_KEY;
  Readonly my $VT_SBL=>0x0400|$VT_KEY;

  Readonly my $VT_ITRI=>0x0800|$VT_KEY;
  Readonly my $VT_FCTL=>0x1000|$VT_KEY;
  Readonly my $VT_DIR=>0x1000|$VT_KEY;

  Readonly my $VT_SEP=>0x0100|$VT_OPR;
  Readonly my $VT_DEL=>0x0200|$VT_OPR;
  Readonly my $VT_ARI=>0x0400|$VT_OPR;

  Readonly my $VT_BARE=>0x0100|$VT_VAL;
  Readonly my $VT_PTR=>0x0200|$VT_VAL;

  Readonly my $VT_SBL_DECL=>0x0100|$VT_XPR;
  Readonly my $VT_PTR_DECL=>0x0200|$VT_XPR;
  Readonly my $VT_REG_DECL=>0x0400|$VT_XPR;
  Readonly my $VT_CLAN_DECL=>0x0800|$VT_XPR;

  Readonly my $VT_SBL_DEF=>0x1000|$VT_XPR;
  Readonly my $VT_PTR_DEF=>0x2000|$VT_XPR;
  Readonly my $VT_REG_DEF=>0x4000|$VT_XPR;
  Readonly my $VT_CLAN_DEF=>0x8000|$VT_XPR;

# ---   *   ---   *   ---

  Readonly my $RM_QUOTES_RE=>qr{^["']+|["']+$}x;

# ---   *   ---   *   ---
# regex tools

# in:pattern
# escapes [*]: in pattern
sub lescap($s) {

  for my $c(split '','[*]:') {
    $s=~ s/\Q${ c }/\\${ c }/g;

  };return $s;

};

sub rmquotes($s) {

  $s=~ s[$RM_QUOTES_RE][]sxmg;
  return $s;

};

# ---   *   ---   *   ---
# in: pattern,string
#
#   splits string at given pattern,
#   eliminating whitespace
#
# gives list of split'd tokens

sub ws_split($pat,$s) {
  if(!defined $s) {croak "Undef string"};
  return (split m/\s*${pat}\s*/,$s);

};

sub ws_split_re($c) {
  return qr{\s*$c\s*};

};

# ---   *   ---   *   ---
# in:pattern
# escapes .^$([{}])+*?/|\: in pattern

sub rescap($s) {

  $s=~ s/\\/\\\\/g;
  for my $c(split $NULLSTR,q[.^$([{}])+-*?/|]) {
    $s=~ s/\Q${ c }/\\${ c }/g;

  };

  return $s;

};

# ---   *   ---   *   ---
# ^bulk

sub array_rescap($ar) {
  return map {rescap($ARG)} @$ar;

};

# ---   *   ---   *   ---
# lyeb@IBN-3DILA on Wed Feb 23 10:58:41 AM -03 2022:

# i apologize for writting this monster,
# but it had to be done

# it matches *** \[end]*** when [beg]*** \[end]*** [end]
# but it does NOT match when [beg]*** \[end]***

# in: delimiter end
# returns correct \end support

sub UBERSCAP($o_end) {

  my $end="\\\\".$o_end;

  my @chars=split '',$end;
  my $s=rescap( shift @chars );
  my $re="[^$s$o_end]";

  my $i=0;for my $c(@chars) {

    $c=($i<1) ? rescap($c.$o_end) : rescap($c);
    $re.='|'.$s."[^$c]";$i++;

  };return "$end|$re";

};

# ---   *   ---   *   ---
# in:substr to exclude,allow newlines,do_uber
# shame on posix regexes, no clean way to do this

sub neg_lkahead(

  $string,
  $ml,

  $do_uber=0

) {

  $ml=(!$ml) ? '' : '\\x0D\\x0A|';
  my @chars=split '',$string;

  my $s=rescap( shift @chars );
  my $re="$ml"."[^$s\\\\]";

# ---   *   ---   *   ---

  for my $c(@chars) {

    $c=rescap($c);
    $re.='|'.$s."[^$c\\\\]";
    $s.=$c;

  };

# ---   *   ---   *   ---

  if($do_uber) {
    $re.='|'.UBERSCAP( rescap($string) );

  };

  return $re;

};

# ---   *   ---   *   ---

sub lkback($pat,$end) {

  $pat=rescap($pat);

  return ('('.

    '\s'.$end.

    # well, crap
    #'|[^'.$pat.']'.$end.
    '|^'.$end.

  ')');

};

# ---   *   ---   *   ---
# delimiter patterns

# in: beg,end,is_multiline

# matches:
#   > beg
#   > unnested grab ([^end]|\end)*
#   > end

sub delim($beg,$end=$NULLSTR,$ml=0) {

  if(!length $end) {
    $end=$beg;

  };

  my $allow=( neg_lkahead($end,$ml,1) );

  $beg=rescap($beg);
  $end=rescap($end);

  my $out="($beg(($allow)*)$end)";
  return qr{$out}x;

};

# ---   *   ---   *   ---

# in: beg,end,is_multiline

# matches:
#   > ^[^beg]*beg
#   > nested grab ([^end]|end)*
#   > end[^end]*$

sub delim2($beg,$end=$NULLSTR,$ml=0) {

  if(!$end) {
    $end=$beg;

  };

  my $allow=( neg_lkahead($end,$ml,0) );

  $beg=rescap($beg);
  $end=rescap($end);

# ---   *   ---   *   ---

  return qr{

    $beg

    (($allow|$end)*)

    $end

    [^$end]*\$

  }x;

};

# ---   *   ---   *   ---
# ^similar, done with recursive pattern
# fairly more accurate

sub rec_delim($beg,$end,%O) {

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

sub array_rec_delim($ar,%O) {

  return qre_or([map {
    rec_delim(@$ARG)

  } @$ar],%O);

};

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
  @ar=array_rescap(\@ar) if $O{escape};

  # ()
  my $beg   = '(';
  my $end   = ')';

  # ^or \b()\b
  if($O{bwrap}) {
    $beg = q[\b].$beg;
    $end = $end.q[\b];

  };

  # give alternation re
  my $out=join q[|],@ar;
  return qr{$beg$out$O{mod}$end}x;

};

# ---   *   ---   *   ---

# in: pattern,line_beg,disable_escapes
# matches:
#   > pattern
#   > grab everything after pattern until newline
#   > newline

sub eaf($pat,%O) {

  $O{escape} //= 0;
  $O{lbeg}   //= 0;

  $pat=rescap($pat) if $O{escape};

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

sub qre2re($ref) {
  $$ref=~ s/\(\?\^u(?:[xsmg]*)://;
  $$ref=~ s/\(\?:/(/;
  $$ref=~ s/\)$//;

};

# ---   *   ---   *   ---
# hexadecimal conversion

sub pehexnc($x) {

  my $r=0;
  my $i=0;

  $x=~ s[^\$][];

  for my $c(reverse split $NULLSTR,$x) {

    if($c=~ m/[hHlL]/) {
      next;

    # fractions in hex (!!!)
    } elsif($c=~ m/\./) {
      $r*=(1/((1<<$i*4)));
      $i=0;next;

    } elsif($c=~ m/[xX]/) {last;}

    my $v=ord($c);

    $v-=($v > 0x39) ? 55 : 0x30;
    $r+=$v<<($i*4);$i++;

  };return $r;

};

# ---   *   ---   *   ---
# octal conversion

sub peoctnc($x) {

  my $r=0;
  my $i=0;

  $x=~ s[^\\][];

  for my $c(reverse split $NULLSTR,$x) {

    if($c=~ m/[oOlL]/) {
      next;

    # fractions in octal (!!!)
    } elsif($c=~ m/\./) {
      $r*=(1/((1<<$i*3)));
      $i=0;next;

    };

    my $v=ord($c);

    $v-=0x30;
    $r+=$v<<($i*3);$i++;

  };return $r;

};

# ---   *   ---   *   ---
# binary conversion

sub pebinnc($x) {

  my $r=0;
  my $i=0;

  for my $c(reverse split $NULLSTR,$x) {

    if($c=~ m/[bBlL]/) {
      next;

    # fractions in binary (!!!)
    } elsif($c=~ m/\./) {
      $r*=(1/((1<<$i)));
      $i=0;next;

    };

    my $v=ord($c);

    $v-=0x30;
    $r+=$v<<($i);$i++;

  };return $r;

};

# ---   *   ---   *   ---

sub nxtok($s,$cutat) {
  $s=~ s/(${cutat}).*//sg;
  return $s;

};

# ---   *   ---   *   ---

sub insens($s,%O) {

  # defaults
  $O{mkre}//=0;

  my $out=$NULLSTR;

  for my $c(split $NULLSTR,$s) {
    $out.=q{[}.(lc $c).(uc $c).q{]}

  };

  $out=($O{mkre})
    ? qr{($out)}x
    : "($out)"
    ;

  return $out;

};

sub array_insens($ar) {
  return map {insens($ARG)} @$ar;

};

# ---   *   ---   *   ---

sub nonscap($s,%O) {

  #defaults
  $O{iv}    //= 0;
  $O{mod}   //= $NULLSTR;
  $O{sigws} //= 0;
  $O{kls}   //= 0;
  $O{-x}    //= $NULLSTR;

  my $c=($O{sigws})
    ? "$s$O{-x}"
    : "$s$O{-x}\\s"
    ;

  $s=($O{kls})
    ? "[$s]"
    : $s
    ;

  my $out=($O{iv})
    ? "((\\\\[^$c]) | [^$c\\\\] | (\\\\ $s))"
    : "((?!< \\\\ ) $s)"
    ;

  return qr~$out$O{mod}~x;

};

# ---   *   ---   *   ---
# get (nscap $beg) <capt> (nscap $end)

sub delim_capt($beg,$end=undef,%O) {

  # defaults
  $O{key} //= 'capt';
  $end    //= $beg;

  # make re
  my $out=

    '(?: (?<! \\\\) ' . $beg . ') \s*' .

    '(?<' . $O{key} . '> (?: [^' . $end . '] ' .
    '| \\\\ ' . $end . ')+)' .

    '\s* (?: (?<! \\\\) ' . $end . ')'

  ;

  return qr{$out}x;

};

# ---   *   ---   *   ---
# book-keeping

my %LANGUAGES=();

sub register_def($name) {
  $LANGUAGES{$name}=eval(q{Lang::}.$name);

};

sub file_ext($file) {

  my $name=undef;

  $file=(split '/',$file)[-1];

  for my $lang(values %LANGUAGES) {

    my $pat=$lang->{ext};

    if($file=~ m/$pat/) {
      $name=$lang->{name};
      last;

    };
  };

  return $name;

};

# ---   *   ---   *   ---
# for when you just need textual recognition

sub quick_op_prec(%h) {

  my $result={};
  my $prec=-1;

# ---   *   ---   *   ---

  my $asg_c=undef;

  if(exists $h{asg}) {
    $asg_c=$h{asg};
    delete $h{asg};

    my ($sign,$compound,$standalone)=@$asg_c;
    my @asg_ops=();

    for my $c(@$compound) {
      push @asg_ops,$c.$sign;

    };

    for my $c(@$standalone) {
      push @asg_ops,$c;

    };

    for my $op(@asg_ops) {
      if(!exists $h{$op}) {$h{$op}=$OP_B|$OP_A}
      else {$h{$op}|=$OP_A};

    };

  };

# ---   *   ---   *   ---

  for my $op(keys %h) {

    my $flags=$h{$op};

    my $ar=[

      undef,  # takes operand on left
      undef,  # takes operand on right
      undef,  # ^takes both operands

      0       # is assignment operator

    ];

# ---   *   ---   *   ---

    if($flags & $OP_L) {
      $ar->[0]
        =[$prec,sub($x) {return $$x.$op}]

    };

# ---   *   ---   *   ---

    if($flags & $OP_R) {
      $ar->[1]
        =[$prec,sub($y) {return $op.$$y}]

    };

# ---   *   ---   *   ---

    if($flags & $OP_B) {
      $ar->[2]
        =[$prec,sub($x,$y) {return $$x.$op.$$y}]

    };

# ---   *   ---   *   ---

    if($flags & $OP_A) {$ar->[3]=1};

    $prec++;
    $result->{$op}=$ar;

  };

  return $result;

};

# ---   *   ---   *   ---
1; # ret
