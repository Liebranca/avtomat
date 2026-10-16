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
  use Type qw(
    typefet
    typetab
    sizeof
    derefof
    is_ptr
  );
  use Arstd::String qw(
    cat
    jag
    strip
    gstrip
    gsplit
  );
  use Arstd::Array qw(
    flatten
    filter
    dupop
    iof
  );
  use Arstd::Bin qw(
    orc
    deepcpy
  );
  use Arstd::Re qw(eiths);
  use Arstd::throw;
  use Arstd::strtok qw(strtok);
  use Arstd::IO qw(io_procin io_procout);
  use Arstd::seq;
  use Arstd::vm qw(
    vm_new
    vm_enter
    vm_leave
    vm_in
    vm_local
    vm_out
    vm_var_get
    vm_label_new
    vm_label_top
    vm_label_find
    vm_label_str
    vm_strir
  );
  use Arstd::opex;
  use Arstd::ins qw(
    ins_new
    ins_build
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
    ctoir
    ir_new
    ir_flat
    ir_prich
  );


# ---   *   ---   *   ---
# info

  my $VERSION = "v0.01.2a";
  my $AUTHOR  = "IBN-3DILA";


# ---   *   ---   *   ---
# entry point
#
# [0]: mem ptr  ; vm instance
# [1]: byte ptr ; string with C code
#
# [<]: mem pptr ; instruction array

sub ctoir {
  my @ir=(
    map {ir_new($_[0],$ARG)}
    Tree::C->rd($_[1])->to_expr()
  );
  # perform recursive walk as checkup
  ir_build($_[0],$ARG) for @ir;

  # handle instruction relocation
  ir_enroque(@ir);

  # cleanup empty nodes
  return ir_filter(@ir);
};
sub ir_build {
  for(qw(ins eins)) {
    my $ins=$_[1]->{$ARG};
    @$ins=ins_build($_[0],typefet("void"),@$ins);
  };
  ir_build($_[0],$ARG) for @{$_[1]->{body}};
  return;
};
sub ir_filter {
  my @out = grep {ir_filter_f($ARG)} @_;
  my @Q   = @out;
  while(@Q) {
    my $node=shift @Q;

    @{$node->{body}}=(
      grep {ir_filter_f($ARG)}
      @{$node->{body}}
    );
    unshift @Q,@{$node->{body}};
  };
  return @out;
};
sub ir_filter_f {
  return ( @{$_[0]->{body}}
  ||       @{$_[0]->{ins}}
  ||       @{$_[0]->{eins}} )

  ||! is_null($_[0]->{label});
};


# ---   *   ---   *   ---
# relocate instructions based on
# which ones are ahead of it

sub ir_enroque {
  my @ir=@_;

  # walk prog...
  my @mvend=();
  for my $i(0..$#ir) {
    # get current node plus next one
    my $this  = $ir[$i];
    my $ahead = ($i+1 <= $#ir) ? $ir[$i+1] : undef;

    # emit missing markers
    my $label=$this->{label};
    if(! is_null($label)) {
      my $beg=$this->{ins};
      my $end=$this->{eins};

      for(qw(skip loop)) {
        next if! $label->{$ARG}->{emit}
             ||! $label->{$ARG}->{cnt};

        push @$beg,ins_new("void",$ARG=>($label));
        push @$end,ins_new("void",end=>());

        $label->{$ARG}->{emit}=0;
      };
    };
    # handle "end" for if/else chains
    if($this->{node_t} eq "fctl") {
      # move previously relocated "end"
      my $ins=$this->{ins};
      if(int(@$ins)
      && $ins->[-1]->{cmd}=~ qr{^(?:if|else)$}) {
        push @{$this->{eins}},@mvend;
        @mvend=();
      };
      # ^relocate "end" for current node
      if($ahead) {
        my $ains=$ahead->{ins};
        if((int(@$ins) && int(@$ains))
        && $ins->[-1]->{cmd} eq "if"
        && $ains->[0]->{cmd} eq "else") {
          push @mvend,@{$this->{eins}};
          @{$this->{eins}}=();
        };
      };
    };
    # recurse
    ir_enroque(@{$this->{body}});
  };
  return;
};


# ---   *   ---   *   ---
# cstruc
#
# recursively translates node from C tree

sub ir_new {
  my ($vm,$node)=@_;

  # labels can be added to any node, and
  # are simply stored within it as a string;
  #
  # we take note of the latest label encountered
  # whenever we step on one
  if(! is_null($node->{label})) {
    $node->{label}=vm_label_new(
      $vm,
      $node->{label}
    );
  };
  # map C node to IR equivalent
  my $ir;
  if($node->{type} eq "proc") {
    $ir=node_proc($vm,$node);

  } elsif($node->{type} eq "asg") {
    $ir=node_asg($vm,$node);

  } elsif($node->{type} eq "expr") {
    $ir=node_expr($vm,$node);

  } elsif($node->{type} eq "fctl") {
    $ir=node_fctl($vm,$node);

  } elsif($node->{type}=~ qr{^(?:null|term)$}) {
    # these empty nodes are used as separators
    # by some block types!
    #
    # it's safe to ignore them :D
    $ir={};
    ir_defnit($ir);

  # catch invalid
  } else {
    throw "NYI: <$node->{type}> node";
  };
  # add additional info to output
  if(! is_null($ir)) {
    # remember who you are!!
    $ir->{node_t}   = $node->{type};
    $ir->{label}  //= $node->{label};

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
    strip($ir->{meta});

    # finally, run standard checks to
    # ensure we emit valid output!
    ir_defnit($ir);
    ir_stkchk($ir);
  };
  # filter empty and give
  return (! is_null($ir) ? $ir : ());
};
sub ir_new_blk {
  my $dep  = {call=>[]};
  my @body = ();

  for(@_[1..$#_]) {
    my $ir=ir_new($_[0],$ARG);
    next if is_null($ir);

    push @{$dep->{call}},@{$ir->{dep}->{call}};
    push @body,$ir;
  };
  dupop($dep->{call});
  return ($dep,@body);
};


# ---   *   ---   *   ---
# sets defaults for node

sub ir_defnit {
  $_[0] //= {};

  $_[0]->{node_t} //= "null";
  $_[0]->{dep}    //= {call=>[]};
  $_[0]->{decl}   //= 0;
  $_[0]->{body}   //= [];
  $_[0]->{ins}    //= [];
  $_[0]->{eins}   //= [];
  $_[0]->{ctx}    //= {};
  $_[0]->{flg}    //= {};
  $_[0]->{meta}   //= null;
  $_[0]->{label}  //= null;

  return $_[0];
};


# ---   *   ---   *   ---
# translate procedures

sub node_proc {
  my ($vm,$node)=@_;

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
  vm_enter($vm,$name=>qw(exe));

  # set arguments
  my (@in,@out)=((),());
  for(@{$node->{args}}) {
    my ($t,$n,@e)=ins_rdexpr($ARG);
    vm_in($vm,$t,$n);
  };
  # set return type
  vm_out($vm,$type,$name);

  # process function body
  my ($dep,@body)=ir_new_blk(
    $vm,
    @{$node->{blk}}
  );
  # close scope and save data
  my $ctx=vm_leave($vm);

  # give IR
  my $label=vm_label_find($vm,$name);
  return {
    name => $name,
    type => $type,
    ctx  => $ctx,
    body => \@body,
    dep  => $dep,
    ins  => [
      ins_new("void",proc=>($label)),
      @in,
      @out,
    ],
    eins => [
      ins_new("void",end=>($label)),
    ],
    flg  => $flg,
  };
};


# ---   *   ---   *   ---
# translate assignments

sub node_asg {
  my ($vm,$node)=@_;
  my ($type,$name,@expr)=ins_rdnode($node,0);

  # declaring value?
  my $decl =! is_null($type);
  if($decl) {
    ($type,$name)=vm_local($vm,$type,$name);

  # ^nope, setting value
  } else {
    my $ptr=vm_var_get($vm,$name);
    ($type,$name)=($ptr->{type},$ptr->{id});
  };
  # evaluate expression! \( ^ .^)/
  my ($dep,@ins)=vm_strir(
    $vm,
    $type,
    $name,
    @expr
  );
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
  my ($vm,$node)=@_;
  my ($type,$name,@expr)=ins_rdnode($node,1);

  # valid type in this case means it's
  # a declaration without a value!
  if(! is_null($type)) {
    vm_local($vm,$type,$name);
    return null;

  # fetch the current function's type
  # when encountering a return statement
  } elsif( @expr
    &&     $expr[0]=~ qr{^(?:ret|return)$} ) {
    my $ptr=vm_var_get($vm,"-out");
    $type=($ptr ? $ptr->{type} : null);

  # lone value!
  } elsif(! is_null($name) &&! @expr) {
    @expr=($name);
  };
  # evaluate this expression...
  my ($dep,@ins)=vm_strir($vm,$type,@expr);

  # not _all_ expressions have a nested block
  # within them, but some of them do...
  my ($sdep,@body)=ir_new_blk(
    $vm,
    @{$node->{blk}},
  );
  # ^roll deps together...
  push @{$dep->{call}},@{$sdep->{call}};
  dupop($dep->{call});

  # give IR
  return {
    name => $name,
    type => $type,
    body => \@body,
    dep  => $dep,
    ins  => \@ins,
  };
};


# ---   *   ---   *   ---
# translate control flow blocks

sub node_fctl {
  my ($vm,$node)=@_;
  my $cmd=$node->{cmd};
  my $blk=$node->{blk};

  # get args for block
  my ($exprdep,@expr)=();
  while(@$blk) {
    # stop at nullterm!
    my $nd=shift @$blk;
    last if $nd->{type} eq "term";

    push @expr,$nd;
  };
  # translate block(...) expression
  ($exprdep,@expr)=ir_new_blk($vm,@expr);

  # translate inner scope of block
  my ($dep,@body)=ir_new_blk($vm,@{$node->{blk}});

  # roll deps together...
  push @{$dep->{call}},@{$exprdep->{call}};
  dupop($dep->{call});

  # generic data used to build the final
  # instruction array
  my @ins   = ();
  my @eins  = ();
  my $type  = null;
  my $tgt   = vm_label_top($vm);
  my $label = (is_null($node->{label}))
    ? vm_label_new($vm,q[@@])
    : $node->{label}
    ;
  # loop: check, then exec
  if($cmd eq "while") {
    # add the conditional
    my $dst  = $expr[-1]->{ins};
       $type = $dst->[-1]->{type};

    push @$dst,ins_new($type,if=>($label));

    # ^ and finally put the rewind after the
    #   body of this block
    $dst=(int(@body))
      ? $body[-1]->{ins}
      : \@eins
      ;
    push    @$dst,ins_new("void",rept=>($label));
    push    @eins,ins_new("void",end=>());
    unshift @body,@expr;

  # loop: exec, *then* check!
  } elsif($cmd eq "do") {
    my $dst  = $expr[-1]->{ins};
       $type = $dst->[-1]->{type};

    push @$dst,ins_new($type,crept=>($label));
    push @body,@expr;

  # break/continue
  } elsif($cmd=~ qr{^(?:break|continue)$}) {
    my $c=0;
    $cmd="rept" if $cmd eq "continue";

    # conditional or jmp target specified?
    while( int(@body)
    &&     int(@{$body[0]->{ins}}) ) {
      # get token
      my $x=$body[0]->{ins}->[-1];
      if($x->{cmd} eq "const") {
        # is the token a keyword?
        $x=$x->{args}->[0];
        if($x=~ qr{^(?:if)$}) {
          $c=1;

        # ^nope, assume it's a label
        } else {
          $tgt=vm_label_find($vm,$x);
        };
        # remove instruction
        pop @{$body[0]->{ins}};

      } else {last};
    };
    # cleanup empty nodes!
    @body=ir_filter(@body);

    # using conditional form with pre-jmp?
    if($c && int(@body)) {
      my $re   =  qr{^c};
         $cmd  =~ s[$re][];

      my $dst  =  $expr[-1]->{ins};
         $type =  $dst->[-1]->{type};

      push @$dst,ins_new($type,if=>($label));

      $dst=$body[-1]->{ins};
      push @$dst,ins_new("void",$cmd=>($tgt));
      push @eins,ins_new("void",end=>());

    # ^nope, straight jmp!
    } else {
      $cmd="c$cmd" if $c;
      my $dst=(int(@body))
        ? $body[-1]->{ins}
        : (int(@expr))
          ? $expr[-1]->{ins}
          : \@eins
        ;
      push @$dst,ins_new("void",$cmd=>($tgt));
    };
    unshift @body,@expr;

  # switch! \( ^ .^)/
  } elsif($cmd eq "switch") {
    # F to get case value
    my $vfn=sub {
      my $re =  qr{^case_};
      my $v  =  $_[0]->{label}->{name};
         $v  =~ s[$re][];

      return $v;
    };
    # the cases themselves
    my @case=grep {! is_null($ARG->{label})} @body;

    # inside a switch, nodes that do not fall
    # under a label are executed first;
    # weird, yes, but nevertheless legal ;>
    @body=grep {is_null($ARG->{label})} @body;

    # sanity check each case AND handle
    # breaking out of switch
    for(@case) {
      my @Q   = @{$ARG->{body}};
      my $own = $ARG->{label};

      $ARG->{meta}="";

      ++$own->{skip}->{cnt};

      while(@Q) {
        my $nd=pop @Q;

        $nd->{meta}=""
        if $nd->{meta} eq "break";

        my ($br)=(
          grep {$ARG->{cmd} eq "break"}
          @{$nd->{ins}}
        );
        if( defined $br
        &&  $br->{args}->[0] eq $own ) {
          $br->{args}->[0]=$label;
          ++$label->{skip}->{cnt};
        };
        unshift @Q,@{$nd->{body}};
      };
    };
    # pick default case
    my ($default)=grep {
      $vfn->($ARG) eq "default"
    } @case;
    # get sorted case values
    my @value=(
      sort { $a->{v} <=> $b->{v} }
      map  { {i=>$ARG,v=>$vfn->($case[$ARG])} }
      grep {
        (defined $default)
          ? $case[$ARG] ne $default
          : 1
          ;
      } 0..$#case
    );
    # now build jump table indices...
    my @tab=();
    my $min=$value[0]->{v};
    my $max=$value[-1]->{v};
    $ARG->{v} -= $min for @value;

    my $sz=($max-$min)+1;
    if($sz <= 0x100) {
      # map value to idex, then do
      # a bounded memory read...
      my $dst  = $expr[-1]->{ins};
         $type = $dst->[-1]->{type};

      my $tmp  = "$label->{name}_tmp";

      push @$dst,(
        ins_new($type,const=>($min)),
        ins_new($type,sub=>()),
      );
      $expr[-1]->{meta}=(
        "(map `$expr[-1]->{meta}` to "
      . "jmptab idex)"
      );

    } else {
      # we'd have to run a binary search for
      # this, so lets hold up until we can
      # write the algo using the compiler ;>
      throw "ir: jump table size > 0x100 "
      .     "not yet implemented";
    };
    # make the jump table!
    my $jmptab=ir_defnit();
    $jmptab->{label}  = vm_label_new($vm,q[@@]);
    $jmptab->{meta}   = "(jmptab)";
    $jmptab->{node_t} = "fctl";

    # map [idex => label]
    unshift @case,{label=>$jmptab->{label}};
    @tab=(($label) x $sz);
    for my $i(0..$#value) {
      my $x=$value[$i]->{v};
      my $y=$case[$value[$i]->{i}]->{label};
      $tab[$x]=$y;
    };
    shift @case;
    push  @tab,(defined $default)
      ? $default->{label}
      : $label
      ;
    my $jmptab_inner=ir_defnit();
    $jmptab_inner->{ins}=[
      ins_new("void",jmptab=>(@tab)),
    ];
    $jmptab->{body}=[@expr,$jmptab_inner];
    ++$jmptab->{label}->{skip}->{cnt};

    # nest the blocks, with the table at the end
    my $anchor=$body[-1];
    for my $nd(reverse @case) {
      if(@{$nd->{ins}}) {
        my $tmp=ir_defnit();
        $tmp->{node_t} = $nd->{node_t};
        $tmp->{ins}    = $nd->{ins};
        $tmp->{eins}   = $nd->{eins};
        $tmp->{meta}   = $nd->{meta};
        $nd->{ins}     = [];
        $nd->{eins}    = [];
        $nd->{meta}    = "";
        unshift @{$nd->{body}},$tmp;
      };
      unshift @{$anchor->{body}},$nd;
      $anchor=$nd;
    };
    unshift @{$anchor->{body}},$jmptab

  # C FOR!! /( ~; .;~)\
  } elsif($cmd eq "for") {
    throw "ir: C-style 'for' must have three "
    .     "sub-expressions (init;chk;update)"

    if    int(@expr) != 3;

    my ($init,$chk,$update)=@expr;

    # condition...
    $type=$chk->{ins}->[-1]->{type};
    push @{$chk->{ins}},ins_new($type,if=>($label));

    # update goes at the end of body
    push @{$update->{ins}},
      ins_new("void",rept=>($label));

    @body=($init,$chk,@body,$update);

    # end wrapper
    push @eins,ins_new("void",end=>());

  # conditionals have some commonalities...
  } elsif($cmd=~ qr{^(?:if|eif|else)$}) {
    # we want to get the type of the value
    # being evaluated...
    my @have=map {@{$ARG->{ins}}} @expr;
    ($type)=(
      map     {$ARG->{type}}
      grep    {! is_null($ARG->{type})}
      reverse @have
    );
    # straight conditional is just a wrapper
    if($cmd eq "if") {
      # (expression) plus (if) on start...
      push @ins,@have;
      push @ins,ins_new($type,if=>($label));

      # ^and then close it
      push @eins,ins_new("void",end=>());

    # "else if" is less straightforward...
    } elsif($cmd eq "eif") {
      # first we add an "else" to force the
      # previous "end" to be relocated
      push @ins,ins_new("void",else=>($label));

      # ^and *then* (expression) plus (if)
      push @ins,@have;
      push @ins,ins_new($type,if=>($label));

    # as mentioned before, the original "end"
    # gets relocated to close the "else" instead
    # of the original "if"
    #
    # that's why we don't add another closer here!
    } else {
      push @ins,ins_new("void",else=>($label));
      push @ins,@have;
    };

  # not yet implemented...
  } else {
    throw "NYI: <$cmd> fctl-node";
  };
  # give IR
  return {
    name => vm_label_str($vm,$label),
    type => $type,
    body => \@body,
    dep  => $dep,
    ins  => \@ins,
    eins => \@eins,

    ($label->{skip}->{cnt})
      ? (label=>$label)
      : ()
      ,
  };
};


# ---   *   ---   *   ---
# performs basic correctness check
# on the generated instructions

sub ir_stkchk {
  my ($ir,$stk,$var)=@_;
  $stk //= [];
  $var //= {};

  return (
    ir_stkchk_impl($ir->{ins},$stk,$var),
    ir_stkchk_impl($ir->{eins},$stk,$var),
  );
};
sub ir_stkchk_impl {
  my ($ar,$stk,$var)=@_;
  $stk //= [];
  $var //= {};

  # walk the instruction list...
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
        $var->{$tgt} //= [];
        push @{$var->{$tgt}},$i;

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
          my $j=shift @{$var->{$tgt}};

#          $ar->[$j]=undef
#          if! int(@{$var->{$tgt}});
        };

      # finally, we unmark the value when
      # it is consumed!
      } elsif($take && exists $var->{$tgt}) {
        shift @{$var->{$tgt}};
        delete $var->{$tgt}
        if! int(@{$var->{$tgt}});
      };
    };
    # validate the stack
    #
    # we get instruction data again, as the
    # previous block might modify it!
    my $err=ir_stkchk_take($ins,$stk,$var);
    if(! is_null($err)) {
      throw "ir-stkchk: $err at "
      .     "<" . ins_prich($ins) . ">";
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
  my ($ins,$stk,$var)=@_;
  my $take=ins_argcnt($ins->{cmd});
  while($take) {
    # fail if instruction required a
    # value on the stack, but there is no value!
    my $other=pop @$stk;
    return "empty stack" if! $other;

    # fail if instruction required a value
    # of a specific width, but there is
    # a mismatch!
    my ($a,$b)=($ins->{type},$other->{type});
    my ($x,$y)=(sizeof($a),sizeof($b));
    if($x != $y) {
      # we make an exception to the above rule in
      # cases where the "faulty" width is due to
      # one of the values being a pointer...
      #
      # IF the dereferenced width is equal to the
      # required one, then we don't throw the
      # type mismatch error
      if(is_ptr($a) &&! is_ptr($b)) {
        $x=sizeof(derefof($a));

      } elsif(is_ptr($b) &&! is_ptr($a)) {
        $y=sizeof(derefof($b));
      };
    };
    return "type mismatch" if $x != $y;
    --$take;
  };
  return;
};


# ---   *   ---   *   ---
# gives flattened array of instructions

sub ir_flat {
  return map {
    my @inner=(
      @{$ARG->{body}},
    );(
      @{$ARG->{ins}},
      (map {ir_flat($ARG)} @inner),
      @{$ARG->{eins}},
    );
  } @_;
};


# ---   *   ---   *   ---
# dbout

sub ir_prich {
  state $depth=0;
  my ($ir,%O)=@_;
  my $out=io_procin(\%O);

  push @$out,ir_prich_meta($ARG,$depth);

  ins_prich($ARG,%O,mute=>1,dr=>\$depth,type=>1)
  for @{$ARG->{ins}};

  ir_prich($ARG,%O,mute=>1) for @{$ARG->{body}};
  push @$out,"\n" if @{$ARG->{eins}};

  ins_prich($ARG,%O,mute=>1,dr=>\$depth,type=>1)
  for @{$ARG->{eins}};

  return io_procout(\%O);
};
sub ir_prich_meta {
  my ($ir,$depth)=@_;
  return (! is_null($ir->{meta}))
    ? "\n" . ("  " x $depth) . "; $ir->{meta}\n"
    : ()
    ;
};


# ---   *   ---   *   ---
1; # ret
