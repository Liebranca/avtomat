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

  use peso::node;
  use peso::program;
  use lyperl::decls;

# ---   *   ---   *   ---

sub import {

  my ($type)=@_;
  my ($ref)={

    lline_exp=>0,

    killed=>0,
    lineno=>1,
    in_doc_block=>0,

    macros=>{},

    unpro=>[],
    exps=>[],
    strings=>[],

    docs_accum=>'',

  };filter_add(bless $ref);

};

# ---   *   ---   *   ---
# demangles the accumulated code strings

sub restore($) {

  my $self=shift;
  my $mangled=shift;

  # replace string tokens
  return lang::stitch($mangled,$self->{strings});

};

# ---   *   ---   *   ---

sub subst_iter($$) {

  my $self=shift;
  my $node=shift;

  my $leaf=$node->leaves->[0];
  if(!defined $leaf) {
    print "Symbol 'iter' requires $,$\n";
    exit;

  };

  my ($a,$b)=split m/\s*,\s*/,$leaf->val;
  $node->pluck($leaf);

  $node->{-VAL}="for my $a".'(@{'.$b.'})';

};

# ---   *   ---   *   ---

my %PROCS=();

sub subst_proc($$) {

  my $self=shift;
  my $node=shift;

  my ($name)=$node->pluck($node->leaves->[0]);
  $name=$name->val;

  $PROCS{$name}=[];

  my @args=();
  my $i=0;

  while(@{$node->leaves}) {

    my ($vtype,$vname)=$node->pluck(
      @{$node->leaves}[0,1]

    );

    push @args,[$vname->val=>$vtype->val];
    push @{$PROCS{$name}},$vtype->val;

    $i++;

  };

  $node->{-VAL}="sub $name(".('$'x$i).")";

  my $s='';
  for my $ref(@args) {
    my $key=$ref->[0];
    $s.='my '.$key."=shift;";

  };return $s;

};

# ---   *   ---   *   ---

sub expsplit($) {

  my $self=shift;
  my @exps=
    split m/([\{\};])/,(join '',@{$self->{unpro}});

  my $root=peso::node::nit(undef,'ROOT');
  my @ances=();

  peso::program::nit();

# ---   *   ---   *   ---

  my %keywords=(
    'iter'=>\&subst_iter,
    'proc'=>\&subst_proc,

  );

# ---   *   ---   *   ---

  my $vname=lyperl::decls::names;

  my $anchor=$root;
  my $last=$root;
  my $rem='';

  for my $exp(@exps) {

    if(defined $exp && length lang::stripline($exp)) {

      if($exp eq '{') {
        push @ances,$anchor;
        $anchor=$last;

      } elsif($exp eq '}') {
        $anchor=pop @ances;

      };

# ---   *   ---   *   ---

      $exp=~ s/^\s*|\s*$//sg;
      $exp=~ s/^${vname}//;

      my $hed=$1;

      if(defined $hed) {

        if(exists $keywords{$hed}) {

          $last=$anchor->nit($hed);
          $last->tokenize($exp);

          $rem=$keywords{$hed}->($self,$last);

        } elsif(exists $PROCS{$hed}) {

          $exp=~ s/^\s*|\s*$//sg;
          my @args=split m/\s*,\s*/,$exp;

          my $i=0;
          for my $type(@{$PROCS{$hed}}) {

            my @wrap=($type eq 'char')
              ? ('int','(',')')
              : ('','"','"')
              ;

            $args[$i]=

              "$wrap[0]$wrap[1]".

              $args[$i].
              "$wrap[2]";

            $i++;

          };my $exp=join ',',@args;

          $last=$anchor->nit($hed.' '.$exp);

        } else {
          $last=$anchor->nit($hed.' '.$exp);

        };

      } else {

        if($exp eq ';') {
          $last->{-VAL}.=$exp;
          next;

        };

        $last=$anchor->nit($exp);

        if($rem) {

          $anchor->nit($rem);
          $rem='';

        };

      };
    };
  };

# ---   *   ---   *   ---

  my $s='';
  my @leaves=(@{$root->leaves});

  TOP:my $leaf=shift @leaves;

  $s.=$leaf->val;
  $s.=('',"\n")[int($leaf->val=~ m/\{|;/)];

  if($leaf->leaves) {
    unshift @leaves,@{$leaf->leaves};

  };

# ---   *   ---   *   ---

  if(@leaves) {goto TOP;};
  END:return $s;

};

# ---   *   ---   *   ---

sub filter {

  my ($self)=@_;
  my $status=filter_read();

# ---   *   ---   *   ---

  if( (!length lang::stripline($_)

      && !$self->{in_doc_block}

      )

  || m/^\s*#/

  ) {

# ---   *   ---   *   ---

    if($status<=0 && !$self->{killed}) {

      $_=$self->restore(
        $self->expsplit()

      );

printf "$_\n";

      $self->{killed}=1;
      $status=1;

    };return $status;

  };

# ---   *   ---   *   ---

  my $s=$_;$_='';

  $self->mangle($s);
  $self->{lineno}++;

  $status;

};

# ---   *   ---   *   ---
1; # ret

