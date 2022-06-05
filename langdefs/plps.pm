#!/usr/bin/perl
# peso language pattern syntax

# ---   *   ---   *   ---
# deps
package langdefs::plps;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use lang;
  use peso::sbl;

# ---   *   ---   *   ---
# translation table

use constant TRTAB=>{

  'type'=>'types',
  'spec'=>'specifiers',
  'bare'=>'names',
  'ode'=>'ode',
  'cde'=>'cde',

};

# ---   *   ---   *   ---
# shorthands

my $plps_sbl=undef;

sub DEFINE($$$) {

  $plps_sbl->DEFINE(
    $_[0],$_[1],$_[2],

  );
};

# ---   *   ---   *   ---

sub ALIAS($$) {

  $plps_sbl->DEFINE(
    $_[0],$_[1],$_[2],

  );
};

my $SBL_ID=0;sub sbl_id() {return $SBL_ID++;};

# ---   *   ---   *   ---

use constant plps_ops=>{

  '->'=>[

    undef,
    undef,

    [-1,sub {my ($x,$y)=@_;return "$$x->$$y";}],

  ],'?'=>[

    [0,sub {my ($x)=@_;$$x->{optional}=1;return $$x;}],
    undef,
    undef,

  ],'+'=>[

    [1,sub {my ($x)=@_;$$x->{consume_equal}=1;return $$x;}],

    undef,
    undef,

  ],'--'=>[

    [2,sub {my ($x)=@_;$$x->{rewind}=1;return $$x;}],

    undef,
    undef,

  ],

# ---   *   ---   *   ---

};use constant DIRECTIVE=>{

  'beg'=>[sbl_id,'1<type>:1<bare>'],
  'end'=>[sbl_id,'0'],

  'in'=>[sbl_id,'1<path>'],

};

# ---   *   ---   *   ---
# UTILITY CALLS

# ---   *   ---   *   ---
# converts <tags> into pattern objects

sub detag($$) {

  my ($program,$node)=@_;
  my $root=$node;

  my @leaves=($node);

# ---   *   ---   *   ---
# iter all tree branches

  do {

    $node=shift @leaves;

    # signals creation of compound pattern
    if($node->value eq 'end') {

      my ($cath,$name)=@{$program->{dst}};
      $root->value($name);

# ---   *   ---   *   ---
# create new pattern instance from tree

      $program->{defs}->{$name}
        =plps_obj::nit($name,[],$cath);

      ;goto END;

    };

# ---   *   ---   *   ---
# common pattern

    my $name=$node->value;
    my $tag=TRTAB->{$name};
    my $v=undef;
    my $attrs=undef;

    my $re=lang::cut_token_re;

# ---   *   ---   *   ---
# <tag> found

    if(defined $tag) {
      $v=$program->{ext}->$tag;
      $attrs=$tag;

      if(lang::is_hashref($v)) {
        $v=lang::hashpat($v);

      };

# ---   *   ---   *   ---
# string token found

    } elsif($node->value=~ m/${re}/) {

      $v=lang::stitch(
        $node->value,
        $program->{strings}

      );

      $v=~ s/^'//;
      $v=~ s/'$//;

      $attrs='string';

# ---   *   ---   *   ---
# reference to compound pattern found

    } elsif(defined

        $program->{defs}
        ->{$node->value}

    ) {

      my $h=$program->{defs}->{$node->value};

      $attrs=$h->{attrs};
      $v=$h->{value};

    };

# ---   *   ---   *   ---
# create instance

    if(defined $v) {

      $node->value(
        plps_obj::nit($name,$v,$attrs)

      );

# ---   *   ---   *   ---
# replace <tag> hierarchy with object instance

      if($node->par->value eq '<') {
        $node->par->repl($node);

      };

    };

# ---   *   ---   *   ---
# tail

    unshift @leaves,@{$node->leaves};
  } while(@leaves);

  END:return;

};

# ---   *   ---   *   ---
# exec language selection directive

sub getext($) {

  my $program=shift;
  my $SYMS=lang->plps->sbl->SYMS;

  my @tree=();

# ---   *   ---   *   ---
# iter tree to find 'in lang->$name'

  for my $node(@{$program->{tree}}) {

    my @ar=$node->branches_in('^in$');
    if(@ar) {
      $SYMS->{$node->value}->ex($node);

    } else {push @tree,$node;};

  };$program->{tree}=\@tree;

};

# ---   *   ---   *   ---
# gets rid of executed branches

sub cleanup($) {

  my $program=shift;
  my @tree=();

  for my $node(@{$program->{tree}}) {

    my @ar=$node->branches_in('^beg$');
    if(!@ar) {
      push @tree,$node;

    };

  };$program->{tree}=\@tree;
};

# ---   *   ---   *   ---

sub build {

  my $program=shift;
  lang->plps->sbl->setdef($program);

  $program->{dst}=undef;
  $program->{defs}={};

  getext($program);
  my $SYMS=lang->plps->sbl->SYMS;

  for my $node(@{$program->{tree}}) {

    if(exists $SYMS->{$node->value}) {
      $SYMS->{$node->value}->ex($node);

# ---   *   ---   *   ---
# build patterns from tree branches

    } else {

      detag($program,$node);

      $node->collapse();
      $node->defield();

# ---   *   ---   *   ---
# remove end marker once it's used

      my @ar=$node->branches_with('^end$');
      for my $leaf(@ar) {
        $leaf->pluck($leaf->leaves->[-1]);

      };

# ---   *   ---   *   ---
# write array of patterns to definitions

      my $name=$node->value;
      @ar=();for my $leaf(@{$node->leaves}) {
        push @ar,$leaf->value;

      };$program->{defs}->{$name}->{value}=\@ar;

# ---   *   ---   *   ---
# tail

    };

  };cleanup($program);
  $program->{-RUN}=\&plps_obj::run;

};

# ---   *   ---   *   ---

BEGIN {
$plps_sbl=peso::sbl::new_frame();

# ---   *   ---   *   ---

DEFINE 'beg',DIRECTIVE,sub {

  my ($inskey,$frame,@fields)=@_;
  my ($f0,$f1)=@fields;
  my $m=$frame->master;

  $f0=$f0->[0];
  $f1=$f1->[0];

  $m->{defs}->{$f1}=undef;
  $m->{dst}=[$f0,$f1];

};

# ---   *   ---   *   ---

DEFINE 'in',DIRECTIVE,sub {

  my ($inskey,$frame,@fields)=@_;
  my ($f0)=@fields;
  my $m=$frame->master;

  $f0=$f0->[0];

  #:!;> also a hack
  $m->{ext}=eval($f0);

};

# ---   *   ---   *   ---
# DEFS END
#
# ---   *   ---   *   ---
# INITIALIZE LANGUAGE
# ie, regify all of the above

# ---   *   ---   *   ---

lang::def::nit(

  -NAME=>'plps',

  -EXT=>'\.pe\.lps',
  -HED=>'\$:%plps;>',
  -MAG=>'Peso-style language patterns',

# ---   *   ---   *   ---

  -TYPES=>[qw(

    type spec dir itri

    sbl ptr bare
    sep del ari
    ode cde

    fctl sbl_decl ptr_decl pattern

  )],

  -DIRECTIVES=>[keys %{langdefs::plps->DIRECTIVE}],

  -SBL=>$plps_sbl,
  -BUILDER=>\&build,

# ---   *   ---   *   ---

  -ODE=>'[<]',
  -CDE=>'[>]',

  -DEL_OPS=>'[<>]',
  -NDEL_OPS=>'[?+-]',
  -OP_PREC=>plps_ops,

  -MCUT_TAGS=>[-CHAR],

);

};

# ---   *   ---   *   ---
1; # ret

# ---   *   ---   *   ---
# utility class

package plps_obj;
  use strict;
  use warnings;

sub nit($$) {

  my ($name,$value,$attrs)=@_;

  my $obj=bless {

    name=>$name,

    value=>$value,
    attrs=>$attrs,

    optional=>0,
    consume_equal=>0,
    rewind=>0,

    space=>2,

  },'plps_obj';

  return $obj;

};

# ---   *   ---   *   ---

sub run {

  my $program=shift;

  my $key=shift;
  my $string=shift;

  my $obj=$program->{defs}->{$key};
  my $last=undef;

  my @pending=($obj);

# ---   *   ---   *   ---
# iter/unpack patterns

  while(@pending) {

    $obj=shift @pending;
    my $pat=$obj->{value};

    # compound pattern, unpack
    if(lang::is_arrayref($pat)) {
      unshift @pending,@$pat;
      $last=$obj;

# ---   *   ---   *   ---
# common pattern, attempt match

    } else {

      REPEAT:

      my $match=int($string=~ s/^(${pat})\s*//);

      if(!$match && !$obj->{optional}) {
        return 1;

      } elsif($match && $obj->{consume_equal}) {
        goto REPEAT;

      } elsif($match && $obj->{rewind}) {
        unshift @pending,$last;next;

      };

# ---   *   ---   *   ---

    };
  };

  return int(length $string);
};

# ---   *   ---   *   ---
