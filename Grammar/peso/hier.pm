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

  use lib $ENV{'ARPATH'}.'/lib/';

  use Grammar;
  use Grammar::peso::std;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
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

    -chier_t => 'clan',
    -chier_n => 'non',

  );

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    q[hier-key]=>re_pekey(qw(
      reg rom clan proc

    )),

  };

# ---   *   ---   *   ---
# parser rules

  rule('~<hier-key>');
  rule('$<hier> hier-key nterm term');

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
  $branch->init($name);

};

# ---   *   ---   *   ---
# forks accto hierarchical type

sub hier_ctx($self,$branch) {

  my $name=$branch->leaf_value(0);
  my $type=$branch->{value};

  # ^re-repack ;>
  $branch->{value}={

    type  => $type,

    name  => $name,
    flptr => {},

  };

  $branch->clear();


  # reset path
  my @path=$self->hier_path($branch,1);
  $self->hier_flags_nit($branch);

  # initialize block
  $self->hier_sort($branch);

  # ^save pointer to branch
  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  @path=grep {$ARG ne '$DEF'} @path;
  $scope->decl_branch($branch,@path);

};

# ---   *   ---   *   ---
# alters current path when
# stepping on a hierarchical

sub hier_path($self,$branch,$clear=0) {

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


  # ^get clear/set from table
  my ($unset,$set)=$self->hier_path_tab($type);

  # ^apply
  map {$f->{$ARG}=undef} (@$unset) x $clear;
  my @path=grep {$ARG} map {$f->{$ARG}} @$set;

  # ^reset path
  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  $scope->path(@path,$name);


  return @path;

};

# ---   *   ---   *   ---
# ^get path keys to clear/set

sub hier_path_tab($self,$type) {

  state $tab=[

    # rom
    [ [qw(-creg -cproc)],
      [qw(-cclan)],

    ],

    # reg
    [ [qw(-crom -cproc)],
      [qw(-cclan)],

    ],

    # clan
    [ [qw(-creg -crom -cproc)],
      [qw()],

    ],

    # proc
    [ [qw()],
      [qw(-cclan -creg -crom)]

    ],

  ];


  # get index of type into table
  my $idex=
    (($type eq 'reg' ) * 1)
  | (($type eq 'clan') * 2)
  | (($type eq 'proc') * 3)
  ;


  return @{$tab->[$idex]};

};

# ---   *   ---   *   ---
# get children nodes of a hierarchical
# performs parenting

sub hier_sort($self,$branch) {

  state $re=qr{^(?:reg|rom)$};


  # alter type for tree search
  my $type=$self->{frame}->{-chier_t};

  $type=($type=~ $re)
    ? q[(?:reg|rom)]
    : $type
    ;

  # ^get child nodes
  my @out=$branch->match_up_to(
    qr{^$type$}

  );

  $branch->pushlv(@out);

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
# do not make a parser tree!

  our @CORE=qw();

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
