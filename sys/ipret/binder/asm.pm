#!/usr/bin/perl
# ---   *   ---   *   ---
# ASM BINDER
# Premature optimizations
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package ipret::binder::asm;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;

  use Arstd::Bytes;
  use Arstd::IO;
  use Arstd::WLog;

  use rd::vref;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# marks registers as holding
# values that must be preserved

sub regused($self,$branch,$proc,$ins,@args) {


#  # get ctx
#  my $l1  = $self->{l1};
#  my $tab = $proc->{vref}->{data};
#
#
#  # map register idex to bit
#  my $bit = 1 << $idex;
#
#  # add elem to timeline
#  my $have=$tab->timeline(
#    $branch->{-uid},
#
#    almask => $bit,
#    ins    => $ins,
#
#  );


  skip:
  return;

};

# ---   *   ---   *   ---
# ^back said values to stack
# when the register has to be
# overwritten!

sub regspill($self,$branch,$dst,$src) {


  # get ctx
  my $mc       = $self->{mc};
  my $anima    = $mc->{anima};
  my $l1       = $self->{l1};
  my $enc      = $self->{encoder};

  my $def_opsz = typefet 'qword';


  # compare avail mask to required!
  my $need = $dst->{-regal}->{glob};

  my $have = $src->{-regal}->{call};
     $have = $have->{$branch->{-uid}};

  my $iggy = ~$anima->reserved_mask;

  my $col  = ($need & $have) & $iggy;


  # get registers to backup/restore
  my $stack = $src->{-stack};
  my @order = ();

  my @reg   = grep {0 > index $ARG,'-'} keys %$src;


  while($col) {

    my $idex=(bitscanf $col)-1;
    $col &= ~(1 << $idex);

    my ($opsz,$key,$loc)=(
      $def_opsz,
      null,

      $stack->{size}

    );


    # have named var?
    my $r=undef;
    @reg=map {

      my $tmp=$src->{$ARG};

      if($tmp->{spec} != $idex) {
        $ARG;

      } else {
        $r=$tmp;
        ();

      };

    } @reg;


    # spilling named variable?
    if(defined $r) {
      nyi "named var spill";

    # ^spilling unnamed!
    } else {
      $key="\$reg-$idex";

    };


    # new variable?
    $src->{$key}=rd::vref->new(

      type => 'REG',

      spec => $idex,
      res  => $opsz,

    ) if ! exists $src->{$key};


    # new stack allocation?
    if(! defined $stack->{have}->{$key}) {
      $stack->{size} += $opsz->{sizeof};

      $loc=$stack->{size};
      $stack->{have}->{$key}=$loc;

    # ^nope, reuse!
    } else {
      $loc=$stack->{have}->{$key};

    };


    push @order,{
      type=>'r',reg=>$idex,
      meta=>[$opsz,$key,$loc]

    };

  };

  goto skip if ! @order;


  # generate additional branches...
  my $par=$branch->{parent};
  my ($pre,$post)=(
    $par->insert($branch->{idex},'pre'),
    $par->insert($branch->{idex}+1,'post'),

  );


  # ^spawn instructions on them ;>
  my $idex=0;

  map {

    my $end=$#order-$ARG;
    my $obj=$order[$ARG];

    my ($opsz,$key,$loc)=@{$obj->{meta}};
    delete $obj->{meta};


    $enc->binreq($pre,[$opsz,st=>{

      type => 'mstk',
      imm  => $loc,

    },$obj]);


  } 0..$#order;


  skip:
  return;

};

# ---   *   ---   *   ---
# generate enter/leave boilerplate
# based on stack use required
# by the previous methods!

sub setup_stack($self,$branch) {


  # skip if there's no stack usage!
  my $vref  = $branch->{vref};
  my $stack = $vref->{data}->{stack};
  my $size  = $stack->{size};

  return if ! $size;


  # get ctx
  my $enc   = $self->{encoder};
  my $l1    = $self->{l1};
  my $anima = $self->{mc}->{anima};
  my $ISA   = $self->{mc}->{ISA};

  my $opsz  = typefet 'qword';


  # get registers
  my $base={
    type => 'r',
    reg  => $anima->stack_base,

  };

  my $ptr={
    type => 'r',
    reg  => $anima->stack_ptr,

  };


  # get offset
  my $imm={
    type => $ISA->immsz($size),
    imm  => $size,

  };


  # dispatch instructions
  my @req=(
    [$opsz,push=>$base],
    [$opsz,ld=>$base,$ptr],
    [$opsz,sub=>$ptr,$imm],

  );

  $enc->binreq($branch,@req);


  # add closing
  my $re=$l1->re(CMD=>'asm-ins'=>'ret');
  map {

    $enc->binreq(
      $ARG->prev_leaf,
      [$opsz,'leave']

    );

  } $branch->branches_in($re);

  return;

};

# ---   *   ---   *   ---
# load the arguments to a call
# into registers, per Linux convention

sub ldargs($self,$branch,$src,@args) {


  # get ctx
  my $l1    = $self->{l1};
  my $enc   = $self->{encoder};
  my $eng   = $self->{engine};

  my @onerr = (

    $branch,

    "no target [ctl]:%s for [good]:%s",
    args=>['proc','pass'],

  );


  # determine target process
  my $call=$src->{-regal}->{call};
  $self->bperr(@onerr) if ! int keys %$call;

  my $re     = $l1->re(CMD=>'asm-ins','call');
  my $anchor = $branch;
  my $found  = 0;


  # walk the tree until next call is found
  while($anchor->{parent} ne $self->{tree}) {

    $anchor=$anchor->next_leaf();
    last if ! defined $anchor;


    # mark/release this register on success ;>
    if($anchor->{value}=~ $re) {
      $found=1;

      my $name = $anchor->{vref}->{res};
         $name = $name->{args}->[0];

      my $dst  = $eng->symfet($name->{data});
         $dst  = $dst->{p3ptr}->{vref};
         $dst  = $dst->{data};

      my $need = $dst->{-order};

      map {

        my $reg   = $need->[$ARG];
        my $value = $args[$ARG];
        my $opsz  = $reg->{res};

        my $mem   = {type=>'r',reg=>$reg->{spec}};

        # auto reus...
        $call->{$anchor->{-uid}} &=
          ~(1 << $mem->{reg});


        # ~:~
        if(defined $value) {

          $enc->binreq(
            $branch,[$opsz,ld=>$mem,$value]

          );

        } else {
          nyi "set defv on ldargs";

        };

      } 0..@$need-1;

      last;

    };

  };


  $self->bperr(@onerr) if ! $found;
  return;

};

# ---   *   ---   *   ---
1; # ret
