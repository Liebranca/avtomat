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
# Most of these regexes where taken from nanorc files!
# all I did was *manually* collect them to make this
# syntax file generator

# ^ this note is outdated ;>
# dirty regexes are at their own language files now

# ---   *   ---   *   ---

# deps
package node;
  use strict;
  use warnings;

my %CACHE=(

  -TREES=>[],
  -NAMES=>'[_a-zA-Z][_a-zA-Z0-9]',

  -OPS=>'[\+\-\*\/\\\$@%&\^<>!\|?\{\[\(\)\]\}~.=;:]',

);

# in: val,is_root;
# make child node or create a new tree
sub nit {

  my $self=shift;

  my $val=shift;
  my $is_root=shift;

  my $tree;

  if(!(defined $is_root)) {

    my @ar=@{ $CACHE{-TREES} };
    $is_root=$#ar;

    my %tree=();
    $tree=\%tree;

    push @{ $CACHE{-TREES} },$tree;


# ---   *   ---   *   ---

  } else {
    $tree=$CACHE{-TREES}->[$is_root];

  };return bless {

    -VAL=>$val,
    -LEAVES=>[],

    -ROOT=>$is_root,


  },'node';

};

# ---   *   ---   *   ---

sub splitlv {

  my $self=shift;

  my $pat=shift;
  my $exp=shift;

  my $is_root=$self->{-ROOT};

  for my $sym(split m/${pat}/,$exp) {

    $exp=~ m/^(.*)${sym}/;
    if(defined $1) {
      $exp=~ s/\Q${1}//;

    };$sym=~ s/\s+//sg;

    if(!(length $sym)) {$sym='$:cut;>';};

    my $node=$self->nit($sym,$is_root);
    push @{ $self->{-LEAVES} },$node;

  };

  return $exp;

};

# ---   *   ---   *   ---

sub pluck {

  my $self=shift;
  my @ar=@_;

  my @plucked=();

  { my $i=0;

    for my $leaf(@{ $self->{-LEAVES} }) {
      if(!$leaf) {next;};

      my $j=0;
      for my $node(@ar) {

        if(!$node) {$j++;next;};

        if($leaf->{-VAL} eq $node->{-VAL}) {

          push @plucked,$self->{-LEAVES}->[$i];

          $ar[$j]=undef;
          $self->{-LEAVES}->[$i]=undef;

          last;

        };$j++;

      };$i++;

    };
  };

# ---   *   ---   *   ---

  # discard blanks

  my @cpy=();
  for(my $i=0;$i<@{ $self->{-LEAVES} };$i++) {

    my $node=$self->{-LEAVES}->[$i];
    if(defined $node) {
      push @cpy,$node;

    };

  };$self->{-LEAVES}=[@cpy];

  return @plucked;

};

# ---   *   ---   *   ---

sub agroup {

  my $self=shift;
  my $is_root=$self->{-ROOT};

  my @buf=();
  my @dst=();

# ---   *   ---   *   ---

  # walk the branches
  while(@{ $self->{-LEAVES} }) {
    my $node=shift @{ $self->{-LEAVES} };

    my $sym=$node->{-VAL};
    if($sym eq '$:cut;>') {
      push @dst,[@buf];

      @buf=();next;

    };

# ---   *   ---   *   ---

    # operator
    if(

       !($sym=~ m/${ CACHE{-OPS} }+\s*:/)
    && !($sym=~ m/:\s*${ CACHE{-OPS} }+/)

    &&   $sym=~ m/${ CACHE{-OPS} }+/

    ) {

      my $t=pop @buf;

      push @buf,$node;
      if($t) {push @buf,$t;};

# ---   *   ---   *   ---

    # anything else
    } else {
      push @buf,$node;

    };

# ---   *   ---   *   ---

  # copy leftovers
  };if(@buf) {
    push @dst,[@buf];

  # reorder
  };for my $ref(@dst) {

    my $node=$self->nit('L',$is_root);

    push @{ $self->{-LEAVES} },$node;
    push @{ $node->{-LEAVES} },@$ref;

# ---   *   ---   *   ---

    my @tail=();
    for my $child(@$ref) {

      push @tail,$child;
      if($child->{-VAL} eq ',') {

        if(@tail>2) {

          $child->{-VAL}='e';
          pop @tail;

          my @tmp=$node->pluck(@tail);
          $child->{-LEAVES}=[@tmp];

        } else {
          $node->pluck($child);

        };@tail=();next;

      };

    };if(@tail>=2) {

      my $child=$node->nit('e',$is_root);
      my @tmp=$node->pluck(@tail);
      $child->{-LEAVES}=[@tmp];

      push @{ $node->{-LEAVES} },$child;

    };
  };

};

# ---   *   ---   *   ---

# deps
package lang;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use ll;

# ---   *   ---   *   ---

  my $_LUN='[_a-zA-Z][_a-zA-Z0-9]';
  my $DRFC='(::|->|\.)';

  my $OPS='+-*/\$@%&\^<>!|?{[()]}~,.=;:';

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
};

# ---   *   ---   *   ---

sub lkback {

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

  return "$beg(($allow)*)$end";

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
# general-purpose regexes

my %DICT=(-GPRE=>{

  -HIER =>[

    # class & hierarchy stuff
    [0x07,'[^[:blank:]]+[^[:blank:]]*^[:blank:]]*'],
    [0x04,eiths('this,self')],
    [0x04,"$_LUN*$DRFC"],
    [0x0D,"\\b$_LUN*$DRFC$_LUN*$DRFC"],
    [0x04,"$DRFC$_LUN*$DRFC"],

  ],

# ---   *   ---   *   ---

  -PFUN =>[

    # functions with parens
    [0x01,"\\b$_LUN*[[:blank:]]*\\("],

  ],

  -GBL =>[

    # constants/globals
    [0x0D,'\b[_A-Z][_A-Z0-9]*\b'],

  ],

  -OPS =>[

    # operators
    [0x0F,eithc($OPS)],

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
    [0x0E,delim('"').'|'.delim("'")],

  ],

# ---   *   ---   *   ---

  -NUMS =>[

    # hex
    [0x03,'('.

      '((\b0*|\\\\)x[0-9A-Fa-f]+[L]*)|'.
      '(\b[0-9A-Fa-f]+[L]*h)'.

      ')\b'

    ],

    # octal
    [0x03,'('.

      '(\\\\[0-7]+[L]*)|'.
      '(\b[0-7]+[L]*o)'.

      ')\b'

    ],

# ---   *   ---   *   ---

    # bin
    [0x03,'('.

      '((\b0|\\\\)b[0-1]+[L]*)|'.
      '([0-1]+[L]*b)'.

      ')\b'

    ],

    # float
    [0x03,'((\b[0-9]*|\.)+[0-9]+f?)\b'],

  ],

# ---   *   ---   *   ---

  -DEV =>[

    [0x0B,'('.( eiths('TODO,NOTE') ).':?|\*+:)'],
    [0x09,'('.( eiths('FIX,BUG') ).':?|\!+:)'],
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

      ,1)).'[[:blank:]]*'.$_LUN.'*\n?)'

    ],[0x0E,'(#[[:blank:]]*'.eiths('else,endif').')'],

    [0x0E,'(#[[:blank:]]*'.

      'define[[:blank:]]*'.
      $_LUN.'*('.( delim2('(',')') ).

      ')?\n?)'

    ],

  ],

# ---   *   ---   *   ---
# hash fetch

});sub PROP {

  my $lang=shift;
  my $key=shift;

  return $DICT{$lang}->{$key};

};

# ---   *   ---   *   ---
# parse utils

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

  # well handle this later, for now its ignored
  $PS{-STR}=~ s/extern "C" \{//;

  while($PS{-STR}=~ m/^\s*(${PS{-PAT}})/sg) {

    if(!$1) {last;};;

    push @{ $PS{-DST}->{$key} },$1;
    $PS{-STR}=~ s/^\s*${PS{-PAT}}\s*//s;

  };

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

sub pehex {

  my $x=shift;
  my $r=0;

  my $i=0;

  for my $c(reverse split '',$x) {

    if($c=~ m/[hHlL]/) {
      next;

    } elsif($c=~ m/[xX]/) {last;};

    my $v=ord($c);

    $v-=($v > 0x39) ? 55 : 0x30;
    $r+=$v<<($i*4);$i++;

  };return $r;

};

# ---   *   ---   *   ---
# langdefs pasted here by sygen
