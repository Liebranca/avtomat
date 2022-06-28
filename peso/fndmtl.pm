#!/usr/bin/perl
# ---   *   ---   *   ---
# FNDMTL
# It's fundamentals
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package peso::fndmtl;

  use v5.36.0;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# constructor for pkg hash

sub getout($type) {

  my %out=(
    type=>$type,

    header=>{},
    data=>[],

  );

  return $out{header},$out{data},%out;

};

# ---   *   ---   *   ---
# decomposes a value declaration tree

sub ptr_decl($m,$tree) {

  my ($header,$data,%out)=getout('ptr_decl');

# ---   *   ---   *   ---
# save block entry descriptors

  $header->{spec}=[$tree->branch_values('^spec$')];
  $header->{type}=[$tree->branch_values('^type$')];

  my @names=$tree->branch_values('^name$');
  my @values=$tree->branch_values('^value$');

# ---   *   ---   *   ---
# case A: more names than values

  if(@names>@values) {

    my $i=@values;
    while($i<@names) {
      push @values,'null';
      $i++;

    };

# ---   *   ---   *   ---
# case B: more values than names

  } elsif(@names<@values) {

    my $i=@names;
    my $j=1;

    my $k=$#names;

    while($i<@values) {
      push @names,"$names[$k]+$j";
      $i++;$j++;

    };
  };

# ---   *   ---   *   ---
# push key:value to data

  my $types=$m->lang->types;
  while(@names) {

    my $name=shift @names;
    my $value=shift @values;

    if(exists $m->{refs}->{$value}) {
      $value=$m->{refs}->{$value};

    };

    push @$data,[$name,$value];

  };

  return \%out;

};

# ---   *   ---   *   ---

sub ptr_decl_pack($m,$pkg) {

  return

  [ $m->blk,
    'new_data_ptr',

    $pkg

  ];

};

# ---   *   ---   *   ---
# decomposes class/struct declaration tree

sub type_decl($m,$tree) {

  my ($header,$data,%out)=getout('ptr_decl');

# ---   *   ---   *   ---
# get entry info

  $header->{type}=[
    $tree->branch_values('^directive$')

  ];

  $header->{spec}=undef;

# ---   *   ---   *   ---
# push to data

  push @$data,$tree->branch_values('^name$');
  return \%out;

};

# ---   *   ---   *   ---

sub type_decl_pack($m,$pkg) {

  return

  [ $m->blk,
    'new_data_block',

    $pkg,

  ];

};

# ---   *   ---   *   ---
# func table

use constant CALLTAB=>{

  'ptr_decl'=>\&ptr_decl,
  'ptr_decl_pack'=>\&ptr_decl_pack,

  'type_decl'=>\&type_decl,
  'type_decl_pack'=>\&type_decl_pack,

};

# ---   *   ---   *   ---
# use tree to build instruction

sub take($m,$key,$tree) {

  my $pkg=CALLTAB->{$key}->($m,$tree);
  my $btc=CALLTAB->{$key.'_pack'}->($m,$pkg);

  return $btc;

};

# ---   *   ---   *   ---
# ^executes

sub give($m,$branch) {

  my $btc=$branch->{btc};
  my $scope=$btc->[0];
  my $fn=$btc->[1];

  my $pkg=$btc->[2];

  my ($header,$data)=(
    $pkg->{header},
    $pkg->{data}

  );

# ---   *   ---   *   ---
# solve pending operations on second pass

  if(!$m->fpass()) {

    my @pending=();
    for my $arg(@{$data}) {

      my $n;
      if(!length ref $arg) {
        unshift @pending,\$arg;

      } else {
        unshift @pending,map {\$_;} @$arg;

      };

# ---   *   ---   *   ---
# go recursive

      while(@pending) {
        $n=shift @pending;

        if(peso::node::valid $$n) {
          $$n=$$n->collapse()->value;

        } elsif(

           $m->lang->valid_name($$n)
        && !(exists $m->lang->types->{$$n})

        ) {

          $$n=$m->ptr->fetch($$n);

        } else {
          $m->lang->numcon($n);

        };

      };

# ---   *   ---   *   ---
# give back call results

    };
  };

  return $scope->$fn($header,$data);

};

# ---   *   ---   *   ---
1; # ret
