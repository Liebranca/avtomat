#!/usr/bin/perl
# ---   *   ---   *   ---
# LANG DEF
# Syntax rules helper
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---
# utility class

package Lang::Def;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Re;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang;

# ---   *   ---   *   ---
# info

  our $VERSION = v1.00.1;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(

    $PESC_RE

  );

# ---   *   ---   *   ---
# ROM

  Readonly our $PESC_RE=>qr{

    \$\:

    (?<body> (?:
      [^;] | ;[^>]

    )+)

    ;>

  }x;

# ---   *   ---   *   ---

  our %DEFAULTS=(

    name=>$NULLSTR,

    com=>q{\#},
    exp_bound=>qr{[;]}x,
    scope_bound=>qr{[{}]}x,

    hed=>'N/A',
    ext=>$NULLSTR,
    mag=>$NULLSTR,

    lcom=>$NULLSTR,

    # array of plain highlighting rules
    # these are ignored by the parser
    highlight=>[],

# ---   *   ---   *   ---

    op_prec=>{},

    delimiters=>[
      '('=>')','PARENS',
      '['=>']','BRACKET',
      '{'=>'}','CURLY',

    ],

    separators=>[','],

    pesc=>$PESC_RE,

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

    regexes=>qr{$NO_MATCH}x,
    qstrs=>qr{$NO_MATCH}x,

    preproc=>qr{$NO_MATCH}x,

    foldtags=>[qw(
      chars strings

    )],

    vstr=>qr{\bv[0-9\.]+[ab]?}x,

# ---   *   ---   *   ---

    sigils=>q{},

    fn_key=>'FN',
    fn_decl=>qr{$NO_MATCH}x,

    utype_key=>'UTYPE',
    utype_decl=>qr{$NO_MATCH}x,

    ptr_decl=>qr{$NO_MATCH}x,
    ptr_defn=>qr{$NO_MATCH}x,
    ptr_asg=>qr{$NO_MATCH}x,

    asg_op=>qr{$NO_MATCH}x,

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

    strip_re=>$NULLSTR,

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

      '('.(

      re_eiths([qw(TODO NOTE)])

      ).':?|#:\*+;>)',

    dev1=>

      '('.(

      re_eiths([qw(FIX BUG)])

      ).':?|#:\!+;>)',

    dev2=>'[[:space:]]+$',

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

sub nit($class,%h) {

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

    my $keypat=re_eiths(
      [keys %ht],bwrap=>1

    );

    if($keypat eq qr{(^|\b)()(\b|$)}x) {
      $keypat=qr{$NO_MATCH}x;

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
    $ref->{asg_op}=qr{($NO_MATCH)};

# ---   *   ---   *   ---

  } else {
    $ref->{ops}=re_eiths(

      [keys %{$ref->{op_prec}}],
      opscape=>1

    );

    $ref->{ops}=~ s/\)$/|${op_obj})/;

# ---   *   ---   *   ---

    my @asg_ops=();
    for my $op(keys %{$ref->{op_prec}}) {

      my $data=$ref->{op_prec}->{$op};

      # is assignment op
      if($data->[3]) {push @asg_ops,$op};

    };

    $ref->{asg_op}=re_eiths(
      \@asg_ops,opscape=>1

    );

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

  $ref->{ode}=re_eiths(\@odes,opscape=>1);
  $ref->{cde}=re_eiths(\@cdes,opscape=>1);

  my @del_ops=(@odes,@cdes);

  $ref->{del_ops}=re_eiths(
    \@del_ops,opscape=>1

  );

  my @seps=@{$ref->{separators}};
  my @ops_plus_seps=(
    keys %{$ref->{op_prec}},
    @seps,

  );

  $ref->{ndel_ops}=re_eiths(
    \@ops_plus_seps,opscape=>1

  );

  $ref->{sep_ops}=re_eiths(
    \@seps,opscape=>1

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

  $ref->{nums_re}=re_eiths(
    [keys %{$ref->{nums}}]

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

  if(!length $ref->{strip_re}) {
    my $comchar="$ref->{com}";
    $ref->{strip_re}=qr{

      (?: ^|\s*)

      (?: $comchar[^\n]*)?
      (?: \n|$)

    }x;

  };

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

  my $def=bless $ref,$class;
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

sub hier_sort($self,$id) {};

# ---   *   ---   *   ---
1; # ret
