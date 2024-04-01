#!/usr/bin/perl
# ---   *   ---   *   ---
# DD
# Data declarations
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package ipret::cmdlib::dd;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'rd::cmd';
  BEGIN {rd::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# shorthand: fetch flag table

sub flagtab($self) {

  my $main  = $self->{main};
  my $mc    = $main->{mc};

  my $flags = $mc->{bk}->{flags};


  return $flags->ivtab();

};

# ---   *   ---   *   ---
# set/unset object flags

cmdsub 'flag-type' => q(opt_qlist) => q{


  # get ctx
  my $main  = $self->{frame}->{main};
  my $links = $self->{links};
  my $obj   = pop @$links;

  my $tab   = $self->flagtab();
  my $flags = $branch->{vref};


  # walk list
  map {


    # can set attr for this object?
    my ($key,$value)=@{$tab->{$ARG}};

    eval {

      (exists $obj->{$key})
        ? $obj->{$key}=$value
        : undef
        ;


    # ^nope, throw!
    } or do {

      $main->perr(
        "'%s' is invalid for <%s>",
        args=>[$ARG,(ref $obj or 'plain')]

      );

    };


  } @$flags;


  $branch->flatten_branch();

  return 1;

};

# ---   *   ---   *   ---
# step on segment

cmdsub 'seg-type' => q() => q{


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};

  # get segment name and type
  my $data = $branch->{vref};
  my $name = $data->{name};
  my $type = $data->{type};


  # scoping or making new?
  my $mem  = $mc->{cas};
  my $have = $mem->haslv($name);

  # ^making new, decl and set flags
  if(! $have) {

    $have=$mem->new(0x10,$name);

    $have->{writeable}  = int($type=~ qr{^ram$});
    $have->{executable} = int($type=~ qr{^exe$});

  };


  # make current and give
  $mc->setseg($have);

  return $have;

};

# ---   *   ---   *   ---
# shorthand: make sense of value branch!

sub value_solve($self,$value) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $eng  = $main->{engine};


  # can solve value now?
  my $have=$eng->value_solve($value);

  # ^give zero on nope
  my $x=(! length $have)
    ? $l1->make_tag(NUM=>0)
    : $have
    ;


  return ($x,$have);

};

# ---   *   ---   *   ---
# reserve memory and solve values
# re-run if not all values solved!

cmdsub 'data-decl' => q() => q{


  # get ctx
  my $main  = $self->{frame}->{main};
  my $mc    = $main->{mc};
  my $l1    = $main->{l1};

  my $scope = $mc->{scope};

  # get pending values
  my $data = $branch->{vref};
  my $type = $data->{type};
  my $list = $data->{list};


  # walk values pending resolution
  my @have = map {


    # unpack
    my ($name,$value)=@$ARG;


    # *attempt* solving
    my ($x,$have)=
      $self->value_solve($value);

    $x=$l1->quantize($x);


    # have ptr?
    my ($ptr_t) = Type->is_ptr($type);

    # ^sanity check
    my $ptrcls   = $mc->{bk}->{ptr};
    my $have_ptr = $ptrcls->is_valid($x);

    if($have_ptr &&! $ptr_t) {

      $main->perr(

        "'%s' is not a pointer type",
        args=>[$type->{name}]

      );

    };


    # assume declaration on first pass
    if(! $main->{pass}) {

      $main->throw_redecl('value',$name)
      if $scope->has($name);

      $mc->decl($type,$name,$x);


    # ^else we're retrying value resolution
    } elsif($have) {


      # fetch value
      my $ref = $mc->psearch($name);
      my $mem = $$ref->getseg();

      my $x   = $l1->quantize($x);


      # overwrite value
      $$ref = $mem->infer(

        $x,

        ptr_t => $ptr_t,
        type  => $type,

        label => $name,
        addr  => $$ref->{addr},

      );

    };


    (! defined $have) ? $ARG : () ;

  } @$list;


  # wait for next pass if values pending
  # else discard branch
  if(@have) {
    @$list=@have;
    return $branch;


  } else {
    $branch->discard();
    return;

  };

};

# ---   *   ---   *   ---
1; # ret
