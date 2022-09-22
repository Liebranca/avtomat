#!/usr/bin/perl
# ---   *   ---   *   ---
# EX
# Holds processed blocktrees
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Peso::Ex;

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

  use Chk;
  use Type;

  use Tree::Syntax;
  use Peso::Rd;

  use Lang;
  use Lang::Peso;

  use lib $ENV{'ARPATH'}.'/lib/hacks';
  use Shwl;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.50.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# shorthand

  my $peso=Lang->Peso;

# ---   *   ---   *   ---
# ROM

  my $Lan={};
  my $CM_RE;

# ---   *   ---   *   ---
# global kick

sub nit($class) {

  my $self=bless {

    loaded=>[],

    defs=>{},

    clans=>{},
    procs=>{},

    mems=>{},
    regs=>{},
    roms=>{},

    nxins=>undef,
    pass=>0,

    tree=>undef,

    node=>Tree::Syntax->new_frame(
      -lang=>$peso

    ),

    -nocase=>{},

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# turns a peso file into an instance
# of this class

sub fopen($self,$fpath) {

  # get raw program tree
  my $rd=Peso::Rd::parse($peso,$fpath);

  my $blk=$rd->select_block(-ROOT);
  my $tree=$blk->{tree};

  # sort tree nodes into a block hierarchy
  $peso->hier_sort($tree);

  # expand string/delim tokens
  $rd->replstr($tree);
  $rd->recurse($tree);

  # run the preprocessor
  $self->preproc($tree);
  $self->expsplit($tree);

  # sort operators by priority
  $tree->subdiv();

  # get rid of commas
  $tree->collapse(
    only=>qr{,}x,
    no_numcon=>1

  );

  return ($tree,$rd);

};

# ---   *   ---   *   ---
# yes, this is the entire peso preprocessor
# it's "short" size due to the fact
# I'm only handling imports for now

sub preproc($self,$tree) {

  state $lib_re=qr{^lib$}ix;
  state $imp_re=qr{^import$}ix;
  state $dcolon_re=qr{::}x;

# ---   *   ---   *   ---
# get DIRECTIVE [args]

  for my $branch($tree->branches_in($lib_re)) {

    my $beg=$branch->{idex};
    my $par=$branch->{parent};

    # arg0,arg1
    my ($env,$subdir)=map {
      $ARG->{value}

    } @{$branch->{leaves}};

    # de-stringify (unstirr ;>)
    my $path=$ENV{$env}.rmquotes($subdir);

    # seek to closing directive
    my $imp_nd=$par->match_from(
      $branch,$imp_re

    );

# ---   *   ---   *   ---
# throw missing closer

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
# grab nodes between open and close

    my @uses=$par->leaves_between(
      $beg,$imp_nd->{idex}

    );

    # discard terminators
    @uses=grep {$ARG->{value} ne ';'} @uses;

# ---   *   ---   *   ---
# break down the inputs

    for my $f(@uses) {

      my ($ext,$name)=(
        $f->{leaves}->[0]->{value},
        $f->{leaves}->[1]->{value},

      );

      $name=~ s[$dcolon_re][/]sxmg;

# ---   *   ---   *   ---
# cat inputs

      my $fpath=$path.$name.rmquotes($ext);
      my $keys={ @{$self->{loaded}} };

      # paste if not already pasted
      if(!exists $keys->{"$fpath"}) {

# ---   *   ---   *   ---
# fopen calls preproc, thus:
#:!!!;> recursive paste

        my ($btree,$brd)=$self->fopen($fpath);

# ^if you know a better way...
# ... then i'd love to know

# else ~ S H U T  I T ~

# ---   *   ---   *   ---
# replace directive with generated tree

        push @{$self->{loaded}},$fpath=>1;

        $f->repl($btree);
        $btree->flatten_branch();

      };

# ---   *   ---   *   ---
# wipe directives from tree

    };

  };

  $tree->pluck(
    $tree->branches_in($lib_re),
    $tree->branches_in($imp_re)

  );

};

# ---   *   ---   *   ---
# ufff, jesus christ...
#
# this sub takes care of that annoying design
# compromise **I made** in letting the
# tokenizer not care for recursive use of
# keywords, just to avoid messing up the
# tree structure at the earliest stage;
#
# why did I do that? because the structure
# isn't the same for every language, and Rd IS
# a MULTI LINGUAL PARSER
#
# get that? it has to work for different syntaxes
# and thus cannot be specific enough: the tree
# structure must be the most basic possible
# just for the system to merely function
#
# therefore, patches like these are needed
# in order to provide that specificity

sub expsplit($self,$tree) {

  state $scopers=qr/\b(clan|reg|rom|proc)\b/i;

  my $op=$peso->{ops};
  my $keyword=$peso->{keyword_re};

  my @pending=@{$tree->{leaves}};

  my $anchor=undef;

# ---   *   ---   *   ---
# walk the hierarchy

  while(@pending) {

    my $nd=shift @pending;

    # assumed to already be head of branch
    if($nd->{value}=~ $scopers) {
      goto TAIL;

    };

    # operators are special cases
    my $is_op=$nd->{value}=~ m[^$op$];

# ---   *   ---   *   ---
# do not attempt grouping if operator
# is trying to influence outside of it's
# own branch

    if(

       $is_op && defined $anchor
    && $anchor->{parent}==$nd->{parent}

    ) {

# ---   *   ---   *   ---
# get nodes between anchor and current

      $anchor->{parent}->idextrav();

      my $beg=$anchor->{idex};
      my $end=$nd->{idex};

      my @ar=$nd->{parent}->leaves_between(
        $beg,$end

      );

      # parent nodes to anchor
      $anchor->pushlv(@ar);
      $anchor=undef;

# ---   *   ---   *   ---
# there's no anchor or moved to a new branch

    } elsif(

       !defined $anchor
    || $anchor->{parent} != $nd->{parent}

    ) {

# ---   *   ---   *   ---
# moved to another branch!

      if(defined $anchor) {

        $anchor->{parent}->idextrav();

        # match from anchor to end of
        # expression

        my $beg=$anchor->{idex};
        my $end=$anchor->{parent}
          ->match_from($anchor,qr{^;$});

# ---   *   ---   *   ---
# 'end' here being the terminator...
#
# or the terminator switched branches,
# fine because it's meaningless on it's own
#
# if not found just get the bottom of the
# token array, same effect

        if(!defined $end) {

          $end=$anchor->{parent}
            ->{leaves}->[-1];

          $end=$end->{idex}+1;

        # terminator did not wander off branch
        } else {
          $end=$end->{idex};

        };

# ---   *   ---   *   ---
# get nodes between anchor and terminator
# push them to anchor

        my @ar=$anchor->{parent}
          ->leaves_between($beg,$end);

        $anchor->pushlv(@ar);

      };

# ---   *   ---   *   ---
# current is made anchor IF it's a keyword

      if($nd->{value}=~ m[^$keyword$]) {
        $anchor=$nd;

      };

# ---   *   ---   *   ---
# the recursive expansion shuffle

    };

TAIL:

    unshift @pending,@{$nd->{leaves}};

  };

};

# ---   *   ---   *   ---
# looks for %var% and replaces it
# with its value

sub sym_deref($self,$host,$sref) {

  state $TOKEN_RE=qr{%(?<name>
    [^%\s]+

  )%}x;

  my $defs=$self->{defs};
  my $rargs=$host->{-r_args};

# ---   *   ---   *   ---
# replace %var% for constant

  while($$sref=~ s[$TOKEN_RE][$Shwl::PL_CUT]s) {

    # capture is identifier
    # stripped of enclosing %
    my $name=$+{name};

    # look for dict entries
    # defd symbols considered first
    my $value=(exists $defs->{$name})
      ? $defs->{$name}
      : $rargs->{$name}
      ;

    errout(

      q[Invalid token-paste '%s'],
      args=>[$name],
      lvl=>$AR_FATAL,

    ) unless defined $value;

    if(is_arrayref($value)) {
      $value=join "\n",@$value;

    };

    # replace constant with value ;>
    $$sref=~ s[$Shwl::PL_CUT_RE][$value]s;

  };

};

# ---   *   ---   *   ---
# ^recursive dereferencing

sub deep_deref($self,$host,$branch) {

  my @pending=(@{$branch->{leaves}});

  while(@pending) {

    my $nd=shift @pending;
    $self->sym_deref($host,\$nd->{value});

    unshift @pending,@{$nd->{leaves}};

  };

};

# ---   *   ---   *   ---
# run subset of instructions provided by $H
# commence execution at given start node

sub run_ins_sl($self,$proc,$H,$start) {

  my $i=$start->{idex};
  my $root=$start->{parent};

  my @ran=();

# ---   *   ---   *   ---
# iter children from start to undef

  while(defined(
    my $ins=$root->{leaves}->[$i]

  )) {

    my $sbl=$H->{$ins->{value}};
    my @input=@{$ins->{leaves}};

    # value of node found in table
    if(defined $sbl) {
      $sbl->($self,$proc,@input);
      push @ran,$ins;

    };

    $i++;

  };

# ---   *   ---   *   ---
# give executed nodes

  return @ran;

};

# ---   *   ---   *   ---
# ^repeats for a group of branches

sub run_blocks_sl($self,$order,$H,%O) {

  # defaults
  $O{plucking}//=0;

# ---   *   ---   *   ---
# walk the array

  for my $blk(@$order) {

    # look for instructions
    my @ran=$self->run_ins_sl(
      $blk,$H,$blk->{start}

    );

    # ^pluck executed
    if($O{plucking}) {
      $blk->{branch}->pluck(@ran);

    };

  };

};

# ---   *   ---   *   ---
# PROTO: interprets one tree using the
# definitions in a program

sub from($self,$tree) {

  my @pending=(@{$tree->{leaves}});

  my $proc;
  my @args=();

# ---   *   ---   *   ---
# walk the tree

  while(@pending) {

    my $nd=shift @pending;

    # first token is command
    if(!defined $proc) {
      $proc=$nd->{value};

    # use token as arg
    # NOTE: this breaks. a lot.
    } elsif($nd->{value} ne ';') {
      push @args,$nd->{value};

    # terminator found
    } else {

      $self->call($proc,@args);

      $proc=undef;
      @args=();

    };

# ---   *   ---   *   ---
# recursive shuffle

    unshift @pending,@{$nd->{leaves}};

  };

};

# ---   *   ---   *   ---
# runs a lan'd branch

sub call($self,$key,@args) {

  # case-insensitive check
  my $uckey=uc $key;

  if(exists $self->{-nocase}->{$uckey}) {
    $key=$uckey;

  };

  my $proc=$self->{procs}->{"$key"};

  # catch bad keyword
  errout(

    q[Unrecognized branch: '%s'],

    args=>[$key],
    lvl=>$AR_FATAL,

  ) unless defined $proc;

# ---   *   ---   *   ---
# decode args

  my @keys=array_keys($proc->{args});
  my @values=array_values($proc->{args});

  array_filter(\@values);

  my %pass=();

# ---   *   ---   *   ---
# handle optional/missing

  while(@keys && @values) {

    my $arg_n=shift @keys;
    my ($type,$default)=@{(shift @values)};

    my $value;

    if($type eq '-slurp') {
      $value=[@args];
      @args=();

    } else {
      $value=shift @args;

    };

    # value missing for mandatory arg
    if(!defined $default && !defined $value) {

      errout(
        q[Arg '%s' of %s is not optional],

        args=>[$arg_n,$key],
        lvl=>$AR_FATAL,

      );

    };

    # ^implicit else: assign default value
    $value//=$default;
    $pass{$arg_n}=$value;

  };

# ---   *   ---   *   ---
# replace argname with values

  $proc->{-r_args}=\%pass;

  $proc->{-r_args_re}=Lang::hashpat(
    $proc->{-r_args}

  );

  my $old_branch=$proc->{branch}->dup();

  for my $mention($proc->{branch}
    ->branches_in(qr{^$proc->{-r_args_re}$})

  ) {

    my $arg_n=$mention->{value};

    $mention->{value}=
      \$proc->{-r_args}->{$arg_n};

  };

# ---   *   ---   *   ---
# execute this branch

  $self->run_ins_sl(

    $proc,

    $Lan->{Sbl_Common},
    $proc->{start},

  );

# ---   *   ---   *   ---
# cleanup

  delete $proc->{-r_args_re};
  delete $proc->{-r_args};

  $proc->{branch}->deep_repl($old_branch);

};

# ---   *   ---   *   ---
# lans a whole tree

sub lan_blocks($self,$tree) {

  # match name of block-type to pattern
  # and subset of instructions

  my @calls=(

    ['procs',qr{^proc$}i,$Lan->{Sbl_Proc}],
    ['roms',qr{^rom$}i,$Lan->{Sbl_Rom}],

  );

# ---   *   ---   *   ---
# ^walk the list and run analyzer

  for my $args(@calls) {

    my ($subset,$pattern,$ex)=@$args;

    $self->lan(
      $tree,

      $subset,
      $pattern,

      ex=>$ex

    );

  };

# ---   *   ---   *   ---
# we set the analyzed tree as
# the new program tree

  $self->{tree}=$tree;

};

# ---   *   ---   *   ---
# get basic info from branch

sub recon($self,$branch) {

  state $pat=$peso->{exp_bound};

  my $i=0;
  my $j=0;

  my @trash=();

  my $name;
  my $type;
  my $start;

# ---   *   ---   *   ---
# get KEYWORD,[inputs];

  while(defined (
    my $leaf=$branch->{leaves}->[$i]

  )) {

    my @input=$branch->match_until(
      $leaf,$pat,

      iref=>\$i,
      inclusive=>0,

    );

# ---   *   ---   *   ---
# first group is input of branch itself

    if(!$j) {

      ($name,$type)=map {
        rmquotes($ARG->{value})

      } @input;

      push @trash,@input;

# ---   *   ---   *   ---
# second one is block entry

    } elsif($j==1) {
      $start=$input[0];

    };

    $j++;

# ---   *   ---   *   ---
# specificity of this give:
# it's only meant to be used by lan ;>

  };

  return $name,$type,$start,@trash;

};

# ---   *   ---   *   ---
# analize body of block
# format it for later execution

sub lan($self,$tree,$subset,$pattern,%O) {

  $O{ex}//=0;
  my @order=();

# ---   *   ---   *   ---
# find nodes matching pattern

  for my $branch($tree
    ->branches_in($pattern)

  ) {

    # unpack
    my ($name,$type,$start,@trash)=
      $self->recon($branch);

    # save gathered data
    $self->{$subset}->{$name}={

      name=>$name,
      start=>$start,

      addr=>undef,
      args=>[],

      stack_sz=>0,

      branch=>$branch,

    };

    # remove lint
    $branch->pluck(@trash,$branch
      ->branches_in(qr{^;$})

    );

    # to avoid executing out of order
    push @order,$self->{$subset}->{$name};

  };

# ---   *   ---   *   ---
# run the block if requested

  if($O{ex}) {

    $self->run_blocks_sl(

      \@order,
      $O{ex},

      plucking=>1,

    );

  };

};

# ---   *   ---   *   ---
# case-insensitive keyword:
# considered first when looking for matching
# key during a call to symbol

sub rom_nocase($self,$host,@leaves) {

  my $key=rmquotes(uc $leaves[0]->{value});
  $self->{-nocase}->{$key}=1;

};

$Lan->{Sbl_Rom}={

  nocase=>\&rom_nocase,

};

# ---   *   ---   *   ---
# registers a given input to a procedure

sub proc_in($self,$host,@leaves) {

  my $keyw=$peso->{keyword_re};
  my $spec=$peso->{specifiers}->{re};

  my ($type,$name,$value);
  my $i=0;

  my $root=$leaves[0]->{parent};

# ---   *   ---   *   ---
# walk the arguments

  while(@leaves) {

    my $nd=shift @leaves;
    my $x=$nd->{value};

    # first is type
    if($i==0) {

      # stops at non-keyword
      if(!($x=~ m[$keyw])) {$i++} else {

        # keyw after type assumed
        # to be type specifier
        if(!length $type) {$type=$x} else {
          $type.="_$x";

        };

      };

    };

# ---   *   ---   *   ---
# second is name of var
# third (optional) is default value

    if($i==1) {$name=$x;$i++}
    elsif($i==2) {$value=$x};

    unshift @leaves,@{$nd->{leaves}};

# ---   *   ---   *   ---
# throw error if type not in table

  };

  $type=$Type::Table->{$type};

  errout(
    q{Invalid type: '%s'},

    args=>[$type],
    lvl=>$AR_FATAL,


  ) unless defined $type;

# ---   *   ---   *   ---
# NOTE:
#
# theoretically: it's not mandatory to
# stack allocate if input is not modified...
#
# ... long as registers are avail ;>
#
# for inputs that are guaranteed not to need
# allocation we can special-case later on

  $host->{stack_sz}+=$type->{size};
  push @{$host->{args}},$name=>[$type,$value];

};

sub proc_slurp($self,$host,@leaves) {

  my $name=$leaves[0]->{value};

  push @{$host->{args}},
    $name=>['-slurp',q{$00}];

};

# ---   *   ---   *   ---
# instruction sub-table: procedure setup

$Lan->{Sbl_Proc}={

  in=>\&proc_in,
  slurp=>\&proc_slurp,

};

# ---   *   ---   *   ---
# checks existence of a compile-time value

sub cm_defd($self,$host,@leaves) {

  my $key=$leaves[0]->{value};
  my $root=$leaves[0]->{parent};

  $root->{value}=int(exists $self->{defs}->{$key});
  $root->pluck(@{$root->{leaves}});

};

# ---   *   ---   *   ---
# ^nit/set compile-time value

sub cm_def($self,$host,@leaves) {

  my ($key,$value)=@leaves;

  $self->sym_deref($host,\$key->{value});
  $self->deep_deref($host,$value);

  $value->collapse();

  $self->{defs}->{$key->{value}}=
    $value->{value};

};

# ---   *   ---   *   ---
# ^destroy

sub cm_undef($self,$host,@leaves) {

  my ($key)=$leaves[0]->{value};
  $self->sym_deref($host,\$key);

  delete $self->{defs}->{$key};

};

# ---   *   ---   *   ---
# rough conditional, wipes branch
# if condition is false
#
# compile-time only. might be worth it to
# add a run-time variant as I favor this
# syntax over eif and friends

sub cm_on($self,$host,@leaves) {

  my $root=$leaves[0]->{parent};
  my @body=();

# ---   *   ---   *   ---
# fetch instructions within conditional

  while(@leaves) {

    my $nd=pop @leaves;

    push @body,$nd if $nd->{value}=~ m[$CM_RE];
    push @leaves,@{$nd->{leaves}};

  };

# ---   *   ---   *   ---
# ^execute them

  for my $start(@body) {

    run_ins_sl(

      $self,$host,
      $Lan->{Sbl_Common},

      $start,

    );

  };

# ---   *   ---   *   ---
# solve conditional

  $root->collapse();

  # start of branch
  my $i=$root->{idex};

  # ^immediate neighbor
  my $mfrom=$root->{parent}->{leaves}
    ->[$root->{idex}+1];

  # walk up to next condition or switch end
  my @block=$root->{parent}->match_until(

    $mfrom,qr{^(?: off|on|or)$}xi,

    iref=>\$i,
    inclusive=>1,

  );

  # if condition, leave it alone
  if($block[-1]->{value}=~ m[^(?: on|or)$]xi) {
    pop @block;

  };

  # wipe branch on false
  if(!$root->leaf_value(0)) {
    $root->{parent}->pluck(@block);

  };

};

# ---   *   ---   *   ---
# placeholder

sub cm_off($self,$host,@leaves) {};

# ---   *   ---   *   ---
# quick and dirty textual output
# because I'm too lazy at the moment

sub cm_out($self,$host,@leaves) {

  state $out_parens=qr{^\(+|\)+$}mx;
  my @lines=map {$ARG->{value}} @leaves;

  # sanitize
  for my $line(@lines) {

    # replace %vars% for values
    $self->sym_deref($host,\$line);

    $line=~ s[$out_parens][]gx;
    $line=~ s[\x20+][ ]sxmg;

    # echo
    say $line;

  };

};

# ---   *   ---   *   ---
# instruction sub-table: standard symbol call

$Lan->{Sbl_Common}={

  def=>\&cm_def,
  defd=>\&cm_defd,

  'undef'=>\&cm_undef,

  on=>\&cm_on,
  off=>\&cm_off,

  out=>\&cm_out,

};

# ^matches each key on the subtab
$CM_RE=Lang::hashpat($Lan->{Sbl_Common});

# ---   *   ---   *   ---
# LEGACY STUFF
#
# deprecated, take whatever is of use
# from here, repurpose it and delete the rest
#
# ---   *   ---   *   ---
# declare an empty block

sub declscope($self,$name,$idex) {

  $self->{scopes}->{$name}={

    # we use these values to navigate
    # pointer arrays through next/prev

    _beg=>$idex,
    _end=>$idex+1,

    _itab=>[],

  };

  return;

};

# ---   *   ---   *   ---
# getters/setters

sub fpass($self) {return $self->{pass}==0};

# ---   *   ---   *   ---
# peso struct stuff

sub reg($self,$name,@entries) {

  my $bframe=$self->{blk};
  my $types=$self->{lang}->{types};

  # get clan or non
  my $dst=($bframe->{dst}->{attrs})
  ? $bframe->{dst}->{parent}
  : $bframe->{dst}
  ;

  # make new block
  my $blk=$bframe->nit($dst,$name,$O_RD|$O_WR);

# ---   *   ---   *   ---
# push values to block

  for my $entry(@entries) {
    my ($type,$attrs,$data)=@$entry;

    $blk->expand(

      $data,

      type=>$type,
      attrs=>$attrs,

    );

  };

};

# ---   *   ---   *   ---
# placeholder

sub run($self,@args) {
  return $self->{run}->($self,@args);

};

sub set_entry($self,$coderef) {
  $self->{run}=$coderef;
  return;

};

# ---   *   ---   *   ---
1; # ret

