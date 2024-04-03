#!/usr/bin/perl
# ---   *   ---   *   ---
# IPRET:ENGINE
# I'm running things!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package ipret::engine;

  use v5.36.0;
  use strict;
  use warnings;

  use Storable;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;
  use Bpack;

  use Arstd::Bytes;
  use Arstd::IO;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.5;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get value from descriptor

sub operand_value($self,$ins,$type,$data) {

  map {

    my $o    = $data->{$ARG};
    my $imm  = exists $o->{imm};

    my $addr = $o->{addr};
       $addr = $addr->() if is_coderef $addr;

    # memory deref?
    if($ins->{"load_$ARG"} &&! $imm) {

      $o->{seg}->load(
        $type,$addr

      );

    # ^immediate?
    } elsif($imm) {
      Bpack::layas($type,$o->{imm});

    # ^plain addr?
    } else {

      my $data=
        $o->{seg}->absloc()+$addr;

      Bpack::layas($type,$data);

    };


  } qw(dst src)[0..$ins->{argcnt}-1];

};

# ---   *   ---   *   ---
# get instruction implementation
# and run it with given args

sub invoke($self,$type,$idx,@args) {


  # get ctx
  my $ISA    = $self->ISA;
  my $guts_t = $ISA->guts_t;
  my $tab    = $ISA->opcode_table;


  # get function assoc with id
  my $fn  = $tab->{exetab}->[$idx];
  my @src = (1 == $#args)
    ? ($args[1]) : () ;


  # ^build call array
  my $op   = $guts_t->$fn($type,@src);
  my @call = (@args)
    ? ($op,$args[0])
    : ($op)
    ;


  # invoke and give
  my @out=$guts_t->copera(@call);

  return \@out;

};

# ---   *   ---   *   ---
# execute next instruction
# in program

sub step($self,$data) {


  # unpack
  my $ezy  = Type::MAKE->LIST->{ezy};
  my $ins  = $data->{ins};

  my $type = typefet $ezy->[$ins->{opsize}];


  # read operand values
  my @values=
    $self->operand_value($ins,$type,$data);

  # execute instruction
  my $ret=$self->invoke(

    $type,
    $ins->{idx},

    @values

  );


  # save result?
  if($ins->{overwrite}) {

    my $dst=$data->{dst};

    $dst->{seg}->store(
      $type,$ret,$dst->{addr}

    );

  };

  return @$ret;

};

# ---   *   ---   *   ---
# read and run jumpless program

sub strexe($self,$program) {


  # get ctx
  my $main = $self->{main};
  my $mc   = $main->{mc};

  my $mem  = $mc->{bk}->{mem};
  my $enc  = $main->{encoder};


  # segment passed as idex?
  if($program=~ $NUM_RE) {

    my $frame = $mc->{cas}->{frame};
    my $seg   = $frame->ice($program);


    # ^validate
    $main->perr(

      "strexe: invalid segment ID "
    . "([num]:%u)",

      args=>[$program],

    ) if ! $seg;

    $program=$seg;

  };


  # input needs decoding?
  if(! is_arrayref($program)) {

    # have executable segment?
    if($mem->is_valid($program)) {
      $program=$program->as_exe;

    };

    # decode binary
    $program=$enc->decode($program);

  };


  # run and give result
  map {$self->step($ARG)} @$program;

};

# ---   *   ---   *   ---
# read and run *real* program!

sub exe($self) {


  # get ctx
  my $main = $self->{main};
  my $enc  = $main->{encoder};


  # read/decode/exec
  my @ret=();
  while(1) {

    my $ins=$enc->exeread();
    last if ! $ins;

    @ret=$self->step($ins);

  };

  return @ret;

};

# ---   *   ---   *   ---
# interpret node as a value

sub value_solve($self,$src,%O) {


  # defaults
  $O{noreg} //= 0;

  # get ctx
  my $main   = $self->{main};
  my $mc     = $main->{mc};
  my $l1     = $main->{l1};
  my $ptrcls = $mc->{bk}->{ptr};


  # output null if unsolved
  my $out=undef;

  # non-tree value passed?
  if(! Tree->is_valid($src)) {
    $out=$src;

  # single node?
  } elsif(! @{$src->{leaves}}) {

    $out=(defined $src->{cmdkey})

      ? (! defined $src->{vref})
        ? $self->cmd_solve($src)
        : $src->{vref}

      : $src->{value}

      ;

  # ^a whole branch!
  } else {
    $out=$self->branch_collapse($src,%O);

  };

  return $l1->quantize($out);

};

# ---   *   ---   *   ---
# get and execute

sub cmd_solve($self,$branch) {

  # get ctx
  my $main   = $self->{main};
  my $cmdlib = $main->{cmdlib};

  # fetch and run
  my $cmd=$cmdlib->fetch($branch->{cmdkey});
  $cmd->{fn}->($cmd,$branch);

  return $branch->{vref};

};

# ---   *   ---   *   ---
# default leaf-to-root
# branch processing logic

sub branch_solve($self,$branch,%O) {


  # defaults
  $O{noreg} //= 0;

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};


  # have operator?
  my $key=$branch->{value};

  if(defined (my $have=$l1->is_opera($key))) {

    my $dst=($have ne '(')
      ? $self->opera_collapse($branch,$have,%O)
      : $branch->leaf_value(0)
      ;

    if(length $dst) {
      $branch->{value}=$dst;
      $branch->clear();

    };


  # 'branch' token denotes any {[(code)]}
  # between delimiters
  } elsif(defined ($have=$l1->is_branch($key))) {

    $self->sbranch_collapse(
      $branch,$have

    );

  };


  return;


};

# ---   *   ---   *   ---
# ^recursive

sub branch_collapse($self,$src,%O) {


  # defaults
  $O{noreg} //= 0;

  # save current state
  my $main = $self->{main};
  my $mc   = $main->{mc};

  $mc->{anima}->backup_alma();


  # get reverse hierarchal order
  my @Q0 = @{$src->{leaves}};
  my @Q1 = ($src);

  while(@Q0) {

    my $nd=shift @Q0;

    push    @Q1,$nd;
    unshift @Q0,@{$nd->{leaves}};

  };


  # ^collapse from bottom leaf to root
  map     {$self->branch_solve($ARG,%O)}
  reverse @Q1;


  # cleanup and give
  $mc->{anima}->restore_alma();
  return $src->{value};

};

# ---   *   ---   *   ---
# ^on sub-branch token

sub sbranch_collapse($self,$branch,$id) {

  my $par = $branch->{parent};
  my @lv  = @{$branch->{leaves}};


  if(1 == @lv) {
    $branch->flatten_branch();

  };


  return;

};

# ---   *   ---   *   ---
# execute const operator branch
# else give handle to executable

sub opera_collapse($self,$branch,$opera,%O) {


  # defaults
  $O{noreg} //= 0;

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};

  my $mc   = $main->{mc};
  my $enc  = $main->{encoder};
  my $ISA  = $self->ISA;

  # save current state
  my $alma = $mc->{anima}->{almask};


  # get argument types
  my @args   = @{$branch->{leaves}};
  my $reg    = 0;

  my @args_b = map {

    my ($type,$spec)=
      $l1->read_tag($ARG->{value});

    my $have=($type && $type ne '*')
      ? $l1->quantize($ARG->{value})
      : $self->value_solve($ARG)
      ;


    $reg   |= $type eq 'r';

    $type   = 'i' if $type eq '*';
    $type  .= $spec if $type eq 'm';

    (defined $have) ? [$type,$have] : () ;


  } @args;


  # ^validate
  return null
  if @args_b != int @args;

  @args=@args_b;

  # ^ops with registers forbidden?
  return null if $reg && $O{noreg};


  # branch is a constant if it in turn
  # operates solely on constants!
  my $const=1;

  # apply formatting to arguments
  @args=map {

    my ($type,$have)=@$ARG;

    if($type eq 'r') {
      $const &=~ 1;
      {type=>$type,reg=>$have};

    } elsif($type eq 'i') {
      my $spec=$ISA->immsz($have);
      {type=>$spec,imm=>$have};

    } elsif(! index $type,'m') {
      nyi "memory operands";

    } elsif($type eq 's') {

      my $addr = ($have->{ptr_t})
        ? $have->load(deref=>0)
        : $have->{addr}
        ;

      my $spec = $ISA->immsz($addr);

      {type=>$spec,imm=>$addr};

    } else {

      $main->perr(

        q[cannot encode [op]:%s operation ]
      . q[for '%s'],

        args=>["\'$opera\'","$type:$have"]

      );

    };


  } @args;


  # fetch operator definition
  my @program=$ISA->xlate(
    $opera,'word',@args

  );


  # check that program has dynamic elements
  #
  # this means some of the operand values are
  # references that cannot be solved at this
  # stage and therefore cannot be encoded
  #
  # in such cases, we must delay the encoding
  # until the next stage!
  #
  # we do this by wrapping the encoding of this
  # operation in a subroutine ;>

  if(

    grep {! $ARG}

    map  {$self->opera_static($ARG,0)}
    map  {[(@$ARG)[2..@$ARG-1]]}

    @program

  ) {

    my $solve=sub {

      map  {$self->opera_static($ARG,1)}
      map  {[(@$ARG)[2..@$ARG-1]]}

      @program;


      return $enc->opera_encode(
        \@program,$const,$alma

      );

    };

    return $solve;


  # ^static, no wrapper needed!
  } else {

    return $enc->opera_encode(
      \@program,$const,$alma

    );

  };

};

# ---   *   ---   *   ---
# check that the operands for
# an instruction are all composed
# of fixed, static values
#
# if not, optionally dereference

sub opera_static($self,$args,$deref=0) {


  # walk operands
  my $out=1;

  for my $operand(@$args) {


    # check type of the operand itself
    my ($isref,$have)=
      Chk::cderef $operand,$deref;

    if($isref && $deref) {

      $operand = $have;
      $out     = 0;
      $isref   = 0;

    };


    # apply same logic to descriptor values
    map {

      my $key   = $ARG;
      my $value = $operand->{$key};

      my ($isref,$have)=
        Chk::cderef $value,$deref;

      if($isref) {
        $operand->{$key} = $have;
        $out             = 0;

      };


    } keys %$operand if ! $isref;

  };


  return $out;

};

# ---   *   ---   *   ---
# generic args validation for
# command arguments

sub argtake($self,@args) {


  # get ctx
  my $main  = $self->{main};
  my $mc    = $main->{mc};
  my $ptr_t = $mc->{bk}->{ptr};


  # can solve all refs now?
  my @repr=map {

    my @have=$self->value_solve($ARG);
    $have[-1];

  } @args;

  return () if @args > @repr;


  # ^validate
  my @solved=grep {
     defined $ARG
  && length $ARG

  } map {

    ($ptr_t->is_valid($ARG))
      ? $ARG->load
      : $ARG
      ;

  } @repr;


  # give null if values pending
  # else give values!
  return (@solved == @repr)
    ? @solved
    : ()
    ;

};

# ---   *   ---   *   ---
1; # ret
