#!/usr/bin/perl
# peso language pattern syntax

# ---   *   ---   *   ---
# deps
package langdefs::plps;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use lang;

  use peso::rd;
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

    [3,sub {

      my ($x)=@_;

      $$x->{optional}=1;
      return $$x;

    }],

    undef,
    undef,

# ---   *   ---   *   ---

  ],'+'=>[

    [3,sub {

      my ($x)=@_;

      $$x->{consume_equal}=1;
      return $$x;

    }],

    undef,
    undef,

  ],'--'=>[

    [3,sub {my ($x)=@_;$$x->{rewind}=1;return $$x;}],

    undef,
    undef,

# ---   *   ---   *   ---

  ],'|>'=>[

    [4,sub {my ($x)=@_;$$x->{space}=0;return $$x;}],

    undef,
    undef,

  ],'|->'=>[

    [4,sub {my ($x)=@_;$$x->{space}=2;return $$x;}],

    undef,
    undef,

# ---   *   ---   *   ---

  ],'%'=>[

    undef,
    undef,

    [5,sub {

      my ($x,$y)=@_;

      $$x->{name}=$$y;
      return $$x;

    }]

# ---   *   ---   *   ---

  ],']'=>[

    undef,
    undef,


    [5,sub {

      my ($x,$y)=@_;

      #:!!;> this is a hack as well
      my $s='int($prev_match=~ m/^'."$$x".'/);';

      return $s;

    }],

# ---   *   ---   *   ---


  ],'~'=>[

    undef,

    [6,sub {

      my ($x)=@_;

      $$x->{save_match}=0;
      return $$x;

    }],

    undef,


  ],'!'=>[

    undef,
    undef,

    [6,sub {

      my ($x,$y)=@_;
      $$y->{on_no_match}=$$x;

      return $$y;

    }],

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

  $program->{target_node}=$root;
  my @leaves=($node);

# ---   *   ---   *   ---
# iter all tree branches

  do {

    $node=shift @leaves;

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
      $v=$h->dup();

    };

# ---   *   ---   *   ---
# create instance

    if(defined $v) {

      if(plps_obj::valid($v)) {
        $node->value($v);

      } else {

        $node->value(
          plps_obj::nit($name,$v,$attrs,undef)

        );
      };

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

};

# ---   *   ---   *   ---
# exec language selection directive

sub getext($) {

  my $program=shift;
  my $SYMS=lang->plps->sbl->SYMS;

# ---   *   ---   *   ---
# iter tree to find 'in lang->$name'

  my @ar=$program->{tree}->branches_in('^in$');

  if(@ar==1) {

    my $node=shift @ar;

    $SYMS->{$node->value}->ex($node);
    $program->{tree}->pluck($node);

  } else {
    print STDERR
      "PLPS file lacking 'in' directive\n";

    exit;

  };

  $program->{tree}->cllv();
  $program->{tree}->idextrav();

};

# ---   *   ---   *   ---
# gets rid of executed branches

sub cleanup($) {

  my $program=shift;
  my @tree=();

  for my $node(@{$program->{tree}->leaves}) {

    my @ar=$node->branches_in('^beg$');
    if(@ar || $node->value ne 'end') {
      $program->{tree}->pluck($node);

    };

  };

  $program->{tree}->cllv();
  $program->{tree}->idextrav();
};

# ---   *   ---   *   ---

sub build {

  my $program=shift;
  lang->plps->sbl->setdef($program);

  $program->{dst}=undef;
  $program->{defs}={};

  getext($program);
  my $SYMS=lang->plps->sbl->SYMS;



  for my $node(@{$program->{tree}->leaves}) {

    if(exists $SYMS->{$node->value}) {
      $SYMS->{$node->value}->ex($node);

# ---   *   ---   *   ---
# build patterns from tree branches

    } else {

$node->prich();

      detag($program,$node);

      $node->collapse();
      $node->defield();

# ---   *   ---   *   ---
# write array of patterns to definitions

      my $name=$node->value;
      my @ar=();

      for my $leaf(@{$node->leaves}) {

        $leaf->value->{parent}
          =$program->{defs}->{$name};

        push @ar,$leaf->value;

      };

      $program->{target_node_value}=\@ar;

# ---   *   ---   *   ---
# tail

    };

  };cleanup($program);
  $program->{-RUN}=\&plps_obj::run;

};

# ---   *   ---   *   ---
# makes plps program for other langdefs

sub make($) {

  my $lang=shift;
  my $program=peso::rd::parse(

    lang->plps,

    peso::rd->FILE,
    $lang->{-PLPS},

  );lang->plps->build($program);

  return $program;

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
  $m->{defs}->{$f0}=$f1;

  $m->{dst}=[$f0,$f1];

};

# ---   *   ---   *   ---

DEFINE 'end',DIRECTIVE,sub {

  my ($inskey,$frame,@fields)=@_;
  my $m=$frame->master;

  my ($cath,$name)=@{$m->{dst}};
  $m->{target_node}->value($name);

# ---   *   ---   *   ---
# create new pattern instance from tree

  $m->{defs}->{$name}=plps_obj::nit(

    $name,
    $m->{target_node_value},
    $cath,
    undef

  );$m->{defs}->{$name}->walkdown();

  delete $m->{target_node};
  delete $m->{target_node_value};

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

  -DELIMITERS=>{

    '<'=>'>',
    '('=>')',

  },

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

  use Scalar::Util qw/blessed/;

# ---   *   ---   *   ---
# typechk

sub valid {

  my $obj=shift;if(

     blessed($obj)
  && $obj->isa('plps_obj')

  ) {

    return 1;
  };return 0;

};

# ---   *   ---   *   ---
# constructor

sub nit($$$$) {

  my ($name,$value,$attrs,$par)=@_;

  my $obj=bless {

    name=>$name,

    value=>$value,
    attrs=>$attrs,

    optional=>0,
    consume_equal=>0,
    rewind=>0,

    on_no_match=>undef,

    space=>1,
    matches=>[],
    save_match=>1,

    parent=>$par,

  },'plps_obj';

  return $obj;

# ---   *   ---   *   ---
# duplicates a pattern tree
#:!!!;> does heavy recursion

};sub dup($) {

  my $self=shift;

  my $compound=lang::is_arrayref(
    $self->{value}

  );

# ---   *   ---   *   ---
# create new instance

  my $cpy=nit(

    $self->{name},
    ($compound) ? [] : $self->{value},
    $self->{attrs},

    undef

  );

# ---   *   ---   *   ---
# copy settings

  $cpy->{optional}=$self->{optional};
  $cpy->{consume_equal}=$self->{consume_equal};
  $cpy->{rewind}=$self->{rewind};
  $cpy->{space}=$self->{space};

  $cpy->{on_no_match}=$self->{on_no_match};
  $cpy->{save_match}=$self->{save_match};

# ---   *   ---   *   ---
# make copy of object hierarchy

  if($compound) {

    for my $obj(@{$self->{value}}) {
      push @{$cpy->{value}},$obj->dup();

    };
  };

  return $cpy;

};

# ---   *   ---   *   ---
# builds hierarchy from top down

sub walkdown($) {

  my $self=shift;
  my $parent=undef;

  my @pending=($self);
  while(@pending) {

    $self=shift @pending;
    my $v=$self->{value};

    $self->{parent}=$parent;

    if(lang::is_arrayref($v)) {
      unshift @pending,@$v;
      $parent=$self;

    };

  };
};

# ---   *   ---   *   ---
# propagates matches upwards the hierarchy

sub regmatch($$$) {

  my ($self,$match,$looped)=@_;
  if(!$self->{save_match}) {return;};

  while(defined $self) {

    if(!$looped || !@{$self->{matches}}) {
      push @{$self->{matches}},$match;

    } else {
      $self->{matches}->[-1].=','.$match;

    };$self=$self->{parent};

  };
};

# ---   *   ---   *   ---
# get matches across the hierarchy

sub getmatch($) {

  my ($self,$program)=@_;
  my @pending=($self);

  my $root=$self;

  my $fr_node=$program->node;
  my $tree=$fr_node->nit(undef,$root->{name});

# ---   *   ---   *   ---

  while(@pending) {

    $self=shift @pending;
    my $v=$self->{value};

    if(lang::is_arrayref($v)) {

      if($self ne $root) {

        $tree=($tree->par)
          ? $tree->par
          : $tree
          ;

        $tree=$fr_node->nit($tree,$self->{name});

      };

      unshift @pending,@$v;

# ---   *   ---   *   ---

    } elsif($self->{save_match}) {

      my $leaf=$fr_node->nit($tree,$self->{name});
      for my $match(@{$self->{matches}}) {
        $fr_node->nit($leaf,$match);

      };

    };
  };

  $tree=(defined $tree->par)
    ? $tree->par
    : $tree
    ;

  return $tree;

};

# ---   *   ---   *   ---
# removes match history across the hierarchy

sub clean($) {

  my $self=shift;

  my @pending=($self);
  while(@pending) {

    $self=shift @pending;
    my $v=$self->{value};

    if(lang::is_arrayref($v)) {
      unshift @pending,@$v;

    };$self->{matches}=[];

  };
};

# ---   *   ---   *   ---
# executes a pattern tree

sub run {

  my $program=shift;

  my $key=shift;
  my $string=shift;

  my $root=$program->{defs}->{$key};

  my $obj=$root;
  my $prev_match=undef;

  my $last=undef;
  my $next=undef;

  my $looped=0;

  my @pending=($obj);

# ---   *   ---   *   ---
# iter/unpack patterns

  while(@pending) {

    $obj=shift @pending;
    my $pat=$obj->{value};

    # compound pattern, unpack
    if(lang::is_arrayref($pat)) {

      $next=$pending[0];

      unshift @pending,@$pat;
      $last=$obj;

# ---   *   ---   *   ---
# common pattern, attempt match

    } else {

      my $space='\s*';
      if($obj->{space}==0) {
        $space=''

      } elsif($obj->{space}==2) {
        $space='\s+'

      };

# ---   *   ---   *   ---

      REPEAT:
      my $match=int($string=~ s/^(${pat})${space}//s);

# ---   *   ---   *   ---
# early exit

      if(!$match) {

        if(defined $obj->{on_no_match} && !$looped) {
          if(eval($obj->{on_no_match})) {

            while($pending[0] ne $next) {

              $obj->regmatch('',$looped);
              $obj=shift @pending;

            };next;

          };
        };

# ---   *   ---   *   ---

        if($looped || $obj->{optional}) {
          $obj->regmatch('',$looped);

        } elsif(!$obj->{optional}) {
          goto END;

        };

# ---   *   ---   *   ---
# continuation modifiers

      } elsif($match) {

        $prev_match=$1;
        $obj->regmatch($1,$looped);

        if($obj->{consume_equal}) {
          $looped=1;
          goto REPEAT;

        };if($obj->{rewind}) {
          $looped=0;
          unshift @pending,($last,$obj);next;

        };

      };$looped=0;

# ---   *   ---   *   ---
# returns object with match details

    };
  };

  END:

  my $matches=$root->getmatch($program);
  my $full_match=!int(length $string);

  $matches->{full}=$full_match;
  $root->clean();

  return $matches;

};

# ---   *   ---   *   ---
