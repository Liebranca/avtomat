#!/usr/bin/perl
# peso language pattern syntax

# ---   *   ---   *   ---
# deps
package langdefs::plps;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;

  use lang;

  use peso::rd;
  use peso::defs;

# ---   *   ---   *   ---
# translation table

use constant TRTAB=>{

  'ari'=>'ops',
  'ptr'=>'is_ptr&',
  'num'=>'is_num&',

  'type'=>'types',
  'spec'=>'specifiers',
  'bare'=>'names',
  'ode'=>'ode',
  'cde'=>'cde',

};

# ---   *   ---   *   ---

use constant plps_ops=>{

  q{->}=>[

    undef,
    undef,

    [-1,sub($x,$y) {return "$$x->$$y"}],

  ],q{?}=>[

    [3,sub($x) {

      $$x->{optional}=1;
      return $$x;

    }],

    undef,
    undef,

# ---   *   ---   *   ---

  ],q{+}=>[

    [3,sub($x) {

      $$x->{consume_equal}=1;
      return $$x;

    }],

    undef,
    undef,

  ],q{--}=>[

    [3,sub($x) {$$x->{rewind}=1;return $$x}],

    undef,
    undef,

# ---   *   ---   *   ---

  ],q{|>}=>[

    [4,sub($x) {$$x->{space}=0;return $$x}],

    undef,
    undef,

  ],q{|->}=>[

    [4,sub($x) {$$x->{space}=2;return $$x}],

    undef,
    undef,

# ---   *   ---   *   ---

  ],q{%}=>[

    undef,
    undef,

    [5,sub($x,$y) {

      $$x->{name}=$$y;
      return $$x;

    }]

# ---   *   ---   *   ---

  ],q{]}=>[

    undef,
    undef,


    [5,sub($x,$y) {

      #:!!;> this is a hack as well
      my $s='int($$prev_match=~ m/^'."$$x".'/);';

      return $s;

    }],

# ---   *   ---   *   ---


  ],q{~}=>[

    undef,

    [6,sub($x) {

      $$x->{save_match}=0;
      return $$x;

    }],

    undef,


  ],q{!}=>[

    undef,
    undef,

    [6,sub($x,$y) {

      $$y->{on_no_match}=$$x;
      return $$y;

    }],

  ],q{|}=>[

    undef,
    undef,

    [7,sub($x,$y) {return "$$x|$$y"}],

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
# finds value for a given tag

sub tagv($program,$tag) {

  my $string_re=lang::CUT_TOKEN_RE;
  my $v=undef;

# ---   *   ---   *   ---
# <tag> found

  if(exists TRTAB->{$tag}) {
    $tag=TRTAB->{$tag};

    if($tag=~ m/&$/) {
      $v=$program->{ext}->{$tag};

    } else {
      $v=$program->{ext}->$tag;

    };

    if(lang::is_hashref($v)) {
      $v=lang::hashpat($v);

    };

# ---   *   ---   *   ---
# string token found

  } elsif($tag=~ $string_re) {

    $v=lang::stitch($tag,$program->{strings});

    $v=~ s/^'//;
    $v=~ s/'$//;

# ---   *   ---   *   ---
# reference to compound pattern found

  } elsif(defined $program->{defs}->{$tag}) {

    my $h=$program->{defs}->{$tag};
    $v=$h->dup();

  };

# ---   *   ---   *   ---
# compile regexes if present

  $v=(

     defined $v

  && !plps_obj::valid($v)
  && !lang::is_coderef($v)

  ) ? qr/$v/ : $v;

  return $v;
};

# ---   *   ---   *   ---
# breaks down node into tags

sub decompose($program,$node) {

  my $name=$node->{value};
  my $altern=0;

# ---   *   ---   *   ---
# operator found

  my @patterns=();
  if($name=~ m/${\peso::node->OPERATOR}/) {

    # alternation
    if($name->{op} eq '|') {

      $altern=1;
      $node->collapse();
      $name=$node->{value};

      push @patterns,split '\|',$name;

      goto END;

    };

# ---   *   ---   *   ---
# common pattern

  };push @patterns,$name;

# ---   *   ---   *   ---

END:

  my @ar=map {tagv($program,$_);} @patterns;
  my @results=();

  for my $v(@ar) {
    if(defined $v) {
      push @results,$v;

    };
  };

  return ($name,$altern,@results);

};

# ---   *   ---   *   ---
# converts <tags> into pattern objects

sub detag($program,$node) {

  my $root=$node;

  $program->{target_node}=$root;
  my @leaves=($node);

# ---   *   ---   *   ---
# iter all tree branches

  while(@leaves) {

    $node=shift @leaves;

    my ($name,$altern,@patterns)=
      decompose($program,$node);

# ---   *   ---   *   ---
# create instance

    if(@patterns) {

      my $v=$patterns[0];

# ---   *   ---   *   ---
# corner case: <tag0|tag1>

      if($altern) {
        $node->{value}=
          plps_obj::nit($name,undef,undef)

        ;

        $node->{value}->{altern}=\@patterns;

# ---   *   ---   *   ---
# compound object

      } elsif(plps_obj::valid($v)) {
        $node->{value}=$v;

# ---   *   ---   *   ---
# standard object

      } else {
        $node->{value}=
          plps_obj::nit($name,$v,undef);

      };

# ---   *   ---   *   ---
# replace <tag> hierarchy with object instance

      if($node->{par}->{value} eq '<') {
        $node->{par}->repl($node);

      };

    };

# ---   *   ---   *   ---
# tail

    unshift @leaves,@{$node->{leaves}};
  };

};

# ---   *   ---   *   ---
# exec language selection directive

sub getext($program) {

  my $SYMS=lang->plps->sbl->SYMS;

# ---   *   ---   *   ---
# iter tree to find 'in lang->$name'

  my @ar=$program->{tree}->branches_in('^in$');

  if(@ar==1) {

    my $node=shift @ar;

    $SYMS->{$node->{value}}->ex($node);
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

sub cleanup($program) {

  my @tree=();

  for my $node(@{$program->{tree}->{leaves}}) {

    my @ar=$node->branches_in('^(beg|end)$');

    if(@ar) {
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

  getext($program);
  my $SYMS=lang->plps->sbl->SYMS;

  for my $node(@{$program->{tree}->{leaves}}) {

    if(exists $SYMS->{$node->{value}}) {
      $SYMS->{$node->{value}}->ex($node);

# ---   *   ---   *   ---
# build patterns from tree branches

    } else {

      detag($program,$node);

      $node->collapse();
      $node->defield();

# ---   *   ---   *   ---
# write array of patterns to definitions

      my @ar=();
      my ($cath,$name)=@{$program->{dst}};

      for my $leaf(@{$node->{leaves}}) {

        $leaf->{value}->{parent}
          =$program->{defs}->{$name};

        push @ar,$leaf->{value};

      };

      $program->{target_node_value}=\@ar;

# ---   *   ---   *   ---
# tail

    };
  };

  cleanup($program);
  $program->set_entry(\&plps_obj::run);

};

# ---   *   ---   *   ---
# makes plps program for other langdefs

sub make($lang) {

  my $program=peso::rd::parse(

    lang->plps,

    peso::rd->FILE,
    $lang->{-PLPS},

  );lang->plps->build($program);

  return $program;

};

# ---   *   ---   *   ---

BEGIN {
  sbl_new(0);

# ---   *   ---   *   ---

DEFINE 'beg',DIRECTIVE,sub {

  my ($inskey,$frame,@fields)=@_;
  my ($f0,$f1)=@fields;
  my $m=$frame->master;

  $f0=$f0->[0];
  $f1=$f1->[0];

  $m->{defs}->{$f1}=undef;

  if(!exists $m->{defs}->{$f0}) {
    $m->{defs}->{$f0}=[];

  };

  push @{$m->{defs}->{$f0}},0x00;
  $m->{dst}=[$f0,$f1];

};

# ---   *   ---   *   ---

DEFINE 'end',DIRECTIVE,sub {

  my ($inskey,$frame,@fields)=@_;
  my $m=$frame->master;

  my ($cath,$name)=@{$m->{dst}};
  $m->{target_node}->{value}=$name;

# ---   *   ---   *   ---
# create new pattern instance from tree

  my $obj=plps_obj::nit(

    $name,
    $m->{target_node_value},
    $cath

  );$obj->walkdown();
  $obj->{tree}=$obj->mktree($m);

  $m->{defs}->{$name}=$obj;
  $m->{defs}->{$cath}->[-1]=$obj;

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

  -EXT=>'\.lps',
  -HED=>'\$:%plps;>',
  -MAG=>'Peso-style language patterns',

# ---   *   ---   *   ---

  -TYPES=>[qw(

    type spec dir itri

    sbl ptr bare
    sep del ari
    ode cde num

    fctl sbl_decl ptr_decl pattern
    type_decl

  )],

  -DIRECTIVES=>[keys %{&DIRECTIVE}],

  -SBL=>$SBL_TABLE,
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

sub valid($obj) {

  if(

     blessed($obj)
  && $obj->isa('plps_obj')

  ) {

    return 1;
  };return 0;

};

# ---   *   ---   *   ---
# constructor

sub nit($name,$value,$par) {

  my $obj=bless {

    name=>$name,
    value=>$value,
    altern=>undef,

    optional=>0,
    consume_equal=>0,
    rewind=>0,

    on_no_match=>undef,

    space=>1,
    matches=>[],
    save_match=>1,

    parent=>$par,

    nxt=>undef,
    prv=>undef,
    looped=>0,

  },'plps_obj';

  return $obj;

# ---   *   ---   *   ---
# duplicates a pattern tree
#:!!!;> does heavy recursion

};sub dup($self) {

  my $cpy=nit($self->{name},undef,undef);

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

  my $v=$self->{value};

  # value is another object
  if(lang::is_arrayref($v)) {
    $cpy->{value}=[map {$_->dup();} @$v];

# ---   *   ---   *   ---
# value is an alternator

  } elsif(!defined $v) {

    $cpy->{altern}=[];
    for my $p(@{$self->{altern}}) {

      if(valid $p) {
        push @{$cpy->{altern}},$p->dup();

      } else {
        push @{$cpy->{altern}},$p;

      };

    };

# ---   *   ---   *   ---
# value is plain pattern

  } else {
    $cpy->{value}=$v;

  };return $cpy;

};

# ---   *   ---   *   ---
# builds hierarchy from top down

sub walkdown($self) {

  my $parent=undef;
  my $root=$self;

  my @pending=($self);
  my @anchors=();

  while(@pending) {

    $self=shift @pending;
    if(!$self) {
      $parent=shift @anchors;
      next;

    };

    $self->{parent}=$parent;

    my $v=$self->{value};

    if(lang::is_arrayref($v)) {
      unshift @pending,(@$v,0);
      unshift @anchors,$parent;

      $parent=$self;

    };
  };
};

# ---   *   ---   *   ---
# breaks down an object into a tree

sub mktree($root,$program) {

  my $frame=peso::node::new_frame($program);

  my $tree=$frame->nit(undef,$root);
  my @objs=[$root,$tree];

# ---   *   ---   *   ---
# walk the hierarchy

  while(@objs) {
    my ($obj,$anchor)=@{(shift @objs)};

# ---   *   ---   *   ---
# unpack this object

    for my $v(@{$obj->{value}}) {

# ---   *   ---   *   ---
# go one level deeper (compound object)

      if(lang::is_arrayref($v->{value})) {

        my $node=$frame->nit(
          $anchor,$v

        );push @objs,[$v,$node];

# ---   *   ---   *   ---
# alternators (<pattern | pattern>)

      } elsif(!defined $v->{value}) {

        my $node=$frame->nit($anchor,$v);

        for my $option(@{$v->{altern}}) {

          if(valid $option) {

            my $branch=$frame->nit(
              $node,$option

            );push @objs,[$option,$branch];

          } else {
            $frame->nit($node,$option);

          };
        };

# ---   *   ---   *   ---
# register pattern (base <tag>)

      } else {

        my $node=$frame->nit($anchor,$v);
        $frame->nit($node,$v->{value});

      };
    };
  };

# ---   *   ---   *   ---
# setup markers between objects

  my @leaves=($tree);
  while(@leaves) {

    my $branch=shift @leaves;

    my @ar=(valid $branch->{value})
      ? (@{$branch->{leaves}})
      : ()
      ;

# ---   *   ---   *   ---
# we want a prev->node->next chain

    my $i=0;while($i<@ar) {

      if(!valid $ar[$i]->{value}) {
        goto SKIP;

      };

      my $prv=($i>0) ? $ar[$i-1] : undef;
      my $nxt=($i<$#ar) ? $ar[$i+1] : undef;

      $ar[$i]->{value}->{prv}=(defined $prv)
        ? $prv->{value} : undef;

      $ar[$i]->{value}->{nxt}=(defined $nxt)
        ? $nxt->{value} : undef;

      $ar[$i]->{value}->{tree}=$ar[$i];

      SKIP:$i++;

# ---   *   ---   *   ---

    };push @leaves,@{$branch->{leaves}};
  };return $tree;
};

# ---   *   ---   *   ---
# propagates matches upwards the hierarchy

sub regmatch($self,$match) {

  if(!$self->{save_match}) {return;};

  while(defined $self) {

    if(!$self->{looped} || !@{$self->{matches}}) {
      push @{$self->{matches}},$match;

    } else {
      $self->{matches}->[-1].=','.$match;

    };$self=$self->{parent};

  };
};

# ---   *   ---   *   ---
# get matches across the hierarchy

sub getmatch($self,$program) {

  my @pending=($self);
  my $root=$self;

  my $fr_node=$program->node;
  my $tree=$fr_node->nit(undef,$root->{name});
  my $top=$tree;

# ---   *   ---   *   ---

  while(@pending) {

    $self=shift @pending;
    if(!$self) {
      $tree=(defined $tree->{par})
        ? $tree->{par}
        : $tree
        ;

      next;

    };

# ---   *   ---   *   ---

    my $v=$self->{value};

    if( lang::is_arrayref($v)) {

      if($self ne $root) {
        $tree=$fr_node->nit($tree,$self->{name});

      };unshift @pending,(@$v,0);

# ---   *   ---   *   ---

    } elsif($self->{save_match}) {

      my $leaf=$fr_node->nit($tree,$self->{name});
      for my $match(@{$self->{matches}}) {
        $fr_node->nit($leaf,$match);

      };
    };
  };

# ---   *   ---   *   ---

  return $top;

};

# ---   *   ---   *   ---
# removes match history across the hierarchy

sub clean($self) {

  my @pending=($self);
  while(@pending) {

    $self=shift @pending;
    my $v=$self->{value};

    if(lang::is_arrayref($v)) {
      unshift @pending,@$v;

    };

    $self->{matches}=[];
    $self->{looped}=0;

  };
};

# ---   *   ---   *   ---

sub trymatch(@args) {

  my ($obj,$program,$string,$pat,$prev_match)=@args;

  my $match=0;
  my $status=0;

# ---   *   ---   *   ---

  my $space='\s*';
  if($obj->{space}==0) {
    $space=''

  } elsif($obj->{space}==2) {
    $space='\s+'

  };

  my ($prev,$next)=($obj->{prv},$obj->{nxt});

# ---   *   ---   *   ---
# textual pattern

  my $matfn=sub {

    $match=int($$string=~ s/^(${pat})(${space})?//s);
    $status|=$match!=0;
    $$prev_match=(defined $1) ? $1 : $$prev_match;

  };

# ---   *   ---   *   ---
# coderef call

  if(lang::is_coderef($pat)) {

    $matfn=sub {

      $match=$pat->(
        $program->{ext},
        $string,$program

      );

      if(length $match) {
        $$string=~ s/^(${space})?//s;
        $$prev_match=$match;

        $status|=1;

      };

    };
  };

# ---   *   ---   *   ---

  REPEAT:
  $matfn->($$string);

# ---   *   ---   *   ---
# early exit

  if(!$match) {

    if(

       defined $obj->{on_no_match}
    && !$obj->{looped}

    ) {

      if(eval($obj->{on_no_match})) {

        $status|=1|4;

        while($obj->{nxt}) {
          $obj->regmatch('');
          $obj=$obj->{nxt};

        };

        goto END;

      };
    };

# ---   *   ---   *   ---
# register blanks on optional/abort if mandatory

    if($obj->{looped} || $obj->{optional}) {
      $obj->regmatch('');
      $status|=1;

    } elsif(!$obj->{optional}) {
      goto END;

    };

# ---   *   ---   *   ---
# continuation modifiers

  } elsif($match) {

    $obj->regmatch($$prev_match);

    if($obj->{consume_equal}) {
      $obj->{looped}=1;
      goto REPEAT;

    };if($obj->{rewind}) {
      $status|=2;
      goto END;

    };
  };

# ---   *   ---   *   ---

  END:

  $obj->{looped}=0;
  return $status;

};

# ---   *   ---   *   ---
# fails match if path is not declared optional
# somewhere upwards the hierarchy

sub optional_branch($self) {

  my $optional=0;

  while($self->{parent}) {
    $self=$self->{parent};

    if(!$self->{parent} || $optional) {last;};
    $optional=$self->{optional};

  };

  return $optional;

};

# ---   *   ---   *   ---
# executes block from a plps program

sub run {

  my ($program,$key,$string)=@_;
  my $root=$program->{defs}->{$key};

  # TODO: iter through these
  if(lang::is_arrayref($root)) {
    $root=$root->[-1];

  };

  my $tree=$root->{tree};

  my $early_exit=0;
  my $prev_match='';

  my @leaves=($tree);

# ---   *   ---   *   ---
# walk the tree

  while(@leaves) {

    my $node=shift @leaves;

    if(!@{$node->{leaves}}) {

      my $obj=$node->{par}->{value};
      my $pat=$node->{value};

      my $status=$obj->trymatch(

        $program,

        \$string,$pat,\$prev_match,

      );

      my $end=(defined $obj->{altern})
        ? $node eq $node->{par}->{leaves}->[-1]
        : 1
        ;

# ---   *   ---   *   ---
# dont attempt further matches

      if(!$status && $end) {

        if(!$obj->optional_branch) {
          $early_exit=1;
          last;

# ---   *   ---   *   ---
# field is optional

        } else {
          while($obj->{nxt}) {
            $obj->regmatch('');
            $obj=$obj->{nxt};

            shift @leaves;

          };$obj->regmatch('');

        };

# ---   *   ---   *   ---
# go to previous field

      } elsif($status&2) {

        unshift @leaves,(
          $obj->{prv}->{tree},$node

        );

# ---   *   ---   *   ---
# go to next field

      } elsif($status&4) {
        next;

      } elsif(

           $status&1
        && defined $obj->{altern}

      ) {

        while($node ne $node->{par}->{leaves}->[-1]) {
          $node=shift @leaves;

        };

      };

# ---   *   ---   *   ---

    } else {
      unshift @leaves,@{$node->{leaves}};

    };
  };

# ---   *   ---   *   ---
# return a tree with the matches

  END:

  my $matches=$root->getmatch($program);
  my $full_match=!int(length $string);

  $matches->{full}=$full_match;
  $root->clean();

  return $matches;

};

# ---   *   ---   *   ---
