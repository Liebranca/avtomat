#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:LX CMD
# Implements command-maker
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::lx::cmd;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use rd::lx::common;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# keyword table

sub cmdset($class,$ice) { return (
  cmd        => [$BARE,$OPT_VLIST,$CURLY],
  'bat-cmd'  => [$PARENS,$OPT_VLIST,$CURLY],

)};

# ---   *   ---   *   ---
# makes new command!

sub cmd_parse($self,$branch) {

  # get ctx
  my $main  = $self->{main};
  my $mc    = $main->{mc};

  my $scope = $mc->{scope};
  my $path  = $mc->{path};


  # unpack
  my ($name,$args,$body)=
    @{$branch->{leaves}};


  # redecl guard
  $name=$name->{value};
  $self->throw_redecl('user command'=>$name)
  if $scope->has(@$path,'UCMD',$name);


  # ^collapse optional
  if(! defined $body) {
    $body=$args;
    $args=undef;

  };


  # have arguments?
  $args=($args)
    ? $self->argread($args,$body)
    : []
    ;


  # make table for ipret
  my $cmdtab={

    name   => $name,
    body   => $body,

    args   => $args,

  };

  # ^save to current namespace and remove branch
  $scope->decl($cmdtab,@$path,'UCMD',$name);
  $branch->discard();

  my $CMD=$self->load_CMD(1);

  use Fmat;
  fatdump(\$CMD);

  exit;

};

# ---   *   ---   *   ---
# ^errme

sub throw_redecl($self,$type,$name) {

  $self->{main}->perr(
    "re-declaration of %s '%s'",
    args=>[$type,$name]

  );

};


# ---   *   ---   *   ---
# prepares a table of arguments
# with default values and
# replacement paths into
# command body

sub argread($self,$args,$body) {

  my $main = $self->{main};
  my $l1   = $main->{l1};

  # got list or single elem?
  my $ar=(defined $l1->is_list($args->{value}))
    ? $args->{leaves}
    : [$args]
    ;


  # make argsfield
  my $idex = 0;
  my $tab  = [ map {


    # [name => default value]
    my $argname = $ARG->{value};
    my $defval  = undef;


    # have default value?
    my $opera=$l1->is_opera($ARG->{value});

    # ^yep
    if(defined $opera && $opera eq '=') {

      ($argname,$defval)=(
        $ARG->{leaves}->[0]->{value},
        $ARG->{leaves}->[1]

      );

    };


    # make replacement paths
    # this helps insert value later
    my $replpath = [];
    my @pending  = $body;

    my $subst    = "\Q$argname";
    my $subststr = "\%$subst\%";
       $subst    = qr{\b(?:$subst)\b};
       $subststr = qr{(?:$subststr)};

    my $place    = ":__ARG[$idex]__:";
    my $replre   = qr"\Q$place";


    # recursive walk tree of body
    while(@pending) {

      my $nd=shift @pending;

      # have string?
      my $re=(defined $l1->is_string($nd->{value}))
        ? $subststr
        : $subst
        ;


      if($nd->{value}=~ s[$re][$place]) {
        my $path=$nd->ancespath($body);
        push @$replpath,$path;

      };

      unshift @pending,@{$nd->{leaves}};

    };

    $idex++;


    # give argname => argdata
    $argname=>{

      repl   => {
        path => $replpath,
        re   => $replre,

      },

      defval => $defval,

    };


  } @$ar ];


  $args->discard();

  return $tab;

};

# ---   *   ---   *   ---
# consume argument nodes for command

sub argsume($self,$branch) {


  # skip if nodes parented to branch
  # or parent is invalid
  my @lv  = @{$branch->{leaves}};
  my $par = $branch->{parent};

  return if @lv ||! $par;


  # get siblings, skip if none
  my @sib=@{$par->{leaves}};
     @sib=@sib[$branch->{idex}+1..$#sib];

  return if ! @sib;


  # get command meta
  my $main = $self->{main};

  my $CMD  = $self->load_CMD();
  my $key  = $main->{branch}->{cmdkey};
  my $args = $CMD->{$key}->{-args};
  my $pos  = $branch->{idex}+1;


  # walk siblings
  $main->{branch}=$par;

  for my $arg(@$args) {

    my $have=$self->argtypechk($arg,$pos);

    throw_badargs($self,$key,$arg,$pos)
    if ! $have &&! $arg->{opt};

    $pos++ if $have;

    $branch->pushlv($have);

  };


  # restore old
  $main->{branch}=$branch;
  return;

};

# ---   *   ---   *   ---
# type-checks command arguments

sub argchk($self) {


  # get command meta
  my $main = $self->{main};

  my $CMD  = $self->load_CMD();
  my $key  = $main->{branch}->{cmdkey};
  my $args = $CMD->{$key}->{-args};
  my $pos  = 0;


  # walk child nodes and type-check them
  for my $arg(@$args) {

    my $have=$self->argtypechk($arg,$pos);

    throw_badargs($self,$key,$arg,$pos)
    if ! $have &&! $arg->{opt};

    $pos++ if $have;

  };

};

# ---   *   ---   *   ---
# ^guts, looks at single
# type option for arg

sub argtypechk($self,$arg,$pos) {


  # get anchor
  my $main = $self->{main};
  my $l1   = $main->{l1};

  my $nd   = $main->{branch};


  # walk possible types
  for my $type(@{$arg->{type}}) {

    # get pattern for type
    my $re=$l1->tagre($type => $arg->{value});

    # return true on pattern match
    my $chd=$nd->{leaves}->[$pos];
    return $chd if $chd && $chd->{value}=~ $re;

  };


  return 0;

};

# ---   *   ---   *   ---
# ^errme

sub throw_badargs($self,$key,$arg,$pos) {

  my $main  = $self->{main};

  my $value = $main->{branch}->{leaves};
     $value = $value->[$pos]->{value};

  my @types = @{$arg->{type}};


  $main->perr(

    "invalid argtype for command '%s'\n"
  . "position [num]:%u: '%s'\n"

  . "need '%s' of type "
  . (join ",","'%s'" x int @types),

    args=>[$key,$pos,$value,$arg->{value},@types],

  );

};

# ---   *   ---   *   ---
1; # ret
