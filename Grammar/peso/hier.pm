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
    q[hier-key]  => re_pekey(@$PE_HIER),
    q[nhier-key] => re_npekey(@$PE_HIER),

  };

# ---   *   ---   *   ---
# parser rules

  rule('~<hier-key>');
  rule('$<hier> hier-key nterm term');

  rule('~<nhier-key>');
  rule('$<nhier> nhier-key nterm term');

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

  my $ckey = "-c$type";

  # ^reset ctx
  $f->{-chier_t} = $type;
  $f->{-chier_n} = $name;
  $f->{$ckey}    = $name;


  # ^get fields to clear
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

    flptr => {},

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
# make a parser tree

  our @CORE=qw(hier nhier);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
