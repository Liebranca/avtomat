#!/usr/bin/perl
# ---   *   ---   *   ---
# VIRTUAL MACHINE
# it's alive!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::vm;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_hashref is_arrayref);
  use Type qw(
    array
    struc
    typefet
    typename
    sizeof

    is_array
  );

  use Arstd::String qw(
    strip
    gstrip
    time_to_uid
  );
  use Arstd::seq;
  use Arstd::strtok qw(strtok);
  use Arstd::mem qw(
    mem_new
    mem_flg
    mem_blk
    mem_has
    mem_push
    mem_store
    mem_dstore
    mem_load
    mem_dload

    ptr_new
    ptr_flg
    ptr_get
    ptr_addr
  );
  use Arstd::throw;
  use Tree::C qw(array_re);


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter "import";
  our @EXPORT_OK=qw(
    vm_new
    vm_enter
    vm_leave
    vm_in
    vm_local
    vm_out
    vm_var_blk
    vm_var_get
    vm_var_has
    vm_sym_in
    vm_sym_out
    vm_sym_get
    vm_eval
    vm_exec
    vm_push
    vm_pop
    vm_load
    vm_store
    vm_skip
    vm_jmp
    vm_prog
    vm_call
    vm_label
    vm_label_new
    vm_label_top
    vm_label_find
    vm_label_str
    vm_strir
  );


# ---   *   ---   *   ---
# info

  my $VERSION = "v0.01.0a";
  my $AUTHOR  = "IBN-3DILA";


# ---   *   ---   *   ---
# cstruc

sub vm_new {
  my %O=@_;
  $O{id}      //= "vm_" . time_to_uid();
  $O{mem}     //= {};
  $O{stk}     //= [];
  $O{prev}    //= [];
  $O{cur}     //= undef;
  $O{typetab} //= {-uid=>0};
  $O{lvl}     //= 0;
  $O{rip}     //= 0;
  $O{prog}    //= [];
  $O{label}   //= [];
  $O{jmp}     //= {};

  my $self=\%O;
  $self->{mem}=mem_new(id=>"non",%{$O{mem}});
  $self->{cur}=$self->{mem};
  mem_blk(
    $self->{mem},
    id  => "var",
    flg => mem_flg(qw(ram grow)),
  );
  vm_label_new($self,$self->{mem}->{id});
  return $self;
};


# ---   *   ---   *   ---
# save/load previous program state

sub vm_ctx {
  state $out=[];
  return $out;
};
sub vm_ctx_save {
  my ($vm,@prog)=@_;

  # save current
  my $mem={
    map {$ARG=>$vm->{$ARG}}
    qw  (rip prog cur)
  };
  # reset
  $vm->{rip}   = -1;
  $vm->{prog}  = [@prog];
  $vm->{cur}   = $vm->{mem};

  # add mem and give
  return push @{vm_ctx()},$mem;
};
sub vm_ctx_load {
  my ($vm)=@_;
  my $mem=pop @{vm_ctx()};

  $vm->{$ARG}=$mem->{$ARG}
  for qw(rip prog cur);

  return;
};


# ---   *   ---   *   ---
# fetches ID for type from internal table

sub vm_typeid {
  my ($vm,$type)=@_;
  my $tab=$vm->{typetab};
  my $key=typename($type);

  # new entry?
  if(! exists $tab->{$key}) {
    $tab->{$key}=$tab->{-uid}++;
  };
  # ^fetch and give
  return $tab->{$key};
};


# ---   *   ---   *   ---
# open/close scope

sub vm_enter {
  my ($vm,$id,@flg)=@_;
  push @{$vm->{prev}},[
    $vm->{cur},
    vm_var_blk($vm)->{buf}
  ];
  # switching to existing block?
  my $out;
  if(exists $vm->{mem}->{ftab}->{$id}) {
    $out=$vm->{mem}->{ftab}->{$id};

  # ^nope, make new!
  } else {
    $out=mem_blk(
      $vm->{cur},
      id  => $id,
      flg => mem_flg(grow=>@flg),
    );
    mem_blk(
      $out,
      id  => "var",
      flg => mem_flg(qw(ram grow)),
    );
    vm_label_new($vm,$id);
  };
  # set as current and give
  $vm->{cur}=$out;
  return $out;
};
sub vm_leave {
  my ($vm)=@_;
  my $out=$vm->{cur};
  my $prev=pop @{$vm->{prev}};

  $vm->{cur}=$prev->[0];
  vm_var_blk($vm)->{buf}=$prev->[1];

  return $out;
};


# ---   *   ---   *   ---
# declare value

sub vm_in {
  return vm_var_decl(
    $_[0],
    "in",
    @_[1..$#_]
  );
};
sub vm_local {
  return vm_var_decl(
    $_[0],
    "local",
    @_[1..$#_]
  );
};
sub vm_out {
  return vm_var_decl(
    $_[0],
    "out",
    $_[1],
    "-out"
  );
};


# ---   *   ---   *   ---
# ^guts

sub vm_var_decl {
  my ($vm,$cmd,$type,$name)=@_;
  my $dst=vm_var_blk($vm);
  ($type,$name)=gstrip($type,$name);

  # void is actually a nop :D
  if(is_null($type) || $type eq "void") {
    ($type,$name)=(null,$name);

  # map `cstr typename` => `mem ptr type`
  } else {
    # is array?
    my $array=array_re();
    if($name=~ s[$array][$+{base}]) {
      my $deref=$type eq "ptr";

      # declare type if need
      my $sz=$+{elem};
      if(! mem_has($dst,$name)) {
        $type=array($type,$sz);

      # ^else use existing
      } else {
        $type=vm_var_get($vm,$name)->{type};
      };
      # quick hack for pointers
      if($deref) {
        $name="*>$name";
      };

    # struc or primitive
    } else {
      $type=typefet($type);
    };
    # add value to table if it doesn't exist
    if(! mem_has($dst,$name)) {
      my $ptr=mem_push($dst,$type,$name);
      $ptr->{flg} |= ptr_flg($cmd);
    };
  };
  return ($type,$name);
};


# ---   *   ---   *   ---
# first block in current mem is where
# we store variables

sub vm_var_blk {
  return $_[0]->{cur}->{blk}->[0];
};
sub vm_var_has {
  my $dst=vm_var_blk($_[0]);
  return mem_has($dst,$_[1]);
};


# ---   *   ---   *   ---
# retrieve pointer

sub vm_var_get {
  my ($vm,$id)=@_;
  my $dst=vm_var_blk($vm);

  # indexing into array?
  my $array=array_re();
  if($id=~ s[$array][]) {
    my $elem = $+{elem};
       $id   = $+{base};

    # get array base
    my $base=ptr_get($dst,$id);
    throw "vm: undefined value '$id'"
    if!   defined $base;

    my $type=$base->{type}->{struc_t}->[0];
    my $step=sizeof($type);
       $type=typefet("$type ptr");

    # eval the idex itself...
    my @ret=vm_eval(
      $vm,
      typefet("dword"),
      $elem
    );
    # ^solved operation, so take result
    my $solved=0;
    if(int(@ret) == 1
    && $ret[0]->{cmd} eq "const") {
      $elem   = $ret[0]->{args}->[0];
      $solved = 1;

    # ^unsolved operation
    } else {
    };
    # generate wrapper operation for handling
    # pointer into array element!
    my $sid="*>(${id}->($elem*$step))";

    # catch invalid type
    throw "vm: cannot idex into non-array "
    .     "<$base->{id}> [i:$elem]"

    if!   is_array($base->{type});

    # need to generate pointer for this offset?
    if(! mem_has($dst,$sid)) {
      my $off=($solved)
        ? $step*$elem
        : 0
        ;
      my $addr=ptr_addr($base)+$off;
      return ptr_new($dst,$type,$sid,$addr);
    };
    # ^nope, give existing!
    return ptr_get($dst,$sid);

  # regular value!
  } else {
    return ptr_get($dst,$id);
  };
};


# ---   *   ---   *   ---
# ^read/write

sub vm_load {
  my ($vm,$id)=@_;
  my $mem=vm_var_blk($vm);
  my $ptr=ptr_get($mem,$id);
  my ($value)=mem_dload($mem,$ptr);

  return vm_push($vm,$ptr->{type},$value);
};
sub vm_store {
  my ($vm,$id,%O)=@_;
  $O{keep} //= 0;

  my $mem   = vm_var_blk($vm);
  my $ptr   = ptr_get($mem,$id);
  my @value = ($O{keep})
    ? ($vm->{stk}->[-1])
    : vm_pop($vm)
    ;
  return mem_dstore(
    $mem,
    $ptr,
    map {$ARG->{value}} @value
  );
};


# ---   *   ---   *   ---
# retrieve symbol data

sub vm_sym_get {
  my ($vm,$id)=@_;
  my $mem=$vm->{mem};
  return (exists $mem->{ftab}->{$id})
    ? $mem->{ftab}->{$id}
    : undef
    ;
};
sub vm_sym_in {
  my ($vm,$sym)=@_;
     $sym //= $vm->{cur};
  my $mem   = $sym->{ftab}->{var};

  # get all values declared as parameters,
  # in the order in which they were declared
  return (
    sort    {ptr_addr($a) > ptr_addr($b)}
    grep    {$ARG->{flg} & ptr_flg("in")}
    values %{$mem->{vtab}}
  );
};
sub vm_sym_out {
  my ($vm,$sym)=@_;
     $sym //= $vm->{cur};
  my $tab   = $sym->{ftab}->{var}->{vtab};

  return (exists $tab->{-out})
    ? $tab->{-out}
    : undef
    ;
};


# ---   *   ---   *   ---
# ~~

sub vm_prog {
  # check the program
  my ($vm,$src)=@_;
  my @prog=vm_prog_rd($vm,$src);

  # context switch...
  vm_ctx_save($vm,@prog);
  vm_label_recalc($vm);

  return @prog;
};
sub vm_prog_rd {
  # xlate string to IR?
  if(! is_arrayref($_[1])) {
    my @ir=Arstd::ir::ctoir($_[0],$_[1]);
    return Arstd::ir::ir_flat(@ir);
  };
  # ^input is IR, so no translation
  #
  # NOTE: we assume the program has already
  #       been validated because ctoir
  #       should handle that
  return Arstd::ir::ir_flat(@{$_[1]});
};


# ---   *   ---   *   ---
# evaluates expressions

sub vm_eval {
  my ($vm,$src,%O)=@_;
  $O{in} //= {};

  my @prog=vm_prog($vm,$src);
  my $ctx=($prog[0]->{cmd} eq "proc")
    ? $vm->{mem}->{ftab}->{$prog[0]->{args}->[0]}
    : undef
    ;
  $vm->{cur}=$ctx if $ctx;

  # set parameters...
  my $mem=vm_var_blk($vm);
  for (keys %{$O{in}}) {
    mem_store($mem,$ARG=>$O{in}->{$ARG});
  };
  # now execute
  my @out=vm_exec($vm);

  # restore context and give
  vm_ctx_load($vm);
  return @out;
};


# ---   *   ---   *   ---
# runs a function

sub vm_call {
  my ($vm,$fn)=@_;

  # setup stack frame!
  vm_enter($vm,$fn->{name});
  my $dst   = vm_var_blk($vm);
  my @param = vm_sym_in($vm);
  my @args  = vm_pop($vm,int(@param));
  for my $i(0..$#param) {
    my $ptr  = $param[$i];
    my $data = $args[$i];
    mem_dstore($dst,$ptr,$data->{value});
  };
  # exec, cleanup and give
  my @out=vm_exec($vm,$fn);
  vm_leave($vm);
  return @out;
};


# ---   *   ---   *   ---
# ^run F of currently loaded program

sub vm_exec {
  my ($vm,$fn)=@_;

  my $old=$vm->{rip};
  vm_jmp($vm,$fn,"x");
  vm_walk($vm,\&vm_exec_ins);

  $vm->{rip}=$old;
  return $vm->{stk}->[-1];
};
sub vm_walk {
  my ($vm,$out)=@_;
  my $stop=0;
  while(
  !  $stop
  && ++$vm->{rip} < int(@{$vm->{prog}})
  ) {
    my $ins  = $vm->{prog}->[$vm->{rip}];
       $stop = $out->($vm,$ins);
  };
  return $stop;
};
sub vm_exec_ins {
  my ($vm,$ins)=@_;
  my $tab = Arstd::ins::ins_tab();
  my $fn  = $tab->{$ins->{cmd}}->{execute};

  $fn->($vm,$ins);
  return $ins->{cmd} eq "ret";
};


# ---   *   ---   *   ---
# stack give/take

sub vm_push {
  my ($vm,$type,$value)=@_;
  push @{$vm->{stk}},{type=>$type,value=>$value};

  return;
};
sub vm_pop {
  my ($vm,$x)=@_;
  $x //= 1;

  my $stk=$vm->{stk};
  my @out=grep {$ARG} map {pop @$stk} 1..$x;

  throw  "vm: pop from empty stack"
  if     int(@out) != $x;

  return reverse @out;
};


# ---   *   ---   *   ---
# make label/jmp to label

sub vm_label {
  my ($vm,$label,$dir)=@_;
  my $name=vm_label_dir($vm,$label,$dir);
  $vm->{jmp}->{$name}=$vm->{rip};

  return;
};
sub vm_jmp {
  my ($vm,$label,$dir)=@_;
  my $name=vm_label_dir($vm,$label,$dir);
  throw "vm: undefined label '$name'"
  if!   exists $vm->{jmp}->{$name};

  $vm->{rip}=$vm->{jmp}->{$name};
  return;
};
sub vm_label_dir {
  my ($vm,$label,$dir)=@_;
  return (is_hashref($label))
    ? join("_",$dir,vm_label_str($vm,$label))
    : $label
    ;
};


# ---   *   ---   *   ---
# recalculate rip value for each label

sub vm_label_recalc {
  my ($vm)=@_;
  my $old=$vm->{rip};

  $vm->{rip}=-1;
  vm_walk($vm,\&vm_label_recalc_main);
  $vm->{rip}=$old;

  return;
};
sub vm_label_recalc_main {
  my $re=qr{^(?:if|else|loop|skip|proc)$};
  return 0 if! ($_[1]->{cmd}=~ $re);

  my $label=$_[1]->{args}->[0];
  if($_[1]->{cmd} eq "loop") {
    my $name=vm_label_dir($_[0],$label,"b");
    $_[0]->{jmp}->{$name}=$_[0]->{rip};

  } elsif($_[1]->{cmd} eq "proc") {
    my $name=vm_label_dir($_[0],$label,"x");
    $_[0]->{jmp}->{$name}=$_[0]->{rip};

  } else {
    my $name = vm_label_dir($_[0],$label,"f");
    my $old  = $_[0]->{rip};

    vm_label_recalc_next($_[0]);
    $_[0]->{jmp}->{$name} = $_[0]->{rip};
    $_[0]->{rip}          = $old;
  };
  return 0;
};
sub vm_label_recalc_next {
  my $re  = qr{^(?:if|loop|skip)}x;
  my $lvl = 1;
  my $fn  = sub {
    ++$lvl if $_[1]->{cmd}=~ $re;
    --$lvl if $_[1]->{cmd}=~ qr{^(?:end|else)$};

    return $lvl == 0;
  };
  return vm_walk($_[0],$fn);
};


# ---   *   ---   *   ---
# compile-time label handling

sub vm_label_new {
  my ($vm,$name)=@_;
  my ($ar,$par)=($vm->{label},undef);

  # fasm rules:
  # * `@@` is anon (generate name)
  # * `<name>` can act as parent
  # * `.<name>` cat with nearest parent
  # * `..<name>` cannot be parent, strip `..`
  if($name eq q[@@]) {
    $name="..anon_" . time_to_uid();

  } elsif($name=~ qr{^\.[^\.]}) {
    ($par)=(
      grep    {! ($ARG->{name}=~ qr{\.[^\.]})}
      reverse @$ar
    );
    throw "ir: no parent for label '$name'"
    if!   defined $par;

  } elsif($vm->{cur} ne $vm->{mem}) {
    $par=$vm->{cur}->{id};
  };
  # ^cleanup ".."
  my $re   =  qr{^\.\.};
     $name =~ s[$re][];

  strip($name);

  # make ice and give
  push @$ar,{
    name => $name,
    par  => $par,
    skip => {cnt=>0,emit=>1},
    loop => {cnt=>0,emit=>1},
  };
  return $ar->[-1];
};
sub vm_label_top {
  my $ar=$_[0]->{label};
  return (@$ar ? $ar->[-1] : undef);
};
sub vm_label_find {
  my $ar=$_[0]->{label};
  for(reverse @$ar) {
    return $ARG
    if     $_[1] eq vm_label_str($_[0],$ARG);
  };
  throw "vm: no such label '$_[1]'";
};
sub vm_label_str {
  my ($vm,$label)=@_;
  my $out=$label->{name};

  # cat parent if any
  if(defined $label->{par}) {
    $out="$label->{par}.$out";
  };
  # replace `.` for `_`, then give
  my $re  =  qr{\.};
     $out =~ s[$re][_]g;

  return $out;
};


# ---   *   ---   *   ---
# turns string to executable IR

sub vm_strir {
  my ($vm,$type,@expr)=@_;
  my $src   = join(" ",gstrip(@expr));
  my $strar = [];
  my $syx   = [Arstd::seq::delim()->{paren}];

  # solve operations!
  strtok($strar,$src,syx=>$syx);
  my $mem={
    dst   => [],
    strar => $strar,
    type  => $type,
    tgt   => null,
    vm    => $vm,
    call  => [],
    syx   => $syx,
  };
  Arstd::opex::opex($mem,$src);

  # get values and functions used;
  # we can later use this for tree-shaking
  my $dep={
    call=>$mem->{call},
  };
  # now convert expanded operations into
  # an array of instructions
  my $rtype = $mem->{type};
  my @body  = Arstd::ins::ins_build(
    $vm,
    $rtype,
    @{$mem->{dst}},
  );
  # ^give both
  return ($dep,@body);
};


# ---   *   ---   *   ---
1; # ret
