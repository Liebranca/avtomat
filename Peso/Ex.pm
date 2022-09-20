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

  use Type;

  use Tree::Syntax;
  use Peso::Rd;

  use Lang;
  use Lang::Peso;

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

sub fopen($self,$fpath) {

  my $rd=Peso::Rd::parse($peso,$fpath);

  my $blk=$rd->select_block(-ROOT);
  my $tree=$blk->{tree};

  $peso->hier_sort($tree);

  $rd->replstr($tree);
  $rd->recurse($tree);

  $self->preproc($tree);
  $self->expsplit($tree);

  $tree->subdiv();

  $tree->collapse(
    only=>qr{,}x,
    no_numcon=>1

  );

  return ($tree,$rd);

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

# ---   *   ---   *   ---

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

# ---   *   ---   *   ---
#:!;> recursive paste

      my $fpath=$path.$name.rmquotes($ext);
      my $keys={ @{$self->{loaded}} };

      if(!exists $keys->{"$fpath"}) {

        my ($btree,$brd)=$self->fopen($fpath);

        push @{$self->{loaded}},
          $fpath=>1;

        $f->repl($btree);
        $btree->flatten_branch();

      };

# ---   *   ---   *   ---

    };

  };

  $tree->pluck(
    $tree->branches_in($lib_re),
    $tree->branches_in($imp_re)

  );

};

# ---   *   ---   *   ---

sub expsplit($self,$tree) {

  state $scopers=qr/\b(clan|reg|rom|proc)\b/i;

  my $op=$peso->{ops};
  my $keyword=$peso->{keyword_re};

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

sub sym_deref($self,$host,$sref) {

  my $defs=$self->{defs};
  my $rargs=$host->{-r_args};

  # defs first
  for my $attr_n(keys %$defs) {
    my $attr_v=$defs->{$attr_n};
    $$sref=~ s[%${attr_n}%][$attr_v]sxmg;

  };

  # then proc args
  for my $arg_n(keys %$rargs) {
    my $arg_v=$rargs->{$arg_n};
    $$sref=~ s[%${arg_n}%][$arg_v]sxmg;

  };

};

# ---   *   ---   *   ---

sub run_ins_sl($self,$proc,$H,$start) {

  my $i=0;
  my $root=$start->{parent};

  my @ran=();

  while(defined(
    my $ins=$root->{leaves}->[$i]

  )) {

    my $sbl=$H->{$ins->{value}};
    my @input=@{$ins->{leaves}};

    if(defined $sbl) {
      $sbl->($self,$proc,@input);
      push @ran,$ins;

    };

    $i++;

  };

  return @ran;

};

sub run_blocks_sl($self,$procs,$H,%O) {

  # defaults
  $O{plucking}//=0;

  for my $proc_n(keys %{$procs}) {
    my $proc=$procs->{$proc_n};

    my @ran=$self->run_ins_sl(
      $proc,$H,$proc->{start}

    );

    if($O{plucking}) {
      $proc->{branch}->pluck(@ran);

    };

  };

};

# ---   *   ---   *   ---

sub from($self,$tree) {

  my @pending=(@{$tree->{leaves}});

  my $proc;
  my @args=();

  while(@pending) {

    my $nd=shift @pending;

    if(!defined $proc) {
      $proc=$nd->{value};

    } elsif($nd->{value} ne ';') {
      push @args,$nd->{value};

    } else {

      $self->call($proc,@args);

      $proc=undef;
      @args=();

    };

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

    my $value=shift @args;

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

  my @calls=(

    ['procs',qr{^proc$}i,$Lan->{Sbl_Proc}],
    ['roms',qr{^rom$}i,$Lan->{Sbl_Rom}],

  );

  for my $args(@calls) {

    my ($subset,$pattern,$ex)=@$args;

    $self->lan(
      $tree,

      $subset,
      $pattern,

      ex=>$ex

    );

  };

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

  };

  return $name,$type,$start,@trash;

};

# ---   *   ---   *   ---
# analize body of block
# format it for later execution

sub lan($self,$tree,$subset,$pattern,%O) {

  $O{ex}//=0;

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

  };

# ---   *   ---   *   ---
# run the block if requested

  if($O{ex}) {

    $self->run_blocks_sl(

      $self->{$subset},
      $O{ex},

      plucking=>1,

    );

  };

};

# ---   *   ---   *   ---

sub rom_nocase($self,$host,@leaves) {

  my $key=rmquotes(uc $leaves[0]->{value});
  $self->{-nocase}->{$key}=1;

};

$Lan->{Sbl_Rom}={

  nocase=>\&rom_nocase,

};

# ---   *   ---   *   ---

sub proc_in($self,$host,@leaves) {

  my $keyw=$peso->{keyword_re};
  my $spec=$peso->{specifiers}->{re};

  my ($type,$name,$value);
  my $i=0;

  my $root=$leaves[0]->{parent};

# ---   *   ---   *   ---

  while(@leaves) {

    my $nd=shift @leaves;
    my $x=$nd->{value};

    if($i==0) {

      if(!($x=~ m[$keyw])) {$i++} else {

        if(!length $type) {$type=$x} else {
          $type.="_$x";

        };

      };

    };

    if($i==1) {$name=$x;$i++}
    elsif($i==2) {$value=$x};

    unshift @leaves,@{$nd->{leaves}};

  };

# ---   *   ---   *   ---

  $type=$Type::Table->{$type};

  errout(
    q{Invalid type: '%s'},

    args=>[$type],
    lvl=>$AR_FATAL,


  ) unless defined $type;

  $host->{stack_sz}+=$type->{size};
  push @{$host->{args}},$name=>[$type,$value];

};

# ---   *   ---   *   ---

$Lan->{Sbl_Proc}={

  in=>\&proc_in,

};

# ---   *   ---   *   ---

sub cm_defd($self,$host,@leaves) {

  my $key=$leaves[0]->{value};
  my $root=$leaves[0]->{parent};

  $root->{value}=int(exists $self->{defs}->{$key});
  $root->pluck(@{$root->{leaves}});

};

sub cm_def($self,$host,@leaves) {

  my ($key,$value)=map {$ARG->{value}} @leaves;

  $self->sym_deref($host,\$key);
  $self->sym_deref($host,\$value);

  $self->{defs}->{$key}=$value;

};

sub cm_undef($self,$host,@leaves) {

  my ($key)=$leaves[0]->{value};
  $self->sym_deref($host,\$key);

  delete $self->{defs}->{$key};

};

# ---   *   ---   *   ---

sub cm_on($self,$host,@leaves) {

  my $root=$leaves[0]->{parent};
  my @body=();

  while(@leaves) {

    my $nd=pop @leaves;

    push @body,$nd if $nd->{value}=~ m[$CM_RE];
    push @leaves,@{$nd->{leaves}};

  };

  for my $start(@body) {

    run_ins_sl(

      $self,$host,
      $Lan->{Sbl_Common},

      $start,

    );

  };

# ---   *   ---   *   ---

  $root->collapse();

  my $i=$root->{idex};

  my $mfrom=$root->{parent}->{leaves}
    ->[$root->{idex}+1];

  my @block=$root->{parent}->match_until(

    $mfrom,qr{^(?: off|on|or)$}xi,

    iref=>\$i,
    inclusive=>1,

  );

  if($block[-1]->{value}=~ m[^(?: on|or)$]xi) {
    pop @block;

  };

  if(!$root->leaf_value(0)) {
    $root->{parent}->pluck(@block);

  };

};

# ---   *   ---   *   ---

sub cm_off($self,$host,@leaves) {};

# ---   *   ---   *   ---

sub cm_out($self,$host,@leaves) {

  state $out_parens=qr{^\(|\)$ }x;
  my @lines=map {$ARG->{value}} @leaves;

  for my $line(@lines) {
    $line=~ s[$out_parens][]sxmg;
    $line=~ s[$SPACE_RE+][ ]sxmg;

    $self->sym_deref($host,\$line);

    say $line;

  };

};

# ---   *   ---   *   ---

$Lan->{Sbl_Common}={

  def=>\&cm_def,
  defd=>\&cm_defd,

  'undef'=>\&cm_undef,

  on=>\&cm_on,
  off=>\&cm_off,

  out=>\&cm_out,

};

$CM_RE=Lang::hashpat($Lan->{Sbl_Common});

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

