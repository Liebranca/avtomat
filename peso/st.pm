#!/usr/bin/perl
# ---   *   ---   *   ---
# ST
# Fundamental peso structures
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package peso::st;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/';
  use style;
  use arstd;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.02.0;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $BRANCH_RE=>{

    name=>qr{^name$},
    spec=>qr{^spec$},
    type=>qr{^type$},
    vals=>qr{^values$},
    bare=>qr{^bare$},

    directive=>qr{^directive$},
    indlvl=>qr{^indlvl$},

  };

  sub BRANCH_RE() {return $BRANCH_RE};

  Readonly our $TYPE_BLOCK=>0x01;

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

sub regpad($names,$values) {

  my @names=@$names;
  my @values=@$values;

# ---   *   ---   *   ---
# case A: more names than values

  if(@names>@values) {

    my $i=@values;
    while($i<@names) {
      push @values,$NULL;
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

  return (\@names,\@values);

};

# ---   *   ---   *   ---
# pushes key:value to array

sub regfmat($dst,$names,$values) {

  while(@$names) {

    my $name=shift @$names;
    my $value=shift @$values;

# NOTE: this is a dereference
#       ill handle it later...
#
#    if(exists $m->{refs}->{$value}) {
#      $value=$m->{refs}->{$value};
#
#    };

    push @$dst,[$name,$value];

  };

};

# ---   *   ---   *   ---
# decomposes a value declaration tree

sub ptr_decl($m,$tree) {

  my ($header,$data,%out)=getout('ptr_decl');

# ---   *   ---   *   ---
# save block entry descriptors

  $header->{spec}=[
    $tree->branch_values($BRANCH_RE->{spec})

  ];

  $header->{type}=[
    $tree->branch_values($BRANCH_RE->{type})

  ];

  my @names=$tree->branch_values(
    $BRANCH_RE->{name}

  );

  my @values=$tree->branch_values(
    $BRANCH_RE->{vals}

  );

# ---   *   ---   *   ---

  { my ($names,$values)=regpad(\@names,\@values);
    regfmat($data,$names,$values);

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
    $tree->branch_values($BRANCH_RE->{directive})

  ];

  $header->{spec}=undef;

# ---   *   ---   *   ---
# push to data

  push @$data,$tree->branch_values(
    $BRANCH_RE->{name}

  );

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

  Readonly my $CALLTAB=>{

    'ptr_decl'=>\&ptr_decl,
    'ptr_decl_pack'=>\&ptr_decl_pack,

    'type_decl'=>\&type_decl,
    'type_decl_pack'=>\&type_decl_pack,

  };

# ---   *   ---   *   ---
# use tree to build instruction

sub take($m,$key,$tree) {

  my $pkg=$CALLTAB->{$key}->($m,$tree);
  my $btc=$CALLTAB->{$key.'_pack'}->($m,$pkg);

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

        if(peso::node::valid($$n)) {
          $$n=$$n->collapse()->{value};

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
