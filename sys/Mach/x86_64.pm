#!/usr/bin/perl
# ---   *   ---   *   ---
# MACH x86_64
# Helps me think in aramaic
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mach::x86_64;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Fmat;

  use Arstd::Array;
  use Arstd::String;
  use Arstd::Int;
  use Arstd::Re;

  use Tree;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.9;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $REGISTERS=>{
    arg=>[qw(rdi rsi rdx r10 r8 r9)],
    stk=>[qw(rbx r11 r12 r13 r14 r15 rcx)],
    ret=>[qw(rax)],

  };

  Readonly my $REGISTERS_RE=>re_eiths(

    [map {@$ARG} values %$REGISTERS],

    bwrap  => 1,
    insens => 0,

  );

  Readonly my $IS_IMM=>qr{^[\d\.\:]+f?$};

# ---   *   ---   *   ---
# cstruc

sub new($class) {

  my $self=bless {

    cur  => undef,
    tab  => {},

    size => 0,
    tf   => Tree->new_frame(),

  },$class;

};

# ---   *   ---   *   ---
# get listing of used/avail
# registers, guts v

sub _get_avail($self,$ar,$avail) {

  my @out=();

  # make note of used registers
  while(@$avail && @$ar) {

    push @out,
       (shift @$avail)
    => (shift @$ar)->{c_data_id}
    ;

  };

  # ^stack-allocate if we run
  # out of registers
  while(@$ar) {

    my $v     = shift @$ar;

    my $width = $v->get_bwidth();
    my $pos   = int_align($self->{size},$width);

    my $id    = $v->set_fasm_lis($self->{size});

    push @out,$id=>$v->{c_data_id};

    $self->{size}=$pos+$width;

  };


  # ^give used
  return @out;

};

# ---   *   ---   *   ---
# ^get registers used by blk
# iface v

sub get_avail($self,$dst,$key,$ar) {

  my @avail = (@{$REGISTERS->{$key}},@$dst);
  my @used  = $self->_get_avail(
    $ar,\@avail

  );

  @$dst=@avail;

  return (

    $key       => \@used,
    "${key}_s" => [],

  );

};

# ---   *   ---   *   ---
# ^combo

sub get_avail_all($self,$dst,%O) {

  return map {
    $self->get_avail($dst,$ARG,$O{$ARG}),

  } qw(arg stk ret);

};

# ---   *   ---   *   ---
# make new frame

sub new_blk($self,$name,%O) {

  # defaults
  $O{arg} //= [];
  $O{stk} //= [];
  $O{ret} //= [];


  # get calling frame
  my $old   = $self->{reg}->[-1];
  my @avail = ();

  my $tf    = $self->{tf};

  # ^make tables
  my $reg={

    $self->get_avail_all(\@avail,%O),

    sct      => {},
    sctk     => [],

    avail    => \@avail,
    using    => [],

    using_re => $NO_MATCH,
    xtab     => {},

    size     => 0,
    insroot  => $tf->new(
      undef,"$name\::insroot"

    ),

  };


  # add to table and give
  $self->{tab}->{$name} = $reg;
  $self->{cur}          = $reg;

  $self->{cur}->{size}  = $self->{size};
  $self->{size}         = 0;

  $self->reset_using();

  return $reg;

};

# ---   *   ---   *   ---
# make re for finding used
# registers

sub reset_using($self) {

  my $cur=$self->{cur};

  # ^get full list of
  # registers in use
  @{$cur->{using}}=map {
    @{$cur->{$ARG}}

  } qw(arg stk ret sctk);

  # ^as regex
  $cur->{using_re}=re_eiths(
    [array_keys($cur->{using})]

  ) if @{$cur->{using}};

};

# ---   *   ---   *   ---
# ^set X to cur

sub set_blk($self,$name) {
  $self->{cur}=$self->{tab}->{$name}
  if exists $self->{tab}->{$name};

};

# ---   *   ---   *   ---
# allocate register

sub get_scratch($self) {

  my $cur=$self->{cur};
  my $out=shift @{$cur->{avail}};

  $cur->{sct}->{$out}=1;
  $cur->{sctk}=[keys %{$cur->{sct}}];

  $self->reset_using();

  return $out;

};

# ---   *   ---   *   ---
# ^give back

sub free_scratch($self,$name) {

  my $cur=$self->{cur};
  unshift @{$cur->{avail}},$name;

  delete $cur->{sct}->{$name};
  $cur->{sctk}=[keys %{$cur->{sct}}];

  $self->reset_using();

};

# ---   *   ---   *   ---
# get overlap in used registers

sub get_used_by($self,$name) {

  my $cur=$self->{cur};
  my $old=$self->{tab}->{$name};

  throw_no_blk($name) if ! $old;


  return map {
    my $re=$old->{using_re};
    grep {$ARG=~ $re} @{$cur->{$ARG}};

  } qw(arg stk ret);

};

# ---   *   ---   *   ---
# ^used by cur

sub in_use($self,$name) {
  my $cur=$self->{cur};
  return int($name=~ $cur->{using_re});

};

# ---   *   ---   *   ---
# ^give code for save/restore

sub save_used_by($self,$name) {

  my @used=$self->get_used_by($name);


  my $save=join "\n",map {
    "push $ARG"

  } @used;

  my $load=join "\n",map {
    "pop $ARG"

  } reverse @used;


  return ("$save\n","$load\n");

};

# ---   *   ---   *   ---
# ^give code for passing args

sub pass_args($self,$name,@values) {

  my $cur=$self->{cur};
  my $old=$self->{tab}->{$name};

  throw_no_blk($name) if ! $old;


  my $args=$old->{arg};

  throw_arg_cnt($name)
  if int(@values) < int(@$args);


  my @out=map {

    my $src=$values[$ARG];
    my $dst=$args->[$ARG];

    "mov $dst,$src";

  } 0..@$args-1;


  return join "\n",@out,"\n";

};

# ---   *   ---   *   ---
# ^errme

sub throw_no_blk($name) {

  errout(

    q[Invalid block name '%s'],

    lvl  => $AR_FATAL,
    args => [$name],

  );

};

# ---   *   ---   *   ---
# make new instruction branch

sub new_ins($self,$dst) {

  my $cur  = $self->{cur};
  my $root = $cur->{insroot};

  $root->inew($dst);

};

# ---   *   ---   *   ---
# ^sub-branch

sub new_insblk($self,$dst) {

  my $cur  = $self->{cur};
  my $root = $cur->{insroot}->{leaves}->[-1];

  $root->inew($dst);

};

# ---   *   ---   *   ---
# ^add instruction to top

sub push_insblk($self,$ins,@args) {

  my $cur  = $self->{cur};
  my $root = $cur->{insroot}->{leaves}->[-1];

  my $blk  = $root->{leaves}->[-1];
  my $top  = $blk->{leaves}->[-1];

  my $nd   = ($top && $top->{value} eq $ins)
    ? $top
    : $blk->inew($ins)
    ;

  map  {$nd->inew($ARG)}
  grep {$ARG} @args;

};

# ---   *   ---   *   ---
# ^add attrs to instruction

sub attr_tie($self,$ins,$attrs) {

  array_dupop($attrs);

  $ins.=
    (':' x (@$attrs != 0))
  . (join ':',@$attrs)
  ;

  return $ins;

};

# ---   *   ---   *   ---
# translates single instruction

sub xlate_sins($self,$dst,$branch) {

  state $tab={

    'add'=>'xlate_add',
    'mul'=>'xlate_mul',
    'sub'=>'xlate_sub',
    'div'=>'xlate_div',

    'mov'=>'xlate_mov',

  };


  # fetch attributes from instruction
  my $ins   = $branch->{value};
  my @attrs = split ':',$ins;

  $ins=(@attrs)
    ? shift @attrs
    : $ins
    ;

  my %attrs=map {$ARG=>1} @attrs;

  # ^set defaults
  $attrs{set}  //= 0;
  $attrs{sign} //= 0;
  $attrs{real} //= 0;

  $attrs{set} &=! $branch->{idex};

  # ^invoke
  my $fn=$tab->{$ins};
  return $self->$fn($dst,$branch,%attrs);

};

# ---   *   ---   *   ---
# generate translation for
# a single instruction block

sub xlate_insblk($self,$dst,$blk) {

  my @out   = ();

  # directives as-is
  if($dst eq 'meta') {

    push @out,(map {

      "$ARG->{value} "
    . (join q[ ],$ARG->branch_values())

    } @{$blk->{leaves}}),"\n";


  # ^proc machine instructions
  } else {

    my $r_dst=$blk->{value};

    push @out,map {
      $self->xlate_sins($r_dst,$ARG);

    } @{$blk->{leaves}};

  };


  return @out;

};

# ---   *   ---   *   ---
# ^bat

sub xlate_ins($self) {

  my @out  = ();

  my $cur  = $self->{cur};
  my $root = $cur->{insroot};


  # walk the tree
  map {

    my $blk=$ARG;

    $self->opz_insblk($blk);

    push @out,map {
      $self->xlate_insblk($blk->{value},$ARG)

    } @{$blk->{leaves}};

  } @{$root->{leaves}};


  return join "\n",@out,"\n";

};

# ---   *   ---   *   ---
# ^clears out redundancies

sub opz_insblk($self,$blk) {

  my $dst = $blk->{value};
  my $lv  = $blk->{leaves};

  # chk blk qualifies for optimization
  return if
    ! ($dst =~ $REGISTERS_RE)
  ||  @$lv  == 1
  ;


  # get intermediate destinations
  # and the instructions on each
  my @idst = map {$ARG->{value}} @$lv;
  my @ins  = map {$ARG->leaf_value(0)} @$lv;


  # ^chk if mov at end of blk is redundant
  if($ins[-1] eq 'mov') {

    my $nd=$lv->[-1]->{leaves}->[0];

    # ^result of add is source of mov
    if($idst[-2] eq $nd->leaf_value(-1)) {
      $lv->[-2]->{value}=$idst[-1];
      $lv->[-1]->discard();

    };

  };

};

# ---   *   ---   *   ---
# combine successive immediates
# by multiplying

sub imm_mul($self,$branch) {

  my @args = ();
  my $imm  = 1;

  map {

    # combine immediates
    if($ARG=~ $IS_IMM) {
      $imm*=$ARG;

    # ^arg is reg or mem
    } else {

      # ^pending combo
      if($imm > 1) {
        push @args,$imm;
        $imm=1;

      };

      # ^then current arg
      push @args,$ARG;

    };

  } $branch->leafless_values();


  # cat pending
  push @args,$imm if $imm > 1;

  # ^get number of iterations
  my $limit=int_urdiv(int(@args),2);


  return ($limit,@args);

};

# ---   *   ---   *   ---
# ^get [dst,src] pairs

sub despair($self,$dst,$args,$i,%O) {

  my @pro=();

  # index with pair offset
  my $a=$args->[0+$ARG*2];
  my $b=$args->[1+$ARG*2];

  # ^shift missing arg (implicit dst)
  if(! defined $b) {
    $b=$a;
    $a=$dst;

  };

  # ^dst switcheroo for cpy
  if($O{set}) {
    @pro = ("  mov $dst,$b") if ! $i;
    $a   = $dst;

  };


  return ($a,$b,@pro);

};

# ---   *   ---   *   ---
# halfway optimized division

sub xlate_div($self,$dst,$branch,%O) {


  # get processed list of args
  # plus number of iterations
  my ($limit,@args)=$self->imm_mul($branch);

  # ^walk [dst,src] pairs
  return map {

    my ($a,$b,@pro)=$self->despair(
      $dst,\@args,$ARG,%O

    );

    my @ins=();

    # optimize division by constant
    if($b=~ $IS_IMM) {

      # div by pow2 is shift
      if(my $shf=int_ispow($b,2)) {
        @ins=("  shr $a,$shf");

      # NOTE:
      #
      #   Y=(2^32)/B   rounded up
      #   (A*Y) >> 32  gives divide
      #
      #   this is the only formula I can
      #   wrap my head around, but it doesn't
      #   work for bigger numbers
      #
      #   gcc does a similar trick but I'm
      #   not sure how they calculate the
      #   constants, so I can't use it
      #
      #   in any case, i can make do with
      #   16 bits so this is already overkill

      # ^32-bit imul trick ;>
      } else {

        $b=int_urdiv(1 << 32,$b);

        @ins=(
          "  mov  rdx,$b",
          "  imul $a,rdx",
          "  shr  $a,32"

        );

      };

    # ^sadface
    } else {


      @ins=(

        ($a ne 'rax')
          ? "  mov rax,$a"
          : ()
          ,

        "  xor rdx,rdx",
        "  div $b",

      );

    };


    (@pro,@ins);

  } 0..$limit-1;

};



# ---   *   ---   *   ---
# halfway optimized multiplication

sub xlate_mul($self,$dst,$branch,%O) {

  # ^same as previous F
  my ($limit,@args)=$self->imm_mul($branch);

  return map {

    my ($a,$b,@pro)=$self->despair(
      $dst,\@args,$ARG,%O

    );

    my @ins=();


    # optimize multiplication by constant
    if($b=~ $IS_IMM) {

      # mul by pow2 is shift
      if(my $shf=int_ispow($b,2)) {
        @ins=("  shl $a,$shf");

      # ^attempt lea
      } else {

        $b-- if ! $O{set};
        my @dupop=$self->xlate_add_dupop_sort(
          $dst,[($a) x $b],%O

        );

        @ins=map {

            "  lea $dst,["

          . (join '+',@$ARG)
          . ']'
          ;

        } @dupop;

      };

    # ^no optimization
    } else {
        @ins=("  imul $a,$b");

    };


    (@pro,@ins);

  } 0..$limit-1;

};

# ---   *   ---   *   ---
# placeholder: plain ow

sub xlate_mov($self,$dst,$branch,%O) {
  my @args=$branch->leafless_values();
  return "  mov $args[0],$args[1]";

};

# ---   *   ---   *   ---
# optimize multiple adds
# into lea

sub xlate_add($self,$dst,$branch,%O) {


  my @out   = ();
  my @args  = ();


  # filter out immediates
  my $imm=0;map {

    if($ARG=~ $IS_IMM) {
      $imm+=$ARG;

    } else {
      push @args,$ARG;

    };

  } $branch->leafless_values();

  push @args,$imm if $imm;


  # ^combine duplicates
  @args=$self->xlate_add_dupop_sort(
    $dst,\@args,%O

  );


  # generate ins
  map {

    push @out,"  lea $dst,["
    . (join '+',@$ARG)
    . ']'
    ;

  } @args;


  return @out;

};

# ---   *   ---   *   ---
# ^combine repeats into scale

sub xlate_add_dupop($self,$args) {


  state $is_scale = qr{^[248]$};


  my $duped={};
  my @dupop=();


  for my $base(@$args) {

    next if exists $duped->{$base};


    # get repeats of name
    my @dup=grep {$ARG eq $base} @$args;


    # ^build array of repeats
    while(@dup) {

      my $limit=(@dup < 8)
        ? @dup
        : 8
        ;

      # 2,4 or 8
      if($limit=~ $is_scale) {
        push @dupop,$base=>$limit;

      # ^3 or 5
      } elsif($limit eq 3 || $limit eq 5) {

        push @dupop,
          $base => $limit-1,
          $base => 1,

        ;

      # ^6 or 7
      } elsif($limit eq 6 || $limit eq 7) {

        my $cnt=$limit-4;

        push @dupop,
          $base => 4,
          $base => $cnt,

        ;

      # ^single
      } else {
        push @dupop,$base=>1;

      };


      map {shift @dup} 0..$limit;

    };

    $duped->{$base}=1;

  };


  return @dupop;

};

# ---   *   ---   *   ---
# ^wrap and sort repeats

sub xlate_add_dupop_sort($self,$dst,$old,%O) {

  my @dupop = $self->xlate_add_dupop($old);


  my @out = ($O{set}) ? ([]) : ([$dst]);
  my $has = {};

  my @arg = array_keys(\@dupop);
  my @cnt = array_values(\@dupop);


  # ^walk
  my $j=0;for my $i(0..$#cnt) {


    # get arg fits in instruction
    my $arg   = $arg[$i];
    my $cnt   = $cnt[$i];
    my $have  = $cnt > 1;


    # get free slot
    my ($slot)=grep {

        @$ARG < 3
    && (! $has->{$ARG} ||! $have)

    } @out;

    # ^make new if none
    if(! $slot) {
      push @out,($j) ? [$dst] : [];
      $slot=$out[-1];

    };


    # ^push to Q
    push @$slot,($have)
      ? "$arg*$cnt"
      : "$arg"
      ;

    $has->{$slot} |= $have;
    $j++;

  };


  return @out;

};

# ---   *   ---   *   ---
# debug out

sub prich_ins($self) {

  my $cur  = $self->{cur};
  my $root = $cur->{insroot};

  $root->prich();

};

sub prich_insblk($self) {

  my $cur  = $self->{cur};
  my $root = $cur->{insroot}->{leaves}->[-1];

  $root->prich();

};

# ---   *   ---   *   ---
1; # ret
