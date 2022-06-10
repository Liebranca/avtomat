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

  use lib $ENV{'ARPATH'}.'/avtomat/';

  use lang;
  use langdefs::perl;

  use peso::rd;
  use peso::node;

# ---   *   ---   *   ---

sub import {

  my ($type)=@_;
  my ($ref)={

    killed=>0,
    lines=>[],

  };filter_add(bless $ref);

};

# ---   *   ---   *   ---
# converts lyperl into executable perl

sub translate($) {

  my $program=shift;

  # keyword-detecting pattern
  # exclusive to lyperl keywords

  my $keys=lang::eiths(

    (join ',',(

      langdefs::perl->LYPERL_DIRECTIVES,
      langdefs::perl->LYPERL_TYPES,

    ))
  );

# ---   *   ---   *   ---
# nit the symbol table

  lang->perl->sbl->setdef($program);
  my $SYMS=lang->perl->sbl->SYMS;

  $program->{defs}={

    types=>{},
    procs=>{},

    cur=>undef,
    lvl=>0,

  };

# ---   *   ---   *   ---
# walk the tree

  for my $branch(@{$program->{tree}}) {

    my $lvl=\$program->{defs}->{lvl};
    my $cur=\$program->{defs}->{cur};

    # keyword found
    if($branch->value=~ m/${keys}/) {
      my $key=$branch->value;
      my $v=$SYMS->{$key}->ex($branch);

      if($v=~ s/^ERROR://) {
        print "$v at line $branch->{lineno}\n";
        exit;

      };

      $branch->value($v);
      $branch->pluck(@{$branch->leaves});

# ---   *   ---   *   ---
# definition block in

    } elsif($branch->value eq '{') {

      if(defined $$cur && $$lvl==$$cur->{lvl}) {
        my $beg=$$cur->{beg};
        $branch->value($beg->($program));

      };

      $$lvl++;

# ---   *   ---   *   ---
# definition block out

    } elsif($branch->value eq '}') {

      $$lvl--;

      if(defined $$cur && $$lvl==$$cur->{lvl}) {

        my $end=$$cur->{end};
        $branch->value($end->($program));

        $$cur=undef;

      };

# ---   *   ---   *   ---
# inside definition block

    } elsif(defined $$cur) {

      if($$cur->{tag} eq 'procs') {

        my @ar=$branch->branches_with('^self$');
        for my $node(@ar) {

          if($node->value=~ m/^node_op/
          && $node->value->{op} eq '->'

          ) {

            for my $leaf(@{$node->leaves}) {
              if($leaf->value=~ m/^self$/) {
                $leaf->value('$self');

              } else {

# ufff

my $key=$$cur->{ref}->{base};
my $kls=$program->{defs}->{types}->{$key};

if(!exists $kls->{attrs}->{$leaf->value}) {

  print
    "Class $key has no attr ".
    $leaf->value.", at line $branch->{lineno}\n";

  exit;

};

my ($fchar,$name,$longname)=
  langdefs::perl::typecon($leaf->value);

$leaf->value("{$longname}");

              };
            };
          };
        };

      };

    };

# ---   *   ---   *   ---

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

  for my $branch(@{$program->{tree}}) {

    my $proc;

    # solve operations and flatten
    $branch->collapse();
    $branch->defield();

    # push semis
    if( $branch->{has_eb}
    && length $branch->value

    ) {$program->node->nit($branch,';');};

# ---   *   ---   *   ---
# convert branch to an array

    if($branch->value eq 'void') {
      $proc=\&peso::node::plain_arr;

    } else {
      $proc=\&peso::node::plain_arr2;

    # stringify and de-space
    };push @ar,lang::stitch(
      (join ' ',$proc->($branch)),
      $program->{strings}

    );$ar[-1]=~ s/\x20*(${op})\x20*/$1/sg;

  };

# ---   *   ---   *   ---
# return the flattened tree as a string

  my $s=join "\n",@ar;
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

        join "\n",@{$self->{lines}}


      );

# ---   *   ---   *   ---

      translate($program);
      $_=restore($program);

# program print
#my $i=0;for my $line(split "\n",$_) {
#  printf "%-3i %s\n",$i++,$line;
#
#};

      $self->{killed}=1;
      $status=1;

    };return $status;

  };

# ---   *   ---   *   ---

  my $s=$_;$_='';

  push @{$self->{lines}},$s;
  $status;

};

# ---   *   ---   *   ---
1; # ret
