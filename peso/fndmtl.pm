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
  use strict;
  use warnings;

# ---   *   ---   *   ---

sub ptr_decl($$) {

  my ($m,$tree)=@_;

  my %out=(
    type=>'ptr_decl',

    header=>{},
    data=>{},

  );

# ---   *   ---   *   ---

  my $header=$out{header};
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

  my @data;
  while(@names) {

    my $name=shift @names;
    my $value=shift @values;

    if(exists $m->{refs}->{$value}) {
      $value=$m->{refs}->{$value};

    };

    push @data,[$name,$value];

  };

  $out{data}=\@data;
  return \%out;

};

# ---   *   ---   *   ---

sub ptr_decl_pack($$) {

  my ($m,$pkg)=@_;

  return

  [ $m->blk->DST,
    'expand',

    $pkg->{data},
    $pkg->{header}->{type}->[0],
    0,

  ];

};

# ---   *   ---   *   ---

use constant CALLTAB=>{

  'ptr_decl'=>\&ptr_decl,
  'ptr_decl_pack'=>\&ptr_decl_pack,

};

# ---   *   ---   *   ---

sub take($$$) {

  my ($m,$key,$tree)=@_;

  my $pkg=CALLTAB->{$key}->($m,$tree);
  my $btc=CALLTAB->{$key.'_pack'}->($m,$pkg);

  return $btc;

};

sub give($$) {

  my ($m,$branch)=@_;

  my $btc=$branch->{btc};
  my $scope=$btc->[0];
  my $fn=$btc->[1];

  my @args=@{$btc}[2..@{$btc}-1];

  $scope->$fn(@args);

};

# ---   *   ---   *   ---

sub run($$) {

  my ($m,$branch)=@_;

  my $btc=$branch->{btc};
  my $scope=$btc->[0];
  my $fn=$btc->[1];

  my @args=@{$btc}[2..@{$btc}-1];
  for my $arg(@{$args[0]}) {

    my $n=$arg->[1];

    if(peso::node::valid $n) {
      $arg->[1]=$n->collapse()->value;

    };

  };$scope->$fn(@args);

};

# ---   *   ---   *   ---
1; # ret
