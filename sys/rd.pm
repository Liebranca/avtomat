#!/usr/bin/perl
# ---   *   ---   *   ---
# RD
# Code reader
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use Storable;

  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Tree;
  use Cli;
  use Shb7;
  use Ring;

  use Arstd::Array;
  use Arstd::IO;
  use Arstd::PM;
  use Arstd::WLog;

  $WLog //= Arstd::WLog->genesis();


  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.4;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  # what the unset is set to!
  DEFAULT => {
    cmdlib => 'rd::cmdlib',

  },


  # subpackages
  layers => [qw(case l0 l1 l2 lx)],

  case_t => 'rd::case',
  l0_t   => 'rd::l0',
  l1_t   => 'rd::l1',
  l2_t   => 'rd::l2',
  lx_t   => 'rd::lx',

  cmd_t  => 'rd::cmd',


  # ^wraps
  Ring->layers => sub { return {

    map {

      my $fn  =  "${ARG}_t";
         $ARG => $_[0]->$fn();


    } @{$_[0]->layers()}


  }},


};


  Readonly my $SF=>{

    blank   => 0x0001,
    string  => 0x0002,
    comment => 0x0004,
    nterm   => 0x0008,
    exprbeg => 0x0010,
    escape  => 0x0020,

  };

  Readonly my $FMODE=>{

    (map {$ARG=>0x01} qw($ elf)),
    (map {$ARG=>0x02} qw(% rom)),
    (map {$ARG=>0x04} qw(@ net)),
    (map {$ARG=>0x08} qw(^ gfi)),

  };


  Readonly my $SF_DEFAULT=>
    $SF->{exprbeg};


# ---   *   ---   *   ---
# cstruc

sub new($class,$src,%O) {

  # defaults
  $O{mc}={

    cls     => 'A9M',

    memroot => 'non',
    pathsep => $DCOLON_RE,

  };

  cload $O{mc}->{cls};


  # make parse tree root
  my $frame = Tree->new_frame();
  my $root  = $frame->new(undef,$NULLSTR);


  # file or string passed?
  my $body=$NULLSTR;

  if(is_filepath($src)) {
    $body = orc($src);
    $src  = Shb7::shpath($src);

  } else {
    $body = $src;
    $src  = '%$';

  };


  # make ice
  my $self=bless {


    # parse tree root
    tree => $root,


    # current l0/l1/l2 value
    char   => $NULLSTR,
    token  => $NULLSTR,
    branch => undef,

    # nesting within current branch
    nest => [],

    # a 'preparse' of sorts!
    case => undef,

    # parse layers: char/token/branch
    l0 => undef,
    l1 => undef,
    l2 => undef,

    # execution layer
    lx    => undef,
    stage => 0,

    mc    => $O{mc}->{cls}->new(%{$O{mc}}),


    # library of commands
    cmdlib  => undef,
    subpkg  => undef,


    # N repeats of a processing stage
    pass   => 0,
    passes => {},

    # shared vars
    status => $SF_DEFAULT,


    # line number!
    lineno => 1,
    lineat => 1,

    # stringmode term
    strterm => $NULLSTR,


    # I/O
    fmode => $FMODE->{rom},
    fpath => $src,
    buf   => $body,


  },$class;

  # nit layers and give ice
  $self->cstruc_layers(
    map {$ARG=>$self}
    @{$self->layers}

  );


  # nit command library
  cloadi $class->cmd_t;

  $self->{cmdlib}=
    $class->cmd_t->new_frame(main=>$self);

  $self->{case}->ready_or_build();


  return $self;

};

# ---   *   ---   *   ---
# in a nutshell

sub crux($src,%O) {

  # defaults
  $O{strip} //= 1;


  # make ice
  my $self=rd->new($src,%O);
  $self->parse();

  # strip parse tree?
  $self->strip() if $O{strip};

  return $self;

};

# ---   *   ---   *   ---
# advance pass/stage

sub next_pass($self) {
  $self->{pass}++;

};

sub next_stage($self) {

  # record number of passes used
  # for this stage
  my $lx   = $self->{lx};
  my $name = $lx->stagename();

  $self->{passes}->{$name}=
    $self->{pass};


  # ^start anew!
  $self->{pass}=0;
  $self->{stage}++;

};

# ---   *   ---   *   ---
# first stage
#
# parses entire file/codestr
# and outputs a tree

sub parse($self) {


  # mutate and run
  $self->parse_subclass();
  $self->{l0}->parse();

  # ^final expr pending?
  $self->unset('blank');
  $self->term();


  # ~
  $self->{case}->parse(
    case=>$self->{tree}

  );


  # cleanup parse-only values
  delete $self->{buf};
  delete $self->{status};
  delete $self->{strterm};
  delete $self->{nest};

  # go next and give
  $self->next_stage();
  return;

};

# ---   *   ---   *   ---
# parses fist expression
#
# this loads definitions accto
# which subclass it redirects
# us to

sub parse_subclass($self) {


  # get ctx
  my $l0=$self->{l0};
  my $l1=$self->{l1};

  # parse first expression
  $l0->parse_single();

  # ^decompose
  my $pkg  = $self->{tree}->{leaves}->[-1];
  my @args = @{$pkg->{leaves}};
  my $have = $pkg->{value};



  # is first token operator?
  if(

     $have eq '$'
  || defined ($have=$l1->is_opera($have))

  ) {

    # validate sigil
    $self->perr(
      "fmode '%s' not in table",
      args=>[$have],

    ) if ! exists $FMODE->{$have};


    # set output mode from table
    my $fmode=$FMODE->{$have};

    # reset source package
    $pkg=shift @args;
    $self->{tree}->{value} .= $have;

  };


  # subclass provided?
  if($pkg) {

    # get path to language definitions
    my $fpath="lps/$pkg->{value}.rom";

    # ^validate
    $self->perr(
      "could not find '%s'",
      args=>[$fpath],

    ) if ! -f $fpath;


    # [INSERT SUBCLASS-MUTATE]

    $self->{tree}->{value} .= $pkg;

  };


  # load cmdlib
  $pkg //= $self->DEFAULT->{cmdlib};
  $self->{cmdlib}->load($pkg);
  $self->{subpkg}=$pkg;


  # pop expression from tree
  $self->{tree}->{leaves}->[-1]->discard();
  $self->{token}=undef;

};

# ---   *   ---   *   ---
# ^all others!

sub walk($self,%O) {

  # defaults
  $O{limit} //= 1;

  $O{fwd}   //= $NOOP;
  $O{rev}   //= $NOOP;
  $O{self}  //= undef;

  # get ctx
  my $l2   = $self->{l2};
  my $tree = $self->{tree};

  # cleanup cache
  my @pending=@{$tree->{leaves}};

  rept:
    $l2->{walked}={};


  # walk tree
  my @Q       = @pending;
     @pending = ();

  map {

    my $branch = $ARG;


    # * if a node is returned, then
    #   it is walked in the next pass
    #
    # * if an F is returned, then it
    #   is executed in the next pass

    my ($have)=(is_coderef $branch)
      ? ($branch,$branch->())
      : $l2->walk($branch,%O)
      ;

    push @pending,$have;

  } @Q;


  # another pass required/allowed?
  $self->next_pass();

  # ^repeat or fail if so!
  my @have=grep {'Tree' eq ref $ARG} @pending;
  if(@have) {

    goto rept if $self->{pass} < $O{limit};


    # report failure!
    $self->throw_unresolved(
      \@have,
      lvl=>$AR_WARNING,

    );

    return 0;

  };


  # go next and give OK
  $self->next_stage();
  return 1;

};

# ---   *   ---   *   ---
# push token to tree

sub commit($self) {

  # have token?
  my $have=0;

  if(length $self->{token}) {


    # classify and mark new expression
    $self->{token}=$self->{l1}->parse(
      $self->{token},
      nocmd=>1,

    );

    $self->unset('exprbeg');

    # start of new branch?
    if(! defined $self->{branch}) {

      $self->{branch}=
        $self->{tree}->inew($self->{token});

      $self->{branch}->{lineno}=
        $self->{lineat};

      $self->{branch}->{escaped}=
        $self->escaped;


    # ^cat to existing
    } else {

      my $branch=
        $self->{branch}->inew($self->{token});

      $branch->{lineno}  = $self->{lineat};
      $branch->{escaped} = $self->escaped;

    };


    $self->{lineat}=$self->{lineno};
    $have |= 1;

  };


  # give true if token added
  $self->{token}=$NULLSTR;
  $self->unset('escape');

  return $have;

};

# ---   *   ---   *   ---
# clear current if not nesting
# else make sub-branch

sub new_branch($self) {


  # leaving branch undefined will trigger
  # it's making on next token commited
  if(! @{$self->{nest}}) {
    $self->{branch}=undef;


  # ^nesting, so not so simple
  } else {

    # get last, deepest sub-branch
    my $anchor = $self->{nest}->[-1];
       $anchor = $anchor->{leaves}->[-1];

    # ^get sub-branch idex relative to it's parent
    my $idex   = int @{$anchor->{leaves}};
    my $l1     = $self->{l1};

    # ^make new sub-branch next to it
    $self->{branch}=$anchor->inew(
      $l1->make_tag('BRANCH'=>$idex)

    );

  };


  # mark beggining of expression
  $self->set('exprbeg');

};

# ---   *   ---   *   ---
# nest one sub-branch deeper

sub nest_up($self) {
  push @{$self->{nest}},$self->{branch};
  $self->new_branch();

};

# ---   *   ---   *   ---
# ^return to previous sub-branch

sub nest_down($self) {
  $self->{branch}=pop @{$self->{nest}};

};

# ---   *   ---   *   ---
# terminate branch or sub-branch

sub term($self) {

  $self->commit();

  $self->new_branch();
  $self->set_termf();

};

# ---   *   ---   *   ---
# defines whether an operator
# is a valid char for a name

sub cmd_name_rule($self) {

  return ! defined $self->{branch}

  &&  @{$self->{tree}->{leaves}}
  &&! @{$self->{nest}}
  &&! $self->blank()

  ;

};

# ---   *   ---   *   ---
# set status flag

sub set($self,@name) {
  map {$self->{status} |= $SF->{$ARG}} @name;

};

# ---   *   ---   *   ---
# ^undo

sub unset($self,@name) {
  map {$self->{status} &=~ $SF->{$ARG}} @name;

};

# ---   *   ---   *   ---
# read status flags are set/unset

sub status($self,@order) {

  # array as hash
  my @fk  = array_keys(\@order);
  my @fv  = array_values(\@order);

  my $fi  = 0;
  my $out = 1;


  # ^walk
  for my $k(@fk) {


    # get [flag => expected state]
    my $v    = $fv[$fi++];

    # ^get actual state
    my $have = (
      $self->{status}
    & $SF->{$k}

    ) != 0;


    # fail on no match
    if($have != $v) {
      $out=0;
      last;

    };

  };


  return $out;

};

# ---   *   ---   *   ---
# ^icebox

sub blank($self) {
  return $self->status(blank=>1);

};

sub comment($self) {
  return $self->status(comment=>1);

};

sub nterm($self) {
  return $self->status(nterm=>1);

};

sub exprbeg($self) {
  return $self->status(exprbeg=>1);

};

sub escaped($self) {
  return $self->status(escape=>1);

};

# ---   *   ---   *   ---
# ^set terminator flags

sub set_termf($self) {
  $self->set('blank');
  $self->unset('nterm');

};

# ---   *   ---   *   ---
# ^set *non* terminator flags

sub set_ntermf($self) {
  $self->unset('blank','exprbeg');
  $self->set('nterm');

};

# ---   *   ---   *   ---
# check for stringmode and
# handle terminator char

sub string($self) {

  my $out=$self->status(string=>1);

  if($out && $self->{char} eq $self->{strterm}) {

    $self->{char}=$NULLSTR;
    $self->unset('string');

    $self->commit();

    if($self->comment()) {
      $self->unset('comment');
      $self->new_branch();

    };

  };


  return $out;

};

# ---   *   ---   *   ---
# wraps: remove comments

sub strip($self) {
  $self->{l2}->strip_comments($self->{tree});

};

# ---   *   ---   *   ---
# AR/IMP:
#
# * runs crux with provided
#   input if run as executable
#
# * if imported as a module,
#   it aliaes 'crux' to 'rd'
#   and adds it to the calling
#   module's namespace

sub import($class,@req) {

  return IMP(

    $class,

    \&ON_USE,
    \&ON_EXE,

    @req

  );

};

# ---   *   ---   *   ---
# ^imported as exec via arperl

sub ON_EXE($class,@input) {


  my $m=Cli->new(

    {id=>'out',short=>'-o',argc=>1},
    {id=>'echo',short=>'-e',argc=>0},
    {id=>'strip',short=>'-s',argc=>0,default=>1},
    {id=>'mc',short=>'-mc',argc=>1},

  );


  # remove nullargs and proc cmd
  @input=grep {defined $ARG} @input;

  # have values to proc?
  my ($src)=$m->take(@input);

  $WLog->err('no input',
    from  => 'rd',
    lvl   => $AR_FATAL

  ) if ! $src;


  # proc options
  my %O=();

  if($m->{mc} ne $NULL) {

    my ($cls,$memroot,$pathsep)=
      split ',',$m->{mc};

    $O{mc}={

      cls     => $cls,

      memroot => $memroot,
      pathsep => $pathsep,

    };

  };

  $O{strip}=$m->{strip} ne $NULL;


  # get parse tree
  my $ice=crux($src,%O);


  # write to file?
  store($ice,$m->{out})
  if $m->{out} ne $NULL;


  # dbout to tty?
  $ice->prich()

  if $m->{echo} ne $NULL
  || $m->{out}  eq $NULL

  ;


  return;

};

# ---   *   ---   *   ---
# ^imported as module via use

sub ON_USE($class,$from,@nullarg) {

  no strict 'refs';

  *rd=*crux;

  submerge(

    [$class],

    main  => $from,
    subok => qr{^rd$},

  );

  return;

};

# ---   *   ---   *   ---
# parse error

sub perr($self,$me,%O) {

  # defaults
  $O{lvl}  //= $AR_FATAL;
  $O{args} //= [];


  # each branch saves at which line
  # it was spawned; use that if avail
  my $lineno=($self->{branch})
    ? $self->{branch}->{lineno}
    : $self->{lineat}
    ;


  # give "(errme) at lineno"
  my $loc="<%s> line [num]:%u";
  unshift @{$O{args}},$self->{fpath},$lineno;

  $WLog->err("at $loc:\n$me",%O,from=>(ref $self));


  return;

};

# ---   *   ---   *   ---
# ~

sub throw_unresolved($self,$Q,%O) {

  # defaults
  $O{lvl} //= $AR_FATAL;

  # ~
  my @args=($self->{fpath},':');
  my $fmat=join "\n",map {

    push @args,$ARG->{value},$ARG->{lineno};
    "unresolved '%s' on line [num]:%u";

  } @$Q;


  # ~
  $WLog->err(

    "at <%s>[op]:%s\n$fmat",

    %O,

    args=>\@args,
    from=>(ref $self),

  );

};

# ---   *   ---   *   ---
# name collision

sub throw_redecl($self,$type,$name) {

  $self->perr(
    "re-declaration of %s '%s'",
    args=>[$type,$name]

  );

};

# ---   *   ---   *   ---
# ^no name!

sub throw_undefined($self,$type,$name,@path) {

  @path=@{$self->{mc}->{path}}
  if ! @path;

  $self->perr(
    "undefined %s '%s' at namespace [errtag]:%s",
    args=>[$type,$name,(join '::',@path)]

  );

};

# ---   *   ---   *   ---
# dbout

sub prich($self,%O) {

  # I/O defaults
  my $out=ioprocin(\%O);

  # own defaults
  $O{tree}   //= 1;
  $O{mem}    //= 'inner,outer';
  $O{anima}  //= 0;
  $O{stack}  //= 0;
  $O{passes} //= $ANY_MATCH;


  # get repr for parse tree?
  if($O{tree}) {

    push @$out,'TREE:';
    $self->{tree}->prich(%O,mute=>1);

    push @$out,"\n";

  };


  # show stack?
  $self->{mc}->{stack}->prich(%O,mute=>1)
  if $O{stack};

  # show registers?
  $self->{mc}->{anima}->prich(%O,mute=>1)
  if $O{anima};


  # get repr for memory?
  if($O{mem}) {


    my $inner=$O{mem}=~ qr{\binner\b};
    my $outer=$O{mem}=~ qr{\bouter\b};


    $self->{mc}->prich(

      %O,

      inner => $inner,
      outer => $outer,

      mute  => 1,

    );


  };


  # show performed passes?
  my $lx = $self->{lx};

  push @$out,"\n",

  map  {"$ARG: $self->{passes}->{$ARG} passes\n"}
  grep {$ARG=~ $O{passes}}

  @{$lx->stages()}[1..$self->{stage}-1];


  return ioprocout(\%O);

};

# ---   *   ---   *   ---
1; # ret
