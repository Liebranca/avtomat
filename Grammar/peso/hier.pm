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
# info

  our $VERSION = v0.00.2;#b
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

  );

  Readonly my $PE_HIER=>[qw(
    clan reg rom proc blk

  )];

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    q[ellipses]  => qr{\x{20}*\.\.\.\s*;\n?},

    q[hier-key]  => re_pekey(@$PE_HIER),
    q[nhier-key] => re_npekey(@$PE_HIER),

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

  # ^filter out cleared
  my @path=grep {$ARG} map {
    $f->{$ARG}

  } qw(-cclan -creg -crom -cproc -cblk);


  # ^reset path
  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  $scope->path(@path);


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

    type  => $type,

    name  => $name,
    body  => $NULLSTR,

    beqs  => [],
    flptr => {},

    oidex => $branch->{idex},

  };

  $branch->{value}=$st;
  $branch->{leaves}->[0]->discard();

};

# ---   *   ---   *   ---
# make flag fields for
# current scope

sub hier_flags_nit($self,$branch) {

  my $st    = $branch->{value};
  my $ptr   = $st->{flptr};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};
  my @path  = $scope->path();

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
    $ptr->{$ARG}->set($value);

  } keys %$ptr;

};

# ---   *   ---   *   ---
# step-on

sub hier_walk($self,$branch) {
  $self->hier_path($branch);
  $self->hier_flags($branch);

};

sub hier_run($self,$branch) {
  $self->hier_walk($branch);

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
    $branch,@$PE_HIER

  );

  # ^get full list of inherited
  my @extern=map {

    $self->hier_beq_expand(
      $tab,$ARG

    )

  } @$PE_HIER;

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

  } @$PE_HIER;


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
      $src,@$PE_HIER

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
# calls preproc F for all
# nodes in hierarchy

sub hier_proc($self,$branch,$o,@args) {

  my $mach    = $self->{mach};
  my @pending = ($branch);

  while(@pending) {

    my $nd=shift @pending;
    my $st=$nd->{value};

    $self->hier_walk($nd);
    $st->{body}=$o->recurse(

      $st->{body},
      @args,

      mach=>$mach,

    );

    unshift @pending,@{$nd->{leaves}};

  };

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
# make a parser tree

  our @CORE=qw(hier beq nhier);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
