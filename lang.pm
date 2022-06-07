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

  sub ws_split {

    my $c=shift;
    my $s=shift;

    return split m/\s*${c}\s*/,$s;

  };

# ---   *   ---   *   ---
# value type flags

  ;;use constant {

    VT_KEY=>0x01,
    VT_OPR=>0x02,
    VT_VAL=>0x04,
    VT_XPR=>0x08,

  };use constant {

    VT_TYPE=>0x0100|VT_KEY,
    VT_SPEC=>0x0200|VT_KEY,
    VT_SBL=>0x0400|VT_KEY,

    VT_ITRI=>0x0800|VT_KEY,
    VT_FCTL=>0x1000|VT_KEY,
    VT_DIR=>0x1000|VT_KEY,

    VT_SEP=>0x0100|VT_OPR,
    VT_DEL=>0x0200|VT_OPR,
    VT_ARI=>0x0400|VT_OPR,

    VT_BARE=>0x0100|VT_VAL,
    VT_PTR=>0x0200|VT_VAL,

    VT_SBL_DECL=>0x0100|VT_XPR,
    VT_PTR_DECL=>0x0200|VT_XPR,
    VT_REG_DECL=>0x0400|VT_XPR,
    VT_CLAN_DECL=>0x0800|VT_XPR,

    VT_SBL_DEF=>0x1000|VT_XPR,
    VT_PTR_DEF=>0x2000|VT_XPR,
    VT_REG_DEF=>0x4000|VT_XPR,
    VT_CLAN_DEF=>0x8000|VT_XPR,

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

  for my $c(split '','.^$([{}])+*?/|') {
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

  };

  my $allow=( neg_lkahead($end,shift,1) );

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

  };

  my $allow=( neg_lkahead($end,shift,0) );

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

;;sub is_code {

  my $v=shift;
  return int($v=~ m/^CODE\(0x[0-9a-f]+\)/);

};sub is_arrayref {

  my $v=shift;
  return int($v=~ m/^ARRAY\(0x[0-9a-f]+\)/);

};sub is_hashref {

  my $v=shift;
  return int($v=~ m/^HASH\(0x[0-9a-f]+\)/);

};

# ---   *   ---   *   ---
# parse utils

;;sub cut_token_re {
  return ':__[A-Z]+_CUT_([\dA-F]+)__:';

};sub cut_token_f {
  return ':__%s_CUT_%X__:';

};

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

    if($s eq '#:cut;>') {
      $s2.=sprintf cut_token_f(),
        $id,$cnt+($i++);

    } else { for my $sub(split '#:cut;>',$s) {

      if($i<$matchno) {

        $s2.=$sub.sprintf(cut_token_f(),
          $id,$cnt+($i++)

        );

      } else {
        $s2.=$sub;

      };

    }};

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

  my $re=cut_token_re();
  while($s=~ m/(${re})/) {

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
# in: hash reference
# sort keys by length and return
# a pattern to match them

sub hashpat($;$) {

  my $h=shift;
  my $disable_escapes=shift;

  my @keys=sort {
    (length $a)<=(length $b);

  } keys %$h;

  if(!$disable_escapes) {
    for my $key(@keys) {
      $key=rescap($key);

    };

  };

  return '('.(join '|',@keys).')';

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

# ---   *   ---   *   ---
# utility class

package lang::def;
  use strict;
  use warnings;

  use peso::sbl;

# ---   *   ---   *   ---

my %DEFAULTS=(

  -NAME=>'',

  -COM=>'#',
  -EXP_BOUND=>'[;]',
  -SCOPE_BOUND=>'[\{\}]',

  -HED=>'N/A',
  -EXT=>'',
  -MAG=>'',

  -OPS=>'',
  -OP_PREC=>{},

  -ODE=>'[\(\[\{]',
  -CDE=>'[\)\]\}]',

  -DEL_OPS=>'[\{\[\(\)\]\}\\\\]',
  -NDEL_OPS=>'[^\s_A-Za-z0-9\.:\{\[\(\)\]\}\\\\]',
  -SEP_OPS=>'[,]',

  -PESC=> lang::delim2('$:',';>'),

# ---   *   ---   *   ---

  -NAMES=>'\b[_A-Za-z][_A-Za-z0-9]*\b',
  -NAMES_U=>'\b[_A-Z][_A-Z0-9]*\b',
  -NAMES_L=>'\b[_a-z][_a-z0-9]*\b',

  -TYPES=>[],
  -SPECIFIERS=>[],

  -BUILTINS=>[],
  -INTRINSICS=>[],
  -FCTLS=>[],

  -DIRECTIVES=>[],
  -RESNAMES=>[],

# ---   *   ---   *   ---

  -DRFC=>'(::|->|\.)',
  -COMMON=>'[^[:blank:]]+',

# ---   *   ---   *   ---

  -SHCMD=>[
    lang::delim('`'),

  ],

  -CHAR=>[
    lang::delim("'"),

  ],

  -STRING=>[
    lang::delim('"'),

  ],

  -REGEX=>[

    '([m|s]+/([^/]|\\\\/)*/'.
    '(([^/]|\\\\/)*/)?([\w]+)?)',

  ],

  -PREPROC=>[

  ],

# ---   *   ---   *   ---

  -EXP_RULE=>sub {;},
  -MLS_RULE=>sub {return undef;},

  -MCUT_TAGS=>[],
  -BUILDER=>sub {;},

# ---   *   ---   *   ---

  -HIER=>'$:drfc;>$:names;>',
  -PFUN=>'$:names;>\s*\\(',

# ---   *   ---   *   ---

  -NUMS=>[

    # hex
    '(((\b0+x[0-9A-F]+[L]*)\b)|'.
    '(((\b0+x[0-9A-F]+\.)+[0-9A-F]+[L]*)\b)'.

    ')\b',

    # bin
    '(((\b0+b[0-1]+[L]*)\b)|'.
    '(((\b0+b[0-1]*\.)+[0-1]+[L]*)\b)'.

    ')\b',

    # octal
    '(((\b0+0[0-7]+[L]*)\b)|'.
    '(((\b0+0[0-7]+\.)+[0-7]+[L]*)\b)'.

    ')\b',

    # decimal
    '((\b[0-9]*|\.)+[0-9]+f?)\b',

  ],

# ---   *   ---   *   ---

  -NUMCON=>[

    # hex conversion
    [ '$:nums 0;>',
      \&lang::pehexnc

    ],

    # ^bin
    [ '$:nums 1;>',
      \&lang::pebinnc

    ],

    # ^octal
    [ '$:nums 2;>',
      \&lang::peoctnc

    ],

    # decimal notation: as-is
    [ '$:nums 3;>',
      sub {return (shift);}

    ],
  ],

# ---   *   ---   *   ---
# trailing spaces and notes

  -DEV0=>

    '('.( lang::eiths('TODO,NOTE') ).':?|#:\*+;>)',

  -DEV1=>

    '('.( lang::eiths('FIX,BUG') ).':?|#:\!+;>)',

  -DEV2=>'(^[[:space:]]+$)|([[:space:]]+$)',


# ---   *   ---   *   ---
# DEPRECATED
# maybe we'll repurpose this slot

  -DEV3=>[

  ],

# ---   *   ---   *   ---
# symbol table is made at nit

  -SBL=>'',

);

# ---   *   ---   *   ---

;;sub vrepl {

  my ($ref,$v)=@_;

  my $names=$ref->{-NAMES};
  my $drfc=$ref->{-DRFC};
  my $nums=$ref->{-NUMS};

  $$v=~ s/\$:names;>/$names/sg;
  $$v=~ s/\$:drfc;>/$drfc/sg;

  while($$v=~
     m/\$:nums (\d*);>/

  ) {

    my $idex=$1;
    my $pat=$nums->[$idex];

    $$v=~ s/\$:nums ${idex};>/$pat/;

  };

};sub arr_vrepl {

  my ($ref,$key)=@_;

  for my $v(@{$ref->{$key}}) {
    vrepl($ref,\$v);

  };
};

# ---   *   ---   *   ---

sub nit {

  my %h=@_;
  my $ref={};

  # set defaults when key not present
  for my $key(keys %DEFAULTS) {

    if(exists $h{$key}) {
      $ref->{$key}=$h{$key};

    } else {
      $ref->{$key}=$DEFAULTS{$key};

    };

  };

# ---   *   ---   *   ---
# convert keyword lists to hashes

  for my $key(

    -TYPES,-SPECIFIERS,
    -BUILTINS,-FCTLS,
    -INTRINSICS,-DIRECTIVES,

    -RESNAMES,

  ) {

    my @ar=@{$ref->{$key}};
    my %ht;while(@ar) {

      my $tag=shift @ar;
      vrepl($ref,\$tag);

# ---   *   ---   *   ---
# definitions to be loaded in later
# if available/applicable

      $ht{$tag}=0;

    };

# ---   *   ---   *   ---
# make keyword-matching pattern
# then save hash

    $ht{re}=lang::hashpat(\%ht);
    $ref->{$key}=\%ht;

  };

# ---   *   ---   *   ---
# handle creation of operator pattern

  if(!keys %{$ref->{-OP_PREC}}) {
    $ref->{-OPS}='('.

      $ref->{-DEL_OPS}.'|'.
      $ref->{-NDEL_OPS}.

    ')';

# ---   *   ---   *   ---

  } else {
    $ref->{-OPS}=lang::hashpat(
      $ref->{-OP_PREC}

    );

  };

  $ref->{-LCOM}=lang::eaf($ref->{-COM},0,1);

# ---   *   ---   *   ---
# replace $:tokens;> with values

  for my $key(keys %{$ref}) {
    if( lang::is_arrayref($ref->{$key}) ) {
      arr_vrepl($ref,$key);

    } else {vrepl($ref,\$ref->{$key});};

  };

# ---   *   ---   *   ---
# make a ode=>cde match table

  my $odes=$ref->{-ODE};
  my $cdes=$ref->{-CDE};

  $odes=~ s/^\[//;
  $odes=~ s/\]$//;
  $odes=~ s/\\\\([^\\\\])/$1/;

  $cdes=~ s/^\[//;
  $cdes=~ s/\]$//;
  $cdes=~ s/\\\\([^\\\\])/$1/;

  my @odes=split '',$odes;
  my @cdes=split '',$cdes;

  my %matchtab=();

  while(@odes) {

    my $ode=shift @odes;
    my $cde=shift @cdes;

    $matchtab{$ode}=$cde;

  };$ref->{-DEL_MT}=\%matchtab;

# ---   *   ---   *   ---

  no strict;

  my $def=bless $ref,'lang::def';
  my $hack="lang::$def->{-NAME}";

  *$hack=sub {return $def};

# ---   *   ---   *   ---

  $def->{-PLPS}=''.
    $ENV{'ARPATH'}.'/include/plps/'.
    $def->{-NAME}.'.pe.lps';

  return $def;

};

# ---   *   ---   *   ---
# getters

sub exp_bound {return (shift)->{-EXP_BOUND};};
sub com {return (shift)->{-COM};};

sub scope_bound {return (shift)->{-SCOPE_BOUND};};

sub hed {return (shift)->{-HED};};
sub mag {return (shift)->{-MAG};};
sub ext {return (shift)->{-EXT};};

# ---   *   ---   *   ---

sub del_ops {return (shift)->{-DEL_OPS};};
sub ndel_ops {return (shift)->{-NDEL_OPS};};
sub sep_ops {return (shift)->{-SEP_OPS};};
sub del_mt {return (shift)->{-DEL_MT};};
sub mls_rule {return (shift)->{-MLS_RULE};};
sub exp_rule {return (shift)->{-EXP_RULE};};

sub ops {return (shift)->{-OPS};};
sub op_prec {return (shift)->{-OP_PREC};};

sub sbl {return (shift)->{-SBL};};

# ---   *   ---   *   ---

sub ode {return (shift)->{-ODE};};
sub cde {return (shift)->{-CDE};};
sub pesc {return (shift)->{-PESC};};

# ---   *   ---   *   ---

sub names {return (shift)->{-NAMES};};

sub types {return (shift)->{-TYPES};};
sub specifiers {return (shift)->{-SPECIFIERS};};

sub builtins {return (shift)->{-BUILTINS};};
sub intrinsics {return (shift)->{-INTRINSICS};};
sub directives {return (shift)->{-DIRECTIVES};};
sub fctls {return (shift)->{-FCTLS};};

sub resnames {return (shift)->{-RESNAMES};};

sub nums {return (shift)->{-NUMS};};
sub numcon {return (shift)->{-NUMCON};};

# PLACEHOLDER && DEPRECATED
sub keywords {return '';};

sub is_keyword {

  my ($self,$s)=@_;

  for my $tag(

    -TYPES,-SPECIFIERS,
    -BUILTINS,-FCTLS,
    -INTRINSICS,-DIRECTIVES,

    -RESNAMES,

  ) {

    if(exists $self->{$tag}->{$s}) {
      return 1;

    };

  };return 0;
};

# ---   *   ---   *   ---

sub valid_name {

  my $self=shift;
  my $s=shift;

  my $name=$self->names;

  if(defined $s && length $s) {
    return $s=~ m/^${name}*/;

  };return 0;
};

# ---   *   ---   *   ---

sub char {return (shift)->{-CHAR};};
sub string {return (shift)->{-STRING};};
sub shcmd {return (shift)->{-SHCMD};};
sub regex {return (shift)->{-REGEX};};
sub preproc {return (shift)->{-PREPROC};};

# ---   *   ---   *   ---
# prototype: s matches non-code text family

sub is_strtype($$$) {

  my ($self,$s,$type)=@_;
  my @patterns=$self->{$type};

  for my $pat(@patterns) {
    if($s=~ m/${pat}/) {
      return 1;

    };

  };return 0;
};

# ---   *   ---   *   ---
# ^buncha clones

sub is_shcmd($$) {my ($self,$s)=@_;
  return $self->is_strtype($self,$s,-SHCMD);

};sub is_char($$) {my ($self,$s)=@_;
  return $self->is_strtype($self,$s,-CHAR);

};sub is_string($$) {my ($self,$s)=@_;
  return $self->is_strtype($self,$s,-STRING);

};sub is_regex($$) {my ($self,$s)=@_;
  return $self->is_strtype($self,$s,-REGEX);

};sub is_preproc($$) {my ($self,$s)=@_;
  return $self->is_strtype($self,$s,-PREPROC);

};

# ---   *   ---   *   ---
# generates a pattern list for mcut

sub mcut_tags($) {

  my $self=shift;
  my $tags=$self->{-MCUT_TAGS};

  my @ar=();

# ---   *   ---   *   ---
# iter the attrs to be used

  for my $key(@$tags) {

    my $pats=$self->{$key};
    my $cpy=$key;
    $cpy=~ s/^-//;

# ---   *   ---   *   ---
# either single pattern or arrays of them

    if(lang::is_arrayref($pats)) {

      my $i=0;for my $pat(@$pats) {

        push @ar,($cpy.chr(0x41+$i),$pat);
        $i++;

      };
    } else {push @ar,($cpy,$pats);};
  };

# ---   *   ---   *   ---
# give back tags=>patterns

  return @ar;

};

# ---   *   ---   *   ---

sub classify($$) {

  my ($self,$token)=@_;

  my @ar=(

    -TYPES=>lang->VT_TYPE,
    -SPECIFIERS=>lang->VT_SPEC,

    -INTRINSICS=>lang->VT_ITRI,
    -DIRECTIVES=>lang->VT_DIR,
    -FCTLS=>lang->VT_FCTL,

    -DEL_OPS=>lang->VT_DEL,
    -SEP_OPS=>lang->VT_SEP,
    -OPS=>lang->VT_ARI,

    -SBL=>lang->VT_SBL,
    -NAMES=>lang->VT_PTR,

    -SHCMD=>lang->VT_BARE,
    -CHAR=>lang->VT_BARE,
    -STRING=>lang->VT_BARE,
    -REGEX=>lang->VT_BARE,
    -PREPROC=>lang->VT_BARE,
    -NUMS=>lang->VT_BARE,

  );

  while(@ar) {

    my $tag=shift @ar;
    my $value_type=shift @ar;

    my $h=$self->{$tag};
    my $proc=undef;

    if(lang::is_hashref($h)) {

      $proc=sub {
        return exists $h->{$token};

      };

    } else {
      $proc=sub {
        return $token=~ m/^${h}/;

      };

    };my $found=$proc->();

    if($found) {return $value_type;};

  };return 0x00;

};

# ---   *   ---   *   ---

sub build {

  my ($self,@args)=@_;
  return $self->{-BUILDER}->(@args);

};

# ---   *   ---   *   ---

sub plps_match($$$) {

  my ($self,$str,$type)=@_;
  return $self->{-PLPS}->run($str,$type);

};

# ---   *   ---   *   ---
