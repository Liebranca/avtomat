#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD IR
# a more  ~ a b s t r a c t ~
# kind of code...
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::ir;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_file);
  use Type qw(typefet typetab);

  use Arstd::String qw(
    cat
    jag
    strip
    gstrip
    gsplit
    time_to_uid
  );
  use Arstd::Array qw(flatten filter dupop);
  use Arstd::Bin qw(
    orc
    deepcpy
  );
  use Arstd::Re qw(eiths);
  use Arstd::throw;
  use Arstd::strtok qw(strtok);
  use Arstd::seq;
  use Arstd::opex;
  use Arstd::ins qw(
    ins_unfold
    ins_rdnode
    ins_rdexpr
    ins_argcnt
    ins_pushcnt
    ins_prich
  );
  use Tree::C;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter "import";
  our @EXPORT=qw(
    ir_new
    ir_prich
  );


# ---   *   ---   *   ---
# info

  my $VERSION = "v0.00.3a";
  my $AUTHOR  = "IBN-3DILA";


# ---   *   ---   *   ---
# cstruc
#
# recursively translates node from C tree

sub ir_new {
  my ($node)=@_;

  # go up one level
  my $pad   = node_state()->{pad};
  my $depth = node_enter();

  # map C node to IR equivalent
  my $ir;
  if($node->{type} eq "proc") {
    $ir=node_proc($node,$depth);

  } elsif($node->{type} eq "asg") {
    $ir=node_asg($node,$depth);

  } elsif($node->{type} eq "expr") {
    $ir=node_expr($node,$depth);

  } elsif($node->{type} eq "fctl") {
    $ir=node_fctl($node,$depth);

  } elsif($node->{type} eq "null") {
    # these empty nodes are used as separators
    # by some block types!
    #
    # it's safe to ignore them :D
    $ir=null;

  # catch invalid
  } else {
    throw "NYI: <$node->{type}> node";
  };
  # add additional info to output
  if(! is_null($ir)) {
    # remember who you are!!
    $ir->{node_t}=$node->{type};

    # not strictly necessary, but we want
    # to add comments to the generated code
    # while we debug the compiler
    my $args=(! is_null($node->{args}))
      ? "(" . join(",",@{$node->{args}}) . ")"
      : ""
      ;
    $ir->{meta}=cat(
      $node->{cmd},
      " ",
      $node->{expr},
      $args,
    );
    $ir->{depth}=$depth;

    # finally, run standard checks to
    # ensure we emit valid output!
    ir_defnit($ir);
    ir_stkchk($ir);
  };
  # go down one level and give
  node_leave();
  return (! is_null($ir) ? $ir : ());
};
sub ir_new_blk {
  my $dep  = {call=>[]};
  my @body = ();

  for(@_) {
    my $ir=ir_new($ARG);
    push @{$dep->{call}},@{$ir->{dep}->{call}};
    push @body,$ir;
  };
  dupop($dep->{call});
  return ($dep,@body);
};


# ---   *   ---   *   ---
# sets defaults for node

sub ir_defnit {
  $_[0]->{node_t} //= "null";
  $_[0]->{decl}   //= 0;
  $_[0]->{head}   //= [];
  $_[0]->{body}   //= [];
  $_[0]->{foot}   //= [];
  $_[0]->{ins}    //= [];
  $_[0]->{eins}   //= [];
  $_[0]->{ctx}    //= {};
  $_[0]->{flg}    //= {};
  $_[0]->{meta}   //= null;
  $_[0]->{depth}  //= 0;

  return;
};


# ---   *   ---   *   ---
# book-keeping for node translation

sub node_state {
  state $out={
    depth => 0,
    sym   => {},
  };
  return $out;
};
sub node_enter {
  my $mem   = node_state();
  my $depth = $mem->{depth}++;

  return $depth;
};
sub node_leave {
  my $mem   = node_state();
  my $depth = --$mem->{depth};

  return $depth;
};


# ---   *   ---   *   ---
# translate procedures

sub node_proc {
  my ($node,$depth)=@_;

  # get return type
  my ($type,$name,@expr)=ins_rdnode($node);
  my $flg_re=qr{\b(public)\b};

  # ^handle flags
  my $flg={
    public=>0,
  };
  while($type=~ s[$flg_re][]) {
    my $x=$1;
    if($x eq "public") {
      $flg->{public}=1;
    };
  };
  # make new scope and register return type
  strip($type);
  proc_state(enter=>$name);

  # set arguments
  my (@in,@out)=((),());
  for(@{$node->{args}}) {
    my ($t,$n,@e)=ins_rdexpr($ARG);
    $t=proc_state(in=>$t=>$n);
    push @in,{
      cmd  => "in",
      args => [$n],
      type => $t,
    };
  };
  # set return type
  $type=proc_state(out=>$type=>$name);
  push @out,{
    cmd  => "out",
    args => [],
    type => $type,
  };
  # process function body
  my ($dep,@body)=ir_new_blk(@{$node->{blk}});

  # now get local values...
  for(proc_state(arlocal=>())) {
    my ($n,$t)=@$ARG;
    push @out,{
      cmd  => "local",
      args => [$n],
      type => $t,
    };
  };
  # close scope and save data
  my $ctx=proc_state(leave=>());

  # give IR
  return {
    name => $name,
    type => $type,
    ctx  => $ctx,
    body => \@body,
    dep  => $dep,
    ins  => [
      {
        cmd  => "proc",
        args => [$name],
        type => null,
      },
      @in,
      @out,
    ],
    flg => $flg,
  };
};


# ---   *   ---   *   ---
# ^book keeping for current proc node

sub proc_state_def {
  return (
    -name  => null,
    -ret   => null,
    -local => {},
    -sym   => {},
    -order => [],
  );
};
sub proc_state {
  state $mem={proc_state_def()};
  my ($cmd,$n)=@_;

  # opens new scope
  if($cmd eq "enter") {
    node_state()->{sym}->{$n}={
      ret  => {},
      args => [],
    };
    $mem->{-name}=$n;
    return;

  # reset state block
  } elsif($cmd eq "leave") {
    my $out=deepcpy($mem);
    %$mem=proc_state_def();

    return $out;

  # fetch full state jar
  } elsif($cmd eq "jar") {
    return $mem;

  # check if variable exists within scope
  } elsif($cmd eq "has") {
    return exists $mem->{$n};

  # ^get type of variable
  } elsif($cmd eq "get") {
    if( (defined $_[2])
    &&  (exists $mem->{$_[2]}) ) {
      return $mem->{$_[2]};

    } elsif(exists $mem->{$n}) {
      return $mem->{$n};
    };

  # ^type of the return value itself
  } elsif($cmd eq "ret") {
    return $mem->{-out};

  # get list of variables
  } elsif($cmd eq "arlocal") {
    my $tab=$mem->{-local};
    return map {[$ARG,$tab->{$ARG}]} keys %$tab;

  # variable decl
  } elsif($cmd=~ qr{^(?:in|local|out)$}) {
    my $t=$n;
    return null if is_null($t);

    $n=$_[2];
    $t=typefet($t);

    push @{$mem->{-order}},$n
    if!  exists $mem->{$n};

    $mem->{$n}=$t;

    # regular variable
    if($cmd eq "local") {
      $mem->{-local}->{$n}=$t;

    # function parameter
    } elsif($cmd eq "in") {
      my $k   = $mem->{-name};
      my $sym = node_state()->{sym}->{$k};

      push @{$sym->{in}},[$t=>$n];

    # function return value
    } elsif($cmd eq "out") {
      my $k   = $mem->{-name};
      my $sym = node_state()->{sym}->{$t};

      $sym->{out}=$mem->{-out}=$t;
    };
    return $t;
  };
  # catch invalid
  throw "ir-proc: undefined command <$cmd>";
};


# ---   *   ---   *   ---
# translate assignments

sub node_asg {
  my ($node,$depth)=@_;
  my ($type,$name,@expr)=ins_rdnode($node);

  # get value type
  my $decl =! is_null($type);
  my $scmd =  ($decl) ? "local" : "get" ;
     $type =  proc_state($scmd=>$type=>$name);

  # evaluate expression! \( ^ .^)/
  my ($dep,@ins)=expr_to_ins($type,$name,@expr);

  # give IR
  return {
    name => $name,
    type => $type,
    ins  => \@ins,
    dep  => $dep,
    decl => $decl,
  };
};


# ---   *   ---   *   ---
# translate generic expressions

sub node_expr {
  my ($node,$depth)=@_;
  my ($type,$name,@expr)=ins_rdnode($node,1);

  # valid type in this case means it's
  # a declaration without a value!
  if(! is_null($type)) {
    proc_state(local=>$type=>$name);
    return null;

  # fetch the current function's type
  # when encountering a return statement
  } elsif($expr[0] eq "ret") {
    $type=proc_state(ret=>());
  };
  # evaluate this expression...
  my ($dep,@ins)=expr_to_ins($type,@expr);

  # give IR
  return {
    name => $name,
    type => $type,
    body => [],
    dep  => $dep,
    ins  => \@ins,
  };
};


# ---   *   ---   *   ---
# translate control flow blocks

sub node_fctl {
  my ($node,$depth)=@_;
  my $cmd=$node->{cmd};
  my $blk=$node->{blk};

  # get args for block
  my ($topdep,@top)=();
  my ($botdep,@bot)=();
  while(@$blk) {
    # stop at nullterm!
    my $nd=shift @$blk;
    last if $nd->{type} eq "null";

    # any vars initialized within the block
    # should come before the label itself,
    # that's why we break these up
    if($nd->{type} eq "asg") {
      push @top,$nd;

    } else {
      push @bot,$nd;
    };
  };
  # translate block(...) condition
  ($topdep,@top)=ir_new_blk(@top);
  ($botdep,@bot)=ir_new_blk(@bot);

  # translate inner scope of block
  my ($dep,@body)=ir_new_blk(@{$node->{blk}});

  # roll deps together...
  push @{$dep->{call}},@{$topdep->{call}};
  push @{$dep->{call}},@{$botdep->{call}};
  dupop($dep->{call});

  # ~~
  if($cmd eq "while") {
    push @top,@bot;
    push @{$top[-1]->{ins}},(
      {
        cmd  => "eqz",
        args => [""],
        type => $top[-1]->{ins}->[-1]->{type},
      },{
        cmd  => "cbreak",
        args => [""],
        type => null,
      },
    );
    @bot=();
  };
  # give IR
  my $name=join("_","fctl",time_to_uid());
  return {
    name => $name,
    type => null,
#    head => \@top,
#    body => \@body,
#    foot => \@bot,
    body => [@top,@body,@bot],
    dep  => $dep,
    ins  => [
      {
        cmd  => "block",
        args => [$name],
        type => null,
      },
    ],
    eins => [
      {
        cmd  => "end",
        args => [$name],
        type => null,
      },
    ],
  };
};


# ---   *   ---   *   ---
# evaluates expressions from C node

sub expr_to_ins {
  my ($type,@expr)=@_;
  my $strar = [];
  my $syx   = [Arstd::seq::delim()->{paren}];
  my $src   = join(" ",gstrip(@expr));

  # solve operations!
  strtok($strar,$src,syx=>$syx);
  my $mem={
    dst   => [],
    strar => $strar,
    type  => $type,
    tgt   => null,
    var   => proc_state(jar=>()),
    sym   => node_state()->{sym},
    call  => [],
  };
  opex($mem,$src);

  # get values and functions used;
  # we can later use this for tree-shaking
  my $dep={
    call=>$mem->{call},
  };
  # now convert expanded operations into
  # an array of instructions
  my @body=map {
    ins_unfold(
      $ARG->{type} // $mem->{type},
      $ARG,
    );

  } @{$mem->{dst}};

  # ^give both
  return ($dep,@body);
};


# ---   *   ---   *   ---
# performs basic correctness check
# on the generated instructions

sub ir_stkchk {
  my ($ir,$stk,$var)=@_;
  $stk //= [];
  $var //= {};

  # walk the instruction list...
  my $ar=$ir->{ins};
  for(0..$#$ar) {
    my $i   = $ARG;
    my $ins = $ar->[$i];

    # get instruction data
    my $take = ins_argcnt($ins->{cmd});
    my $give = ins_pushcnt($ins->{cmd});
    my $tgt  = $ins->{args}->[0] // null;

    # handle get/set stack checkup
    if(! is_null($tgt)
    &&   ($tgt=~ qr{^[[:alnum:]_]+$}) ) {
      # first, we mark that a value is loaded
      if($ins->{cmd} eq "get") {
        $var->{$tgt}=$i;

      # ^then handle *storing* that value
      } elsif($ins->{cmd} eq "set") {
        # we check whether to conserve or
        # consume the value uppon storing,
        # accto it being needed by a subsequent
        # instruction!
        if(ir_stkchk_lkahead($ar,$stk,$var,$i)) {
          $ins->{cmd}="seep";
        };
        # then we also check for a redundant get
        if(exists $var->{$tgt}) {
          my $j=$var->{$tgt};
          $ar->[$j]=undef;
        };

      # finally, we unmark the value when
      # it is consumed!
      } elsif($take) {
        delete $var->{$tgt};
      };
    };
    # validate the stack
    #
    # we get instruction data again, as the
    # previous block might modify it!
    my $have = int(@$stk);
       $take = ins_argcnt($ins->{cmd});
       $give = ins_pushcnt($ins->{cmd});
    if( ($have < $take)
    ||! ir_stkchk_take($ins,$stk,$var,$take) ) {
      ir_prich($ir);
      throw "BADSTK";
    };
    push @$stk,$ins if $give;
  };
  filter($ar);
  return;
};
sub ir_stkchk_lkahead {
  my ($ar,$stk,$var,$i)=@_;
  for($i+1..$#$ar) {
    my $j     = $ARG;
    my $tail  = $ar->[$i];
    my $ahead = $ar->[$j];

    # true if both instructions require
    # the same value to be loaded!
    my $x=$tail->{args}->[0] // null;
    my $y=$ahead->{args}->[0] // null;
    return 1 if $x eq $y;
  };
  return 0;
};
sub ir_stkchk_take {
  my ($ins,$stk,$var,$take)=@_;
  while($take) {
    # fail if instruction required a
    # value on the stack, but there is no value!
    my $other=pop @$stk;
    return 0 if! $other;

    # fail if instruction required a value
    # of a specific width, but there is
    # a mismatch!
    my ($x,$y)=(
      $ins->{type}->{sizeof},
      $other->{type}->{sizeof},
    );
    return 0 if $x != $y;
    --$take;
  };
  return 1;
};


# ---   *   ---   *   ---
# dbout

sub ir_prich {
  for(@_) {
    my $pad="  " x $ARG->{depth};
    say "\n$pad; $ARG->{meta}";

    ins_prich($ARG,pad=>$pad,type=>1)
    for @{$ARG->{ins}};

    ir_prich($ARG) for @{$ARG->{head}};
    ir_prich($ARG) for @{$ARG->{body}};
    ir_prich($ARG) for @{$ARG->{foot}};

    ins_prich($ARG,pad=>$pad,type=>1)
    for @{$ARG->{eins}};
  };
  return;
};


# ---   *   ---   *   ---
1; # ret
