#!/usr/bin/perl
# ---   *   ---   *   ---

package main;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{ARPATH}.'/avtomat/sys/';
  use Style;

  use rd;
  use Bpack;

  use Arstd::Bytes;

# ---   *   ---   *   ---
# rev xform test

sub holy_bit($l2,$branch) {

  # get ctx
  my $rd = $l2->{rd};
  my $l1 = $rd->{l1};

  # have operator?
  my $key   = $branch->{value};
  my $opera = $l1->is_opera($key);

  if(defined $opera) {
    quantize_opera($rd,$branch,$opera);
    $branch->{value}=$l1->make_tag(REG=>0);

  };


  return;


};

# ---   *   ---   *   ---
# ^~

sub quantize_opera($rd,$branch,$opera) {


  # get ctx
  my $l1  = $rd->{l1};
  my $mc  = $rd->{mc};
  my $ISA = $mc->{ISA};
  my $imp = $ISA->imp();


  #  get argument types
  my @args   = $branch->branch_values();
  my @args_b = map {

    my ($type,$spec) = $l1->read_tag($ARG);
    my $have         = $l1->quantize($ARG);

    $type .= $spec if $type eq 'm';
    (defined $have) ? [$type,$have] : () ;


  } @args;


  # ^validate
  return null
  if @args_b != int @args;

  @args=@args_b;


  # apply formatting to arguments
  @args=map {

    my ($type,$have)=@$ARG;

    if($type eq 'r') {
      {type=>$type,reg=>$have};

    } elsif($type eq 'i') {
      my $spec=(8 < bitsize $have) ? 'y' : 'x' ;
      {type=>"i$spec",imm=>$have};

    };


  } @args;

  # find instruction matching op
  my $name=$imp->xlate($opera,@args);
  return null if ! length $name;

  $mc->exewrite(
    $mc->{scratch},
    ['word',$name,@args],

  );

};

# ---   *   ---   *   ---
# ~

use Fmat;
use Arstd::xd;

my $rd = rd('./lps/lps.rom');
my $mc = $rd->{mc};

$rd->walk(limit=>2,rev=>\&holy_bit);
#$rd->prich();

my @ins=$mc->exeread($mc->{scratch});
$mc->ipret(@ins);
$mc->{anima}->prich();

# ---   *   ---   *   ---
1; # ret
