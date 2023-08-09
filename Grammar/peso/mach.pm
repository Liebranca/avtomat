#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO MACH
# Low-level core
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::mach;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::Bytes;
  use Arstd::String;
  use Arstd::Re;
  use Arstd::IO;
  use Arstd::PM;

  use Tree::Grammar;
  use Mach;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang;

  use Grammar 'dynamic';
  use Grammar::peso::common;
  use Grammar::peso::eye;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw($PE_MACH);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# inherits from

  submerge(

    [qw(

      Grammar::peso::value

    )],

    xdeps=>1,
    subex=>qr{^throw_},

  );

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) { return {

    -creg   => undef,
    -cclan  => 'non',
    -cproc  => undef,

    -cdecl  => [],

    %{$PE_COMMON->Frame_Vars()},

  }};

  sub Shared_FVars($self) { return {
    %{Grammar::peso::eye::Shared_FVars($self)},

  }};

  Readonly our $PE_MACH=>
    'Grammar::peso::mach';

  Readonly our $REGEX=>{

    colon  => re_nonscaped(':'),
    ncolon => re_escaped(':',mod=>'+'),

  };

  # cstruc attrs of default parser
  Readonly my $DEF_CSTRUC=>{

    ext=>{
      $PE_COMMON=>[qw(lcom opt-nterm term)],

    },

    rules=>[

      '~<colon> &term',
      '~<ncolon>',

      '<label> &label ncolon colon',

      '~<inskey>',
      '<ins> inskey opt-nterm term',

    ],

    core=>[qw(lcom label ins)],

  };

  # test program
  Readonly our $BOOT=>q[

  .boot:

    clr   .boot;

#    cpy   ar,'crux';
#    alloc xs,ar,$40;

  ];

# ---   *   ---   *   ---
# make dynamic grammar from mach model

sub from_model($class,$name,%O) {

  # defaults
  $O{dom}   //= $class;
  $O{ext}   //= {};
  $O{rules} //= [];
  $O{core}  //= [];

  my $mach=Mach->fetch(0,model=>$name);
  my $self=$class->dnew($name,dom=>$O{dom});


  # ^nit retab
  $self->{regex}={

    %$REGEX,
    inskey=>$mach->{optab}->{re},

  };

  # ^run rule imports
  map {

    $self->dext_rules(
      $ARG,@{$O{ext}->{$ARG}}

    )

  } keys %{$O{ext}};

  # ^nit local rules
  map {$self->drule($ARG)} @{$O{rules}};
  $self->mkrules(@{$O{core}});


  return $self;

};

# ---   *   ---   *   ---
# ^ensure existance of default parser

  $PE_MACH->from_model(
    'default',%$DEF_CSTRUC

  ) unless $PE_MACH->dhave('default');

# ---   *   ---   *   ---
# post-parse for [not-colon] :

sub label($self,$branch) {

  my $lv   = $branch->{leaves};
  my $name = $lv->[0]->leaf_value(0);

  my $st={

    name => $name,

    cap  => 0,
    pos  => 0,

    lvl  => 0,

    pen  => [],

  };

  $branch->clear();
  $branch->init($st);

};

# ---   *   ---   *   ---
# ^hierarchical sort

sub label_ctx($self,$branch) {

  state $re=qr{^label$};

  my $par = $branch->{parent};
  my $st  = $branch->leaf_value(0);

  $branch->clear();


  # get every node from self
  # up to next label, exclusive
  my @lv=$branch->match_up_to($re);

  # ^parent nodes
  $branch->pushlv(@lv);
  $branch->{value}=$st;

};

# ---   *   ---   *   ---
# ^set byte offset for next label

sub label_ord($self,$branch) {
  $self->label_get_pos($branch);
  $self->label_tmp_asg($branch);

};

# ---   *   ---   *   ---
# ^calculate offset for next label

sub label_get_pos($self,$branch) {

  my $st    = $branch->{value};
  my $ahead = $branch->next_branch();

  # do nothing on last label
  if(defined $ahead) {

    $ahead->{value}->{pos}=
      $st->{cap}
    + $st->{pos}
    ;

  };

};

# ---   *   ---   *   ---
# ^store label value in tmp

sub label_tmp_asg($self,$branch) {

  my $st    = $branch->{value};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my @path  = ('$tmp',$st->{name});

  (! $scope->has(@path))
    ? $scope->decl(\$st->{pos},@path)
    : $scope->asg(\$st->{pos},@path)
    ;

};

# ---   *   ---   *   ---
# adjust label pos as
# codesize shrinks

sub label_cl($self,$branch) {

  my $st    = $branch->{value};
  my $pen   = $st->{pen};

  my $i=0;

REPEAT:

  map {$self->blk_repl($ARG)} @$pen;

  goto REPEAT if $i++ < 1;

  exit;

};

# ---   *   ---   *   ---
# re-encodes instructions in
# block after value expansion

sub blk_repl($self,$branch) {

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $cst   = $branch->{value};
  my @raw   = @{$cst->{raw}};

  my @new   = @{$cst->{pen}};
  my @old   = @new;


  # fetch previously unresolved symbols
  @new=map {
    $scope->get('$tmp',$ARG->{raw})

  } @new;

  # ^replace within instruction array
  my @cooked=map {[

    map {
      my $x=$ARG;

      # if X refers to one of those
      # previoulsy unresolved...
      map {
        $x=${$new[$ARG]}
        if $x eq $old[$ARG];

      } 0..$#new;

      $x;

    } @$ARG

  ]} @raw;


  # ^encode with the updated instructions
  $self->ins_encode($branch,@cooked);

};

# ---   *   ---   *   ---
# instruction post-parse
# solve flat args at this stage

sub ins($self,$branch) {

  my $lv  = $branch->{leaves};
  my $key = $lv->[0]->leaf_value(0);

  # parse nterm
  my @eye=$PE_EYE->recurse(

    $lv->[1]->{leaves}->[0],

    mach       => $self->{mach},
    frame_vars => $self->Shared_FVars(),

  );


  # ^proc args
  my @args = $eye[0]->branch_values();
     @args = $self->ins_unpack_args(@args);

  my @ins  = $self->ins_expand($key,@args);


  # ^store
  $branch->clear();

  $branch->{value}='ins';
  $branch->init(\@ins);

};

# ---   *   ---   *   ---
# ^unpack instruction args

sub ins_unpack_args($self,@args) {

  return map {

    my $value=$self->deref($ARG,ptr=>1);

    # convert string to bytes
    if($ARG->{type} eq 'str') {
      [lmord($value)];

    } elsif($ARG->{type} eq 'num') {
      $value->{raw};

    # ^as-is
    } else {
      $value;

    };

  } @args;

};

# ---   *   ---   *   ---
# ^expand multi-part instructions

sub ins_expand($self,$key,@args) {

  my @out=();

  # last argument is slurped into
  # multiple copies of instruction
  if(is_arrayref($args[-1])) {
    my $data=pop @args;
    @out=map {[$key,@args,$ARG]} @$data;

  # ^single instruction
  } else {
    @out=([$key,@args]);

  };

  return @out;

};

# ---   *   ---   *   ---
# ^encode instructions
# then merge branches

sub ins_ctx($self,$branch) {

  my @ins=$self->ins_merge($branch);
  my @pen=$self->ins_pending($branch,@ins);

  # save initial state
  $branch->{value}={

    raw=>\@ins,
    enc=>undef,

    pen=>\@pen,

  };

  my $st=$branch->{value};


  # notify parent of recalcs in Q
  my $par=$branch->{parent};
  my $pst=$par->{value};

  push @{$pst->{pen}},$branch
  if @{$st->{pen}};


  # run first encoding pass
  $self->ins_encode($branch,@ins);

};

# ---   *   ---   *   ---
# ^does the merging

sub ins_merge($self,$branch) {

  state $re=qr{^ins$};

  # get ins branches in block
  my $par=$branch->{parent};
  my @blk=$par->branches_in($re);

  # ^merge values
  my @ins=map {
    @{$ARG->leaf_value(0)}

  } @blk;

  # ^pop all but first from block
  $par->pluck(grep {$ARG ne $branch} @blk);

  return @ins;

};

# ---   *   ---   *   ---
# ^get value expansions pending

sub ins_pending($self,$branch,@ins) {

  return grep {$ARG} map {

    grep {
      Mach::Value->is_valid($ARG);

    } @$ARG

  } @ins;

};

# ---   *   ---   *   ---
# ^encode and store merged
# ins branches

sub ins_encode($self,$branch,@ins) {

  my $par  = $branch->{parent};
  my $pst  = $par->{value};
  my $st   = $branch->{value};


  # run encoder
  my $mach=$self->{mach};

  my ($cap,@opcodes)=
    $mach->xs_encode(@ins);

  # ^store encoded and size
  $st->{enc}  = \@opcodes;
  $pst->{cap} = $cap;

};

# ---   *   ---   *   ---
# ^test

my $mach=Mach->new();
$mach->parse($BOOT);

$mach->xs_run();
$mach->{reg}->{-seg}->prich();

#my $mem=$mach->{scope}->get('SYS','crux');
#   $mem=$mem->deref();
#
#$mem->prich();

# ---   *   ---   *   ---
1; # ret
