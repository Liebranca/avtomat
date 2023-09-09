#!/usr/bin/perl
# ---   *   ---   *   ---
# Grammar
# Halfway mimics p6's
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Tree::Grammar;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::IO;
  use Tree::Exec;

  use parent 'Tree';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.02.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# constructor

sub nit($class,$frame,%O) {

  # defaults
  $O{fn}    //= $NOOP;
  $O{pfn}   //= $NOOP;

  $O{hier}  //= 0;
  $O{opt}   //= 0;
  $O{alt}   //= 0;
  $O{greed} //= 0;
  $O{max}   //= 0;

  $O{xlate} //= {};

  # get ice
  my $self=Tree::nit(

    $class,
    $frame,

    $O{parent},
    $O{value},

    %O

  );


  # setup post-match actions
  $self->{fn}    = $O{fn};
  $self->{pfn}   = $O{pfn};
  $self->{hier}  = $O{hier};
  $self->{opt}   = $O{opt};
  $self->{alt}   = $O{alt};
  $self->{greed} = $O{greed};
  $self->{max}   = $O{max};

  $self->{chain} = $O{chain};
  $self->{xlate} = $O{xlate};

  if(

     $self->{parent}
  && $self->{parent}->has_flag('alt')

  ) {$self->{hier}=1};

  return $self;

};

# ---   *   ---   *   ---
# ^from instance

sub init($self,$x,%O) {

  $O{parent}//=$self;

  return $self->{frame}->nit(value=>$x,%O);

};

# ---   *   ---   *   ---
# clones a node

sub dup($self) {

  my $out     = undef;

  my @anchor  = ();
  my @pending = ($self);

  while(@pending) {

    my $nd=shift @pending;

    my $cpy=$nd->{frame}->nit(

      value  => $nd->{value},
      fn     => $nd->{fn},
      pfn    => $nd->{pfn},
      opt    => $nd->{opt},
      greed  => $nd->{greed},
      max    => $nd->{max},
      alt    => $nd->{alt},

      chain  => [@{$nd->{chain}}],
      xlate  => {%{$nd->{xlate}}},

      parent => (@anchor)
        ? (shift @anchor)
        : $out
        ,

    );

    $out//=$cpy;

    unshift @anchor,$cpy;
    unshift @pending,@{$nd->{leaves}};

  };

  return $out;

};

# ---   *   ---   *   ---
# remove branch if it's not root

sub purge($self) {
  $self->{parent}->pluck($self)
  if $self->{parent};

};

# ---   *   ---   *   ---
# get next fn in queue

sub shift_chain($self,@chain) {

  # default to old
  $self->{chain}//=[];
  @chain=@{$self->{chain}}
  if ! @chain;

  $self->{pfn}   = $self->{fn};
  $self->{fn}    = undef;
  $self->{chain} = [@chain];

  $self->{fn}=shift @{
    $self->{chain}

  };

  $self->{fn}//=$NOOP;

};

# ---   *   ---   *   ---
# ^whole branch, no reasg

sub shift_branch($self,%O) {

  state $xlate_re=qr{^[0-1]$}x;

  # defaults
  $O{keepx}  //= 0;
  $O{frame}  //= Tree::Exec->get_frame();

  # ^target lang for translation passed
  # rather than an actual chain shift
  my $xlate=! ($O{keepx}=~ $xlate_re);


  my $dst     = undef;
  my @pending = ($self);


  # walk the tree
  while(@pending) {

    my $nd=shift @pending;


    # signal to go up one level
    if(! $nd) {

      $dst=$dst->{parent}

      if defined $dst
      && defined $dst->{parent};

      next;

    };

    # ^get F to assoc with branch
    my $fn=($xlate)
      ? $nd->{xlate}->{$O{keepx}}
      : $nd->{fn}
      ;

    # ^skip blank methods
    if($fn && $fn ne $NOOP) {

      $dst=$O{frame}->nit(
        $dst,$fn,$nd

      );

      $nd->{xbranch}=$dst;

    };


    # ^go to next pass when not
    # executing or translating
    $nd->shift_chain()
    if ! $O{keepx} &&! $xlate;


    # get next node
    unshift @pending,@{$nd->{leaves}},0;

  };


  # give top of hierarchy
  my ($out)=(defined $dst)
    ? $dst->root()
    : undef
    ;

  return $out;

};

# ---   *   ---   *   ---
# for modifying the callstack
# from within a post-parse proc

sub fork_chain($self,%O) {

  # get ctx
  my ($root) = $self->root();
  my $ctx    = $root->{ctx};
  my $class  = $ctx->{frame}->{-class};

  # defaults
  $O{dom}  //= $class;
  $O{name} //= $self->{value};
  $O{skip} //= 0;


  # ^get coderefs
  $class->fnbreak(\%O);
  $self->{chain} = [@{ $O{chain} }];
  $self->{xlate} = {%{ $O{xlate} }};
  $self->{fn}    = $O{fn};


  # discard previous passes
  map {$self->shift_chain()} 0..$O{skip}-1;

  # exec fn for current pass
  $self->{fn}->($ctx,$self)
  if $self->{fn} ne $NOOP;

  $self->shift_chain() if $O{skip} > 0;

};

# ---   *   ---   *   ---
# recursively clears children
# that do not have pending
# procs in callstack

sub clear_nproc($self) {

  map {

    my $par   = $ARG->{parent};
    my $chain = $ARG->{chain};

    if($par) {

      my @has=grep {$ARG ne $NOOP} @$chain;

      unshift @has,$ARG->{fn}

      if $ARG->{fn}
      && $ARG->{fn} ne $NOOP
      ;

      $par->pluck($ARG) if ! @has;

    };

  } $self->rwalk();

};

# ---   *   ---   *   ---
# true if node is part of
# a branch with a given flag

sub branch_has_flag($self,$flag) {

  my $out=($self->{$flag})
    ? $self
    : undef
    ;

  while(defined $self->{parent}) {

    if($self->{$flag}) {
      $out=$self;
      last;

    };

    $self=$self->{parent};

  };

  return $out;

};

# ---   *   ---   *   ---
# ^had by self

sub has_flag($self,$flag) {
  return $self->{$flag};

};

# ---   *   ---   *   ---
# exec calls attached to branch

sub on_match($self,$branch) {

  my ($root)=$branch->root();


  $self->{fn}->($root->{ctx},$branch)
  if $self->{fn} ne $NOOP;

  # ^detect if post-parse proc
  # is setting the callstack for
  # this branch
  my $chain=($branch->{chain})
    ? $branch->{chain}
    : $self->{chain}
    ;


  # ^similar, translation procs
  my $xlate=(%{$branch->{xlate}})
    ? $branch->{xlate}
    : $self->{xlate}
    ;

  # ^manual search if all fails!
  my @have=grep {
    $ARG ne $NOOP

  } values %$xlate;

  if(! @have) {

    my $ctx    = $root->{ctx};
    my $class  = $ctx->{frame}->{-class};

    $class->xbreak(
      $branch,$class,codename($self->{fn})

    );

  # ^no search needed ;>
  } else {
    $branch->{xlate}={%$xlate};

  };


  # advance to next step
  $branch->shift_chain(@$chain);

};

# ---   *   ---   *   ---
# run string match

sub re_leaf($self,$anchor,$sref,%O) {

  my $out = undef;
  my $re  = ${$self->{value}};

  my $jmp=qr{(?:
    (?: ^\s* )
  | (?: ^    )

  )}x;

  my $scope = $O{mach}->{scope};
  my $cdef  = $scope->cdef_re();


  # match against pattern
  if($$sref=~ s[$jmp($re)][]) {
    $out=$anchor->init($1);

  # ^match against macro expansion (!!)
  } elsif($$sref =~ s[$jmp($cdef)][]) {

    my $token=$1;

    # expansion is valid for rule
    if($scope->cdef_get($token) =~ m[($re)]) {

      my $idex=@{$anchor->{leaves}};

      $out=$anchor->init($token);
      $anchor->{is_cdef}->[$idex]=1;

    # ^nope
    } else {

      # non-optional means failure
      # else keep going
      $anchor->status_ffail()
      if ! $self->{parent}->{opt};

      # push token back into source
      $$sref="$token$$sref";

    };

  # ^accept defeat if non-optional
  } elsif(! $self->{parent}->{opt}) {
    $anchor->status_ffail();

  };

  return $out;

};

# ---   *   ---   *   ---
# determines type of node

sub re_or_branch($self,$ctx,$sref,%O) {

  my $out = undef;
  my $x   = $self->{value};

  my $anchors = $ctx->{anchors}->[-1];
  my $anchor  = $anchors->[-1];

  $anchor->{is_cdef}//=[];
  map {$ARG//=0} @{$anchor->{is_cdef}};

  my $dst     = undef;

  if(is_qreref($x)) {
    $out=$self->re_leaf($anchor,$sref,%O);
    $dst=$anchor if $out;

  } else {
    $out=$anchor->init($self->{value});
    push @$anchors,$out;

  };

  return ($out,$dst);

};

# ---   *   ---   *   ---
# recurse

sub match($self,$ctx,$s,%O) {

  my $x     = $self->{value};
  my $fn    = $self->{fn};

  my $class = $self->{frame}->{-class};

  # parallel
  my $root=$self->{frame}->nit(
    parent => undef,
    value  => $x,

  );

  $root->{ctx}=$ctx;
  $root->init_status($self);

  my @anchors = ($root);
  my @pending = (@{$self->{leaves}});
  my $depth   = 0;

  my $branch  = $self;

  push @{$ctx->{anchors}},\@anchors;
  push @{$ctx->{pending}},\@pending;

  # ^walk
  while(@pending) {

    last if ! length $s;

    $self=$branch->shift_pending(
      $ctx,\$depth

    ) or next;

    my ($m,$dst)=
       $self->re_or_branch($ctx,\$s,%O);

    my $fn=$self->{fn};


    $anchors[-1]->init_status($self);
    $dst->status_add($self) if $dst;

    ! $self->alternation($ctx,\$s,%O)
    or next;

    ! $self->greed($ctx,\$s,%O)
    or next;

    ! $self->hier_sub($ctx,\$s,%O)
    or next;

    my $opt_branch=
      $self->branch_has_flag('opt');

    if($class->is_valid($m)) {
      $m->{other}=$self;
      $fn->($ctx,$m) if $fn ne $NOOP;

    } elsif(! $m &&! $opt_branch) {
      last;

    };

    my @lv=@{$self->{leaves}};
    $depth+=0<@lv;

    unshift @pending,@lv,$depth;

  };

  pop @{$ctx->{anchors}};
  pop @{$ctx->{pending}};

  return ($root,$s);

};

# ---   *   ---   *   ---
# ^skips non-node steps in
# the walk array

sub shift_pending($branch,$ctx,$depthr) {

  my $pending = $ctx->{pending}->[-1];
  my $anchors = $ctx->{anchors}->[-1];
  my $anchor  = $anchors->[-1];

  my $total   = int(@{$branch->{leaves}});
  my $current = int(@$pending);

  my $out     = shift @$pending;
  my $class   = $branch->{frame}->{-class};

  if(! $class->is_valid($out)) {

    while($out <= $$depthr) {
      pop @$anchors;
      $$depthr--;

    };

    $out=undef;

  };

  # end of alternation
  my $eoa=int($branch->{alt}

  && ! $$depthr
  && ! ($total eq $current)

  );

  if($eoa) {

    if($ctx->{match_ok}) {
      @$pending = ();
      $out      = undef;

    } else {
      $anchor->clear();

    };

  };

  $out=(! @$anchors) ? undef : $out;

  return $out;

};

# ---   *   ---   *   ---
# wrap parens round branch

sub subtree($self,$ctx,$sref,%O) {

  # defaults
  $O{-root}//=0;
  $O{-clip}//=0;

  $O{-closed}=1;

  my $anchors = $ctx->{anchors}->[-1];
  my $root    = $anchors->[$O{-root}];

  return undef if ! $root;

  my $out=undef;

  my ($m,$ds)=$self->hier_match(
    $ctx,$$sref,%O

  );

  my $match;

  if($O{-clip}) {
    $match=$self->subtree_clip(
      $root,$m,$ds,$sref

    );

    $out=pop @$anchors if @$anchors > 1;

  } else {
    $match=$self->subtree_noclip(
      $root,$m,$ds,$sref

    );

    pop @$anchors;
    $out=$match;

  };

  $ctx->{match_ok}=defined $match;

  return $out;

};

# ---   *   ---   *   ---
# ^common subtree solve

sub subtree_noclip($self,$root,$m,$ds,$sref) {

  my $out=undef;

  if($m && $m->status_ok()) {
    $$sref=$ds;

    $root->pushlv($m);
    $root->flatten_branch();

    $root->status_add($self);

    $out=$root;

  } elsif($self->{opt}) {
    $root->status_force_ok();

  };

  return $out;

};

# ---   *   ---   *   ---
# ^mess of an edge-case

sub subtree_clip($self,$root,$m,$ds,$sref) {

  my $out     = undef;
  my $clip    = 1 <= @{$root->{leaves}};

  if($m && $m->status_ok()) {

    $$sref = $ds;
    my @lv = ($m);

    if($clip) {

      $root = $root->{leaves}->[-1];
      $root = $root->{leaves}->[0];

      @lv   = @{$m->{leaves}};

    };

    $root->pushlv(@lv);
    $root->status_add($self);

    $out=$m;

  } elsif($self->{opt}) {
    $root->status_force_ok();

  };

  return $out;

};

# ---   *   ---   *   ---
# branch opens a new scope

sub hier_sub($self,$ctx,$sref,%O) {

  my $out=0;
  $O{-root}=-1;

  if($self->has_flag('hier')) {

    my $nd=$self->subtree(
      $ctx,$sref,%O

    );

    $out=1;

  };

  return $out;

};

# ---   *   ---   *   ---
# branch must match at most one
# pattern out of a group

sub alternation($self,$ctx,$sref,%O) {

  my $out=0;
  $O{-root}=-1;

  if($self->has_flag('alt')) {

    my $n=$self->subtree(
      $ctx,$sref,%O,

    );

    $out=1;

  };

  return $out;

};

# ---   *   ---   *   ---
# branch keeps matching until
# failure

sub greed($self,$ctx,$sref,%O) {

  my $out  = 0;
  my $root = undef;

  $O{-root}=-1;
  $O{-clip}=1;

  if($self->has_flag('greed')) {
    $out=1;

    while(1) {

      my $t=$self->subtree(
        $ctx,$sref,%O

      );

      if($t && $t->status_ok()) {
        $root//=$t;
        $out++;

      } else {
        $root->flatten_branch() if $root;
        last;

      };

    };

  };

  return $out;

};

# ---   *   ---   *   ---
# inits 'completion bar' ;>

sub init_status($self,$other) {

  return if exists $self->{status};

  my @lv_s = @{$self->{leaves}};
  my @lv_o = @{$other->{leaves}};

  my $ar   = $other->status_array();
  my $max  = $other->{max};

  $self->{status}={

    ar    => $ar,
    max   => $max,

    fail  => 0,

    opt   => int($other->{opt} &&! $max),
    alt   => $other->{alt},
    greed => $other->{greed},

  };

  return $self->{status};

};

# ---   *   ---   *   ---
# details matches within a branch

sub status_array($self) {

  my $out=[];

  for my $nd(@{$self->{leaves}}) {

    my $sub_status={

      alt   => $nd->{alt},
      opt   => $nd->{opt},
      greed => $nd->{greed},

      ok    => 0,

    };

    push @$out,$sub_status;

  };

  return $out;

};

# ---   *   ---   *   ---
# register succesful match

sub status_add($self,$other) {

  my $status = $self->{status};

  my $ar     = $status->{ar};
  my $idex   = $other->{idex};

  $ar->[$idex]->{ok}=1;

};

# ---   *   ---   *   ---
# ^force success

sub status_force_ok($self) {

  my $status  = $self->{status};
  my $ar      = $status->{ar};

  # walk tree and set bools
  map {$ARG->{ok}=1} @$ar;
  map {

    $ARG->status_force_ok()
    if $ARG->{status};

  } @{$self->{leaves}};

  # set bool for self
  $status->{fail}=0;

};

# ---   *   ---   *   ---
# get match success

sub status_ok($self) {

  $self->status_chk();

  my $status = $self->{status};
  my $subok  = $self->status_subok();

  my $opt    = $status->{opt};
  my $alt    = $status->{alt};
  my $greed  = $status->{greed};
  my $max    = $status->{max};
  my $ar     = $status->{ar};

  my $ok=int(

     ($subok eq @$ar)
  || ($max && $subok <= $max)
  || ($alt && $subok eq 1)
  || ($opt && ! $greed)

  );

  $status->{fail}=int(
     (! $ok) || ($status->{fail})

  );

  return ! $status->{fail};

};

# ---   *   ---   *   ---
# ^walk children

sub status_subok($self) {

  my $out    = 0;

  my $lv     = $self->{leaves};
  my $status = $self->{status};
  my $ar     = $status->{ar};

  for my $sus(@$ar) {

    $out+=

       $sus->{ok}
    || $sus->{opt}
    ;

  };

  return $out;

};

# ---   *   ---   *   ---
# ^recurse

sub status_chk($self) {

  my $status  = $self->{status};
  my @pending = @{$self->{leaves}};

  my $i  = 0;
  my $ar = $status->{ar};

  for my $nd(@pending) {

    next if ! $nd->{status};

    my $sus    = $ar->[$i++];
    $sus->{ok} = $nd->status_ok();

  };

};

# ---   *   ---   *   ---
# force failure

sub status_ffail($self) {

  my $status=$self->{status};
  $status->{fail}=1;

};

# ---   *   ---   *   ---
# debug print

sub status_db_out($self) {

  my @out    = ();

  my $status = $self->{status};
  my $ar     = $status->{ar};

  my $i=0;

  for my $sub_status(@$ar) {

    push @out,int(

       $sub_status->{ok}
    || $sub_status->{opt}

    );

  };

  $i=0;

  say {*STDERR}
    int(! $status->{fail})
  . " $self->{value}"
  ;

  for my $ok(@out) {

    say {*STDERR} "\\-->$ok";
    $i++;

  };

  say $NULLSTR;

  for my $leaf(@{$self->{leaves}}) {
    next if ! $leaf->{status};
    $leaf->status_db_out();

  };

};

# ---   *   ---   *   ---
# match against all branches

sub hier_match($self,$ctx,$s,%O) {

  # defaults
  $O{-closed}//=0;

  my @out=(undef,$s);
  my @pending=($O{-closed})
    ? $self
    : @{$self->{leaves}}
    ;

  for my $branch(@pending) {

    my ($m,$ds)=$branch->match(
      $ctx,$s,%O

    );

    if($m->status_ok()) {

      @out=($m,$ds);

      $ctx->{Q}->wex();
      $branch->on_match($m);

      last;

    };

  };


  return @out;

};

# ---   *   ---   *   ---
# makes new dst for parser ice

sub new_p3($self,$ctx) {

  my $p3=$self->{frame}->nit(
    parent => undef,
    value  => $self->{value}

  );

  $p3->{ctx}=$ctx;

  return $p3;

};

# ---   *   ---   *   ---
# ^breaks down input

sub parse($self,$s,%O) {

  # defaults
  $O{skip}//=0;

  my $out   = $NULLSTR;
  my $ctx   = $self->{ctx};
  my $gram  = $ctx->{gram};

  my $retab = (ref $ctx)->get_retab();
  my $nterm = (
     exists $retab->{nterm}
  && exists $retab->{term}
  )

    ? qr{$retab->{nterm} \s* $retab->{term}}x
    : qr{[^\n]*\n?}
    ;

  while(1) {

    # exit when input consumed
    last if (! length $s)
         || ($s=~ m{^\s+$});


    # ^attempt
    my ($match,$ds)=
      $gram->hier_match($ctx,$s,%O);

    # ^errchk
    if(! $match) {

      if($O{skip}) {

        ($s=~ s[^($nterm)][])

          ? $out.=$1

          : throw_linebug($s,$retab)
            && last

          ;

      } else {
        $self->throw_no_match($gram,$s);

      };

      next;

    };


    # push to tree and run queue
    $self->pushlv($match);
    $ctx->{Q}->wex();

    # update string
    $s=$ds;

  };


  return $out;

};

# ---   *   ---   *   ---
# ^errme

sub throw_no_match($self,$gram,$s) {

  my $s_short=substr $s,0,64;

  say {*STDERR}

    "_______________\n\n" .

    "PARSE-IRUPT"

  ;

  $self->prich(errout=>1);

  say {*STDERR} "_______________\n";

  errout(

    "%s\n\n".
    q[^^^ Could not parse this bit ].
    q[with grammar <%s>],

    args => [$s_short,$gram->{value}],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
# ^further

sub throw_linebug($s,$retab) {


  my $nterm = $retab->{nterm};
  my $term  = $retab->{term};

  my $re    = qr{(
    (?: $nterm)?
    $term

  )}x;


  my $line  = ! ($s=~ $re)
    ? $s
    : $1
    ;


  errout(

    q[Linebug encountered at ]
  . q[[err]:%s -- possibly missing an ]
  . q[[good]:%s char before [err]:%s],

    lvl  => $AR_FATAL,
    args => [$line,'nterm','term']

  ) if length $s;


  return 1;

};

# ---   *   ---   *   ---
1; # ret

