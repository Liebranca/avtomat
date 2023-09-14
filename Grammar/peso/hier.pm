#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO HIER(-archicals)
# Determination of context
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::hier;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::Re;
  use Arstd::IO;
  use Arstd::PM;

  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Grammar;
  use Grammar::peso::std;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw($PE_HIER);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.9;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # beqs
  $PE_STD->use_common();
  $PE_STD->use_eye();
  $PE_STD->use_wed();

  # class attrs
  fvars(

    'Grammar::peso::common',

    -cclan   => 'non',
    -creg    => undef,
    -crom    => undef,
    -cproc   => undef,
    -cblk    => undef,

    -chier_t => 'clan',
    -chier_n => 'non',

    -cdecl   => [],

    -seg_t   => $NULLSTR,

  );

  Readonly our $PE_HIER=>
    'Grammar::peso::hier';

  Readonly my $PE_HIER_KEY=>[qw(
    clan reg rom proc blk

  )];

  Readonly my $PE_HIER_CKEY=>[map {
    "-c$ARG"

  } @$PE_HIER_KEY];

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    q[ellipses]  => qr{\x{20}*\.\.\.\s*;\n?},

    q[hier-key]  => re_pekey(@$PE_HIER_KEY),
    q[nhier-key] => re_npekey(@$PE_HIER_KEY),

    q[beq-key]   => re_pekey(qw(beq)),

  };

# ---   *   ---   *   ---
# parser rules

  rule('~<hier-key>');
  rule('$<hier> hier-key nterm term');

  rule('~<nhier-key>');
  rule('$<nhier> nhier-key nterm term');

  rule('~<beq-key>');
  rule('$<beq> beq-key nterm term');

# ---   *   ---   *   ---
# ^post-parse

sub hier($self,$branch) {

  # unpack
  my ($type,$name)=
    $self->rd_name_nterm($branch);

  $type=lc $type;


  # ^repack
  $branch->clear();

  $branch->{value}=$type;
  $branch->init($name->[0]->get());

};

# ---   *   ---   *   ---
# forks accto hierarchical type

sub hier_ctx($self,$branch) {

  # initialize block
  $self->hier_sort($branch);

  # reset path
  my @path=$self->hier_path($branch);
  $self->hier_flags_nit($branch);

  # ^save pointer to branch
  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  @path=grep {$ARG ne '$DEF'} @path;
  $scope->decl_branch($branch,@path);

};

# ---   *   ---   *   ---
# alters current path when
# stepping on a hierarchical

sub hier_path($self,$branch) {

  # get ctx
  my $f    = $self->{frame};
  my $st   = $branch->{value};


  my $name = $st->{name};
  my $type = $st->{type};


  # get fields to clear
  my @unset=qw(-cblk);

  if($type eq 'clan') {
    push @unset,qw(-creg -crom -cproc);

  } elsif($type eq 'reg') {
    push @unset,qw(-crom -cproc);

  } elsif($type eq 'rom') {
    push @unset,qw(-creg -cproc);

  };

  # ^clear
  map {$f->{$ARG}=undef} @unset;

  # ^reset ctx
  my $ckey="-c$type";
  $f->{-chier_t} = $type;
  $f->{-chier_n} = $name;
  $f->{$ckey}    = $name;


  # ^reuse pre-calc'd path
  if(@{$st->{opath}}) {

    my $cpath=$st->{cpath};

    map  {
      $f->{$ARG}=$cpath->{$ARG};

    } @$PE_HIER_CKEY;

  };


  # ^filter out cleared
  my @path=grep {$ARG} map {
    $f->{$ARG}

  } @$PE_HIER_CKEY;


  # ^reset path
  my $mach  = $self->{mach};
  my $scope = $mach->{scope};
  my $x86   = $mach->{x86_64};

  $scope->path(@path);
  $x86->set_blk(join q[::],@path);


  return @path;

};

# ---   *   ---   *   ---
# get children nodes of a hierarchical
# performs parenting

sub hier_sort($self,$branch) {

  # nodes already sorted
  return if is_hashref($branch->{value});

  # ^nope, perform for whole tree
  my $root=$self->{p3};


  # walk node types
  map {

    my $type = $ARG;
    my @ar   = $root->branches_in(qr{^$type$});

    # ^get stop pattern
    my $re=$self->hier_typere($type);

    # ^walk all nodes of type
    map {

      # get child nodes and push
      my @out=$ARG->match_up_to($re);
      $ARG->pushlv(@out);

    } @ar;

  } qw(clan reg rom proc blk);


  # ^repeat to nit sorted
  map {

    my $type = $ARG;
    my @ar   = $root->branches_in(qr{^$type$});

    map {$self->hier_pack($ARG)} @ar;

  } qw(clan reg rom proc blk);

};

# ---   *   ---   *   ---
# ^get hierarchical types
# a node may not be a parent of

sub hier_typere($self,$type) {

  state $is_data=qr{^(?:reg|rom)$};


  my $out=$ANY_MATCH;

  if($type eq 'clan') {
    $out=qr{^clan$};

  } elsif($type=~ $is_data) {
    $out=qr{^(?:clan|reg|rom)$};

  } elsif($type eq 'proc') {
    $out=qr{^(?:clan|reg|rom|proc)$};

  } else {
    $out=qr{^(?:clan|reg|rom|proc|blk)$};

  };


  return $out;

};

# ---   *   ---   *   ---
# ^packs node value as hash
# once sorting is done

sub hier_pack($self,$branch) {

  my $name=$branch->leaf_value(0);
  my $type=$branch->{value};

  my $st={

    type    => $type,
    attr    => {},

    name    => $name,
    body    => $NULLSTR,

    beqs    => [],
    from    => [],
    flptr   => {},

    in      => [],
    out     => [],
    stk     => [],

    stktab  => {},

    prin    => [],
    prout   => [],
    prstk   => [],

    procs   => [],

    opath   => [],
    cpath   => {},

    oidex   => $branch->{idex},

  };

  $branch->{value}=$st;
  $branch->{leaves}->[0]->discard();

};

# ---   *   ---   *   ---
# ^"overly complicated" way
# of (lit) registering
# all values used by block

sub hier_stktab_set($self,$branch,$value) {

  my $st    = $branch->{value};

  my $tab   = $st->{stktab};
  my $stk   = $st->{stk};

  my $id    = $value->data_id($self,1);


  # ^add non-registered
  if(

      $value->{id}

  &&! $value->{const}
  &&! exists $tab->{$id}

  ) {

#    # recurse to decompose ops
#    if($value->{type} eq 'ops') {
#
#      map {
#        $self->hier_stktab_set($branch,$ARG)
#
#      } @{$value->{V}};
#
#    };

    # ^write top-level
    $tab->{$id}=$value;
    push @$stk,$value;

  };

};

# ---   *   ---   *   ---
# make flag fields for
# current scope

sub hier_flags_nit($self,$branch) {

  my $st    = $branch->{value};
  my $ptr   = $st->{flptr};

  my $mach  = $self->{mach};
  my $flags = $self->flags_default();


  # bind to scope
  # save ptrs in branch
  map {

    my $value=$flags->{$ARG};

    $ptr->{$ARG}=$mach->decl(
      num=>$ARG,raw=>$value

    );

  } keys %$flags;

};

# ---   *   ---   *   ---
# ^sets defaults on walk

sub hier_flags($self,$branch) {

  my $st    = $branch->{value};
  my $ptr   = $st->{flptr};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};
  my @path  = $scope->path();

  my $flags = $self->flags_default();


  # ^resets values
  map {
    my $value=$flags->{$ARG};
    ${$ptr->{$ARG}}->set($value);

  } keys %$ptr;

};

# ---   *   ---   *   ---
# further sorting

sub hier_cl($self,$branch) {
  $self->hier_walk($branch);
  $self->hier_vars($branch);

};

# ---   *   ---   *   ---
# ^get implicit values accto type

sub hier_vars($self,$branch) {

  my $f     = $self->{frame};
  my $st    = $branch->{value};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  $st->{opath}=[$scope->path()];
  $st->{cpath}={map {
    $ARG=>$f->{$ARG}

  } @$PE_HIER_CKEY};


  # get class methods
  if($st->{type} eq 'reg') {

    my $procs={map {

      my $nst=$ARG->{value};

      $nst->{name} => sub ($o,@args) {

        my $path=join q[::],
          @{$st->{opath}},
          $nst->{name}
        ;

        $self->run_branch(
          $path,$o,@args,

        );

      };

    } grep {
      my $nst=$ARG->{value};
      $nst->{type} eq 'proc';

    } @{$branch->{leaves}} };

    $st->{procs}=$procs;


  # ^add implicit args for methods
  } elsif($st->{type} eq 'proc') {

    my $par  = $branch->{parent};
    my $pst  = $par->{value};

    if($pst->{type} eq 'reg') {

      my $type = join q[::],
        @{$pst->{opath}};

      $st->{body}=
        "  in $type self;\n"
      . $st->{body}
      ;

    };

  };

};

# ---   *   ---   *   ---
# kick aramaic helper

sub hier_x86_nit($self,$branch) {

  $self->hier_walk($branch);

  my $st    = $branch->{value};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};
  my $x86   = $mach->{x86_64};

  my @path  = $scope->path();

  # register scope
  $x86->new_blk(

    (join q[::],@path),

    arg=>$st->{in},
    stk=>$st->{stk},
    ret=>$st->{out},

  );

  # ^recurse
  map {
    $self->hier_x86_nit($ARG)

  } $self->hier_filt($branch);

};

# ---   *   ---   *   ---
# filters out non-hier nodes
# from leaves

sub hier_filt($self,$branch) {

  my $re=$REGEX->{q[hier-key]};

  return grep {

     exists $ARG->{value}
  && is_hashref($ARG->{value})

  && exists $ARG->{value}->{type}

  && $ARG->{value}->{type}=~ $re

  } @{$branch->{leaves}};

};

# ---   *   ---   *   ---
# step-on

sub hier_walk($self,$branch) {
  my @path=$self->hier_path($branch);
  $self->hier_flags($branch);

  return @path;

};

sub hier_run($self,$branch) {

  $self->hier_save($branch);
  $self->hier_walk($branch);

  my $mach=$self->{mach};

  # get input binds
  my $st=$branch->{value};
  my $in=$st->{in};


  # get passed inputs
  my @stk=$mach->get_args();

  throw_overargs($st,int @stk)
  if @stk > @$in;

  # ^reset
  map {
    ${$in->[$ARG]}->set($stk[$ARG]);

  } 0..$#stk;

};

# ---   *   ---   *   ---
# ^errme

sub throw_overargs($st,$cnt) {

  my $diff=$cnt - @{$st->{in}};
  my $path=join q[::],@{$st->{opath}};


  errout(

    q[(:%u) extra argument(s) for blk ]
  . q[[goodtag]:%s],

    lvl   => $AR_FATAL,
    args  => [$diff,$path]

  );

};

# ---   *   ---   *   ---
# stores current stack frame

sub hier_stk_save($self,$dst,$src) {

  push @$dst,[];
  my $old=$dst->[-1];

  map {push @$old,$$ARG->get()} @$src;

};

# ---   *   ---   *   ---
# ^bat

sub hier_save($self,$branch) {

  my $st    = $branch->{value};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};


  # remember origin path
  push @{$st->{from}},[$scope->path()];

  # ^remember state
  map {

    my $dst=$st->{"pr$ARG"};
    my $src=$st->{$ARG};

    $self->hier_stk_save($dst,$src);

  } qw(in out stk);

};

# ---   *   ---   *   ---
# ^restores

sub hier_stk_load($self,$dst,$src) {

  my $old=pop @$src;
  my @out=map {$$ARG->rget()} @$dst;

  map {$$ARG->set(pop @$old)} @$dst;


  return $out[0];

};

# ---   *   ---   *   ---
# ^bat

sub hier_load($self,$branch) {

  my $st    = $branch->{value};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};


  # restore origin path
  my $path=pop @{$st->{from}};
  $scope->path(@$path);

  # ^restore state
  map {

    my $src=$st->{"pr$ARG"};
    my $dst=$st->{$ARG};

    $self->hier_stk_load($dst,$src);

  } qw(in stk);


  # ^give output
  my $src=$st->{prout};
  my $dst=$st->{out};

  return $self->hier_stk_load($dst,$src);

};

# ---   *   ---   *   ---
# end of block

sub ret_run($self,$branch) {
  my $par=$branch->{parent};
  return $self->hier_load($par);

};

# ---   *   ---   *   ---
# ^adds at bottom of branch

sub ret_add($self,$branch) {

  my $ret=$branch->init('ret');

  $ret->fork_chain(

    dom  => ref $self,
    name => 'ret',

    skip => $self->num_passes(),

  );

};

# ---   *   ---   *   ---
# post parse for anything
# that is NOT a hierarchical

sub nhier($self,$branch) {

  my $body=join $NULLSTR,
    $branch->leafless_values();

  $branch->{value}="  $body;\n";
  $branch->clear();

};

# ---   *   ---   *   ---
# ^cat contents to parent

sub nhier_ctx($self,$branch) {

  my $body = $branch->{value};

  my $par  = $branch->{parent};
  my $st   = $par->{value};

  $st->{body} .= $body;

  $branch->discard();

};

# ---   *   ---   *   ---
# post-parse inheritor

sub beq($self,$branch) {

  # unpack
  my ($type,$name)=
    $self->rd_name_nterm($branch);

  $type=lc $type;


  # ^repack
  $branch->{value}={
    type=>$type,
    name=>$name->[0]->get(),

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^bind

sub beq_ctx($self,$branch) {

  my $st  = $branch->{value};

  my $par = $branch->{parent};
  my $pst = $par->{value};

  push @{$pst->{beqs}},$st->{name};

  $branch->discard();

};

# ---   *   ---   *   ---
# outs asm codestr

sub hier_fasm_xlate($self,$branch) {

  my $st    = $branch->{value};

  my $type  = $st->{type};
  my $attr  = $st->{attr};


  # get segment type
  my $f     = $self->{frame};
  my $seg_t = \$f->{-seg_t};
  my $hed   = $NULLSTR;

  # ^readable exectuable
  if($type   eq 'proc'
  && $$seg_t ne 'rx') {

    $hed    = "segment readable executable\n";
    $$seg_t = 'rx';


  # ^readable
  } elsif(
     $type   eq 'rom'
  && $$seg_t ne 'r') {

    $hed    = "segment readable\n";
    $$seg_t = 'r';

  # ^readable writeable
  } elsif(
     $type   eq 'reg'
  && $$seg_t ne 'rw'

  && $attr->{static}

  ) {

    $hed    = "segment readable writeable\n";
    $$seg_t = 'rw';

  };

  $hed.='align $10';


  # step-on
  my @path = $self->hier_walk($branch);
  my @out  = ();


  # get label name
  if($type ne 'clan') {
    shift @path;
    $path[0]=".$path[0]";

  };

  my $name = join '_',@path;


# DEPRECATED in favor of mach->{x86_64}
#
#  # add stack frame for procs
#  if($type eq 'proc') {
#
#    push @out,
#
#      q[  push rbp],
#      q[  mov  rbp,rsp],
#
#      "  sub  rsp,$st->{stkoff}",
#
#    if $st->{stkoff};
#
#  };

  $branch->{fasm_xlate}=join "\n",

    "\n; ---   *   ---   *   ---\n",
    $hed,

    "$name:",
    @out,

    "\n"

  ;

};

# ---   *   ---   *   ---
# ^ret

sub ret_fasm_xlate($self,$branch) {

  my $st  = $branch->{parent}->{value};
  my @out = ($st->{stkoff})
    ? qw(leave ret)
    : qw(ret)
    ;

  $branch->{fasm_xlate}=join "\n",@out,"\n"
  if $st->{type} eq 'proc';

};

# ---   *   ---   *   ---
# crux

sub recurse($class,$branch,%O) {

  my $s=(Tree::Grammar->is_valid($branch))
    ? $branch->{value}
    : $branch
    ;

  my $ice = $class->parse($s,%O);
  my @top = $ice->{p3}->pluck_all();

  return @top;

};

# ---   *   ---   *   ---
# find all blocks of type
# within a hierarchy

sub hier_search($self,$branch,@types) {

  my $out     = {map {$ARG=>[]} @types};
  my @pending = ($branch);


  # ^walk branch
  while(@pending) {

    my $nd=shift @pending;
    my $st=$nd->{value};

    # type-chk node
    if(is_hashref($st) && exists $st->{type}) {

      map {

        my $type=$types[$ARG];

        push @{$out->{$type}},$nd
        if $st->{type} eq $type;

      } 0..$#types;

    };

    # ^go next
    unshift @pending,@{$nd->{leaves}};

  };


  return $out;

};

# ---   *   ---   *   ---
# perform inheritance

sub hier_beq($self,$branch) {

  $self->hier_walk($branch);

  my $st    = $branch->{value};
  my $beqs  = $st->{beqs};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $tab   = {};

  # expand path::to and make search
  my @cpy=map {

    # locate inherited block
    my $path = $ARG;
    my $src  = $scope->cderef_branch(
      0,\$path

    );

    # ^validate
    throw_beqpath($ARG) if ! $src;

    my ($a,$b)=(
      $$src->{value}->{type},
      $st->{type},

    );

    throw_beqtype($ARG,$a,$b) if $a ne $b;


    # store [type=>[nodes]]
    my $cpy=$$src->dup();
    my $bst=$cpy->{value};

    $tab->{$bst->{type}} //= [];

    my $ar=$tab->{$bst->{type}};
    push @$ar,$cpy;

    # merge node contents
    $self->hier_beq_replcat(
      $branch,$cpy

    );

    $cpy;

  } @$beqs;


  # get current nodes
  my $local=$self->hier_search(
    $branch,@$PE_HIER_KEY

  );

  # ^get full list of inherited
  my @extern=map {

    $self->hier_beq_expand(
      $tab,$ARG

    )

  } @$PE_HIER_KEY;

  # ^flatten
  map {

    my $h=$ARG;

    map {
      push @{$tab->{$ARG}},@{$h->{$ARG}};

    } keys %$h;

  } @extern;


  # ^walk inherited
  map {

    my $type=$ARG;

    $self->hier_beq_array_merge(
      $local,$tab,$type

    );

  } @$PE_HIER_KEY;


  $branch->rec_hvarsort(qw(value oidex));

};

# ---   *   ---   *   ---
# ^errme for blk not found

sub throw_beqpath($path) {

  errout(

    q[Block [err]:%s not found in scope],

    lvl  => $AR_FATAL,
    args => [$path],

  );

};

# ---   *   ---   *   ---
# ^errme for type mismatch

sub throw_beqtype($path,$a,$b) {

  errout(

    q[Block of type [good]:%s ]
  . q[cannot inherit [err]:%s of type [err]:%s],

    lvl  => $AR_FATAL,
    args => [$b,$path,$a],

  );

};

# ---   *   ---   *   ---
# ^recursively mine beq'd

sub hier_beq_expand($self,$extern,$type) {

  return map {

    # get inherited nodes
    my $src   = $ARG;
    my $entry = $self->hier_search(
      $src,@$PE_HIER_KEY

    );

    # filter out base node
    map {

      @{$entry->{$ARG}}=grep {
        $ARG ne $src

      } @{$entry->{$ARG}}

    } keys %$entry;

    # ^pop base from result
    $extern->{$type}=[];
    $entry;

  } @{$extern->{$type}};

};

# ---   *   ---   *   ---
# merges nodes with matching
# name and type

sub hier_beq_merge(

  $self,

  $src_nd,$local,
  $type

) {

  # get nodes with matching
  # name and type
  my $src    = $src_nd->{value};
  my @match  = grep {

    my $dst_nd = $ARG;
    my $dst    = $dst_nd->{value};

    $src->{name} eq $dst->{name};

  } @{$local->{$type}};


  # ^merge
  map {

    my $dst_nd=$ARG;

    $self->hier_beq_replcat($dst_nd,$src_nd);
    $src_nd->discard();

  } @match;


  # ^filter out merged
  return (! @match)
    ? ($src_nd)
    : ()
    ;

};

# ---   *   ---   *   ---
# ^bat

sub hier_beq_array_merge(

  $self,

  $local,$extern,
  $type

) {

  my $i=0;

  # merge all nodes of type
  map {

    my @out=$self->hier_beq_merge(
      $ARG,$local,$type

    );

    $extern->{$type}->[$i]=undef
    if ! @out;

    $i++;


  } @{$extern->{$type}};


  # ^filter out merged from table
  my @rem=@{$extern->{$type}}=grep {
    defined $ARG

  } @{$extern->{$type}};


  # ^push leftovers
  my $dst=$local->{$type}->[0];
  if($dst) {
    $dst->{parent}->pushlv(@rem);

  };

};

# ---   *   ---   *   ---
# repls '...' or cats the
# bodies of two blocks

sub hier_beq_replcat($self,$dst_nd,$src_nd) {

  my $dst=$dst_nd->{value};
  my $src=$src_nd->{value};

  my ($a,$b)=(
    $src->{body},
    $dst->{body},

  );

  my $re=$REGEX->{ellipses};

  # repl '...' with codestr
  if($a=~ $re) {
    $a=~ s[$re][$b];
    $dst->{body}=$a;

  # ^simply cat
  } else {
    $dst->{body}="$a$b";

  };

};

# ---   *   ---   *   ---
# template: walk hierarchy
# and apply some F to body

sub _temple_branch_fn($self,$branch,$fn) {

  my @pending=($branch);

  while(@pending) {

    my $nd=shift @pending;
    my $st=$nd->{value};

    next if $st eq 'ret';

    unshift @pending,@{$nd->{leaves}};

    $self->hier_walk($nd);
    $st->{body}=$fn->($self,$nd);

  };

};

# ---   *   ---   *   ---
# ^ice of, call recurse

sub branch_recurse($self,$branch,$o,@args) {

  my $fn=sub ($self2,$branch2) {

    my $st=$branch2->{value};

    return $o->recurse(

      $st->{body},
      @args,

      mach       => $self->{mach},
      frame_vars => $self->get_fvars(),

    );

  };

  $self->_temple_branch_fn($branch,$fn);

};

# ---   *   ---   *   ---
# ^parser

sub branch_parse($self,$branch,$ice) {

  my $fn=sub ($self2,$branch2) {

    my $st  = $branch2->{value};
    my $out = $ice->parse($st->{body});


    # ^fuse trees
    my @lv  = $ice->{p3}->pluck_all();

    $branch2->insertlv(0,@lv);
    $self2->ret_add($branch2);


    return $out->{sremain};

  };


  $self->_temple_branch_fn($branch,$fn);

};

# ---   *   ---   *   ---
# debug out

sub hier_prich($self,$branch) {

  my @pending=($branch);

  while(@pending) {

    my $nd=shift @pending;

    say

      $nd->{value}->{type},q[ ],
      $nd->{value}->{name},q[;]

    ;

    say $nd->{value}->{body};

    unshift @pending,@{$nd->{leaves}};

  };

};

# ---   *   ---   *   ---
# get currently looking at ROM sec

sub inside_ROM($self) {

  my $f=$self->{frame};

  return
      defined $f->{-crom}
  &&! defined $f->{-cproc}
  ;

};

# ---   *   ---   *   ---
# ^current statement is a decl

sub inside_decl($self) {
  my $f=$self->{frame};
  return defined $f->{-cdecl}->[-1];

};

# ---   *   ---   *   ---
# make a parser tree

  our @CORE=qw(hier beq nhier);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
