#!/usr/bin/perl
# ---   *   ---   *   ---
# ASM
# Pseudo assembler
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package ipret::cmdlib::asm;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;
  use Bpack;

  use Arstd::Bytes;
  use Arstd::Array;
  use Arstd::IO;

  use rd::vref;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'ipret::cmd';
  BEGIN {ipret::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.02.7;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# offset within current segment

sub current_byte($self,$branch) {

  my $main = $self->{frame}->{main};
  $branch->{vref}->{res}=$main->cpos;

  return;

};

# ---   *   ---   *   ---
# defines entry point

sub entry($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};
  my $l1   = $main->{l1};
  my $sep  = $mc->{pathsep};
  my $vref = $branch->{vref};

  # get name of symbol
  my $name=$vref->{spec};


  # ^as a path!
  my @path=split $sep,$name;

  # can fetch symbol?
  my $seg=$mc->ssearch(@path);
  return $branch if ! length $seg;


  # validate, set and give
  $main->perr(
    "redeclaration of entry point"

  ) if defined $main->{entry};

  $main->{entry}=\@path;


  return;

};

# ---   *   ---   *   ---
# replace aliases!

sub lisrepl($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};

  my $proc = $mc->{hiertop};
  my $lis  = $proc->{p3ptr}->{vref}->{data};


  # unpack
  my $vref = $branch->{vref}->{res};
  my $name = $vref->{name};
  my $opsz = $vref->{opsz};

  # walk operands
  my @Q=map {$ARG->{data}} @{$vref->{args}};

  while(@Q) {

    my $nd   = shift @Q;

    my $key  = $nd->{value};
    my $have = $l1->xlate($key);


    # all aliases are symbols!
    if($have->{type} eq 'SYM'
    && exists $lis->{$have->{spec}}) {

      my $x    = $lis->{$have->{spec}};
      my $type = $x->{res};


      # typed alias?
      if(length $type) {


        # replace sole operation size?
        if($vref->{opsz_def}) {
          $vref->{opsz_def}=0;
          $opsz=$vref->{opsz}=$type;

        # ^nope, match against existing!
        } else {

          $main->err(
            "type specifier mismatch"

          ) if $type ne $opsz;

        };

      };


      # replace alias with value ;>
      $nd->{value}=$l1->tag(
        $x->{type}=>$x->{spec}

      ) . $x->{data};

      $nd->{vref}=$x;

    };

    unshift @Q,@{$nd->{leaves}};

  };


  return;

};

# ---   *   ---   *   ---
# solve instruction arguments

sub argsolve($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};
  my $eng  = $main->{engine};
  my $ISA  = $mc->{ISA};
  my $lib  = $main->{cmdlib};

  $self->lisrepl($branch);


  # unpack
  my $vref = $branch->{vref};
  my $vres = $vref->{res};
  my $name = $vres->{name};
  my $opsz = $vres->{opsz};

  # walk operands
  my @args=map {

    my $nd   = $ARG->{data};
    my $key  = $nd->{value};
    my $type = $ARG->{type};
    my $have = $l1->xlate($key);

    if($type eq 'SYM'
    && $type ne $have->{type}) {
      $ARG  = $nd->{vref};
      $type = $have->{type};

    };

    my $O={};


    # have register?
    if($type eq 'REG') {
      $O->{reg}  = $eng->quantize($key);
      $O->{type} = 'r';


    # have immediate?
    } elsif($type eq 'NUM') {
      $O->{imm}  = $eng->quantize($key);
      $O->{type} = $ISA->immsz($O->{imm});


    # have operator?
    } elsif($type eq 'OPR') {


      # arrow is special ;>
      if($have->{spec} eq '->') {

        $nd->prich();
        exit;


      # ^common op
      } else {

        my $x=$eng->opera_collapse(
          $nd,$have,

          noreg=>1,
          noram=>1,

        );

        return null if ! length $x;

        $O->{imm}  = $x;
        $O->{type} = $ISA->immsz($O->{imm});

      };


    # have memory?
    } elsif($type eq 'MEM') {
      $O=$self->addrmode($branch,$nd);
      return null if ! length $O;


    # have symbol?
    } elsif($type eq 'SYM') {
      $O=$self->symsolve($branch,$ARG,0);
      return null if ! length $O;

    };


    # give descriptor
    $O;


  } @{$vres->{args}};


  # have enqueued checks?
  if(defined $vref->{ctc}) {

    my $ok=$vref->{ctc}->(

      $self,
      $branch,

      $opsz,$name,@args

    );


    # need to discard or retry?
    return null if $ok eq $branch;
    return ($opsz,null) if ! length $ok;

    $opsz=$ok;


  };

  goto skip if $name=~ $ISA->{guts}->meta_re;


  # overwrite default type?
  my $nc_name=$name;

  my $def=$vres->{opsz_def};
  my $fix=$ISA->get_ins_fix_size($nc_name);

  if(defined $fix) {

    if($def) {
      $opsz=typefet $fix->[0];

    } else {

      my $have=array_iof $fix,$opsz->{name};

      $main->perr(

        "[ctl]:%s [good]:%s: "
      . "invalid size for instruction",

        args => [$name,$opsz->{name}],

      ) if ! defined $have;

    };

  };


  # give descriptor
  skip:
  return ($opsz,$name,@args);

};

# ---   *   ---   *   ---
# TODO: move this bit somewhere else!
#
#  # command dereference
#  if(my $have=$l1->typechk(CMD=>$key)) {
#
#    my $cmd   = $lib->fetch($have->{spec});
#    my $solve = $cmd->{key}->{fn}->($self,$nd);
#
#    return null if $solve && $solve eq $nd;
#
#
#    # ~
#    my $value=(defined $solve)
#      ? $solve
#      : $nd->{vref}
#      ;
#
#
#    # delay value deref until encoding
#    $O->{imm}=$value;
#
#    $O->{type}=sub ($x,$y) {
#      $x->immsz($y)
#
#    };
#
#    $O->{type_args}=[$ISA,$value];

# ---   *   ---   *   ---
# generic instruction

sub asm_ins($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $enc  = $main->{encoder};
  my $ISA  = $main->{mc}->{ISA};

  # can solve arguments?
  my ($opsz,$name,@args)=
    $self->argsolve($branch);

  return $branch
  if ! length $opsz;


  # instruction discarded?
  if(! length $name) {
    $branch->discard();
    return;

  };


  # all OK, request and give
  $branch->{vref}->{res}->{args}=[@args];
  $enc->binreq(
    $branch,[$opsz,$name,@args],

  );

  return $ISA->ins_ipret($main,$name,@args);

};

# ---   *   ---   *   ---
# get chain of operations is
# valid for an addressing mode

sub get_valid_ptr($self,$type,$nd,@args) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  my $out  = 0;


  # have register?
  if($type eq 'REG') {

    my ($stk)=@args;


    # check stack addressing?
    if($stk) {

      $main->perr(

        'invalid operation; '

      . 'stack base can only be used as '
      . 'destination for substraction'

      ) if(
         $nd->{idex} > 0
      || $self->get_opr_parent($nd,qr{^(?:\-)$})

      );


    # check common LH usage?
    } elsif(! $nd->{idex}) {


      $main->perr(

        'invalid operation; '

      . 'register can only be used as '
      . 'destination for addition, substraction '
      . 'or multiplication'

      ) if $self->get_opr_parent(
        $nd,qr{^(?:\-|\+|\*)$}

      );


      # scale applied to register?
      my $value = $nd->{parent}->{value};
      my $have  = $l1->typechk(OPR=>$value);

      $out=$have->{spec} eq '*' if $have;


    # check common RH usage?
    } else {

      $main->perr(

        'invalid operation; '

      . 'register can only be used as '
      . 'source for addition'

      ) if $self->get_opr_parent(
        $nd,qr{^(?:\+)$}

      );


    };


  # have symbol or immediate?
  } else {


    # forbid symbol as scale
    if($type eq 'SYM') {

      $main->perr(

        'invalid operation; '

      . 'symbol can only be used as '
      . 'source for addition or '
      . 'substraction'

      ) if $nd->{idex} && $self->get_opr_parent(
        $nd,qr{^(?:\-\>|\-|\+)$}

      );

    };


    # apply negation to value?
    my $value = $nd->{parent}->{value};
    my $have  = $l1->typechk(OPR=>$value);

    $out=(

       $nd->{idex}
    && $have->{spec} eq '-'

    ) if $have;


  };


  return $out;

};

# ---   *   ---   *   ---
# ^find valid operator above a node

sub get_opr_parent($self,$nd,$opr) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};


  # walk up the hierarchy!
  my $par  = $nd->{parent};
  my $have = 0;

  while($par) {


    # operator found?
    if(my $desc=$l1->typechk(
      OPR=>$par->{value}

    )) {

      $have=! ($desc->{spec}=~ $opr);
      last if $have;

    };


    # ^nope, keep going!
    $par=$par->{parent};

  };


  return $have;

};

# ---   *   ---   *   ---
# get idex of element in addr
# decomposition tree

sub addr_elem($type,@tree) {

  grep {
    $tree[$ARG]->{type} eq $type

  } 0..$#tree;

};

# ---   *   ---   *   ---
# determine type of memory operand

sub addr_decompose($self,$nd) {


  # get ctx
  my $main  = $self->{frame}->{main};
  my $l1    = $main->{l1};
  my $anima = $main->{mc}->{anima};
  my $eng   = $main->{engine};


  # get first branch:
  #
  # [`[]
  # \-->[b0]
  # .  \-->(beg)

  my $beg = $nd->{leaves}->[0];
     $beg = $beg->{leaves}->[0];

  # solve const ops
  $eng->branch_collapse(

    $beg,

    delay=>1,

    noreg=>1,
    noram=>1,
    norom=>1,
    noptr=>1,

  );


  # decompose address
  my @tree = ();

  my $stk  = 0;
  my $lea  = 0;
  my $opsz = undef;

  my @Q    = $beg;

  while(@Q) {

    my $nd   = shift @Q;

    my $key  = $nd->{value};
    my $have = undef;


    # register name?
    if($have=$l1->typechk(REG=>$key)) {

      $stk |= $have->{spec} == $anima->stack_base;
      $lea |= $self->get_valid_ptr(REG=>$nd,$stk);

      push @tree,{

        spec => $have->{spec},

        neg  => 0,
        type => 'REG',

      };


    # symbol name?
    } elsif($have=$l1->typechk(SYM=>$key)) {

      push @tree,{

        spec => $have->{spec},

        neg  => $self->get_valid_ptr(SYM=>$nd),
        type => 'SYM',

      };


    # immediate?
    } elsif(! ($have=$l1->typechk(OPR=>$key))) {

      push @tree,{

        spec => $eng->quantize($key),

        neg  => $self->get_valid_ptr(IMM=>$nd),
        type => 'IMM',

      };


    # arrow?
    } elsif($have->{spec} eq '->') {

      my ($sym,$off,$field_t)=
        $eng->arrow_to_offset($nd);

      return null if ! $sym;


      $opsz=$field_t;

      push @tree,{
        spec => $sym,
        neg  => 0,
        type => 'SYM',

      },{
        spec => $off,
        neg  => 0,
        type => 'IMM',

      };

      next;


    # operator!
    } else {

      push @tree,{

        spec => $have->{spec},

        neg  => 0,
        type => 'OPR',

      } if ! ($have->{spec}=~ qr{^(?:\-|\+)$});


    };


    unshift @Q,@{$nd->{leaves}};


  };


  # check legal register use
  my $reg  = [addr_elem REG=>@tree];
     $lea |= @$reg > 1;

  $main->perr(

    'cannot use more than two '
  . 'registers to calculate pointer'

  ) if @$reg > 2;


  # ^remove registers from tree!
  @$reg = map  {$tree[$ARG]} @$reg;
  @tree = grep {$ARG->{type} ne 'REG'} @tree;


  # give descriptor
  return {

    tree  => \@tree,
    reg   => $reg,

    sym   => [addr_elem SYM=>@tree],
    imm   => [addr_elem IMM=>@tree],

    stk   => $stk,
    lea   => $lea,

    opsz  => $opsz,

  };

};

# ---   *   ---   *   ---
# build memory operand from
# operation tree

sub addrmode($self,$branch,$nd) {


  # get type lists
  my $data=$self->addr_decompose($nd);
  return null if ! length $data;

  my $tree=$data->{tree};


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};

  # out
  my $type      = null;
  my $opsz      = $branch->{vref}->{opsz};
  my $opsz_args = [];
  my $O         = {};


  # have symbols?
  map {


    # skip if can't solve!
    my $idex = $ARG;
    my $head = $self->symsolve(
      $branch,$tree->[$idex],1

    );


    return null if ! length $head;


    # overwrite operation size if
    # symbol is the sole component!
    if(! defined $opsz &&! @$tree-1) {
      $opsz      = $head->{opsz};
      $opsz_args = $head->{opsz_args};

    };


    # put symbol descriptor in tree
    $head->{neg}   = $tree->[$idex]->{neg};
    $tree->[$idex] = $head;


  } @{$data->{sym}};


  # [sb-i]
  if($data->{stk}) {

    $O->{imm}      = \&addrsolve_collapse;
    $O->{imm_args} = $tree;

    $O->{type}     = 'mstk';


  # [r+r+i*x]
  } elsif($data->{lea}) {

    my ($rX,$rY)=map {

      my $ar=$data->{reg};

      (defined $ar->[$ARG])
        ? $ar->[$ARG]->{spec}+1
        : 0
        ;

    } 0..1;


    # validate scale value
    my $scale=0;
    if(@$tree > 2) {

      $scale=pop @$tree;
      $main->perr(

        'invalid scale factor of [num]:%u '
      . 'for address',

        args => [$scale->{spec}],

      ) if ! ($scale->{spec}=~ qr{^(?:1|2|4|8)$});


      # ^remove multiplication from tree!
      my ($off)=grep {
         exists $tree->[$ARG]->{spec}
      && $tree->[$ARG]->{spec} eq '*'

      } reverse 0..@$tree-1;

      $tree->[$off]=undef;
      @$tree=grep {defined $ARG} @$tree;

      $scale={
        1 => 0,
        2 => 1,
        4 => 2,
        8 => 3,

      }->{$scale->{spec}};

    };


    # make descriptor
    $O->{rX}       = $rX;
    $O->{rY}       = $rY;

    $O->{imm}      = \&addrsolve_collapse;
    $O->{imm_args} = $tree;

    $O->{scale}    = $scale;
    $O->{type}     = 'mlea';


  # [r+i]
  } elsif(@{$data->{reg}}) {

    $O->{reg}      = $data->{reg}->[0]->{spec};

    $O->{imm}      = \&addrsolve_collapse;
    $O->{imm_args} = $tree;

    $O->{type}     = 'msum';


  # [i]
  } else {

    $O->{imm}      = \&addrsolve_collapse;
    $O->{imm_args} = $tree;

    $O->{type}     = 'mimm';

  };


  # decide which operation size to use
  if(defined $data->{opsz}) {
    $O->{opsz}      = $data->{opsz};
    $O->{opsz_args} = [];

  } else {
    $O->{opsz}      = $opsz;
    $O->{opsz_args} = $opsz_args;

  };


  return $O;

};

# ---   *   ---   *   ---
# adds symbols and immediates
# inside an address tree

sub addrsolve_collapse(@tree) {


  my $opera = qr{^(?:\/|\*)$};
  my @have  = map {

    my $neg = 0;
    my $out = 0;

    # have fetch?
    if(exists $ARG->{imm}) {
      $out = $ARG->{imm}->(@{$ARG->{imm_args}});
      $neg = $ARG->{neg};

    # have value!
    } else {
      $out = $ARG->{spec};
      $neg = $ARG->{neg};

    };

    $out *= 1-(2*$neg)
    if ! ($out=~ $opera);

    $out;


  } @tree;

  my $out=0;
  while(@have) {

    my $x=shift @have;
    if($x=~ $opera) {
      my ($lh,$rh)=(shift @have,shift @have);
      $out += eval "$lh $x $rh";

    } else {
      $out += $x;

    };

  };


  return int $out;

};

# ---   *   ---   *   ---
# delayed dereference ;>

sub symsolve($self,$branch,$vref,$deref) {


  # can solve destination?
  my $dst=$self->argproc($vref);
  return null if ! length $dst;


  # get ctx
  my $main  = $self->{frame}->{main};
  my $mc    = $main->{mc};
  my $ISA   = $mc->{ISA};
  my $vres  = $branch->{vref}->{res};

  my ($name,@path)=$dst->fullpath;


  # out
  my $O={

    imm      => \&symsolve_addr,
    imm_args => [$dst,$deref],

    id       => [$name,@path],

  };


  # using default size?
  if($vres->{opsz_def}) {

    $O->{opsz}      = \&symsolve_opsz;
    $O->{opsz_args} = [$dst,$deref];

  # have size modifier!
  } else {
    $O->{opsz}=$vres->{opsz};
    $O->{opsz_args}=[];

  };


  # get *minimum* required size ;>
  $O->{type}      = \&symsolve_min;
  $O->{type_args} = [$ISA,$dst,$deref];

  return $O;

};

# ---   *   ---   *   ---
# ^get address of symbol

sub symsolve_addr($dst,$deref) {

  if(! $deref && defined $dst->{type}) {
    my ($seg,$off)=$dst->read_ptr();
    return $off+$seg->update_absloc();

  } else {

    $dst=$dst->{route}
    if $dst->{route};

    return $dst->update_absloc();

  };

};

# ---   *   ---   *   ---
# ^get operation size for symbol

sub symsolve_opsz($dst,$deref) {

  my $opsz=undef;

  if(exists $dst->{type}) {

    $opsz=($deref)
      ? $dst->{type}
      : $dst->{ptr_t}
      ;

  } else {

    $dst=$dst->{route}
    if $dst->{route};

    $opsz=Type->ptr_by_size($dst->absloc);

  };

  $opsz //= typefet 'ptr';
  return $opsz;

};

# ---   *   ---   *   ---
# ^get minimum size of operand

sub symsolve_min($ISA,$dst,$deref) {
  return $ISA->immsz(symsolve_addr($dst,$deref));

};

# ---   *   ---   *   ---
# add entry points

cmdsub '$'        => q() => \&current_byte;
cmdsub 'entry'    => q() => \&entry;
cmdsub 'asm-ins'  => q() => \&asm_ins;

# ---   *   ---   *   ---
1; # ret
