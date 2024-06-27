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
  use Arstd::String;
  use Arstd::IO;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.9;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# get value from descriptor

sub operand_value($self,$ins,$type,$data) {

  map {

    my $o    = {%{$data->{$ARG}}};
    my $imm  = exists $o->{imm};

    my $addr = (is_coderef $o->{addr})
      ? $o->{addr}->()
      : $o->{addr}
      ;


    # memory deref?
    if($ins->{"load_$ARG"} &&! $imm) {
      $o->{seg}->load($type,$addr);

    # ^immediate?
    } elsif($imm) {
      Bpack::layas($type,$o->{imm});

    # ^plain addr?
    } else {
      my $x=$addr+$o->{seg}->absloc();
      Bpack::layas($type,$x);

    };


  } qw(dst src)[0..$ins->{argcnt}-1];

};

# ---   *   ---   *   ---
# get instruction implementation
# and run it with given args

sub invoke($self,$type,$idx,@args) {


  # get ctx
  my $ISA  = $self->ISA;
  my $guts = $ISA->{guts};
  my $tab  = $ISA->opcode_table;

  # get function assoc with id
  my $fn  = $tab->{exetab}->[$idx];
  my @src = (1 == $#args)
    ? ($args[1]) : () ;


  # ^build call array
  my $op   = $guts->$fn($type,@src);
  my @call = (@args)
    ? ($op,$args[0])
    : ($op,0x00)
    ;


  # invoke and give
  my @out=$guts->opera(@call);

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
  if($ins->{overwrite} && $data->{dst}) {

    my $dst=$data->{dst};

    $dst->{seg}->store(
      $type,$ret,$dst->{addr}

    );

  };

  return @$ret;

};

# ---   *   ---   *   ---
# read program from segment idex
# or memory reference

sub strseg($self,$program,%O) {

  # defaults
  $O{decode} //= 1;

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
    $program=$enc->decode($program)
    if $O{decode};

  };


  return $program;

};

# ---   *   ---   *   ---
# read and run jumpless program

sub strexe($self,$program) {

  map {$self->step($ARG)}
  @{$self->strseg($program)};

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

    last if $ret[0]
    && $ret[0] eq '$:LAST;>';

  };

  return @ret;

};

# ---   *   ---   *   ---
# interpret node as a value

sub value_solve($self,$src,%O) {


  # defaults
  $O{noreg} //= 0;
  $O{noram} //= 0;
  $O{norom} //= 0;
  $O{noptr} //= 0;
  $O{delay} //= 0;

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
      ? $self->cmd_solve($src)
      : $src->{value}
      ;

  # ^a whole branch!
  } else {
    $out=$self->branch_collapse($src,%O);

  };

  return (! $O{delay})
    ? $self->quantize($out)
    : $out
    ;

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
# solve and quantize

sub value_flatten($self,$src,%O) {


  # defaults
  $O{args} //= [];

  # get ctx
  my $main = $self->{main};
  my $mc   = $main->{mc};
  my $l1   = $main->{l1};

  my $args = $O{args};
  delete $O{args};


  # can solve value now?
  my $have=$self->value_solve($src,%O);

  # ^give zero on nope
  my $x=(! length $have)
    ? $l1->tag(NUM=>0)
    : $have
    ;

  # handle references
  my ($isref)=
    Chk::cderef $x,0;

  if($isref) {

    $mc->backup();
    ($isref,$x)=Chk::cderef $x,1,@$args;

    $mc->restore();

  };

  $x=$self->quantize($x);

  if($x && is_hashref $x) {

    if($x->{type} eq 'STR') {
      $x=$x->{data};

    };

  };


  return ($x,$have);

};

# ---   *   ---   *   ---
# default leaf-to-root
# branch processing logic

sub branch_solve($self,$branch,%O) {


  # defaults
  $O{noreg} //= 0;
  $O{noram} //= 0;
  $O{norom} //= 0;
  $O{noptr} //= 0;


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};


  # have operator?
  my $key=$branch->{value};

  if(my $have=$l1->typechk(OPR=>$key)) {

    my $dst=$self->opera_collapse(
      $branch,$have,%O

    );

    if(length $dst) {
      $branch->{value}=$dst;
      $branch->clear();

    };


  # SCP token denotes any {[(code)]}
  # between delimiters
  } elsif($have=$l1->typechk(SCP=>$key)) {

    $self->sbranch_collapse(
      $branch,$have

    ) if $have->{spec} eq '(';

  } elsif($have=$l1->typechk(EXP=>$key)) {

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
  $O{noram} //= 0;
  $O{norom} //= 0;
  $O{noptr} //= 0;


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

#  if(1 == @lv) {
    $branch->flatten_branch();

#  };


  return;

};

# ---   *   ---   *   ---
# execute const operator branch
# else give handle to executable

sub opera_collapse($self,$branch,$opera,%O) {


  # defaults
  $O{noreg} //= 0;
  $O{noram} //= 0;
  $O{norom} //= 0;
  $O{noptr} //= 0;


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

    my $head=$l1->xlate($ARG->{value});

    my ($type,$spec)=(
      $head->{type},
      $head->{spec},

    );


    my $have=($type && $type ne 'OPR')
      ? $self->quantize($ARG->{value})
      : $self->value_solve($ARG,%O)
      ;


    $reg |= $type eq 'REG';

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


    # register
    if($type eq 'REG') {
      $const &=~ 1;
      {type=>'r',reg=>$have};


    # immediate
    } elsif($type eq 'NUM') {
      my $spec=$ISA->immsz($have);
      {type=>$spec,imm=>$have};


    # TODO: memory
    } elsif(! index $type,'MEM') {
      nyi "memory operands";


    # symbols
    } elsif($type eq 'SYM') {

      return null if ! length $have;


      # symbol deref allowed?
      my $seg=$have->getseg();

      return null

      if (  $seg->{writeable} && $O{noram})
      || (! $seg->{writeable} && $O{norom})

      || (  $have->{ptr_t}    && $O{noptr});


      # ^deref and give
      my $addr = ($have->{ptr_t})
        ? $have->load(deref=>0)
        : $have->{addr}
        ;

      my $spec = $ISA->immsz($addr);

      {type=>$spec,imm=>$addr};


    # either impossible or NYI ;>
    } elsif($type eq 'OPR') {
      return null;


    # error!
    } else {

      $main->perr(

        q[cannot encode [op]:%s operation ]
      . q[for '%s'],

        args=>["\'$opera->{spec}\'","$type:$have"]

      );

    };


  } @args;


  # fetch operator definition
  my @program=$ISA->xlate(
    $opera->{spec},'word',@args

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


  # assume truth, then challenge
  my $out=1;


  # walk operands
  for my $operand(@$args) {


    # check type of the operand itself
    my ($isref,$have)=
      Chk::cderef $operand,$deref;

    # overwrite on dereference
    if($isref && $deref) {

      $operand = $have;
      $out     = 0;
      $isref   = 0;

    };


    # ^apply same logic to descriptor values
    map {


      # get [field => value]
      my $key   = $ARG;
      my $value = $operand->{$key};

      # optional field with arguments
      # used when value is a coderef!
      my $data   = $operand->{"${key}_args"};
         $data //= [];


      # check value is a reference
      my ($isref,$have)=
        Chk::cderef $value,$deref,@$data;

      # overwrite on reference,
      # deref'd or not!
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
# symbol lookup

sub symfet($self,$token) {


  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};


  # deref tree branch
  $token=$token->{value}
  if Tree->is_valid($token);


  # read meta
  my $name=$l1->untag($token);
     $name=($name) ? $name->{spec} : $token ;

  # can find symbol?
  my $sym=$mc->ssearch(
    split $mc->{pathsep},$name

  );

  return $sym;

};

# ---   *   ---   *   ---
# token to value

sub quantize($self,$src) {


  # skip on undef/null
  return null
  if ! defined $src ||! length $src;

  # get ctx
  my $main = $self->{main};
  my $l1   = $main->{l1};


  # have ptr?
  my $mc     = $main->{mc};
  my $ptrcls = $mc->{bk}->{ptr};

  return $src if $ptrcls->is_valid($src);


  # ^else unpack tag
  my $have=$l1->xlate($src);
  return $src if ! $have;


  my ($type,$spec)=(
    $have->{type},
    $have->{spec},

  );


  # have plain value?
  if($type=~ qr{NUM|REG}) {
    return $spec;

  # have plain symbol name?
  } elsif($type eq 'SYM') {
    return $self->symfet($spec);


  # have string?
  } elsif($type eq 'STR') {

    charcon \$have->{data}
    if $spec eq '"';

    return $have;

  # have executable binary? (yes ;>)
  } elsif($type eq 'EXE') {
    return $self->strexe($spec);


  # have scope?
  } elsif($type eq 'SCP') {
    return $src;


  # as for anything else...
  } else {
    nyi "<$type> quantization";

  };

};

# ---   *   ---   *   ---
1; # ret
