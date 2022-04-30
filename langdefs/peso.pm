#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO
# $ syntax defs
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package langdefs::peso;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use lang;

  use peso::decls;
  use peso::rd;
  use peso::ptr;
  use peso::node;
  use peso::block;
  use peso::symbol;
  use peso::defs;
  use peso::program;

# ---   *   ---   *   ---

sub SYGEN_KEY {return -PESO;};
sub RC_KEY {return 'peso';};

# ---   *   ---   *   ---

my %PESO=(

  -NAME=>'peso',

  -EXT=>peso::decls::ext,
  -HED=>peso::decls::hed,
  -MAG=>peso::decls::mag,
  -COM=>peso::decls::com,

# ---   *   ---   *   ---

  -VARS =>[

    # primitives
    [0x04,lang::eiths(

      '('.peso::decls::types_re().
      ')'.'[1-9]*,'

    ,1)],

    # intrinsics
    [0x04,peso::decls::intrinsic],

    # simbolic constants (sblconst)
    [0x04,lang::eiths(

      'self,null,non,other'

    ,1)],

  ],

# ---   *   ---   *   ---

  -BILTN =>[

    # instructions
    [0x01,lang::eiths(

      ( join ',',
        keys %{peso::decls::bafa()}

      ).','.

      'mem,fre,'.
      'shift,unshift,'.

      'kin,sow,reap,'.
      'sys,stop'

    ,1)],

  ],

# ---   *   ---   *   ---

  -KEYS =>[

    # program flow
    [0x0D,lang::eiths(
      (join ',',keys %{peso::decls::bafc()})

    ,1)],

    # directives
    [0x0D,lang::eiths(
      (join ',',keys %{peso::decls::bafb()})

    ,1)],

  ],

# ---   *   ---   *   ---

);$PESO{-LCOM}=[
  [0x02,lang::eaf($PESO{-COM},0,1)],

];lang::DICT->{SYGEN_KEY()}=\%PESO;

# ---   *   ---   *   ---

my %MAM=(

  # subrd for current context
  -CNTX=>'non',

  # fwd decl the execution path table
  -EXTAB=>{},

  # instruction stack
  -PROGRAM=>[],

);

# ---   *   ---   *   ---

# in: filename
# reads in a peso file
sub peso_rd {

  my @exps=@{peso::rd::file(shift)};

# ---   *   ---   *   ---
# aliases for these patterns

  my $directive=$PESO{-KEYS}->[1]->[1];
  my $flowctl=$PESO{-KEYS}->[0]->[1];

  my $primitive=$PESO{-VARS}->[0]->[1];
  my $intrinsic=$PESO{-VARS}->[1]->[1];
  my $sblconst=$PESO{-VARS}->[2]->[1];

  my $instruct=$PESO{-BILTN}->[0]->[1];

  my $operator='\{|\}';

  my $number
    =lang::DICT->{-GPRE}
    ->{-NUMS}->[0]->[1];

# ---   *   ---   *   ---

  my $pat='(('.$directive.'\s+)';
  $pat.='|('.$primitive.'\s+)';

  $pat.='|('.$instruct.'(\s+|$))';
  $pat.='|('.$flowctl.'(\s+|$))';
  $pat.='|('.$intrinsic.'(\s+|$))';

  $pat.='|('.$sblconst.'\s+)';

  $pat.='|('.$operator.'\s*)';

  $pat.=")*";
  my @tree=();
  my $program=$MAM{-PROGRAM};

# ---   *   ---   *   ---

  # initialize peso modules
  peso::program::nit();

  # iter expressions
  for my $exp(@exps) {

    if(!$exp) {next;};
    $exp=~ s/^\s*(${ pat })//;

    # first element is topmost in hierarchy
    my $key=$1;

    if( !(defined $key)
    ||  (!$exp && !length $key)

    ) {next;};

    $exp=~ s/\s*(${operator}+)\s*/$1/sg;
    $exp=~ s/(\(|\[|\]|\))/ $1 /sg;

# ---   *   ---   *   ---

    # create root node
    my $root=peso::node::nit(undef,$key);

    # determine expath from key and context

    my $expath=undef;
    { my $i=0;for my $p(

        $directive,
        $flowctl,
        $primitive,
        $intrinsic,
        $sblconst,
        $instruct,

        $operator,

      ) {

        # get index of matching group
        my $sa=$key=~ m/${p}/;
        if($sa) {last;};$i++;

      };

# ---   *   ---   *   ---

      # fetch expath from table

      my $tab=peso::defs::SYMS;

      if($tab) {

        my $k=($i==2)
          ? 'value_decl'
          : $key
          ;

        $k=~ s/\s+$//;
        if(exists $tab->{$k}) {
          $expath=$tab->{$k};

        };

      };
    };

# ---   *   ---   *   ---

    $exp=~ s/\s+,/,/;

    # tokenize expression
    $root->splitlv(

      '\b[^\s]+\b\s',
      $exp

    );

# ---   *   ---   *   ---

    # sort tokens
    $root->branch_reloc();
    $root->agroup();
    $root->subdiv();

    # solve constants
    $root->collapse();

# ---   *   ---   *   ---

    # save instructions
    if(!$root->{-PAR}) {

      push @tree,$root;

      # context swapping
      if($key=~ m/(reg|proc|clan)/) {
        $MAM{-CNTX}=$1;

      # data block or directive
      };if(

         $MAM{-CNTX} eq 'reg'
      || $key=~ m/$directive/

      ) {

        $expath->ex($root,$key);

        # save data initializer
        # run on second pass
        if($MAM{-CNTX}=~ m/reg|clan/) {

          push(
            @$program,
            [$expath,$root,$key]

          );
        };

# ---   *   ---   *   ---

      # code block
      } elsif($MAM{-CNTX} eq 'proc') {

        # initialize
        if($root->val=~ m/proc/) {
          $expath->ex($root);

# ---   *   ---   *   ---

        # encode instruction
        } else {

          my $ins_name=$root->val;
          my $stack_alloc=0;

          if($root->val=~ m/$primitive/) {

            $expath->ex($root);

            my $dst=$MAM{-DST};

            push(

              @$program,
              [ sub {peso::block::DST($dst)},
                $root,$key

              ]

            );

            push(
              @$program,
              [$expath,$root,$key]

            );next;

          };

# ---   *   ---   *   ---

          my $dst=peso::block::DST;
          my $inum=peso::program::nxins;

          # generate identifier
          my $iname=sprintf(
            'ins_%.08i',$inum

          # get instruction id
          );

          my $inskey=$root->val;
          $inskey=~ s/\s+$//;

          my $iidex=
              peso::defs::INSID->{$inskey};

          my @ins=([$iname,$iidex]);

# ---   *   ---   *   ---

          # encode args
          my $nname=sprintf(
            'arg_%.08i',$inum

          );my $nidex=peso::program::setnode(
            $root

          );


# ---   *   ---   *   ---

          # save encoded ins+args
          $dst->expand([
            [$iname,$iidex],
            [$nname,$nidex],

          ],'long');

          push(
            @$program,

            [ \&peso::block::expand,

              $dst,

              [ [$iname,$iidex],
                [$nname,$nidex] ],

              'long'

            ]
          );

        };peso::program::incnxins();

      };

    };
  };

# ---   *   ---   *   ---
# replace names with ptr references
# we only do this once all names are declared

  for my $root(@tree) {
    $root->findptrs();

  };

# ---   *   ---   *   ---
# run second pass to set values
# memory is already reserved

  peso::block::incpass();
  for my $ref(@$program) {
    my @ar=@{$ref};

    my $sym=shift @ar;
    my @args=@ar;

    if(peso::symbol::valid($sym)) {
      $sym->ex(@args);

    } else {
      $sym->(@args);

    };

  };

# ---   *   ---   *   ---
# execute and print memory

  peso::program::run();
  peso::block::NON->prich();

  return;

};

# ---   *   ---   *   ---
1; # ret
