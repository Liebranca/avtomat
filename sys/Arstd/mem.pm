#!/usr/bin/perl
# ---   *   ---   *   ---
# MEMORY
# you can't handle it
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::mem;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null nop);
  use Chk qw(is_null);
  use Type qw(typefet strucv is_prim);

  use Arstd::String qw(
    gstrip
    gsplit
    time_to_uid
  );
  use Arstd::Int qw(mulpow2);
  use Arstd::flg qw(
    flg_def
    flg_get
    flg_or
  );
  use Arstd::throw;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter "import";
  our @EXPORT_OK=qw(
    mem_new
    mem_del
    mem_blk
    mem_flg
    mem_has
    mem_load
    mem_dload
    mem_store
    mem_dstore
    mem_push

    ptr_new
    ptr_del
    ptr_get
    ptr_flg
    ptr_addr
  );


# ---   *   ---   *   ---
# info

  my $VERSION = "v0.00.5a";
  my $AUTHOR  = "IBN-3DILA";


# ---   *   ---   *   ---
# ROM

sub mem_flg {
  state $tab=flg_def(qw(
    grow rom ram exe
  ));
  if(int(@_)) {
    my $out=0x00;
    return flg_or($out,$tab,@_);
  };
  return $tab;
};
sub mem_step {64};


# ---   *   ---   *   ---
# cstruc

sub mem_new {
  # defaults
  my (%O)=@_;
  $O{id}   //= "mem_" . time_to_uid();
  $O{blk}  //= [];
  $O{par}  //= undef;
  $O{vtab} //= {};
  $O{ftab} //= {};
  $O{sz}   //= mem_step();
  $O{ptr}  //= 0;
  $O{top}  //= 0;
  $O{buf}  //= "\0" x $O{sz};
  $O{flg}  //= 0x00;

  # catch invalid
  throw "mem: buf-size mismatch"
  if    length($O{buf}) != $O{sz};

  my $self=\%O;
  return $self;
};


# ---   *   ---   *   ---
# ^push new child

sub mem_blk {
  my ($mem,%O)=@_;
  my $out=mem_new(%O,par=>$mem);

  throw "mem: redeclaration of symbol "
  .     "<$out->{id}> at '$mem->{id}'"

  if    exists $mem->{ftab}->{$out->{id}};

  $mem->{ftab}->{$out->{id}}=$out;
  push @{$mem->{blk}},$out;

  return $out;
};


# ---   *   ---   *   ---
# dstruc

sub mem_del {
  my ($mem)=@_;
  if($mem->{par}) {
    my $blk=$mem->{par}->{blk};
    @$blk=grep {$ARG->{id} ne $mem->{id}} @$blk;
    delete $mem->{par}->{ftab}->{$mem->{id}};
  };
  return;
};


# ---   *   ---   *   ---
# buf read/write

sub mem_load {
  my ($mem,$id)=@_;
  my $ptr=ptr_get($mem,$id)
  or throw "mem: undefined ptr <$id>";

  return mem_dload($mem,$ptr);
};
sub mem_dload {
  # primitive
  if(is_prim($_[1]->{type})) {
    return vec(
      $_[0]->{buf},
      $_[1]->{off},
      $_[1]->{bits}
    );
  };
  # struc or array
  my $data=substr(
    $_[0]->{buf},
    ptr_addr($_[1]),
    $_[1]->{type}->{sizeof},
  );
  return unpack(
    $_[1]->{type}->{packof},
    $data
  );
};

sub mem_store {
  my ($mem,$id,@data)=@_;
  my $ptr=ptr_get($mem,$id)
  or throw "mem: undefined ptr <$id>";

  return mem_dstore($mem,$ptr,@data);
};
sub mem_dstore {
  # primitive
  if(is_prim($_[1]->{type})) {
    return vec(
      $_[0]->{buf},
      $_[1]->{off},
      $_[1]->{bits}

    )=$_[2] // 0;
  };
  # struc or array
  my $data=pack(
    $_[1]->{type}->{packof},
    @_[2..$#_]
  );
  return substr(
    $_[0]->{buf},
    ptr_addr($_[1]),
    length($data),
    $data,
  );
};


# ---   *   ---   *   ---
# ^check if value exists

sub mem_has {
  return exists $_[0]->{vtab}->{$_[1]};
};


# ---   *   ---   *   ---
# ^declare value

sub mem_push {
  my ($mem,$type,$id,@data)=@_;
  my $ptr=mem_push_impl($mem,$type,$id);
  mem_dstore($mem,$ptr,@data);

  return $ptr;
};
sub mem_push_impl {
  my ($mem,$type,$id)=@_;
  $id   //= "ptr_" . time_to_uid();
  $type   = typefet($type);

  # ensure ptr is aligned, then adjust top
  my $rem  = $mem->{top} % $type->{sizeof};
  my $addr = $mem->{top} + $rem;

  $mem->{top}=$addr+$type->{sizeof};

  # conditionally allocate more space
  # *IF* this buf has the correct flag set
     mem_goob   ($mem,$mem->{top})
  if mem_flgchk ($mem,"grow");

  # ^make ice and give
  return ptr_new($mem,$type,$id,$addr);
};


# ---   *   ---   *   ---
# allocate N more bytes to buf
#
# [!]: N is forced to the nearest multiple
#      of mem_step

sub mem_grow {
  my ($mem,$n)=@_;
  $n=mulpow2($n,mem_step());
  $mem->{buf} .= "\0" x $n;
  $mem->{sz}  += $n;

  return;
};


# ---   *   ---   *   ---
# checks if address is within bounds

sub mem_oob {
  return $_[1] > $_[0]->{sz};
};


# ---   *   ---   *   ---
# ^^grow if addr is out of bounds!

sub mem_goob {
  return (mem_oob(@_))
    ? mem_grow($_[0],$_[1] - $_[0]->{sz})
    : ()
    ;
};


# ---   *   ---   *   ---
# get name for id that includes ancestry

sub mem_strid {
  my ($mem,$id)=@_;
  my @ar=($mem->{id});
  while($mem->{par}) {
    $mem=$mem->{par};
    push @ar,$mem->{id};
  };
  return join(".",reverse($id,@ar));
};


# ---   *   ---   *   ---
# check/set/unset flags

sub mem_flgchk {
  $_[0]->{flg} &   mem_flg(@_[1..$#_]);
};
sub mem_flgset {
  $_[0]->{flg} |=  mem_flg(@_[1..$#_]);
};
sub mem_flgunset {
  $_[0]->{flg} &= ~mem_flg(@_[1..$#_]);
};


# ---   *   ---   *   ---
# ROM

sub ptr_flg {
  state $tab=flg_def(qw(
    in local out proc
  ));
  if(int(@_)) {
    my $out=0x00;
    return flg_or($out,$tab,@_);
  };
  return $tab;
};


# ---   *   ---   *   ---
# cstruc values for mem
#
# [0]: mem ptr  ; src
# [1]: byte ptr ; type
# [2]: qword    ; addr in bytes

sub ptr_new {
  my ($mem,$type,$id,$addr)=@_;
  $type=typefet($type);

  # make ice
  my $ptr={
    id   => $id,
    off  => 0,
    bits => 0,
    type => $type,
    flg  => 0x00,
  };
  # ATOW `vec` can read/write 64 bits at most;
  # so we only point to the first element
  # for structs and arrays that are larger
  # than said limit
  $ptr->{bits}=($type->{sizebs} <= 64)
    ? $type->{sizebs}
    : strucv($type)->{sizebs}
    ;
  # get aligned offset
  $ptr->{off}=int(
    (($addr << 3) / $ptr->{bits})
  + 0.5
  );
  # save ref to internal table
  $mem->{vtab}->{$id}=$ptr;

  # catch unaligned/out of bounds access
  #
  # neither is strictly necessary, as `vec`
  # has guardrails for both, but it's nice
  # to have imo
  throw "mem: OOB ptr <$type->{name}> '$id'"
  if    mem_oob($mem,$addr);

  throw "mem: unaligned ptr <$type->{name}> '$id'"
  if    ptr_addr($ptr) != $addr;

  # instead of the instance itself, we
  # should access the ptr through its id
  #
  # this way the offset can be easily
  # recalculated if _and_ when the containing
  # buffer is merged with another
  #
  # anyway, this F itself gives the ptr
  # just for convenience...
  return $ptr;
};


# ---   *   ---   *   ---
# ^dstruc

sub ptr_del {
  my ($mem,$id)=@_;
  delete $mem->{vtab}->{$id};

  return;
};


# ---   *   ---   *   ---
# ^retrieve from table(s)
#
# we need to do it this way to
# support nested namespaces!

sub ptr_get {
  my ($mem,$id)=@_;
  while($mem) {
    # match hit?
    return $mem->{vtab}->{$id}
    if     mem_has($mem,$id);

    # ^else recurse
    $mem=$mem->{par};
  };
  return;
};


# ---   *   ---   *   ---
# calculates the pointer's full
# address in bytes

sub ptr_addr {
  return $_[0]->{off}*($_[0]->{bits} >> 3);
};


# ---   *   ---   *   ---
1; # ret
