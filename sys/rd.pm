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
  use id;

  use Arstd::Array;
  use Arstd::IO;
  use Arstd::PM;
  use Arstd::WLog;

  $WLog //= Arstd::WLog->genesis();


  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.8;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  # what the unset is set to!
  DEFAULT => {
    cmdlib => 'rd::cmdlib',

  },


  # subpackages
  layers    => [qw(preproc l0 l1 l2 lx)],

  preproc_t => 'rd::preproc',
  l0_t      => 'rd::l0',
  l1_t      => 'rd::l1',
  l2_t      => 'rd::l2',
  lx_t      => 'rd::lx',

  cmd_t     => 'rd::cmd',
  syntax_t  => 'rd::syntax',


  # ^wraps
  Ring->layers => sub { return {

    map {

      my $fn  =  "${ARG}_t";
         $ARG => $_[0]->$fn();


    } @{$_[0]->layers()}


  }},

  # names of functions to run on
  # the parser being invoked
  pipeline => [qw(parse preproc reparse)],


  # WIP; output formats
  fmode_tab => {
    (map {$ARG=>0x01} qw($ elf)),
    (map {$ARG=>0x02} qw(% rom)),
    (map {$ARG=>0x04} qw(@ net)),
    (map {$ARG=>0x08} qw(^ gfi)),

  },


};

# ---   *   ---   *   ---
# cstruc

sub new($class,$src,%O) {


  # defaults
  $O{mc} //= {

    cls     => 'A9M',

    memroot => 'non',
    pathsep => $DCOLON_RE,

  };

  cload $O{mc}->{cls};


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


    # parse tree root/preproc namespace
    tree  => undef,
    inner => undef,
    scope => undef,

    # a glorified source filter ;>
    preproc => undef,

    # parse layers: char/token/branch
    l0 => undef,
    l1 => undef,
    l2 => undef,

    # execution layer
    lx    => undef,
    stage => 0,
    rerun => 0,

    mc    => undef,


    # library of commands
    cmdlib  => undef,
    subpkg  => undef,


    # N repeats of a processing stage
    pass   => 0,
    passes => {},


    # line number!
    lineno => 1,
    lineat => 1,


    # I/O
    fmode => $class->fmode_tab->{rom},
    fpath => $src,
    buf   => $body,


  },$class;


  # generate/reuse instance ID
  id->chk($self,$O{id});

  # make VM
  $self->{mc}=$O{mc}->{cls}->new(

    %{$O{mc}},

    mainid  => $self->{iced},
    maincls => $class,

  );


  # make parse tree root
  my $frame      = Tree->get_frame($self->{iced});

  $self->{tree}  = $frame->new(undef,$NULLSTR);
  $self->{inner} = $frame->new(undef,'INNER');
  $self->{scope} = $self->{inner};


  # nit layers
  $self->cstruc_layers(
    map {$ARG=>$self}
    @{$self->layers}

  );

  # ^now kick em
  $self->{l1}->build();
  $self->{l2}->build();


  # nit command library
  cloadi $class->cmd_t;

  $self->{cmdlib}=
    $class->cmd_t->new_frame(main=>$self);

  $self->{cmdlib}->kick();


  return $self;

};

# ---   *   ---   *   ---
# fetch ice

sub ice($class,$src) {
  return id->fet($src);

};

# ---   *   ---   *   ---
# dstruc

sub DESTROY($self) {
  id->del($self);
  return;

};

# ---   *   ---   *   ---
# in a nutshell

sub crux($src,%O) {

  # defaults
  $O{strip} //= 1;


  # make ice
  my $self=rd->new($src,%O);


  # run stages
  map {$self->$ARG()}
  @{$self->pipeline};

  # cleanup parse-only values
  delete $self->{buf};


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

  # get ctx
  my $l0=$self->{l0};
  my $l1=$self->{l1};
  my $l2=$self->{l2};


  # make scope
  $l2->enter();

  # mutate and build initial tree
  $self->parse_subclass();
  $l0->parse();

  # ^final expr pending?
  $l0->flagset(ws=>0);
  $l0->term();

  # terminate scope
  $l2->leave();
  $l2->sweep();


  # go next and give
  $self->next_pass();
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
  my $l2=$self->{l2};

  # parse first expression
  $l0->parse_single();

  # ^decompose
  my $pkg  = $self->{tree}->{leaves}->[0];
  my @args = @{$pkg->{leaves}};
     $pkg  = shift @args;

  my $have = undef;


  # is first token operator?
  if(
     ($have=$l1->typechk(SYM=>$pkg->{value}))
  || ($have=$l1->typechk(OPR=>$pkg->{value}))

  ) {


    # validate sigil
    my $tab = $self->fmode_tab;
    my $key = $have->{spec};

    $self->perr(
      "fmode '%s' not in table",
      args=>[$have],

    ) if ! exists $tab->{$key};


    # set output mode from table
    $self->{fmode}=$tab->{$key};

    # reset source package
    $pkg=$l1->stirr(shift @args);
    $self->{tree}->{value} .= $key;

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
  $self->{subpkg}=$pkg;


  # pop expression from tree
  $self->{tree}->{leaves}->[0]->discard();
  $self->{tree}->{leaves}->[0]->discard();

  $l2->{branch} = undef;
  $l1->{token}  = $NULLSTR;

  $l2->term();


  # load new syntax rules!
  cloadi $self->syntax_t;

  $self->{syntax}=$self->syntax_t->new($self);
  $self->{syntax}->build();


  return;

};

# ---   *   ---   *   ---
# second stage
#
# passes result of initial parse
# through the preprocessor!

sub preproc($self) {


  # kick if need
  $self->{preproc}->ready_or_build();

  # invoke
  my $ok=
    $self->{preproc}->parse($self->{tree});


  # validate and give
  $self->perr(
    "TODO: preproc err"

  ) if ! $ok;

  $self->next_pass();
  $self->next_stage();

  return;

};

# ---   *   ---   *   ---
# third stage
#
# re-evaluates the tree after
# being altered by the preprocessor

sub reparse($self) {


  # get ctx
  my $l1=$self->{l1};
  my $l2=$self->{l2};

  # fetch definitions
  $self->{cmdlib}->load($self->{subpkg});


  # re-evaluate symbols
  rept:

  $self->{rerun}=0;

  my @Q=@{$self->{tree}->{leaves}};
  while(@Q) {

    my $nd  = shift @Q;
    my $key = $nd->{value};

    my $have=$l1->xlate($key);

    my ($type,$spec)=($have)

      ? ($have->{type},$have->{spec})
      : ($NULLSTR,$NULLSTR)
      ;

    if($type && $type eq 'SYM') {
      $key=$spec;

    };


    $nd->{value}=$l1->detect($key);

    unshift @Q,@{$nd->{leaves}};

  };


  # re-evaluate all branches
  $l2->parse($self->{tree});

  # go next and give
  $self->next_pass();
  goto rept if $self->{rerun};

  $self->next_stage();

  return;

};

# ---   *   ---   *   ---
# all stages after reparse are
# done with this F ;>

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
# move to next line!

sub next_line($self) {
  $self->{lineat}=$self->{lineno};

};

# ---   *   ---   *   ---
# wraps: remove comments

sub strip($self) {

  my $l2=$self->{l2};

  $l2->strip_comments($self->{tree});
  $l2->sweep();

  return;

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

sub import($class,@args) {

  return IMP(

    $class,

    \&ON_USE,
    \&ON_EXE,

    @args

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
  my $lineno=($self->{l2}->{branch})
    ? $self->{l2}->{branch}->{lineno}
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

    "undefined [ctl]:%s '%s' "
  . "at namespace [errtag]:%s",

    args=>[$type,$name,(join '::',@path)]

  );

};

# ---   *   ---   *   ---
# encode to binary

sub mint($self) {


  # add general attrs
  my @out=map {
    $ARG=>$self->{$ARG}

  } qw(

    fpath

    fmode subpkg lineat lineno
    stage pass passes

    tree inner l2 preproc

  );


  # virtual machine attrs
  my $mc       = $self->{mc};

  my $root     = $mc->{astab_i}->[0];
     $root     = $mc->{astab}->{$root};

  my $mc_attrs = {

    cls     => ref $mc,

    memroot => $root->{value},
    pathsep => $mc->{pathsep},

  };

  push @out,mc => $mc_attrs;

  return @out;

};

# ---   *   ---   *   ---
# ^undo

sub unmint($class,$O) {


  # make ice
  my $self=bless {%$O},$class;
  id->chk($self);


  # regen missing layers ;>
  $self->cstruc_layers(
    map {$ARG=>$self} qw(l0 l1 lx)

  );

  $self->{l1}->build();


  # make new machine instance?
  if(! is_blessref $self->{mc}) {

    my $mc=$self->{mc};

    $self->{mc}=$mc->{cls}->new(

      memroot => $mc->{memroot},
      pathsep => $mc->{pathsep},

      mainid  => $self->{iced},
      maincls => $class,

    );

  };


  # load commandlib
  cloadi $class->cmd_t;

  $self->{cmdlib}=
    $class->cmd_t->new_frame(main=>$self);

  $self->{cmdlib}->kick();
  $self->{cmdlib}->load($self->{subpkg});


  return $self;

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

  grep {
     defined $self->{passes}->{$ARG}
  && $ARG=~ $O{passes}

  } @{$self->pipeline};


  return ioprocout(\%O);

};

# ---   *   ---   *   ---
1; # ret
