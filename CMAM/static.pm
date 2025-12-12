#!/usr/bin/perl
# ---   *   ---   *   ---
# CMAM STATIC
# guts
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package CMAM::static;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null no_match);
  use Chk qw(is_null);

  use Arstd::String qw(gsplit);
  use Arstd::Bin qw(deepcpy);
  use Arstd::Path qw(from_pkg extwap);
  use Arstd::Re qw(eiths);
  use Tree::C;
  use Type::MAKE;

  use lib "$ENV{ARPATH}/lib/";
  use AR ();

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    cpackage
    cmamlol
    cmamgbl
    cmamfn
    cmamdef
    cmamdef_re
    ctree

    is_local_scope
    set_local_scope
    unset_local_scope

    cmamout
    cmamout_push_pm
    cmamout_push_c
    cmamout_exported
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.01.0a';
  our $AUTHOR  = 'IBN-3DILA';

  sub errsafe {return 1};


# ---   *   ---   *   ---
# get current package from C space
#
# [<]: mem ptr ; selfex

sub cpackage {
  state $out='non';
  $out=$_[0] if ! is_null($_[0]);
  return (! is_null($out))
  ? $out
  : 'SWAN::cmacro'
  ;
};


# ---   *   ---   *   ---
# get handle to output buffer
#
# [<]: mem ptr ; output hashref

sub cmamoutp {
  state $out={};
  return $out;
};
sub cmamout {
  my $out=cmamoutp();
  my $pkg=cpackage();

  $out->{$pkg}//={
    def    => [],
    dep    => {c=>[],pm=>[]},
    type   => [],
    export => [],
    info   => {},
  };
  return $out->{$pkg};
};


# ---   *   ---   *   ---
# get local/global scope

sub cmamscope {
  state $out={local=>{},global=>{},fn=>{}};
  return $out;
};
sub cmamlol {return cmamscope()->{local}};
sub cmamgbl {return cmamscope()->{global}};
sub cmamfn  {return cmamscope()->{fn}};


# ---   *   ---   *   ---
# get defined symbols

sub cmamdef {
  state $out={};
  return $out;
};

sub cmamdef_re {
  my $spec   = shift;
     $spec //= 0x0000;

  my $tab=cmamdef();
  my $key=[
    grep {! ($tab->{$ARG}->{flg} & $spec)}
    keys %$tab
  ];

  return no_match() if ! @$key;
  return eiths(
    $key,
    bwrap => 1,
    capt  => 'scmd',
  );
};


# ---   *   ---   *   ---
# we use this to make sure we don't
# accidentally delete packages that
# are required by the current process

sub exedeps {
  state $out={};
  return $out;
};


# ---   *   ---   *   ---
# wipes global state
#
# use this when you start processing
# a new file

sub restart {
  my $pkg  = cpackage();
  my $deps = exedeps();

  # unimport any packages that were dynamically
  # loaded while processing the previous file
  my @unload=(
    map {AR::unload($ARG)}

    # filter out dependencies for *this* program!
    grep {! exists $deps->{$ARG}}
    (map {$ARG->[0]} @{cmamout()->{dep}->{pm}}),

    # ^current package unloaded last ;>
    $pkg
  );

  # delete any dynamically defined symbols
  #
  # we do this to make sure a file cannot
  # access things it hasn't directly or
  # indirectly included

  no strict 'refs';
  for(grep {
    ! ($ARG=~ qr{(?:package|use|macro)})

  } keys %{cmamdef()}) {
    undef  *{"$pkg\::$ARG"};
    delete cmamdef()->{$ARG};
  };
  use strict 'refs';

  # delete parse tree
  ctree(0xCC);

  # now reset globals
  %{cmamdef()}   = ();
  %{cmamoutp()}  = ();
  %{cmamscope()} = (local=>{},global=>{},fn=>{});
  ${cflag()}     = 0x00;

  cpackage(null);

  return;
};


# ---   *   ---   *   ---
# read from global flag

sub cflag {
  state $out=0x00;
  return \$out;
};
sub is_local_scope {${cflag()} & 0x01};


# ---   *   ---   *   ---
# ^set global flag AND handle scope setup

sub set_local_scope {
  my ($nd)=@_;
  ${cflag()} |= 0x01;

  # clear scope
  %{cmamlol()}=();

  # ^and add function args to scope
  add_value_typedata(
    Tree::C->rd($ARG)->to_expr()

  ) for @{$nd->{args}};;

  # overwrite F data container
  my $dst = cmamfn();
  my $fn  = Tree::C::node_to_fn($nd);

  %$dst=%$fn;

  return;
};


# ---   *   ---   *   ---
# ^cleanup

sub unset_local_scope {
  ${cflag()}   &=~ 0x01;
  %{cmamlol()}  =  ();
  %{cmamfn()}   =  ();

  return;
};


# ---   *   ---   *   ---
# add value typedata to current scope
#
# [0]: mem ptr ; expression hashref

sub add_value_typedata {
  my ($nd)=@_;
  my ($name,$type)=Tree::C::decl_from_node($nd);

  # is the joined string in the type-table?
  if( Type->is_valid($type)
  &&! Type->is_base_ptr($type)) {
    # what scope are we in?
    my $scope=(is_local_scope())
      ? cmamlol()
      : cmamgbl()
      ;

    # record typedata about this value
    $scope->{$name}=$type;
  };
  return;
};


# ---   *   ---   *   ---
# add perl dependency
#
# [0]: byte ptr ; package name
# [1]: byte ptr ; import arguments
#
# [<]: byte pptr ; import argument (as new array)
#
# [*]: writes to output hash

sub cmamout_push_pm {
  # get args passed to import;
  my $qw_re  = qr{qw\s*\(([^\)]+)\)\s*;};
  my ($have) = ($_[1]=~ $qw_re);
  my @req    = gsplit($have);

  # append to out and give required symbols
  push @{cmamout()->{dep}->{pm}},[$_[0]=>@req];
  return @req;
};


# ---   *   ---   *   ---
# add C dependency
#
# [0]: byte ptr ; package name
# [*]: writes to output hash

sub cmamout_push_c {
  my $cpy="$_[0]";
  from_pkg($cpy);
  extwap($cpy,'h');
  push @{cmamout()->{dep}->{c}},$cpy;

  return "#include \"$cpy\";";
};


# ---   *   ---   *   ---
# get/make parse tree

sub ctree {
  state $tree=undef;
  if(! is_null($_[0])) {
    $tree=($_[0] ne 0xCC)
      ? Tree::C->rd($_[0])
      : undef
      ;
  };
  return $tree;
};


# ---   *   ---   *   ---
# fetches and sorts symbols in export array

sub sort_export {
  my @proc  = ();
  my @type  = ();
  my @const = ();

  for my $blk(@{cmamout()->{export}}) {
    for my $nd(@$blk) {
      if($nd->{type}=~ qr{(?:struc|union)}) {
        my ($name,$t)=Type::MAKE::strucdef($nd);
        my @ptr=Type::MAKE::ptrfet($name);
        push @type,$t,@ptr;

      } elsif($nd->{type} eq 'utype') {
        my ($name,$t)=Type::MAKE::utypedef($nd);
        my $cpy=deepcpy($t);
        $cpy->{name}=$name;
        push @type,$cpy;

      } elsif($nd->{type} eq 'proc') {
        push @proc,$nd;

      } elsif($nd->{type} eq 'asg'
        &&    $nd->{cmd}  eq 'CX') {
        push @const,$nd;
      };
    };
  };
  return {
    proc  => [@proc],
    type  => [@type],
    const => [@const],
  };
};


# ---   *   ---   *   ---
1; # ret
