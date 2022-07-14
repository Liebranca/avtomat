#!/usr/bin/perl
# ---   *   ---   *   ---
# INLINE
# None of you dared
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

package inline;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use Carp;
  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/hacks/';

  use parent 'lyfil';
  use shwl;

  use lib $ENV{'ARPATH'}.'/lib';
  use style;
  use arstd;

#  use Filter::Util::Call;

# ---   *   ---   *   ---
# ROM

  Readonly our $CREATE_SCOPE=>0x01;

# ---   *   ---   *   ---
# global state

  my $TABLE={};
  my $PARENS_RE=shwl::delm(q[(],q[)]);

# ---   *   ---   *   ---

sub decl_args($rd,@args) {

  my $nd_frame=$rd->{program}->{node};
  my $block=$rd->{curblk};

  my $branch=$block->{tree};
  my $id=$block->{name};
  my $i=0;

# ---   *   ---   *   ---

  for my $argname(@args) {

    $argname=~ s/^([\$\@\%]+)//sg;
    my $original=$argname;

    if(!defined ${^CAPTURE[0]}) {

      arstd::errout(
        "Can't match sigil for var %s\n",

        args=>[$original],
        lvl=>$FATAL,

      );

    };

# ---   *   ---   *   ---

    my $sigil=${^CAPTURE[0]};

    my $arg=sprintf $shwl::ARG_FMAT,$i;
    my $nd=$nd_frame->nit(

      $branch,
      "my \$inlined_${id}_$argname=$arg;",

      unshift_leaves=>1,

    );

    $i++;

  };

};

# ---   *   ---   *   ---

sub repl_args($order,@args) {

  my %tab;
  my @order=@$order;

# ---   *   ---   *   ---

  for my $node(@args) {
    my $key=$node->{value};

# ---   *   ---   *   ---

    if(!exists $tab{$key}) {
      $tab{$key}=[$node];

# ---   *   ---   *   ---

    } else {
      push @{$tab{$key}},$node;

    };

  };

# ---   *   ---   *   ---

  my $i=0;
  for my $arg(@order) {

    my $key=$arg->{name};

    goto TAIL if !exists$tab{$key};
    my @nodes=@{$tab{$key}};

# ---   *   ---   *   ---

    for my $node(@nodes) {
      $node->{value}=":__ARG_${i}__:";

    };

# ---   *   ---   *   ---

TAIL:
    $i++;

  };

};

# ---   *   ---   *   ---

sub rename_args($rd,@args) {

  my $block=$rd->{curblk};
  my $id=$block->{name};

# ---   *   ---   *   ---

  for my $mention(@args) {

    my $key=$mention->{value};

    $key=~ s/^([\$\@\%]+)//sg;

# ---   *   ---   *   ---

    if(!defined ${^CAPTURE[0]}) {
      die "Can't match sigil";

    };

# ---   *   ---   *   ---

    my $sigil=${^CAPTURE[0]};

    $mention->{value}=$sigil.
      "inlined_${id}_$key";

  };

};

# ---   *   ---   *   ---

sub process_block($rd,$pkgname) {

  my $block=$rd->{curblk};
  my $branch=$block->{tree};
  my $nd_frame=$rd->{program}->{node};

# ---   *   ---   *   ---
# default strategy is plain paste the code

  $block->{inline_strat}=0;
  my $strat=\$block->{inline_strat};

  $rd->recurse($branch);

# ---   *   ---   *   ---
# find assignment operations

  my ($order,@args)=$rd->find_args();
  my %args_asg=$rd->find_asg_ops(@args);

  $block->{argc}=int(@$order);
  $block->{ob_argc}=0;

# ---   *   ---   *   ---
# handle arg data

  for my $arg(@$order) {
    $block->{ob_argc}+=
      !defined $arg->{default};

  };

  $block->{args}=$order;

# ---   *   ---   *   ---
# assignment to args means we
# need to create a separate scope

  my @keys=keys %args_asg;
  if(@keys) {

    $$strat|=$inline::CREATE_SCOPE;
    decl_args($rd,@keys);

    rename_args(

      $rd,
      map {@{$ARG}} values %args_asg

    );

  };

  repl_args($order,@args);

# ---   *   ---   *   ---
# handle return values

  my @rets=$branch->branches_in(qr{^return$});

  for my $ret(@rets) {

    if($$strat & $inline::CREATE_SCOPE) {
      $ret->{value}=$shwl::RET_STR;

      $nd_frame->nit(
        $ret,q{=},
        unshift_leaves=>1,

      );

# ---   *   ---   *   ---

    } else {

      if($branch->leaf_value(-1) eq q{;}) {
        $branch->pluck($branch->{leaves}->[-1]);

      };

      $ret->flatten_branch();

    };

# ---   *   ---   *   ---

  };

  $rd->replstr($branch);
  $block->{inline_code}=$branch->flatten();

  $TABLE->{$pkgname.q{::}.$block->{name}}=$block;

};
# ---   *   ---   *   ---

sub make_table_re() {

  if(exists $TABLE->{re}) {
    delete $TABLE->{re};

  };

  my @names=sort {
    (length $a)<=(length $b)

  } keys %$TABLE;

  if(!@names) {
    arstd::errout(
      "Empty inlined symbol table\n",
      lvl=>$WARNING,

    );

  };

  my $re=q{\b(?<name>}.(join q{|},@names).q{)\b}.
    q{\s*\(\s* (?<args> .*?) \s*\)\s*};

  $TABLE->{re}=qr{$re}xs;

};

# ---   *   ---   *   ---

sub inspect($rd) {

  my $block=$rd->select_block('-ROOT');
  my $tree=$block->{tree};

  $rd->recurse($tree);

# ---   *   ---   *   ---

  while(

  my $branch=
    $tree->branch_in($TABLE->{re})

  ) {

    $branch->{value}=~ s/$TABLE->{re}/#:cut_fn;>/;

    my $id=$+{name};
    my $args=$+{args};

    my $block=$TABLE->{$id};
    my $code=$block->{inline_code};

    my @args=solve_args($block,\$code,$args);
    my @dst=solve_dst($rd,$block,$branch);

    apply_strategy(

      $block,
      $branch,
      $code,

      args=>\@args,
      dst=>\@dst,

    );

  };

# ---   *   ---   *   ---

  my $s=$tree->flatten();

  print "$s\n";
  print eval("$s")."\n";

};

# ---   *   ---   *   ---

sub solve_args($block,$code,$args) {

  my @passed_args=();
  my $errme=$NULLSTR;

  if(length $args) {

    @passed_args=split m/\s*,\s*/,$args;

# ---   *   ---   *   ---
# errchk

    if(@passed_args<$block->{ob_argc}) {
      $errme='Insufficient arguments';
      goto ERR;

    } elsif(@passed_args>$block->{argc}) {
      $errme='Too many arguments';
      goto ERR;

    };

# ---   *   ---   *   ---
# put default values

    my $i=0;
    for my $arg(@{$block->{args}}) {

      if(!defined $passed_args[$i]) {
        push @passed_args,$arg->{default};

      };

      $i++;

    };

# ---   *   ---   *   ---
# errchk

  } elsif($block->{argc}) {
    $errme='Insufficient arguments';
    goto ERR;

  };

# ---   *   ---   *   ---
# replace mentions

  my $i=0;
  for my $arg(@passed_args) {

    my $arg_re=sprintf $shwl::ARG_FMAT,$i;
    $arg_re=qr{$arg_re}x;

    $$code=~ s/$arg_re/$arg/sg;
    $i++;

  };

  return @passed_args;

# ---   *   ---   *   ---
# jump of utter failure

ERR:

  arstd::errout(
    "$errme for %s\n",

    args=>[$block->{name}],
    lvl=>$FATAL,

  );

};

# ---   *   ---   *   ---

sub solve_dst($rd,$block,$branch) {

  my $line=$branch->{value};
  my $dst_re=$rd->{lang}->{ptr_asg};

  my $decl=$NULLSTR;
  my $dst=$NULLSTR;
  my $asg=$NULLSTR;

# ---   *   ---   *   ---

  if($line=~ s/($dst_re)/#:cut_dst;>/) {

    if($+{is_decl}) {

      $decl=$+{keyw};

      $dst.=$+{sigil};
      $dst.=$+{name};

      $dst.=(defined $+{attrs})
        ? $+{attrs}
        : $NULLSTR
        ;

      $asg=$+{asg_op};

# ---   *   ---   *   ---

    } elsif($+{is_defn}) {
      arstd::nyi('non-decl dst for inline subs');

    } else {
      arstd::nyi('void context for inline subs');

    };

# ---   *   ---   *   ---

  };

  $branch->{value}=$line;
  return ($decl,$dst,$asg);

};

# ---   *   ---   *   ---

sub apply_strategy($block,$branch,$code,%data) {

  my $is_conditional=
    $branch->{parent}->{value}=~
    m/(?: elsif|if)/x

  ;

  my $create_scope=
    ($block->{inline_strat} & $CREATE_SCOPE)!=0;

  my $gran=$branch->{parent}->{parent};

  my @args=@{$data{args}};
  my @dst=@{$data{dst}};

# ---   *   ---   *   ---

  if($is_conditional) {

    my $idex=$gran->{idex};

    $gran->insert(
      $gran->{idex},
      '#:cut_dst;>#:cut_fn;>'

    );

    $branch->{value}=~ s/\#\:cut_fn;>//;

    my $node=$gran->{leaves}->[$idex];
    my $dst=join q{ },@dst[0..1];

    my $asg=(!$create_scope)
      ? $dst[2]
      : q{;}
      ;

    $code=~ s/$shwl::RET_RE/$dst[1]/;

    $node->{value}=~ s/\#\:cut_fn;>/\{$code\}/;
    $node->{value}=~ s/\#\:cut_dst;>/$dst$asg/;
    $branch->{value}=~ s/\#\:cut_dst;>/$dst[1]/;

# ---   *   ---   *   ---

  } else {
    arstd::nyi('inlining outside conditional');

  };

};

# ---   *   ---   *   ---

#sub code_emit {
#
#  my ($self)=@_;
#
#  for my $fn(@{$self->{data}}) {
#
#    my $str=shwl::STRINGS->{$fn};
#
#    if(!($str=~ $TABLE->{re})) {
#      next;
#
#    };
#
#    my $symname=${^CAPTURE[0]};
#    my $sbl=$TABLE->{$symname};
#
## ---   *   ---   *   ---
## fetch args
#
#    my @args=();
#    if($str=~ m/($PARENS_RE)/s) {
#      @args=split m/,/,${^CAPTURE[0]};
#
#    };
#
## ---   *   ---   *   ---
## expand symbol and insert
#
#    my $code=$sbl->paste(@args);
#    $str=~ s/${symname}$PARENS_RE/$code/;
#
#    shwl::STRINGS->{$fn}=$str;
#
## ---   *   ---   *   ---
#
#  };
#
#};
#
## ---   *   ---   *   ---
#
#sub import {
#
#  my ($pkg,$fname,$lineno)=(caller);
#  my $self=lyfil::nit($fname,$lineno);
#
#  if($self!=$NULL) {
#    $TABLE=shwl::getlibs();
#    filter_add($self);
#
#  };
#
#};
#
## ---   *   ---   *   ---
#
#sub unimport {
#  filter_del();
#
#};
#
## ---   *   ---   *   ---
#
#sub filter {
#
#  my ($self)=@_;
#
#  my ($pkg,$fname,$lineno)=(caller);
#  my $status=filter_read();
#
#  $self->logline(\$_);
#
#  my $matches=shwl::cut(
#    \$self->{chain}->[0]->{raw},
#
#    "INLINE",
#
#    $TABLE->{re},
#
#  );
#
#  push @{$self->{data}},@$matches;
#  return $status;
#
#};

# ---   *   ---   *   ---
1; # ret
