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
  use Carp;

  use List::Util qw( max );

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd;
  use Chk;

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
# regex tools

# in:pattern
# escapes [*]: in pattern
sub lescap($s) {

  for my $c(split '','[*]:') {
    $s=~ s/\Q${ c }/\\${ c }/g;

  };return $s;

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
  for my $c(split '','.^$([{}])+*?/|') {
    $s=~ s/\Q${ c }/\\${ c }/g;

  };

  return $s;

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
# one-of pattern

# in: string,disable escapes
# matches (char0|...|charN)
sub eithc($string,$disable_escapes) {

  my @chars=split '',$string;

# ---   *   ---   *   ---

  if(!$disable_escapes) {
    for my $c(@chars) {$c=rescap($c);};

  };

# ---   *   ---   *   ---

  my $out='('.( join '|',@chars).')';
  return qr{$out}x;

};

# ---   *   ---   *   ---
# in:
#
#   >"str0,...,strN"
#   >disable escapes
#   >disable \bwrap
#
# matches \b(str0|...|strN)\b

sub eiths(

  $string,
  $disable_escapes=0,
  $disable_bwrap=0,

) {

  my @words=sort {
    (length $a)<=(length $b);

  } (split ',',$string);

# ---   *   ---   *   ---

  if(!$disable_escapes) {
    for my $s(@words) {
      $s=rescap($s);

    };
  };

# ---   *   ---   *   ---

  my $out='('.(join '|',@words).')';
  if(!$disable_bwrap) {
    $out='\b'.$out.'\b';

  };

  return qr{$out}x;

};

# ---   *   ---   *   ---
# ^same, input is array

sub eiths_l(

  $ar,

  $disable_escapes=0,
  $disable_bwrap=0

) {

  my @words=sort {
    (length $a)<=(length $b);

  } @{$ar};

# ---   *   ---   *   ---

  if(!$disable_escapes) {

    for my $s(@words) {
      $s=rescap($s);

    };
  };

# ---   *   ---   *   ---

  my $out='('.(join '|',@words).')';
  if(!$disable_bwrap) {
    $out='(^|\b)'.$out.'(\b|$)';

  };

  return qr{$out}x;

};

# ---   *   ---   *   ---

# in: pattern,line_beg,disable_escapes
# matches:
#   > pattern
#   > grab everything after pattern until newline
#   > newline

sub eaf(

  $pat,
  $line_beg=1,
  $disable_escapes=1,

) {

  $pat=(!$disable_escapes)
    ? rescap($pat) : $pat

  ;

# ---   *   ---   *   ---

  if($line_beg>0) {
    $pat='^'.$pat;

  } elsif($line_beg<0) {
    $pat='^[\s|\n]*'.$pat;

  };

# ---   *   ---   *   ---

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
# in: hash reference
# sort keys by length and return
# a pattern to match them

sub hashpat(
  $h,

  $disable_escapes=0,
  $disable_bwrap=0,

) {

  my @keys=sort {
    (length $a)<=(length $b);

  } keys %$h;

  return eiths_l(
    \@keys,

    $disable_escapes,
    $disable_bwrap

  );

};

# ---   *   ---   *   ---
# ^ same thing for an array

sub arrpat(
  $ar,

  $disable_escapes=0,
  $disable_bwrap=0,

) {

  my @keys=sort {
    (length $a)<=(length $b);

  } @$ar;

  return eiths_l(
    \@keys,

    $disable_escapes,
    $disable_bwrap

  );

};

# ---   *   ---   *   ---
# hexadecimal conversion

sub pehexnc($x) {

  my $r=0;
  my $i=0;

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
# book-keeping

my %LANGUAGES=();

sub register_def($name) {
  $LANGUAGES{$name}=1;

};

sub file_ext($file) {

  my $name=undef;

  $file=(split '/',$file)[-1];

  for my $key(keys %LANGUAGES) {
    my $pat=lang->$key->{ext};

    if($file=~ m/$pat/) {
      $name=$key;last;

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

# ---   *   ---   *   ---
# utility class

package Lang::Def;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Peso::Sbl;

# ---   *   ---   *   ---

my %DEFAULTS=(

  name=>$NULLSTR,

  com=>q{\#},
  exp_bound=>qr{[;]}x,
  scope_bound=>qr{[{}]}x,

  hed=>'N/A',
  ext=>$NULLSTR,
  mag=>$NULLSTR,

  lcom=>$NULLSTR,

# ---   *   ---   *   ---

  op_prec=>{},

  delimiters=>[
    '('=>')','PARENS',
    '['=>']','BRACKET',
    '{'=>'}','CURLY',

  ],

  separators=>[','],

  pesc=>Shwl::delm2('$:',';>'),

# ---   *   ---   *   ---

  names=>'\b[_A-Za-z][_A-Za-z0-9]*\b',
  names_u=>'\b[_A-Z][_A-Z0-9]*\b',
  names_l=>'\b[_a-z][_a-z0-9]*\b',

  types=>[],
  specifiers=>[],

  builtins=>[],
  intrinsics=>[],
  fctls=>[],

  directives=>[],
  resnames=>[],

# ---   *   ---   *   ---

  drfc=>'(?:->|::|\.)',
  common=>'[^[:blank:]]+',

# ---   *   ---   *   ---

  shcmds=>qr{

    (?<! ["'])

    `
    (?: \\` | [^`\n] )*

    `

  }x,

  chars=>qr{

    (?<! ["`])

    '
    (?: \\' | [^'\n] )*

    '

  }x,

  strings=>qr{

    (?<! ['`])

    "
    (?: \\" | [^"\n] )*

    "

  }x,

  regexes=>qr{$^}x,
  qstrs=>qr{$^}x,

  preproc=>qr{$^}x,

  foldtags=>[qw(
    chars strings

  )],

  vstr=>qr{\bv[0-9\.]+[ab]?}x,

# ---   *   ---   *   ---

  sigils=>q{},

  fn_key=>'FN',
  fn_decl=>qr{$^}x,

  utype_key=>'UTYPE',
  utype_decl=>qr{$^}x,

  ptr_decl=>qr{$^}x,
  ptr_defn=>qr{$^}x,
  ptr_asg=>qr{$^}x,

  asg_op=>qr{$^}x,

# ---   *   ---   *   ---

  exp_rule=>$NOOP,
  _builder=>$NOOP,
  _plps=>$NULLSTR,

# ---   *   ---   *   ---

  hier_re=>q{

    (?:$:names;>$:drfc;>?)+

  },

  hier_sort=>$NOOP,

  hier=>['$:names;>$:drfc;>','$:drfc;>$:names;>'],
  pfun=>'$:names;>\s*\\(',

# ---   *   ---   *   ---

  nums=>{

    # hex
    '(((\b0+x[0-9A-F]+[L]*)\b)|'.
    '(((\b0+x[0-9A-F]+\.)+[0-9A-F]+[L]*)\b)'.

    ')\b'=>\&Lang::pehexnc,

    # bin
    '(((\b0+b[0-1]+[L]*)\b)|'.
    '(((\b0+b[0-1]*\.)+[0-1]+[L]*)\b)'.

    ')\b'=>\&Lang::pebinnc,

    # octal
    '(((\b0+0[0-7]+[L]*)\b)|'.
    '(((\b0+0[0-7]+\.)+[0-7]+[L]*)\b)'.

    ')\b'=>\&Lang::peoctnc,

    # decimal
    '((\b[0-9]*|\.)+[0-9]+f?)\b'
    =>sub {return (shift);},

  },

# ---   *   ---   *   ---
# trailing spaces and notes

  dev0=>

    '('.( Lang::eiths('TODO,NOTE') ).':?|#:\*+;>)',

  dev1=>

    '('.( Lang::eiths('FIX,BUG') ).':?|#:\!+;>)',

  dev2=>'(^[[:space:]]+$)|([[:space:]]+$)',

# ---   *   ---   *   ---
# symbol table is made at nit

  symbols=>{},

);

# ---   *   ---   *   ---

sub consume_pesc($sref) {

  my $out=undef;
  if($$sref=~ s/\$\:(.*?);>/\#\:pesc_cut;>/sxm) {
    $out=${^CAPTURE[0]};

  };

  return $out;

};

sub vrepl($ref,$v) {

  while(defined (my $key=consume_pesc($v))) {

    my $rep;

    if($key=~ m/->/) {

      $rep=$ref;
      for my $x(split m/->/,$key) {
        $rep=$rep->{$x};

      };

    } else {
      $rep=$ref->{$key};

    };

# ---   *   ---   *   ---

    if(!defined $rep || !length $rep) {
      $rep=$key;

    };

    $$v=~ s/\#\:pesc_cut;>/$rep/sxmg;

  };

};

# ---   *   ---   *   ---

sub arr_vrepl($ref,$key) {

  for my $v(@{$ref->{$key}}) {
    vrepl($ref,\$v);

  };
};sub hash_vrepl($ref,$key) {

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

sub nit(%h) {

  my $ref={};

# ---   *   ---   *   ---
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

  my @keyword_patterns=();
  for my $key(qw(

    types specifiers
    builtins fctls
    intrinsics directives

    resnames

  )) {

    my @ar=@{$ref->{$key}};
    my %ht;

    while(@ar) {

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

    my $keypat=Lang::hashpat(\%ht,1,0);

    if($keypat eq qr{(^|\b)()(\b|$)}x) {
      $keypat=qr{$^}x;

    } else {
      push @keyword_patterns,$keypat;

    };

    $ht{re}=$keypat;
    $ref->{$key}=\%ht;

  };

  my $keyword_patterns=
    join q{|},@keyword_patterns;

  $ref->{keyword_re}=qr{$keyword_patterns}x;

# ---   *   ---   *   ---
# handle creation of operator pattern

  my $op_obj='node_op=HASH\(0x[0-9a-f]+\)';
  if(!keys %{$ref->{op_prec}}) {
    $ref->{ops}="($op_obj)";
    $ref->{asg_op}=qr{($^)};

# ---   *   ---   *   ---

  } else {
    $ref->{ops}=Lang::hashpat(
      $ref->{op_prec},0,1

    );

    $ref->{ops}=~ s/\)$/|${op_obj})/;

# ---   *   ---   *   ---

    my @asg_ops=();
    for my $op(keys %{$ref->{op_prec}}) {

      my $data=$ref->{op_prec}->{$op};

      # is assignment op
      if($data->[3]) {push @asg_ops,$op};

    };

    $ref->{asg_op}=Lang::arrpat(\@asg_ops,0,1);

  };

# ---   *   ---   *   ---
# make open/close delimiter patterns

  my @odes=();
  my @cdes=();

# ---   *   ---   *   ---

  { my @qstr_re=();
    my @regex_re=();

    my %del_id=();
    my %del_re=();

    my $i=0;
    my $ar=$ref->{delimiters};

    while($i<@$ar) {

      my $beg=$ar->[$i+0];
      my $end=$ar->[$i+1];
      my $key=$ar->[$i+2];

      my $re=Shwl::delm($beg,$end);

# ---   *   ---   *   ---
# fnn perl man

      if($ref->{perl_mode}) {
        push @qstr_re,qdelm($beg,$end);
        push @regex_re,sdelm($beg,$end);

      };

# ---   *   ---   *   ---

      $del_re{$beg}=$re;
      $del_id{$beg}=$key;

      push @odes,$beg;
      push @cdes,$end;

      $i+=3;

    };

# ---   *   ---   *   ---

    if(@qstr_re) {
      $ref->{qstr_re}='('.(
        join q{|},@qstr_re

      ).')';

      $ref->{regex_re}='('.(
        join q{|},@regex_re

      ).')';

    };

# ---   *   ---   *   ---

    $ref->{delimiters}={

      order=>\@odes,

      re=>\%del_re,
      id=>\%del_id,

    };

  };

# ---   *   ---   *   ---
# token res

  { my $del_ids=join q{|},
      values %{$ref->{delimiters}->{id}};

    my $str_ids=join q{|},
      map {uc $ARG} @{$ref->{foldtags}};

    my $a_re=$Shwl::CUT_RE;
    my $b_re=$a_re;

    $a_re=~ s/\\w\+/(?:$del_ids)/;
    $b_re=~ s/\\w\+/(?:$str_ids)/;

    $ref->{cut_a_re}=$a_re;
    $ref->{cut_b_re}=$b_re;

  };

# ---   *   ---   *   ---

  $ref->{ode}=Lang::eiths_l(\@odes,0,1);
  $ref->{cde}=Lang::eiths_l(\@cdes,0,1);

  my @del_ops=(@odes,@cdes);
  $ref->{del_ops}=Lang::eiths_l(\@del_ops,0,1);

  my @seps=@{$ref->{separators}};
  my @ops_plus_seps=(
    keys %{$ref->{op_prec}},
    @seps,

  );

  $ref->{ndel_ops}=Lang::eiths_l(
    \@ops_plus_seps,0,1

  );

  $ref->{sep_ops}=Lang::eiths_l(
    \@seps,0,1

  );

# ---   *   ---   *   ---
# replace $:tokens;> with values

  for my $key(keys %$ref) {

    if($ref->{$key}=~ $Chk::ARRAYREF_RE) {
      arr_vrepl($ref,$key);

    } elsif($ref->{$key}=~ $Chk::HASHREF_RE) {
      hash_vrepl($ref,$key);

    } else {
      vrepl($ref,\$ref->{$key});

    };

  };

# ---   *   ---   *   ---

  $ref->{nums_re}=Lang::hashpat(
    $ref->{nums},1,1

  );

# ---   *   ---   *   ---

  { my %tmp=();
    for my $key(keys %{$ref->{nums}}) {
      my $value=$ref->{nums}->{$key};
      $key=qr{$key}x;

      $tmp{$key}=$value;

    };

    $ref->{nums}=\%tmp;

  };

# ---   *   ---   *   ---

  for my $key(qw(
    drfc hier hier_re
    names names_l names_u

    fn_decl utype_decl ptr_decl
    ptr_defn ptr_asg sigils

  )) {

    if($ref->{$key}=~ $Chk::ARRAYREF_RE) {
      for my $re(@{$ref->{$key}}) {
        $re=qr{$re}x;

      };

# ---   *   ---   *   ---

    } elsif($ref->{$key}=~ $Chk::HASHREF_RE) {

      for my $rek(keys %{$ref->{$key}}) {
        my $re=$ref->{$key}->{$rek};
        $re=qr{$re}x;

        $ref->{$key}->{$rek}=$re;

      };

# ---   *   ---   *   ---

    } else {
      my $re=$ref->{$key};
      $ref->{$key}=qr{$re}x;

    };

  };

# ---   *   ---   *   ---
# parse2 regexes

  my $comchar="$ref->{com}";
  $ref->{strip_re}=qr{

    (?: ^|\s*)

    (?: $comchar[^\n]*)?
    (?: \n|$)

  }x;

  $ref->{exp_bound_re}=qr{

    ($ref->{scope_bound}|$ref->{exp_bound})

  }x;

# ---   *   ---   *   ---
# these are for coderef access from plps

  for my $key('is_ptr&','is_num&') {

    my $fnkey='plps_'.$key;
    $fnkey=~ s/&$//;

    $ref->{$key}=eval('\&'."$fnkey");

  };

# ---   *   ---   *   ---

  if(!length $ref->{lcom}) {
    $ref->{lcom}=$ref->{com}.q{.*}."\n";

  };

# ---   *   ---   *   ---

  no strict;

  my $def=bless $ref,'Lang::Def';
  my $hack="Lang::$def->{name}";

  *$hack=sub {return $def};

# ---   *   ---   *   ---

  $def->{_plps}=''.
    $ENV{'ARPATH'}.'/include/plps/'.
    $def->{name}.'.lps';

  Lang::register_def($def->{name});

  return $def;

};

# ---   *   ---   *   ---

sub numcon($self,$value) {

  for my $key(keys %{$self->{nums}}) {

    if($$value=~ m/^${key}/) {
      $$value=$self->{nums}->{$key}->($$value);
      last;

    };

  };
};

# ---   *   ---   *   ---

sub is_num($self,$s) {
  return int($s=~ m/^$self->{nums_re}$/);

};

sub plps_is_num($self,$s,$program) {

  my $out=undef;
  my $tok=Lang::nxtok($$s,' |,');

  if($self->is_num($tok)) {
    $$s=~ s/^${tok}//;
    $out=$tok;

  };

  return ($out);

};

# ---   *   ---   *   ---

sub valid_name($self,$s) {

  my $name=$self->{names};

  if(defined $s && length $s) {
    return $s=~ m/^${name}$/;

  };return 0;
};

# ---   *   ---   *   ---
# prototype: s matches non-code text family

sub is_strtype($self,$s,$type) {

  my @patterns=$self->{$type};

  for my $pat(@patterns) {
    if($s=~ m/${pat}/) {
      return 1;

    };

  };return 0;
};

# ---   *   ---   *   ---
# ^buncha clones

sub is_shcmd($self,$s) {
  return $self->is_strtype($self,$s,'shcmds');

};sub is_char($self,$s) {
  return $self->is_strtype($self,$s,'chars');

};sub is_string($self,$s) {
  return $self->is_strtype($self,$s,'strings');

};sub is_regex($self,$s) {
  return $self->is_strtype($self,$s,'regexes');

};sub is_preproc($self,$s) {
  return $self->is_strtype($self,$s,'preproc');

};

# ---   *   ---   *   ---

sub build($self,@args) {
  return $self->{_builder}->(@args);

};

# ---   *   ---   *   ---

sub plps_match($self,$str,$type) {
  return $self->{_plps}->run($str,$type);

};

# ---   *   ---   *   ---

sub is_ptr($self,$s,$program) {

  my $out=undef;
  my $tok=Lang::nxtok($$s,' ');

  if($self->valid_name($tok)) {
    $$s=~ s/^${tok}//;
    $out=$tok;

  };

  return ($out);

};

# ---   *   ---   *   ---
