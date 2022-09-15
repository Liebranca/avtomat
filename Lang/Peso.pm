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
  use Type;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang;

  use parent 'Lang::Def';

  use Peso::Ops;
  use Peso::Defs;

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

  ];

# ---   *   ---   *   ---

  Readonly my $FCTL=>[

    Lang::insens('jmp'),
    Lang::insens('on'),
    Lang::insens('or'),

    Lang::insens('call'),
    Lang::insens('ret'),
    Lang::insens('wait'),

  ];

# ---   *   ---   *   ---
# missing/needs rethinking:
# str,buf,fptr,lis,lock

  Readonly my $INTRINSIC=>[

    Lang::insens('wed'),
    Lang::insens('unwed'),
    Lang::insens('ipol'),

    Lang::insens('in'),
    Lang::insens('out'),
    Lang::insens('xform'),

  ];

  Readonly my $SPECIFIER=>[

    Lang::insens('ptr'),
    Lang::insens('fptr'),

    Lang::insens('str'),
    Lang::insens('buf'),
    Lang::insens('tab'),

  ];

# ---   *   ---   *   ---
# UTILS

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

sub reorder($self,$tree) {

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
          $anchor//=$root;
          @anchors[2]=$leaf;

# ---   *   ---   *   ---

        } elsif($match=~ m[^proc$]i) {
          $anchor=$anchors[2];
          @anchors[3]=$leaf;

        };

# ---   *   ---   *   ---
# move node and reset anchor

      };

      if($leaf->{parent} ne $anchor) {
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

  $rd->recurse($tree);

# ---   *   ---   *   ---

  my @inputs=();

  for my $in_b($tree->branches_in(qr{^in$})) {

    my @l=map {$ARG->{value}} @{$in_b->{leaves}};

    my @data;
    my $type='bare';
    my $opt=0;

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

    for my $key(@data) {
      $code.='  uint64_t '.$key.'_id'.
        q{=*buff++;}."\n";

      $code.='  char* '.$key.'=get_keyw_or_val('.
        $key."_id);\n";

      push @inputs,$key;

    };

  };

# ---   *   ---   *   ---

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

  ext=>'\.(pe)$',
  hed=>'\$;',
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

sub hier_sort($self,$rd) {

  my $id='-ROOT';
  my $block=$rd->select_block($id);
  my $tree=$block->{tree};

  my $nd_frame=$tree->{frame};
  my @branches=$tree->branches_in(
    qr{^(?: reg|rom)$}xi

  );

  my $i=0;
  my @scopes=();

  for my $branch(@branches) {

    $branch->{parent}->idextrav();

    my $pkgname=$branch->{leaves}->[0]->{value};
    my $idex_beg=$branch->{idex};
    my @children=@{$tree->{leaves}};

# ---   *   ---   *   ---

    my $ahead=$branches[$i+1];
    my $idex_end;

    if(defined $ahead) {
      $idex_end=$ahead->{idex}-1;

    } else {
      $idex_end=$#children;

    };

# ---   *   ---   *   ---

    @children=@children[$idex_beg..$idex_end];
    @children=$tree->pluck(@children);

    my $pkgroot=$nd_frame->nit(
      undef,$branch->{value}

    );

    push @scopes,$pkgroot;

    $pkgroot->pushlv(@children);
    $pkgroot->{leaves}->[0]->flatten_branch();
    $i++;

# ---   *   ---   *   ---

  };

  $tree->pushlv(@scopes);

};

# ---   *   ---   *   ---
1; # ret
