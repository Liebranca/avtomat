#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO
# $ syntax defs
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Lang::Peso;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys';

  use Style;

  use Arstd;
  use Arstd::Array;
  use Arstd::IO;

  use Type;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang;

  use parent 'Lang::Def';

  use Peso::Ops;
  use Peso::Defs;

  use Peso::Rd;

# ---   *   ---   *   ---

BEGIN {

my $NUMS=$Lang::Def::DEFAULTS{nums};
$NUMS->{'(\$[0-9A-F]+)'}=\&Lang::pehexnc;

# ---   *   ---   *   ---
# builtins and functions, group A

  Readonly my $BUILTIN=>[

    Lang::insens('cpy'),
    Lang::insens('mov'),
    Lang::insens('wap'),

    Lang::insens('pop'),
    Lang::insens('push'),

    Lang::insens('inc'),
    Lang::insens('dec'),
    Lang::insens('clr'),

    Lang::insens('exit'),

  ];

# ---   *   ---   *   ---

  Readonly my $DIRECTIVE=>[

    Lang::insens('reg'),
    Lang::insens('rom'),

    Lang::insens('clan'),
    Lang::insens('proc'),

    Lang::insens('entry'),
    Lang::insens('atexit'),

    Lang::insens('nocase'),
    Lang::insens('case'),

    # ipret layer
    Lang::insens('def'),
    Lang::insens('redef'),
    Lang::insens('undef'),

    # preproc
    Lang::insens('lib'),
    Lang::insens('import'),

  ];

# ---   *   ---   *   ---

  Readonly my $FCTL=>[

    Lang::insens('jmp'),
    Lang::insens('jif'),
    Lang::insens('eif'),

    Lang::insens('on'),
    Lang::insens('then'),
    Lang::insens('or'),
    Lang::insens('off'),

    Lang::insens('call'),
    Lang::insens('ret'),
    Lang::insens('wait'),

  ];

# ---   *   ---   *   ---

  Readonly my $INTRINSIC=>[

    Lang::insens('wed'),
    Lang::insens('unwed'),
    Lang::insens('ipol'),

    Lang::insens('in'),
    Lang::insens('out'),
    Lang::insens('xform'),

    Lang::insens('defd'),

  ];

  Readonly my $SPECIFIER=>[

    Lang::insens('ptr'),
    Lang::insens('fptr'),

    Lang::insens('str'),
    Lang::insens('buf'),
    Lang::insens('tab'),

  ];

# ---   *   ---   *   ---
# executes a small subset of peso

sub mini_ipret($self,$rd,$tree) {

  state $FN_HED=

  q{void FN_%FMAT%(}."\n".
  q[uint64_t tcnt,uint64_t* buff]."\n".
  q[) {]."\n"

  ;

  state $QDQ_RE=qr{['"]}x;

  my $fmat='""';
  my $code=$NULLSTR;
  my $code_epi=$NULLSTR;

  return;

# ---   *   ---   *   ---

  my @inputs=();

  for my $in_b($tree->branches_in(qr{^in$})) {

    my @l=map {$ARG->{value}} @{$in_b->{leaves}};

    my @data;
    my $type='bare';

    my $opt;

    while(@l) {

      if($l[0] eq '?') {
        shift @l;
        $opt=shift @l;

      } elsif($l[0]=~ s{^\[([\s\S]+)\]$}{}sxgm) {
        $type=$1;
        shift @l;

      } else {
        push @data,@l;
        last;

      };

    };



# ---   *   ---   *   ---

    push @data,$opt if !@data && defined $opt;

    for my $key(@data) {
      $code.='  uint64_t '.$key.'_id'.
        q{=*buff++;}."\n";

      $code.='  char* '.$key.'=get_keyw_or_val('.
        $key."_id);\n";

      push @inputs,$key;

    };

# ---   *   ---   *   ---

  };

  for my $xform($tree->branches_in(qr{^xform$})) {

    my @data=map {$ARG->{value}} @{
      $xform->{leaves}

    };

    array_filter(\@data,sub {$ARG ne ','});
    my $fn=shift @data;
    my $dst=$data[0];

    $code.=q{  }.
      $fn.'('.(join ',',@data).");\n";

  };

# ---   *   ---   *   ---

  if(defined (
    my $out_b=$tree->branch_in(qr{^out$})

  )) {

    my @leaves=@{$out_b->{leaves}};
    my @data=map {$ARG->{value}} @leaves;

    map {

      $ARG=~ s[\n][ ]sxgm;
      $ARG=~ s[\s+][ ]sxgm;
      $ARG=~ s[^,$][];

      $ARG=~ s[^\(|\)$][]sxmg;

    } @data;

    array_filter(\@data);

    my $data=join '\n',@data;
    $fmat="\"$data".'\n'."\"";

  };

# ---   *   ---   *   ---

  my @cuts=split m[%BLK%],$fmat;
  array_filter(\@cuts);

  if(@cuts) {

    for my $c(@cuts) {
      $c=~ s{$QDQ_RE}{}sxmg;
      $c="\"$c".'\n'."\"";

    };

    $code.='  char* cuts[]={'.
      (join ',',@cuts).

    "};\n";

    $code.='  char* %FMAT%_STR=str_isert('.
      'pe_blk_name,cuts,'.int(@cuts).

    ");\n";

  } else {
    $code='char* %FMAT%_STR='.$fmat.";\n";

  };

# ---   *   ---   *   ---

  $code.='  printf(%FMAT%_STR'.
    (','x(@inputs>0)).
    (join ',',@inputs).

  ');';

  if(length $code) {
    $code=$FN_HED.$code;
    $code.="\n}";

  };

  $code.="\n";

  return $code;

};

# ---   *   ---   *   ---

Lang::Peso->nit(

  name=>'Peso',

  ext=>'\.(pe|rom)$',
  hed=>'(\$|\%);',
  mag=>'$ program',

  op_prec=>$Peso::Ops::TABLE,
  nums=>$NUMS,

# ---   *   ---   *   ---

  types=>[
    grep {!($ARG=~ m[^-])} keys %$Type::Table,

  ],

  specifiers=>[@$SPECIFIER],

  resnames=>[qw(
    self other null non

  )],

# ---   *   ---   *   ---

  intrinsics=>[@$INTRINSIC],

  directives=>[@$DIRECTIVE],

  fctls=>[@$FCTL],

# ---   *   ---   *   ---

  builtins=>[qw(

    mem fre shift unshift
    kin sow reap sys stop

  ),@$BUILTIN,

  ],

# ---   *   ---   *   ---

  fn_key=>Lang::insens('proc'),

  fn_decl=>q{

    \b$:sbl_key;> \s+

    (?<attrs> $:types->re;> \s+)*\s*
    (?<name> $:names;>)\s*

    [;]+

    (?<scope>
      (?<code>

        (?: (?:ret|exit) \s+ [^;]+)
      | (?: \s* [^;]+; \s* (?&scope))

      )*

    )

    \s*[;]+

  },

# ---   *   ---   *   ---

)};

# ---   *   ---   *   ---
# sets up nodes such that:
#
# >clan
# \-->reg
# .  \-->proc
# .
# .
# \-->reg
# .
# >clan

sub hier_sort($self,$tree) {

  my $root=$tree;

  my $anchor=$root;
  my @anchors=($root,undef,undef,undef);

  my $scopers=qr/\b(clan|reg|rom|proc)\b/i;

# ---   *   ---   *   ---
# iter tree

  for my $leaf(@{$tree->{leaves}}) {
    if($leaf->{value}=~ $scopers) {
      my $match=$1;

# ---   *   ---   *   ---

      if(@anchors) {
        if($match=~ m[^clan$]i) {
          $anchors[1]=$leaf;
          $anchor=$root;

# ---   *   ---   *   ---

        } elsif($match=~ m[^(?:reg|rom)$]i) {
          $anchor=$anchors[1];
          $anchor//=$anchors[0];
          @anchors[2]=$leaf;

# ---   *   ---   *   ---

        } elsif($match=~ m[^proc$]i) {
          $anchor=$anchors[2];
          $anchor//=$anchors[1];
          $anchor//=$anchors[0];

          @anchors[3]=$leaf;

        };

# ---   *   ---   *   ---
# move node and reset anchor

      };

      if(

         defined $anchor
      && $leaf->{parent} ne $anchor

      ) {

        ($leaf)=$leaf->{parent}->pluck($leaf);
        $anchor->pushlv($leaf);

      };

      $anchor=$leaf;

# ---   *   ---   *   ---
# node doesn't modify anchor

    } elsif($leaf->{parent} ne $anchor) {
      ($leaf)=$leaf->{parent}->pluck($leaf);
      $anchor->pushlv($leaf);

    };

  };

};

# ---   *   ---   *   ---
1; # ret
