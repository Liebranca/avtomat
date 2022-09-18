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

      if(

         defined $anchor
      && $leaf->{parent} ne $anchor

      ) {

#        ($leaf)=$leaf->{parent}->pluck($leaf);
#        $anchor->pushlv($leaf);

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

sub preproc($self,$tree) {

  state $lib_re=qr{^lib$}ix;
  state $imp_re=qr{^import$}ix;
  state $dcolon_re=qr{::}x;

  for my $branch($tree->branches_in($lib_re)) {

    my $beg=$branch->{idex};
    my $par=$branch->{parent};

    my ($env,$subdir)=map {
      $ARG->{value}

    } @{$branch->{leaves}};

    my $path=$ENV{$env}.rmquotes($subdir);

    my $imp_nd=$par->match_from(
      $branch,$imp_re

    );

    if(!defined $imp_nd) {

      errout(
        q{No matching 'import' directive }.
        q{for lib call on %s},

        args=>[$path],
        lvl=>$AR_FATAL

      );

      exit(1);

    };

# ---   *   ---   *   ---

    my @uses=$par->leaves_between(
      $beg,$imp_nd->{idex}

    );

    @uses=grep {$ARG->{value} ne ';'} @uses;

    for my $f(@uses) {

      my ($ext,$name)=(
        $f->{leaves}->[0]->{value},
        $f->{leaves}->[1]->{value},

      );

      $name=~ s[$dcolon_re][/]sxmg;

      my $fpath=$path.$name.rmquotes($ext);

      my $rd=Peso::Rd::parse($self,$fpath);
      my $blk=$rd->select_block(-ROOT);

      $blk->{tree}->prich();

    };

  };

};

# ---   *   ---   *   ---

sub expsplit($self,$tree) {

  state $scopers=qr/\b(clan|reg|rom|proc)\b/i;

  my $op=$self->{ops};
  my $keyword=$self->{keyword_re};

  my @pending=@{$tree->{leaves}};

  my $anchor=undef;

  while(@pending) {

    my $nd=shift @pending;

    if($nd->{value}=~ $scopers) {
      goto TAIL;

    };

    my $is_op=$nd->{value}=~ m[^$op$];

# ---   *   ---   *   ---

    if(

       $is_op && defined $anchor
    && $anchor->{parent}==$nd->{parent}

    ) {

      $anchor->{parent}->idextrav();

      my $beg=$anchor->{idex};
      my $end=$nd->{idex};

      my @ar=$nd->{parent}->leaves_between(
        $beg,$end

      );

      $anchor->pushlv(@ar);
      $anchor=undef;

# ---   *   ---   *   ---

    } elsif(

       !defined $anchor
    || $anchor->{parent} != $nd->{parent}

    ) {

      if(defined $anchor) {

        $anchor->{parent}->idextrav();

        my $beg=$anchor->{idex};
        my $end=$anchor->{parent}
          ->match_from($anchor,qr{^;$});

        if(!defined $end) {

          $end=$anchor->{parent}
            ->{leaves}->[-1];

          $end=$end->{idex}+1;

        } else {
          $end=$end->{idex};

        };

        my @ar=$anchor->{parent}
          ->leaves_between($beg,$end);

        $anchor->pushlv(@ar);

      };

# ---   *   ---   *   ---

      if($nd->{value}=~ m[^$keyword$]) {
        $anchor=$nd;

      };

# ---   *   ---   *   ---

    };

TAIL:

    unshift @pending,@{$nd->{leaves}};

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

  $self->expsplit($tree);
  $tree->subdiv();

  $self->preproc($tree);

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
