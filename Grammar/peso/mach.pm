#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO MACH
# Low-level subset
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

  our $VERSION = v0.00.2;#b
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

  Readonly our $REGEX=>{};

  # cstruc attrs of default parser
  Readonly my $DEF_CSTRUC=>{

    ext=>{
      $PE_COMMON=>[qw(lcom opt-nterm term)],

    },

    rules=>[
      '~<inskey>',
      '<ins> inskey opt-nterm term',

    ],

    core=>[qw(lcom ins)],

  };

  # test program
  Readonly our $BOOT=>q[

    clr   $00;

    cpy   ar,'crux';
    alloc xs,ar,$40;

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
# instruction post-parse

sub ins($self,$branch) {

  my $lv  = $branch->{leaves};
  my $key = $lv->[0]->leaf_value(0);

  # parse nterm
  my @eye=$PE_EYE->recurse(

    $lv->[1]->{leaves}->[0],

    mach       => $self->{mach},
    frame_vars => $self->Shared_FVars(),

  );

  # overwrite
  my $st={
    key  => $key,
    args => [$eye[0]->branch_values()],

  };

  $branch->clear();
  $branch->{value}=$st;

};

# ---   *   ---   *   ---
# ^solve args

sub ins_ctx($self,$branch) {

  my $st    = $branch->{value};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my @path  = $scope->path();

  # unpack args
  @{$st->{args}}=map {

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

  } @{$st->{args}};

};

# ---   *   ---   *   ---
# ^expand multi-part instructions

sub ins_opz($self,$branch) {

  my $st   = $branch->{value};

  my $key  = $st->{key};
  my @args = @{$st->{args}};

  my @ins  = ();

  # last argument is slurped into
  # multiple copies of instruction
  if(is_arrayref($args[-1])) {
    my $data=pop @args;
    @ins=map {[$key,@args,$ARG]} @$data;

  # ^single instruction
  } else {
    @ins=([$key,@args]);

  };

  $branch->{value}='ins';
  $branch->init(\@ins);

};

# ---   *   ---   *   ---
# ^merge branches

sub ins_pre($self,$branch) {

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

  # ^store merged
  $branch->{value}=\@ins;

};

# ---   *   ---   *   ---
# ^write instructions to segment

sub ins_ipret($self,$branch) {

  my $mach = $self->{mach};
  my @ins  = @{$branch->{value}};

  $mach->xs_write(@ins);

};

# ---   *   ---   *   ---
# ensure existance of default parser

  $PE_MACH->from_model(
    'default',%$DEF_CSTRUC

  ) unless $PE_MACH->dhave('default');

# ---   *   ---   *   ---
# ^test

my $mach=Mach->new();
$mach->parse($BOOT);

$mach->xs_run();
$mach->{reg}->{-seg}->prich();

my $mem=$mach->{scope}->get('SYS','crux');
   $mem=$mem->deref();

$mem->prich();

# ---   *   ---   *   ---
1; # ret
