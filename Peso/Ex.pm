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

sub call($self,$key,@args) {

  my $proc=$self->{procs}->{$key};

  my @keys=array_keys($proc->{args});
  my @values=array_values($proc->{args});

  my %pass=();

# ---   *   ---   *   ---

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

  # cleanup
  delete $proc->{-r_args_re};
  delete $proc->{-r_args};

  $proc->{branch}->deep_repl($old_branch);

};

# ---   *   ---   *   ---

sub lan_blocks($self,$tree) {

  $self->lan_proc($tree);
  $self->{tree}=$tree;

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

    my $proc_s;

    while(defined (
      my $leaf=$branch->{leaves}->[$i]

    )) {

      my @input=$branch->match_until(
        $leaf,$pat,

        iref=>\$i,
        inclusive=>0,

      );

      if(!$j) {
        ($proc_n,$proc_t)=map {
          rmquotes($ARG->{value})

        } @input;

      } elsif($j==1) {
        $proc_s=$input[0];

      };

      $j++;

    };

# ---   *   ---   *   ---

    $self->{procs}->{$proc_n}={

      name=>$proc_n,
      start=>$proc_s,

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

  $self->run_blocks_sl(
    $self->{procs},
    $Lan->{Sbl_Proc},

    plucking=>1,

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

sub cm_out($self,$host,@leaves) {

  state $out_parens=qr{^\(|\)$ }x;
  my @lines=map {$ARG->{value}} @leaves;

  for my $line(@lines) {
    $line=~ s[$out_parens][]sxgm;
    $line=~ s[$NEWLINE_RE][ ]sxgm;
    $line=~ s[$SPACE_RE+][ ]sxgm;

    say $line;

  };

};

# ---   *   ---   *   ---

$Lan->{Sbl_Common}={

  def=>\&cm_def,
  defd=>\&cm_defd,

  'undef'=>\&cm_undef,

  on=>\&cm_on,
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

