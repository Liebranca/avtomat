#!/usr/bin/perl
# ---   *   ---   *   ---
# C
# Don't cast the RET of malloc!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Tree::C;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_arrayref is_hashref);

  use Arstd::String qw(
    strip
    gstrip
    gsplit
    has_prefix
  );
  use Arstd::throw;
  use Ftype::Text;

  use parent 'Tree';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.4a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# entry point

sub rd {
  # make a new branch to begin parsing on
  my $class = shift;
  my $self  = (ref $class)
    ? $class->nest('$:>')
    : $class->new()
    ;

  # tokenize strings and remove comments
  $self->strtok($_[0]);
  comstrip($_[0]);

  # parse source
  my @char = split '',$_[0];
  my $tok  = null;
  my $opr  = 0;

  for(@char) {
    if($ARG=~ qr{[\{\}]}) {
      $self->commit($tok);
      $self->branch($ARG);
      $tok=null;

    } elsif($ARG=~ qr{[[:alnum:]_]}) {
      if($opr) {
        $self->commit($tok);
        $opr  = 0;
        $tok  = null;
      };
      $tok .= $ARG;

    } else {
      my $term=$ARG eq ';';
      if(! $opr || $term) {
        $self->commit($tok);
        $tok=null;

        $self->commit(';') if $term;
      };

      if(! ($ARG=~ qr{\s+}) &&! $term) {
        $opr=1;
        $tok.=$ARG;
      };
    };
  };

  if(! is_null($tok)) {
    $self->commit($tok);
  };

  my $lv=$self->{leaves};
  if(@$lv && $lv->[-1]->{value} ne ';') {
    $self->commit(';');
  };

  return $self;
};


# ---   *   ---   *   ---
# cstruc

sub new {
  my $class=shift;

  if(Tree->is_valid($class)) {
    my $par=$class;
    return Tree::new($par,$_[0]);
  };

  my $self=Tree::new($class,'root');
  $self->{branch}=$self;
  $self->{string}=[];

  return $self;
};


# ---   *   ---   *   ---
# turns strings into tokens

sub strtok {
  my $self = (shift)->root();
  my $ar   = $self->{string};
  my $out  = null;
  my $tok  = null;
  my $end  = null;
  my $str  = 0;
  my $com  = 0;
  my $esc  = 0;
  my $i    = -1;
  my @char = split '',$_[0];

  for(@char) {
    ++$i;

    if(! $str) {
      if(
      # not a comment (yet)...
      !  $com

      # stepped on first comment char
      && $ARG eq '/'

      # and next char is also comment char
      && defined $char[$i+1]
      && $char[$i+1] eq '/'
      ) {
        # then we *are* in a comment!
        $com=1;

        # save whatever was left in the token
        $out .= $tok if ! is_null($tok);
        $tok  = null;

        next;

      # it is a comment, so skip until newline
      } elsif($com) {
        $com *= $ARG ne "\n";
        next;
      };
    };

    # start of string?
    if(! $str && ($ARG=~ qr{["']}) &&! $esc) {
      $out .= $tok;
      $tok  = $ARG;
      $end  = $ARG;
      $esc  = 0;
      $str  = 1;

    # ^inside string?
    } elsif($str && $ARG eq $end &&! $esc) {
      $out .= sprintf(strtok_fmat(),int(@$ar));
      push @$ar,"$tok$ARG";

      $str = 0;
      $esc = 0;
      $end = null;
      $tok = null;

    # ^escape next character?
    } elsif($ARG eq '\\') {
      $esc  = 1;
      $tok .= $ARG;

    # ^just a regular character
    } else {
      $esc  = 0;
      $tok .= $ARG;
    };
  };

  # terribly unhelpful error message ;>
  throw "Unterminated string!" if $str;

  # save whatever was left on the token
  # then overwrite the input string
  $out.=$tok;
  $_[0]=$out;

  return;
};

sub strtok_fmat {"__STRTOK_%i__"};
sub strtok_re   {qr{__STRTOK_(\d+)__}};


# ---   *   ---   *   ---
# ^undo

sub unstrtok {
  return 0 if is_null($_[1]);
  my $self = shift;
  my $re   = strtok_re();
  my $have = $self->root()->{string};

  while($have && ($_[0]=~ $re)) {
    my $s=$have->[$1];
    $_[0]=~ s[$re][$s];
  };

  return ! is_null($_[0]);
};


# ---   *   ---   *   ---
# removes whitespace and comments

sub comstrip {
  return 0 if is_null($_[0]);

  my $nl_re  = qr{\\?\n\s+};
  my $com_re = qr{//\s*};
  my $ws_re  = qr{\s+};

  $_[0]=~ s[$com_re][]gsm;
  $_[0]=~ s[$nl_re][ ]gsm;
  $_[0]=~ s[$ws_re][ ]gsm;

  return ! is_null($_[0]);
};


# ---   *   ---   *   ---
# adds token to current scope

sub commit($self,$tok) {
  return if is_null($tok);

  my $root=$self->root();
  return $root->{branch}->new($tok);
};


# ---   *   ---   *   ---
# handles enter/leave

sub branch($self,$c) {
  my $root = $self->root();
  my $nd   = $root->{branch}->new($c);
  if($c eq '{') {
    $root->{branch}=$nd;
  } else {
    $root->{branch}=$root->{branch}->{parent};
  };
  return;
};


# ---   *   ---   *   ---
# starts a new tree within self

sub nest($self,$tok) {
  my $root=$self->root();
  $root->{branch}=$root;

  my $nd=$self->commit($tok);
  $root->{branch}=$nd;

  return $nd;
};


# ---   *   ---   *   ---
# get copy of token tree as expression tree

sub to_exprtree($self) {
  my $out=ref($self)->new();
  $out->{string}=$self->{string};

  my $expr    = null;
  my $prev    = [];
  my @pending = (@{$self->{leaves}});
  while(@pending) {
    my $nd = shift @pending;
    my $c  = $nd->{value};

    if($c eq ';') {
      my $have=$out->commit("$expr");
      $expr=null;

    } else {
      if($c=~ qr{[\{\}]}) {
        next if $expr eq null;

        my $rec=$nd->to_exprtree();
        $rec->{value}=$expr;
        $out->pushlv($rec);
        $expr=null;

      } else {
        $expr.=(is_null($expr)) ? $c : " $c" ;
      };
    };
  };
  return $out;
};


# ---   *   ---   *   ---
# ^breaks down expressions for whole tree

sub to_expr {
  my ($self)=@_;
  my $tree=$self->to_exprtree();
  return $tree->to_expr_impl();
};

sub to_expr_impl {
  return map {
    $ARG->node_to_expr()

  } @{$_[0]->{leaves}};
};


# ---   *   ---   *   ---
# ^breaks down single expression

sub node_to_expr {
  # early exit?
  my ($nd) = @_;
  my $expr = $nd->{value};
  my @blk  = $nd->to_expr_impl();

  return {
    type => 'null',
    cmd  => null,
    expr => null,
    args => null,
    blk  => \@blk,

  } if is_null($expr);


  # patterns used to break down the expression
  my $name_re = Ftype::Text->name_re();
  my $cmd_re  = qr{^(?<cmd> $name_re)}x;
  my $args_re = qr{\((?<args>[^\)]*)\)$};
  my $asg_re  = qr{
    (?:[\|\&\^\+\-\/\*\%]|\s)
    = [^[:alnum:]]*
  }x;

  # asm/peso rules: first token is instruction
  # everything else is arguments!
  $expr=~ s[$cmd_re][];
  my $cmd    = $+{cmd};
     $cmd  //= null;

  # ^get first appearance of arguments
  my $have_args   = int($expr=~ s[$args_re][]);
  my $args        = $+{args};
     $args      //= null;

  strip($ARG) for $cmd,$expr,$args;

  my $type='expr';
  if(@blk && $have_args && ! is_null($expr)) {
    $type='proc';
    $args=[gsplit($args,qr{\s*,\s*})];

  } else {
    $expr .= "($args)" if $have_args;

    my $fctl_re=qr{^(?:
      if|elsif|else|while|do|switch
    )$}x;

    if($cmd=~ $fctl_re) {
      $type='fctl';

    } elsif($expr=~ $asg_re) {
      $type='asg';

    } elsif(has_prefix($expr,'#')) {
      $type='macro';

    } elsif(@blk && $cmd=~ qr{^(?:union|struct?)}) {
      $type='struc';
    };
  };

  return {
    type => $type,
    cmd  => $cmd,
    expr => $expr,
    args => $args,
    blk  => \@blk,
  };
};


# ---   *   ---   *   ---
# get [x=>int] from "int x =? value"
#
# [0]: mem  ptr  ; expression hashref
# [<]: byte pptr ; new [name=>type] array

sub decl_from_node {
  my ($nd)=@_;

  # first, get the entire expression and
  # split it at the assignment part if any
  my $full     = "$nd->{cmd} $nd->{expr}";
  my $asg_re   = qr{[\s\d\w](=[^=].+)};
  my ($lh,@rh) = ($nd->{type} eq 'asg')
    ? gsplit($full,$asg_re)
    : ($full,())
    ;

  # we don't actually use the right-hand side
  # right now, but we _may_ do so later
  #
  # anyway, convert the left-hand side to an
  # array so we can check whether this is
  # a value declaration
  return decl_from_code($lh);
};


# ---   *   ---   *   ---
# get [x=>int] from "int x"
#
# [0]: byte ptr  ; codestring
# [<]: byte pptr ; new [name=>type] array

sub decl_from_code {
  my @type=gsplit($_[0]);
  push @type,'void' if ! @type;

  my $name=pop @type;
  my $type=join ' ',grep {
    ! ($ARG=~ spec_re())

  } @type;

  return ($name ne 'void')
    ? ($name,$type)
    : ()
    ;
};


# ---   *   ---   *   ---
# pattern for matching specifiers
#
# [*]: const
# [<]: re

sub spec_re {
  return qr{(?:
    IX
  | CX
  | CIX
  | static
  | inline
  | const
  | public
  | typedef
  | struct
  | union
  )}x;
};


# ---   *   ---   *   ---
# get F data container from node

sub node_to_fn {
  my ($nd) = @_;
  my $fn   = {};

  # ^save data to dst
  my @args=@{$nd->{args}};
  my ($name,$type)=decl_from_node($nd);
  $fn->{name}    = $name;
  $fn->{type}    = $type;
  $fn->{argtype} = join(',',@args);
  $fn->{argname} = join(',',map {
    my ($name)=decl_from_code($ARG);
    (defined $name) ? $name : () ;

  } @args);

  return $fn;
};


# ---   *   ---   *   ---
# gives C code from expression array

sub expr_to_code($self,@ar) {
  my $out=$self->expr_to_code_impl(@ar);
  $self->unstrtok($out);

  return $out;
};
sub expr_to_code_impl($self,@ar) {
  state $lvl=0;
  my $pad='  ' x $lvl++;

  my $s=join "\n",map {
    # include <file.h> is effed as < file.h >
    # so catch that here
    if($ARG->{type} eq 'macro'
    && ($ARG->{expr}=~ qr{include})) {
      my $sysinc_re=qr{< (.+) >};
      $ARG->{expr}=~ s[$sysinc_re][<$1>]g;
    };

    my @blk=@{$ARG->{blk}};
    my $out=$pad . join ' ',gstrip(
      $ARG->{cmd},
      $ARG->{expr},
      (is_arrayref($ARG->{args}))
        ? '(' . join(',',@{$ARG->{args}}) . ')'
        : ()
        ,
    );

    my $lparens_re = qr{ *\( *};
    my $rparens_re = qr{ *\) *};
    my $comma_re   = qr{ *\, *};
    my $dot_re     = qr{ *\. *};
    $out=~ s[$lparens_re][(]g;
    $out=~ s[$rparens_re][)]g;
    $out=~ s[$comma_re][,]g;
    $out=~ s[$dot_re][.]g;

    if(int @blk) {
      my $blk  = $self->expr_to_code_impl(@blk);
      my $post = (exists $ARG->{_afterblk})
        ? "$ARG->{_afterblk};"
        : (($ARG->{type}=~ qr{^(?:proc|struc)}) ? ';' : null )
        ;

      if($ARG->{type} eq 'asg') {
        $blk   =~ s[;$][];
        $post .=  ';';
      };
      "$out\n${pad}{\n$blk\n${pad}}$post";

    } elsif($ARG->{type} eq 'macro') {
      "$out";

    } else {
      "$out;"
    };

  } grep {is_hashref($ARG)} @ar;

  --$lvl;
  return $s;
};


# ---   *   ---   *   ---
1; # ret
