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

# ---   *   ---   *   ---
# in:
#
#   >"str0,...,strN"
#   >disable escapes
#   >disable \bwrap
#
# matches \b(str0|...|strN)\b

sub eiths($;$$) {

  my $string=shift;
  my $disable_escapes=shift;
  my $disable_bwrap=shift;

  my @words=sort {
    (length $a)<=(length $b);

  } (split ',',$string);

  if(!$disable_escapes) {
    for my $s(@words) {
      $s=rescap($s);

    };
  };

  my $out='('.(join '|',@words).')';
  if(!$disable_bwrap) {
    $out='\b'.$out.'\b';

  };return $out;

# ---   *   ---   *   ---
# ^same, input is array

};sub eiths_l(\@;$$) {

  my $ar=shift;
  my $disable_escapes=shift;
  my $disable_bwrap=shift;

  my @words=sort {
    (length $a)<=(length $b);

  } @{$ar};

  if(!$disable_escapes) {

    for my $s(@words) {
      $s=rescap($s);

    };
  };

  my $out='('.(join '|',@words).')';
  if(!$disable_bwrap) {
    $out='\b'.$out.'\b';

  };return $out;

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

;;sub is_coderef {

  my $v=shift;
  return defined $v
    && int($v=~ m/^CODE\(0x[0-9a-f]+\)/);

};sub is_arrayref {

  my $v=shift;
  return defined $v
    && int($v=~ m/^ARRAY\(0x[0-9a-f]+\)/);

};sub is_hashref {

  my $v=shift;
  return defined $v
    &&  int($v=~ m/^HASH\(0x[0-9a-f]+\)/);

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
  my $h=shift;

  my $result='';
  my $i=0;

  my $cnt=(keys %$h)/2;

# ---   *   ---   *   ---
# cut at pattern match

  my @ar=();
  while($s=~ s/${pat}/#:cut;>/) {
    push @ar,$1;$i++;

  };

# ---   *   ---   *   ---
# utility anon

  my $append_match=sub {

    my $elem=shift;

    my $v=shift @ar;
    my $token=undef;

    if(exists $h->{$v}) {
      $token=$h->{$v};

    } else {
      $token=sprintf cut_token_f(),
        $id,$cnt+($i);

      $h->{$v}=$token;
      $h->{$token}=$v;

    };$result.=$elem.$token;

  };

# ---   *   ---   *   ---
# put token in place of match

  if($i) {

    my $matchno=$i;
    $i=0;

# ---   *   ---   *   ---
# corner case: single match, whole string

    if($s eq '#:cut;>') {
      $append_match->('');

# ---   *   ---   *   ---
# append matches

    } else { for my $elem(split '#:cut;>',$s) {

      if($i<$matchno) {
        $append_match->($elem);

# ---   *   ---   *   ---
# handle remainder

      } else {
        $result.=$elem;

      };$i++;

    }};

# ---   *   ---   *   ---
# no match

  } else {$result=$s;};
  return $result;

# ---   *   ---   *   ---
# in:
#
#   > string
#   > array of matches
#
# restores a previously cut string

};sub stitch($$) {

  my $s=shift;
  my $h=shift;

# ---   *   ---   *   ---
# look for cut tokens

  my $re=cut_token_re();
  while($s=~ m/(${re})/) {

    my $pat=$1;

# ---   *   ---   *   ---
# use id of token to find the original
# pattern match

    my $str=(exists $h->{$pat})
      ? $h->{$pat}
      : "TOKEN_ERROR($pat)"
      ;

    $s=~ s/${pat}/$str/;

  };return $s;

# ---   *   ---   *   ---
# remove all whitespace

};sub stripline($) {

  my $s=shift;
  $s=~ s/\s*//sg;
  $s=~ s/:__NL__://sg;

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
  my $h=shift;

  my %patterns=@_;

  for my $id(keys %patterns) {

    my $new_id='';
    ($s,$new_id)=cut(
      $s,$patterns{$id},$id,$h

    );

  };return $s;

};

# ---   *   ---   *   ---
# in: hash reference
# sort keys by length and return
# a pattern to match them

sub hashpat($;$$) {

  my $h=shift;
  my $disable_escapes=shift;
  my $disable_bwrap=shift;

  my @keys=sort {
    (length $a)<=(length $b);

  } keys %$h;

  return eiths_l(
    @keys,

    $disable_escapes,
    $disable_bwrap

  );

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

# ---   *   ---   *   ---
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

# ---   *   ---   *   ---
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

sub nxtok($$) {

  my ($s,$cutat)=@_;

  $s=~ s/${cutat}.*//sg;
  return $s;

};

# ---   *   ---   *   ---
# book-keeping

my %LANGUAGES=();

sub register_def($) {

  my $name=shift;
  $LANGUAGES{$name}=1;

};sub file_ext($) {

  my $file=shift;
  my $name=undef;

  $file=(split '/',$file)[-1];

  for my $key(keys %LANGUAGES) {
    my $pat=lang->$key->ext;

    if($file=~ m/$pat/) {
      $name=$key;last;

    };
  };

  return $name;

};

# ---   *   ---   *   ---
# for when you just need textual recognition

sub quick_op_prec {

  my %h=@_;
  my $result={};

  for my $op(keys %h) {

    my $flags=$h{$op};
    my $ar=[undef,undef,undef];

# ---   *   ---   *   ---

    if($flags&0x01) {
      $ar->[0]
        =[-1,sub {my ($x)=@_;return $$x.$op;}]

    };

# ---   *   ---   *   ---

    if($flags&0x02) {
      $ar->[1]
        =[-1,sub {my ($x)=@_;return $op.$$x;}]

    };

# ---   *   ---   *   ---

    if($flags&0x04) {
      $ar->[2]
        =[-1,sub {my ($x,$y)=@_;return $$x.$op.$$y;}]

    };

# ---   *   ---   *   ---

    $result->{$op}=$ar;
  };

  return $result;

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

# ---   *   ---   *   ---

  -OP_PREC=>{},

  -DELIMITERS=>{
    '('=>')',
    '['=>']',
    '{'=>'}',

  },

  -SEPARATORS=>[','],

  -PESC=>lang::delim('$:',';>'),

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

  -HIER=>['$:names;>$:drfc;>','$:drfc;>$:names;>'],
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

  -NUMCON=>{

    # hex conversion
    '$:nums 0;>'=>\&lang::pehexnc,

    # ^bin
    '$:nums 1;>'=>\&lang::pebinnc,

    # ^octal
    '$:nums 2;>'=>\&lang::peoctnc,

    # decimal notation: as-is
    '$:nums 3;>'=>sub {return (shift);},

  },

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
};sub hash_vrepl {

  my ($ref,$key)=@_;
  my $h=$ref->{$key};

  my $result={};

  for my $v(keys %$h) {

    my $original=$v;

    vrepl($ref,\$v);
    $result->{$v}=$h->{$original};

  };

  $ref->{$key}=$result;
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

    my $keypat=lang::hashpat(\%ht,1,0);

    $keypat=($keypat eq '\b()\b')
      ? '$^' : $keypat;

    $ht{re}=$keypat;
    $ref->{$key}=\%ht;

  };

# ---   *   ---   *   ---
# handle creation of operator pattern

  my $op_obj='node_op=HASH\(0x[0-9a-f]+\)';
  if(!keys %{$ref->{-OP_PREC}}) {
    $ref->{-OPS}="($op_obj)";

# ---   *   ---   *   ---

  } else {
    $ref->{-OPS}=lang::hashpat(
      $ref->{-OP_PREC},0,1

    );

    $ref->{-OPS}=~ s/\)$/|${op_obj})/;

  };

  $ref->{-LCOM}=lang::eaf($ref->{-COM},0,1);

# ---   *   ---   *   ---
# make open/close delimiter patterns

  my @odes=keys %{$ref->{-DELIMITERS}};
  my @cdes=values %{$ref->{-DELIMITERS}};

  $ref->{-ODE}=lang::eiths_l(@odes,0,1);
  $ref->{-CDE}=lang::eiths_l(@cdes,0,1);

  my @del_ops=(@odes,@cdes);
  $ref->{-DEL_OPS}=lang::eiths_l(@del_ops,0,1);

  my @seps=@{$ref->{-SEPARATORS}};
  my @ops_plus_seps=(
    keys %{$ref->{-OP_PREC}},
    @seps,

  );

  $ref->{-NDEL_OPS}=lang::eiths_l(
    @ops_plus_seps,0,1

  );

  $ref->{-SEP_OPS}=lang::eiths_l(
    @seps,0,1

  );

# ---   *   ---   *   ---
# replace $:tokens;> with values

  for my $key(keys %{$ref}) {
    if( lang::is_arrayref($ref->{$key}) ) {
      arr_vrepl($ref,$key);

    } else {vrepl($ref,\$ref->{$key});};

  };hash_vrepl($ref,-NUMCON);

# ---   *   ---   *   ---
# these are for coderef access from plps

  for my $key('is_ptr&') {

    my $fnkey=$key;
    $fnkey=~ s/&$//;

    $ref->{$key}=eval('\&'."$fnkey");

  };

# ---   *   ---   *   ---

  no strict;

  my $def=bless $ref,'lang::def';
  my $hack="lang::$def->{-NAME}";

  *$hack=sub {return $def};

# ---   *   ---   *   ---

  $def->{-PLPS}=''.
    $ENV{'ARPATH'}.'/include/plps/'.
    $def->{-NAME}.'.lps';

  lang::register_def($def->{-NAME});

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

sub separators {return (shift)->{-SEP_OPS};};

# ---   *   ---   *   ---

sub is_keyword {

  my ($self,$s)=@_;
  my $x=0;

  for my $tag(

    -TYPES,-SPECIFIERS,
    -BUILTINS,-FCTLS,
    -INTRINSICS,-DIRECTIVES,

    -RESNAMES,

  ) {

    my $h=$self->{$tag};
    my $pat=$self->{$tag}->{re};

    $x=int(

       (exists $h->{$s})
    || ($s=~ m/^${pat}$/)

    );if($x) {last;};
  };return $x;
};

# ---   *   ---   *   ---

sub valid_name {

  my $self=shift;
  my $s=shift;

  my $name=$self->names;

  if(defined $s && length $s) {
    return $s=~ m/^${name}/;

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

sub mcut_tags($;$) {

  my ($self,$append)=@_;
  my $tags=[@{$self->{-MCUT_TAGS}}];

  if(defined $append) {
    push @$tags,@{$append};

  };

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

sub is_ptr($$) {

  my ($self,$program,$string)=@_;
  my $out=undef;

  my $tok=lang::nxtok($$string,' ');

  if($self->valid_name($tok)) {
    $$string=~ s/^${tok}//;
    $out=$tok;

  };

  return ($out);

};

# ---   *   ---   *   ---
