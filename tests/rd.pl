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
  use Arstd::IO;

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

    $branch->prich();

    my $dst=quantize_opera(
      $rd,$branch,$opera

    );

    $branch->{value}=$dst;
    $branch->clear();

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

    } else {
      nyi "memory operands";

    };


  } @args;


  # find instruction matching op
  my @program=$ISA->xlate($opera,'word',@args);
  $mc->exewrite($mc->{scratch},@program);

  @args=$program[-1]->[2];


  # give dst as a tag
  my $type = $args[0]->{type};
  my $out  = undef;

  if($type eq 'r') {
    $out=$l1->make_tag(REG=>$args[0]->{reg});

  } elsif(! index $type,'i') {
    $out=$l1->make_tag(NUM=>$args[0]->{imm});

  } else {
    nyi "memory operands";

  };


  return $out;

};

# ---   *   ---   *   ---
# the bit

use Fmat;
use Arstd::xd;

my $rd = rd('./lps/lps.rom');
my $mc = $rd->{mc};


my $mem   = $mc->{anima}->{mem};
my $alloc = $mem->get_alloc();

my @buf   = map {
  $alloc->get_block(0x04);

} 0..0x10;

$alloc->prich(inner=>1,root=>1,depth=>1);

#   $mem   = $alloc->{mem};
#
#my $tree  = $mem->{inner};
#
#my $node  = $tree->has('head','lvl[0]');
#   $node  = $$node;
#
#$node->store(0x0020);
#$alloc->prich(inner=>1);

#$rd->walk(limit=>2,rev=>\&holy_bit);
#$rd->prich();

#my @ins=$mc->exeread($mc->{scratch});
#$mc->ipret(@ins);
#$mc->{anima}->prich();
#$mc->{scratch}->prich(root=>1);

# ---   *   ---   *   ---
1; # ret
