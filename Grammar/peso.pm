#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO GRAMMAR
# Recursive swan song
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::Array;
  use Arstd::String;
  use Arstd::Re;
  use Arstd::IO;
  use Arstd::PM;

  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang;
  use Grammar;

  use Grammar::peso::common;
  use Grammar::peso::value;
  use Grammar::peso::ops;
  use Grammar::peso::re;
  use Grammar::peso::eye;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.02.0;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # inherits from
  submerge(

    [qw(

      Grammar::peso::common
      Grammar::peso::value
      Grammar::peso::re

      Grammar::peso::ops

    )],

    xdeps=>1,
    subex=>qr{^throw_},

  );

# ---   *   ---   *   ---
# class attrs

  sub Frame_Vars($class) { return {

    -cdecl  => [],

    %{$PE_COMMON->Frame_Vars()},

  }};

  sub Shared_FVars($self) { return {
    %{Grammar::peso::eye::Shared_FVars($self)},

  }};

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    # imports
    %{$PE_COMMON->get_retab()},
    %{$PE_VALUE->get_retab()},
    %{$PE_OPS->get_retab()},
    %{$PE_RE->get_retab()},

    # ^new
    q[io-type]=>re_eiths(

      [qw(io in out)],

      bwrap  => 1,
      insens => 1,

    ),

    width=>re_eiths(

      [qw(

        byte wide brad word
        unit half line page

        nihil stark signal

      )],

      bwrap  => 1,
      insens => 1,

    ),

    spec=>re_eiths(

      [qw(ptr fptr str buf tab)],

      bwrap  => 1,
      insens => 1,

    ),

# ---   *   ---   *   ---
# compile-time values

    q[def-key]   => re_insens('def',mkre=>1),
    q[undef-key] => re_insens('undef',mkre=>1),
    q[redef-key] => re_insens('redef',mkre=>1),

  };

# ---   *   ---   *   ---
# rule imports

  ext_rules(

    $PE_COMMON,qw(

    clist lcom
    term nterm opt-nterm

    beg-curly end-curly
    fbeg-parens fend-parens

  ));

  ext_rules(

    $PE_VALUE,qw(

    bare seal bare-list
    sigil flg flg-list
    num

    value vlist opt-vlist

  ));

  ext_rules(

    $PE_OPS,qw(

    expr opt-expr invoke

  ));

  ext_rules($PE_RE,qw(re));

# ---   *   ---   *   ---
# compile-time definitions

  rule('~<def-key> &discard');
  rule('~<redef-key> &discard');
  rule('~<undef-key> &discard');

  rule('$<def> &cdef def-key bare nterm');
  rule('$<redef> &credef redef-key bare nterm');
  rule('$<undef> &cundef undef-key bare nterm');

# ---   *   ---   *   ---
# ^post-parse

sub cdef($self,$branch) {

  $self->cdef_common($branch);

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $st    = $branch->bhash();

  $scope->cdef_decl($st->{nterm},$st->{bare});
  $scope->cdef_recache();

  $branch->clear();
  $branch->{value}=$st;

};

# ---   *   ---   *   ---
# ^move global to local scope

sub cdef_ctx($self,$branch) {

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $st    = $branch->{value};

  $scope->cdef_decl($st->{nterm},$st->{bare});
  $scope->cdef_recache();

};

# ---   *   ---   *   ---
# ^selfex

sub cdef_common($self,$branch) {
  my $key_lv=$branch->{leaves}->[0];
  $branch->pluck($key_lv);

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
# patterns for declaring members

  rule('~<width>');
  rule('~<spec>');
  rule('*<specs> &list_flatten spec');

  rule('$<type> width specs');

  # ^combo
  rule(q[

    $<ptr-decl>
    &ptr_decl

    type nterm

  ]);

# ---   *   ---   *   ---
# pushes constructors to current namespace

sub ptr_decl($self,$branch) {

  my $f=$self->{frame};
  push @{$f->{-cdecl}},1;

  my $lv   = $branch->{leaves};
  my $type = $lv->[0];

  # ^unpack type
  my $type_lv = $type->{leaves};
  my $width   = $type_lv->[0]->leaf_value(0);
  my @spec    = (defined $type_lv->[1])
    ? $type_lv->[1]->branch_values()
    : ()
    ;

  # parse nterm
  my @eye=$PE_EYE->recurse(

    $lv->[1]->{leaves}->[0],

    mach       => $self->{mach},
    frame_vars => $self->Shared_FVars(),

  );

  # ^unpack
  my @names=map {
    ($ARG->{type} eq 'array_decl')
      ? @{$ARG->{raw}}
      : $ARG->{raw}
      ;

  } $eye[0]->branch_values();

  my @values=(defined $eye[1])
    ? $eye[1]->branch_values()
    : ()
    ;

  # ^repack ;>
  $branch->{value}={

    width  => $width,
    spec   => \@spec,

    names  => \@names,
    values => \@values,

  };

  $branch->clear();
  pop @{$f->{-cdecl}};

};

# ---   *   ---   *   ---
# ^pre-run step

sub ptr_decl_ctx($self,$branch) {

  my $mach   = $self->{mach};
  my @path   = $mach->{scope}->path();

  my $st     = $branch->{value};
  my $f      = $self->{frame};

  my @names  = @{$st->{names}};

  # errchk
  throw_invalid_scope(\@names,@path)
  if !$f->{-crom}
  && !$f->{-creg}
  && !$f->{-cproc}
  ;

  # select default cstruc
  my $dtype=(defined $st->{spec}->[-1])
    ? $st->{spec}->[-1]
    : 'void'
    ;

  # ^enforce on uninitialized
  map {
    $st->{values}->[$ARG]//=
      $mach->null($dtype)

  } 0..$#names;

  # struct-wise macro expansion
  $mach->{scope}->crepl(\$st);

  # bind and save ptrs
  $branch->{value}=$self->bind_decls(

    $st->{width},

    $st->{names},
    $st->{values},

  );

};

# ---   *   ---   *   ---
# ^errme

sub throw_invalid_scope($names,@path) {

  my $p=(@path) ? join q[/],@path : $NULLSTR;
  my $s=join q[,],map {$p.'/%s'} @$names;

  errout(

    q[No valid container for decls ]."<$s>",

    args => [@$names],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
# register decls to current scope

sub bind_decls($self,$width,$names,$values) {

  # ctx
  my $mach = $self->{mach};
  my $rom  = $self->inside_ROM();

  # dst
  my $ptrs=[];

  # iter
  while(@$names && @$values) {

    my $name  = shift @$names;
    my $value = shift @$values;

    # reparse element after macro expansion
    $self->value_expand(\$value);

    # set ctx attrs
    $value->{id}    = $name;
    $value->{width} = $width;
    $value->{const} = $rom;

    # write to mem
    my $ptr=$mach->bind($value);
    push @$ptrs,$ptr;

  };

  return $ptrs;

};

# ---   *   ---   *   ---
# in/out ctl

  rule('~<io-type>');
  rule('$<io> &rdio io-type ptr-decl');

# ---   *   ---   *   ---
# ^forks

sub rdio($self,$branch) {

  state $table={
    io  => undef,

    out => undef,
    in  => 'rdin',

  };

  my @lv    = @{$branch->{leaves}};
  my $class = $self->{frame}->{-class};

  my $st={
    type  => $lv[0]->leaf_value(0),
    value => $lv[1],

  };

  $branch->{value}=$st;
  $branch->clear_nproc();

  $branch->fork_chain(
    dom  => $class,
    name => $table->{$st->{type}},

  );

};

# ---   *   ---   *   ---
# ^proc input

sub rdin_opz($self,$branch) {

  my $st=$branch->{value};
  my $ar=$st->{value};

  $branch->{value}=$ar->{value};

};

sub rdin_run($self,$branch) {

  for my $ptr(@{$branch->{value}}) {
    $$ptr->{raw}=$self->{mach}->stkpop();

  };

};

# ---   *   ---   *   ---
# aliasing

  rule('%<lis-key=lis>');
  rule('$<lis> lis-key value value');

# ---   *   ---   *   ---
# ^post-parse

sub lis($self,$branch) {

  my $lv    = $branch->{leaves};

  my $name  = $lv->[1]->leaf_value(0);
  my $value = $lv->[2]->leaf_value(0);

  my $o={
    to   => $name,
    from => $value,

  };

  $branch->{value}=$o;
  $branch->clear();

};

# ---   *   ---   *   ---
# ^context build

sub lis_ctx($self,$branch) {

  my $st    = $branch->{value};
  my $mach  = $self->{mach};

  my $key   = $st->{to};
     $key   = "$key->{raw}";

  $mach->lis($key,$st->{from});

};

# ---   *   ---   *   ---
# buffered IO

  rule('%<sow-key=sow>');
  rule('%<reap-key=reap>');

  rule('<sow> sow-key invoke vlist');
  rule('<reap> reap-key invoke');

# ---   *   ---   *   ---
# ^post-parse

sub sow($self,$branch) {

  # convert {invoke} to plain value
  $self->invokes_solve($branch);

  # ^dissect tree
  my $lv    = $branch->{leaves};
  my $value = $lv->[1]->leaf_value(0);
  my @vlist = $lv->[2]->branch_values();

  $branch->{value}={

    fd    => $value,
    vlist => \@vlist,

    const => [],

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^bind values

sub sow_opz($self,$branch) {

  my $st=$branch->{value};

  # get fd is const
  $self->io_const_fd($st);

  # ^same for args
  @{$st->{const_vlist}}=map {
    $self->const_deref($ARG);

  } @{$st->{vlist}};

  my $i=0;map {

    $ARG=(defined $st->{const_vlist}->[$i++])
      ? undef
      : $ARG
      ;

  } @{$st->{vlist}};

};

# ---   *   ---   *   ---
# get file descriptor is const

sub io_const_fd($self,$st) {

  my $mach=$self->{mach};

  $st->{const_fd}=
    $self->const_deref($st->{fd});

  # ^it is, get handle
  if($st->{const_fd}) {

    ($st->{fd},$st->{buff})=$mach->fd_solve(
      $st->{const_fd}->deref()

    );

  };

};

# ---   *   ---   *   ---
# ^exec

sub sow_run($self,$branch) {

  my $mach = $self->{mach};
  my $st   = $branch->{value};

  my @path = $mach->{scope}->path();

  # get message
  my $s=$NULLSTR;
  my $i=0;

  map {

    my $x=(! defined $ARG)
      ? $self->deref($st->{vlist}->[$i])
      : $ARG
      ;

    $s.=(Mach::Value->is_valid($x))
      ? $x->{raw}
      : $x
      ;

    $i++;

  } @{$st->{const_vlist}};

  # ^write to dst
  my ($fd,$buff);
  if($st->{const_fd}) {

    $fd   = $st->{fd};
    $buff = $st->{buff};

    $$buff.=$s;

  } else {
    $fd=$self->deref($st->{fd})->{raw};
    $mach->sow($fd,$s);

  };

};

# ---   *   ---   *   ---
# ^similar story, flushes buffer writes

sub reap($self,$branch) {

  # convert {invoke} to plain value
  $self->invokes_solve($branch);

  # ^dissect tree
  my $lv=$branch->{leaves};
  my $fd=$lv->[1]->leaf_value(0);

  $branch->{value}={fd=>$fd};
  $branch->clear();

};

# ---   *   ---   *   ---
# ^binding

sub reap_opz($self,$branch) {
  my $st=$branch->{value};
  $self->io_const_fd($st);

};

# ---   *   ---   *   ---
# ^exec

sub reap_run($self,$branch) {

  my $mach = $self->{mach};
  my $st   = $branch->{value};

  # ^write to dst
  my ($fd,$buff);
  if($st->{const_fd}) {

    $fd   = $st->{fd};
    $buff = $st->{buff};

    print {$fd} $$buff;
    $fd->flush();

    $$buff=$NULLSTR;

  } else {
    $fd=$self->deref($st->{fd})->{raw};
    $mach->reap($fd);

  };

};

# ---   *   ---   *   ---
# switch flips

  rule('~<wed-type>');
  rule('$<wed> wed-type flg-list');



# ---   *   ---   *   ---
# pop current block

  rule('%<ret-key=ret>');
  rule('<ret> ret-key opt-nterm');

# ---   *   ---   *   ---

sub ret_ctx($self,$branch) {

  my $mach = $self->{mach};
  my $n    = 1;

  $mach->{scope}->ret($n);

};

# ---   *   ---   *   ---
# procedure calls

  rule('%<call-key=call>');
  rule('<call> call-key value vlist');

# ---   *   ---   *   ---
# ^post-parse

sub call($self,$branch) {

  my $st=$branch->bhash(0,1);
  $branch->clear();

  $branch->{value}={
    fn   => [(split $REGEX->{nsop},$st->{value})],
    args => $st->{values},

  };

};

# ---   *   ---   *   ---
# ^optimize

sub call_opz($self,$branch) {

  my $mach  = $self->{mach};
  my $st    = $branch->{value};

  my @path  = $mach->{scope}->path();
  my $procr = $mach->{scope}->search(

    (join q[::],@{$st->{fn}},q[$branch]),
    @path,

  );

  $st->{fn}=$$procr;

  for my $arg(@{$st->{args}}) {
    next if ! ($arg=~ m[^$REGEX->{bare}$]);
    $mach->{scope}->cderef(1,\$arg,@path);

  };

};

# ---   *   ---   *   ---
# ^exec

sub call_run($self,$branch) {

  my $st   = $branch->{value};

  my $fn   = $st->{fn};
  my @args = @{$st->{args}};

  for my $arg(reverse @args) {
    $self->{mach}->stkpush($arg);

  };

  unshift @{$self->{callstk}},
    $fn->shift_branch(keepx=>1);

};

# ---   *   ---   *   ---
# groups

  # default F
  rule('|<bltn> &clip sow reap');
  rule('|<cdef> &clip def redef undef');

  # non-terminated
  rule('|<meta> &clip lcom');

  # ^else
  rule(q[

    |<needs-term-list>
    &clip

    header hier sdef
    wed cdef lis

    re io ptr-decl

    switch jmp rept bltn

  ]);

  rule(q[

    <needs-term>
    &clip

    needs-term-list term

  ]);

# ---   *   ---   *   ---
# ^generate parser tree

  our @CORE=qw(meta needs-term);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
# test

  my $src=$ARGV[0];
  $src//='lps/peso.rom';

  my $prog=($src=~qr{\.rom$})
    ? orc($src)
    : $src
    ;

  return if ! $src;

  $prog =~ m[([\S\s]+)\s*STOP]x;
  $prog = ${^CAPTURE[0]};

  my $ice=Grammar::peso->parse($prog);

#  $ice->{p3}->prich();
  $ice->{mach}->{scope}->prich();


#  $ice->run(
#
#    entry=>1,
#    keepx=>1,
#
#    input=>[
#
#      'hey',
#
#    ],
#
#  );

# ---   *   ---   *   ---
1; # ret
