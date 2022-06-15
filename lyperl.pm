#!/usr/bin/perl
# ---   *   ---   *   ---
# LYPERL
# Makes Perl even cooler
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package lyperl;
  use strict;
  use warnings;

  use Filter::Util::Call;

  use lib $ENV{'ARPATH'}.'/lib/';

  use lang;
  use langdefs::perl;
  use langdefs::peso;

  use peso::rd;
  use peso::node;

# ---   *   ---   *   ---

sub import {

  my ($type)=@_;
  my ($file,$lineno)=(caller)[1,2];

  my ($ref)={

    killed=>0,
    lines=>[],
    file=>$file,
    lineno=>$lineno+1,

  };filter_add(bless $ref);

};

# ---   *   ---   *   ---

sub namerepl($$$) {

  my ($node,$cur,$program)=@_;
  my @leaves=($node);

  TOP:while(@leaves) {

    $node=shift @leaves;
    unshift @leaves,@{$node->leaves};

    if($node->value=~ m/\bself\b/) {
      my $t='$self';
      $node->{-VALUE}=~ s/\bself\b/$t/sg;

# ---   *   ---   *   ---
# check for attr

    } else {

      my $key=$$cur->{ref}->{base};
      my $kls=$program->{defs}->{types}->{$key};

      my $v=$node->value;

# ---   *   ---   *   ---
# skip if not an attr or a getter exists

      if(

         (!exists $kls->{attrs}->{$v})
      || (exists $kls->{procs}->{$v})

      ) {next;};

# ---   *   ---   *   ---
# wrap attr in curlies

      $node->value("{$v}");

    };
  };
};

# ---   *   ---   *   ---
# converts lyperl into executable perl

sub translate($) {

  my $program=shift;

# ---   *   ---   *   ---
# nit the symbol table

  lang->peso->sbl->setdef($program);
  my $SYMS=lang->peso->sbl->SYMS;

  $program->{defs}={

    types=>{},
    procs=>{},

    cur=>undef,
    lvl=>0,

  };

# ---   *   ---   *   ---
# set up hierarchy

  my $tree=$program->{tree};
  langdefs::peso::reorder($tree);

# ---   *   ---   *   ---
# walk the tree

  my @branches=@{$tree->leaves};
  while(@branches) {

    my $branch=shift @branches;

    my $lvl=\$program->{defs}->{lvl};
    my $cur=\$program->{defs}->{cur};

# ---   *   ---   *   ---
# keyword found

    if(lang->peso->is_keyword($branch->value)) {

      my $key=$branch->value;
      my $v=$SYMS->{$key}->ex($branch);

      if(defined $v && $v=~ s/^ERROR://) {

        print STDERR
          "$v at line $branch->{lineno}\n";

        exit;

      } elsif(!defined $v) {

        print STDERR
          "Symbol exec error at line ".
          "$branch->{lineno}\n";

        $branch->prich();

        exit;

      };

#      $branch->value($v);
#      $branch->pluck(@{$branch->leaves});

# ---   *   ---   *   ---
# scope in

    } elsif($branch->value eq '{') {
      $$lvl++;

# ---   *   ---   *   ---
# scope out

    } elsif($branch->value eq '}') {
      $$lvl--;

# ---   *   ---   *   ---
# inside definition block

    } elsif(defined $$cur) {
      ;

    };

# ---   *   ---   *   ---

    END:
    unshift @branches,@{$branch->leaves};

  };
};

# ---   *   ---   *   ---
# re-assembles the code

sub restore($) {

  my $program=shift;
  my @ar=();

  my $lang=$program->lang;

  my $op

    =$lang->del_ops.'|'.
     $lang->ndel_ops.'|'.
     $lang->exp_bound

  ;

# ---   *   ---   *   ---
# walk the tree

  my @branches=$program->{tree}->exp_arr();
  for my $branch(reverse @branches) {

    # solve operations and flatten
    $branch->collapse();
    $branch->defield();

    # push semis
    if( $branch->{has_eb}
    && length $branch->value

    ) {$program->node->nit($branch,';');};

    # stringify
    my $s=$branch->flatten();
    $branch->par->pluck($branch);

    # de-space
    $s=~ s/\x20*(${op})\x20*/$1/sg;

    # restore string tokens
    push @ar,lang::stitch(
      $s,$program->{strings}

    );

  };

# ---   *   ---   *   ---
# return the flattened tree as a string

  my $s=join "\n",reverse @ar;
  return $s;

};

# ---   *   ---   *   ---

sub filter {

  my ($self)=@_;
  my $status=filter_read();

# ---   *   ---   *   ---

  if(!length lang::stripline($_)) {

    if($status<=0 && !$self->{killed}) {

      # process read lines
      my $program=peso::rd::parse(

        lang->perl,
        peso::rd->STR,

        (join "\n",@{$self->{lines}}),

        lineno=>$self->{lineno},


      );

# ---   *   ---   *   ---

      translate($program);

my $non=$program->blk->NON;
$non->prich();

$program->{tree}->prich();

exit;

# ---   *   ---   *   ---

      $_=restore($program);

# program print

my $i=0;for my $line(split "\n",$_) {
  printf "%-3i %s\n",$i++,$line;

};

exit;

      $self->{killed}=1;
      return 1;

    };
  };

# ---   *   ---   *   ---

  my $s=$_;$_='';

  push @{$self->{lines}},$s;
  return $status;

};

# ---   *   ---   *   ---
1; # ret

