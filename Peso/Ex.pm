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

    regs=>{},
    roms=>{},

    nxins=>undef,
    pass=>0,

    tree=>undef,

    node=>Tree::Syntax->new_frame(
      -lang=>$peso

    ),

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

sub run_ins_sl($self,$proc,$H,@body) {

  for my $ins(@body) {

    my $sbl=$H->{$ins->{value}};
    my @input=@{$ins->{leaves}};

    if(defined $sbl) {
      $sbl->($self,$proc,@input);

    };

  };

};

sub run_block_sl($self,$procs,$H) {

  for my $proc_n(keys %{$procs}) {
    my $proc=$procs->{$proc_n};

    $self->run_ins_sl(
      $proc,$H,
      @{$proc->{body}}

    );

  };

};

# ---   *   ---   *   ---

sub run_blocks($self,$tree) {

  $self->run_block_sl(
    $self->{procs},
    $Lan->{Sbl_Common},

  );

  $tree->prich();

};

# ---   *   ---   *   ---

sub lan_blocks($self,$tree) {

  $self->lan_proc($tree);

};

# ---   *   ---   *   ---
# analize proc body and format it for
# later execution

sub lan_proc($self,$tree) {

  my $pat=$peso->{exp_bound};

  for my $branch($tree
    ->branches_in(qr{^proc$}i)

  ) {

    my $i=0;
    my $j=0;

    my $proc_n;
    my $proc_t;

    my @proc_b=();

    while(defined (
      my $leaf=$branch->{leaves}->[$i]

    )) {

      my @input=$branch->match_until(
        $leaf,$pat,\$i

      );

      if(!$j) {
        ($proc_n,$proc_t)=map {
          $ARG->{value}

        } @input;

      } else {
        push @proc_b,@input;

      };

      $j++;

    };

# ---   *   ---   *   ---

    $self->{procs}->{$proc_n}={

      name=>$proc_n,
      body=>\@proc_b,

      addr=>undef,
      args=>[],

      stack_sz=>0,

      branch=>$branch,

    };

    $branch->pluck($branch
      ->branches_in(qr{^;$})

    );

    $branch->idextrav();

  };

# ---   *   ---   *   ---

  $self->run_block_sl(
    $self->{procs},
    $Lan->{Sbl_Proc},

  );

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

  $root->{parent}->pluck($root);

};

# ---   *   ---   *   ---

$Lan->{Sbl_Proc}={

  in=>\&proc_in,

};

# ---   *   ---   *   ---

sub cm_defd($self,$host,@leaves) {

  my $key=$leaves[0]->{value};
  my $root=$leaves[0]->{parent};

  $root->{value}=exists $self->{$key};
  $root->pluck(@{$root->{leaves}});

};

sub cm_def($self,$host,@leaves) {

  my ($key,$value)=map {$ARG->{value}} @leaves;
  $self->{defs}->{$key}=$value;

};

sub cm_undef($self,$host,@leaves) {

  my ($key)=$leaves[0]->{value};
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

  run_ins_sl(

    $self,$host,
    $Lan->{Sbl_Common},

    @body

  );

# ---   *   ---   *   ---

  $root->collapse();

  my $i=$root->{idex};
  my $mfrom=$root->{parent}->{leaves}
    ->[$root->{idex}+1];

  my @block=$root->{parent}->match_until(
    $mfrom,qr{^(?: off|on|or)$}xi,\$i

  );

  map {$ARG->prich()} @block;

  if(!$root->leaf_value(0)) {
    $root->{parent}->pluck(@block);

  };

};

# ---   *   ---   *   ---

$Lan->{Sbl_Common}={

  def=>\&cm_def,
  defd=>\&cm_defd,

  'undef'=>\&cm_undef,

  on=>\&cm_on,

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
