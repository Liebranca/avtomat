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

# NOTE:
# Most of these regexes were taken from nanorc files!
# all I did was *manually* collect them to make this
# syntax file generator

# ^ this note is outdated ;>
# dirty regexes are at their own language files now

# ---   *   ---   *   ---


# deps
package lang;
  use strict;
  use warnings;

  use List::Util qw( max );

  use lib $ENV{'ARPATH'}.'/lib/';

# ---   *   ---   *   ---

  sub DRFC {return '(::|->|\.)';};
  sub OPS {return '+-*/\$@%&\^<>!|?{[()]}~,.=;:';};
  sub _LUN {return '[_a-zA-Z][_a-zA-Z0-9]';};

  sub ws_split {

    my $c=shift;
    my $s=shift;

    return split m/\s*${c}\s*/,$s;

  };

# ---   *   ---   *   ---
# regex tools

# in:pattern
# escapes [*]: in pattern
sub lescap {

  my $s=shift;
  for my $c(split '','[*]:') {
    $s=~ s/\Q${ c }/\\${ c }/g;

  };return $s;

};

# in:pattern
# escapes .^$([{}])+*?/|\: in pattern
sub rescap {

  my $s=shift;$s=~ s/\\/\\\\/g;

  for my $c(split '','.^$([{}])+*?/|:') {
    $s=~ s/\Q${ c }/\\${ c }/g;

  };

  return $s;

# ---   *   ---   *   ---
# lyeb@IBN-3DILA on Wed Feb 23 10:58:41 AM -03 2022:

# i apologize for writting this monster,
# but it had to be done

# it matches *** \[end]*** when [beg]*** \[end]*** [end]
# but it does NOT match when [beg]*** \[end]***

# in: delimiter end
# returns correct \end support
};sub UBERSCAP {

  my $o_end=shift;
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
sub neg_lkahead {

  my $string=shift;
  my $ml=shift;
  $ml=(!$ml) ? '' : '\\x0D\\x0A|';

  my $do_uber=shift;
  my @chars=split '',$string;

  my $s=rescap( shift @chars );
  my $re="$ml"."[^$s\\\\]";

  for my $c(@chars) {

    $c=rescap($c);
    $re.='|'.$s."[^$c\\\\]";
    $s.=$c;

  };if($do_uber) {$re.='|'.UBERSCAP( rescap($string) );};
  return $re;

# ---   *   ---   *   ---

};sub lkback {

  my $pat=rescap(shift);
  my $end=shift;

  return ('('.

    ' '.$end.

    # well, crap
    #'|[^'.$pat.']'.$end.
    '|^'.$end.

  ')');

};

# ---   *   ---   *   ---

# do not use
sub vcapitalize {
  my @words=split '\|',$_[0];
  for my $word(@words){
    $word=~ m/\b([a-z])[a-z]*\b/;

    my $c=$1;if(!$c) {next;};

    $c='('.(lc $c).'|'.(uc $c).')';

    $word=~ s/\b[a-z]([a-z]*)\b/FFFF${ 1 }/;
    $word=~ s/FFFF/${ c }/g;

  };return join '|',@words;

};

# ---   *   ---   *   ---
# delimiter patterns

# in: beg,end,is_multiline

# matches:
#   > beg
#   > unnested grab ([^end]|\end)*
#   > end

sub delim {

  my $beg=shift;
  my $end=shift;
  if(!$end) {
    $end=$beg;

  };my $allow=( neg_lkahead($end,shift,1) );

  $beg=rescap($beg);
  $end=rescap($end);

  return "($beg(($allow)*)$end)";

};

# ---   *   ---   *   ---

# in: beg,end,is_multiline

# matches:
#   > ^[^beg]*beg
#   > nested grab ([^end]|end)*
#   > end[^end]*$

sub delim2 {

  my $beg=shift;
  my $end=shift;
  if(!$end) {
    $end=$beg;

  };my $allow=( neg_lkahead($end,shift,0) );

  $beg=rescap($beg);
  $end=rescap($end);

  return ''.
    "$beg".
    "(($allow|$end)*)$end".
    "[^$end]*\$";

};

# ---   *   ---   *   ---
# one-of pattern

# in: string,disable escapes
# matches (char0|...|charN)
sub eithc {

  my $string=shift;
  my $disable_escapes=shift;

  my @chars=split '',$string;
  if(!$disable_escapes) {
    for my $c(@chars) {$c=rescap($c);};

  };return '('.( join '|',@chars).')';

};

# in: "str0,...,strN",disable escapes,v(C|c)apitalize
# matches \b(str0|...|strN)\b
sub eiths {

  my $string=shift;
  my $disable_escapes=shift;

  if(!$disable_escapes) {
    $string=rescap($string);

  };my $vcapitalize=shift;

  my @words=split ',',$string;

  if($vcapitalize) {@words=vcapitalize(@words);};

  return '\b('.( join '|',@words).')\b';

};

# ---   *   ---   *   ---

# in: pattern,line_beg,disable_escapes
# matches:
#   > pattern
#   > grab everything after pattern until newline
#   > newline

# line_beg=1 matches only at beggining of line
# line_beg=-1 doesnt match if pattern is first non-blank
# ^ line_beg=0 disregards these two

sub eaf {

  my $pat=shift;
  my $line_beg=shift;

  my $disable_escapes=shift;
  $pat=(!$disable_escapes) ? rescap($pat) : $pat;

  if(!$line_beg) {
    ;

  } elsif($line_beg>0) {
    $pat='^'.$pat;

  } elsif($line_beg<0) {
    $pat='^[\s|\n]*'.$pat;

  };return "($pat.*(\\x0D?\\x0A|\$))";

};

# ---   *   ---   *   ---
# type-check utils

sub is_code {

  my $v=shift;
  return int($v=~ m/^CODE\(0x[0-9a-f]+\)/);

};sub valid_name {

  my $s=shift;my $_LUN=_LUN();
  if(defined $s && length $s) {
    return $s=~ m/^${_LUN}*/;

  };return 0;

};

# ---   *   ---   *   ---
# general-purpose regexes

my $DICT={-GPRE=>{

  -HIER =>[

    # class & hierarchy stuff
    [0x07,'[^[:blank:]]+'],
    [0x04,eiths('this,self')],
    [0x04,_LUN.'*'.DRFC],
    [0x0D,"\\b"._LUN.'*'.DRFC._LUN.'*'.DRFC],
    [0x04,DRFC._LUN.'*'.DRFC],

  ],

# ---   *   ---   *   ---

  -PFUN =>[

    # functions with parens
    [0x01,"\\b"._LUN.'*[[:blank:]]*\\('],

  ],

  -GBL =>[

    # constants/globals
    [0x0D,'\b[_A-Z][_A-Z0-9]*\b'],

  ],

  -OPS =>[

    # operators
    [0x0F,eithc(OPS)],

  ],

# ---   *   ---   *   ---

  -DELM0 =>[

    # level 0 delimiters
    [0x01,delim('`')],

  ],

  -DELM1 =>[

    # level 1 delimiters
    [0x0E,delim('$:',';>')],

  ],

  -DELM2 =>[

    # level 2 delimiters
    [0x0E,delim('"')],
    [0x0E,delim("'")],

  ],

  -DELM3 =>[

    # nevermind this one
    [0x0E,

      '([m|s]+/([^/]|\\\\/)*/'.
      '(([^/]|\\\\/)*/)?([\w]+)?)'

    ],

  ],

# ---   *   ---   *   ---

  -NUMS =>[

    # hex
    [0x03,'('.

      '((\b0+x[0-9A-F]+[L]*)\b)|'.
      '(((\b0+x[0-9A-F]+\.)+[0-9A-F]+[L]*)\b)'.

      ')\b'

    ],

    # bin
    [0x03,'('.

      '((\b0+b[0-1]+[L]*)\b)|'.
      '(((\b0+b[0-1]*\.)+[0-1]+[L]*)\b)'.

      ')\b'

    ],

# ---   *   ---   *   ---

    # octal
    [0x03,'('.

      '((\b0+0[0-7]+[L]*)\b)|'.
      '(((\b0+0[0-7]+\.)+[0-7]+[L]*)\b)'.

      ')\b'

    ],

    # float
    [0x03,'((\b[0-9]*|\.)+[0-9]+f?)\b'],

  ],

# ---   *   ---   *   ---

  -DEV =>[

    [0x0B,'('.( eiths('TODO,NOTE') ).
      ':?|#:\*+;>)'

    ],

    [0x09,'('.( eiths('FIX,BUG') ).
      ':?|#:\!+;>)'

    ],

    [0x66,'(^[[:space:]]+$)'],
    [0x66,'([[:space:]]+$)'],


# ---   *   ---   *   ---
  # preprocessor

    [0x0E,

      '#[[:blank:]]*include[[:blank:]]*'.
      delim2('<','>')

    ],

    [0x0E,

      '#[[:blank:]]*include[[:blank:]]*'.
      delim2('"')

    ],

    [0x0E,'(#[[:blank:]]*'.( eiths(

      '(el)?if,ifn?def,'.
      'undef,error,warning'

      ,1)).'[[:blank:]]*'._LUN.'*\n?)'

    ],[0x0E,'(#[[:blank:]]*'.eiths('else,endif').')'],

    [0x0E,'(#[[:blank:]]*'.

      'define[[:blank:]]*'.
      _LUN.'*('.( delim2('(',')') ).

      ')?\n?)'

    ],

  ],

# ---   *   ---   *   ---
# hash fetch

}};sub PROP {

  my $lang=shift;
  my $key=shift;

  return $DICT->{$lang}->{$key};

# hash access
};sub DICT {return $DICT;};

# ---   *   ---   *   ---
# parse utils

sub dqstr {return DICT->{-GPRE}->{-DELM2}->[0]->[1];};
sub sqstr {return DICT->{-GPRE}->{-DELM2}->[1]->[1];};
sub restr {return DICT->{-GPRE}->{-DELM3}->[0]->[1];};

# ---   *   ---   *   ---
# in:
#
#   > string
#   > pattern to match
#   > a name for this pattern
#   > arrayref to store matches
#
# replace pattern match with a token, to be
# put back together at a later date

sub cut($$$$) {

  my $s=shift;
  my $pat=shift;
  my $id=shift;
  my $ar=shift;

  my $s2='';
  my $i=0;

  my $cnt=@$ar;

# ---   *   ---   *   ---
# cut at pattern match

  ;;while($s=~ s/${pat}/#:cut;>/) {
    push @$ar,$1;$i++;

# ---   *   ---   *   ---
# put token in place of match

  };if($i) {

    my $matchno=$i;
    $i=0;

    for my $sub(split '#:cut;>',$s) {

      if($i<$matchno) {
        $s2.=sprintf "$sub:__${id}_CUT_%04X__:",
          $cnt+($i++);

      } else {
        $s2.=$sub;

      };

    };

  } else {$s2=$s;};

  return $s2;

# ---   *   ---   *   ---
# in:
#
#   > string
#   > array of matches
#
# restores a previously cut string

};sub stitch($$) {

  my $s=shift;
  my $ar=shift;

# ---   *   ---   *   ---
# look for cut tokens

  while($s=~ m/(:__[A-Z]+_CUT_([\dA-F]+)__:)/) {

    my $pat=$1;
    my $i=hex($2);

# ---   *   ---   *   ---
# use id of token to find the original
# pattern match

    my $str=(defined $ar->[$i]) ? $ar->[$i] : '';
    if(!length $str) {next;};

    $s=~ s/${pat}/$str/;

  };return $s;

# ---   *   ---   *   ---
# remove all whitespace

};sub stripline($) {

  my $s=shift;
  $s=~ s/\s*//sg;

  return $s;

};

# ---   *   ---   *   ---
# in:
#
#   > string
#   > array ref to store matches
#   > pattern array
#
# cut for multiple patterns, one after the other

;;sub mcut($$@) {

  my $s=shift;
  my $ar=shift;

  my %patterns=@_;

  for my $id(keys %patterns) {

    my $new_id='';
    ($s,$new_id)=cut(
      $s,$patterns{$id},$id,$ar

    );

  };return $s;

};

# ---   *   ---   *   ---

my %PS=(

  -PAT => '',
  -STR => '',

  -DST => {},

);

# ---   *   ---   *   ---

# in: key into PS{-DST}
# looks for pattern and substs it
# matches are pushed to dst{key}

sub ps {

  my $key=shift;
  my $pat=shift;

  # well handle this later, for now its ignored
  $PS{-STR}=~ s/extern "C" \{//;

  while($PS{-STR}=~ m/^\s*(${pat})/sg) {

    if(!$1) {last;};

    push @{ $PS{-DST}->{$key} },$1;
    $PS{-STR}=~ s/^\s*${pat}\s*//s;

  };

};sub ps_str {

  my $new=shift;
  if($new) {
    $PS{-STR}=$new;

  };return $PS{-STR};

};sub ps_dst {

  my $new=shift;
  if($new) {
    $PS{-DST}=$new;

  };return $PS{-DST};

};

# ---   *   ---   *   ---

sub pscsl {

  my $key=shift;

  if(my @ar=split m/\s*,\s*/,$PS{-STR}) {

    push @{ $PS{-DST}->{$key} },@ar;
    $PS{-STR}='';

  };

};

# ---   *   ---   *   ---

# in: pattern,string,key
# looks for pattern in string
sub pss {

  my $pat=shift,
  my $str=shift;
  my $key=shift;

  $PS{-PAT}=$pat;

  if($str) {$PS{-STR}=$str;};

  if(!$PS{-DST}->{$key}) {
    $PS{-DST}->{$key}=[];

  };ps($key);return @{ $PS{-DST}->{$key} };

# ---   *   ---   *   ---

# in: string,key
# reads comma-separated list until end of string

};sub psscsl {

  my $str=shift;
  my $key=shift;

  if($str) {$PS{-STR}=$str;};

  if(!$PS{-DST}->{$key}) {
    $PS{-DST}->{$key}=[];

  };pscsl($key);return @{ $PS{-DST}->{$key} };

# ---   *   ---   *   ---

};sub clps {
  for my $key(keys %{ $PS{-DST} }) {
    $PS{-DST}->{$key}=[];

  };
};

# ---   *   ---   *   ---

# hexadecimal conversion
sub pehexnc {

  my $x=shift;
  my $r=0;

  my $i=0;

  for my $c(reverse split '',$x) {

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

# octal conversion
sub peoctnc {

  my $x=shift;
  my $r=0;

  my $i=0;

  for my $c(reverse split '',$x) {

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

# binary conversion
sub pebinnc {

  my $x=shift;
  my $r=0;

  my $i=0;

  for my $c(reverse split '',$x) {

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
1; # ret
