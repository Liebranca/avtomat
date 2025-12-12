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
    cat
    strip
    gstrip
    gsplit
    has_prefix
    has_suffix
  );
  use Arstd::throw;
  use Arstd::fatdump;
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

  # get root to check flags
  my $root = $self->root();

  # parse source
  my @char = split '',$_[0];
  my $tok  = null;
  my $opr  = 0;
  my $cmd  = 1;

  while(@char) {
    my $c=shift @char;

    # inside body of macro?
    if( ($root->{flg} & flg_macro())
    &&! ($root->{flg} & flg_cblk())) {
      if($c eq '{') {
        $self->commit($tok);
        $self->branch($c);
        ++$root->{lvl};
        $tok=null;

      } elsif($c eq '}') {
        $self->commit($tok);
        $self->branch($c);
        --$root->{lvl};
        $tok=null;

      } elsif(($root->{lvl} <= $root->{plvl})
        &&    ($c eq ';')) {
        $root->{flg} &=~ flg_macro();
        $self->commit($tok);
        $self->branch('end macro');
        $self->commit(';');
        $tok=null;
        $cmd=1;

      } else {
        if($c eq ';') {
          $cmd=1;
          $self->commit($tok);
          $self->commit(';');
          $tok=null;

        } elsif(! ($c=~ qr{\s+})) {
          $tok .= $c;

        } else {
          if($cmd && $tok eq 'C') {
            $self->commit($tok,1);
            $tok=null;
          };

          if(! is_null($tok)) {
            $tok .= $c;
            $cmd  = 0;
          };
        };
      };

    } elsif($c=~ qr{[\{\}]}) {
      $self->commit($tok);
      $self->branch($c);
      $tok=null;

    } elsif($c=~ qr{[[:alnum:]_]}) {
      if($opr) {
        $self->commit($tok);
        $opr  = 0;
        $tok  = null;
      };
      $tok .= $c;

    } else {
      my $ws   = $c=~ qr{\s+};
      my $term = $c eq ';';

      if(! $opr || $term) {
        $self->commit($tok,$cmd);

        if($term) {
          $self->commit(';');
          $cmd=1;
        } elsif(! is_null($tok)) {
          $cmd=0;
        };
        $tok=null;
      };
      if(! $ws &&! $term) {
        $opr  = 1;
        $tok .= $c;
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
  $self->{branch} = $self;
  $self->{string} = [];
  $self->{flg}    = 0;
  $self->{lvl}    = 0;
  $self->{clvl}   = -1;
  $self->{plvl}   = -1;

  return $self;
};


# ---   *   ---   *   ---
# flags

sub flg_macro {return 0x01};
sub flg_cblk  {return 0x02};


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

sub commit($self,$tok,$cmd=0) {
  return if is_null($tok);
  my $root=$self->root();

  # 'macro' effectively commands the parser
  # to treat the entire branch as a string
  if($tok=~ qr{^\s*macro\b} && $cmd) {
    $root->{flg}  |= flg_macro();
    $root->{plvl}  = $self->{lvl};

    return $self->branch($tok);

  # ^except when a 'C' block is found within ;>
  } elsif($tok=~ qr{^\s*C\b} && $cmd) {
    throw "Error: 'C' block outside of macro"
    if ! ($root->{flg} & flg_macro());

    $root->{flg}  |= flg_cblk();
    $root->{clvl}  = $self->{lvl};

    return $self->branch($tok);
  };

  return $root->{branch}->new($tok);
};


# ---   *   ---   *   ---
# handles enter/leave

sub branch($self,$c) {
  my $root = $self->root();
  my $nd   = undef;

  # go down one level
  if($c=~ qr{^(?:\{|macro|C)$}) {
    $nd=$root->{branch}->new($c);

    # handle C blocks inside macros
    if($root->{flg} & flg_cblk()) {
      ++$root->{lvl};
    };

  # go up one level
  } elsif($c eq '}') {
    $root->{branch}->new($c);
    $nd=$root->{branch}->{parent};

    # handle C blocks inside macros
    if($root->{flg} & flg_cblk()) {
      --$root->{lvl};
      if($root->{lvl} <= $root->{clvl}+1) {
        $root->{clvl}  =  $root->{lvl} - 1;
        $root->{flg}  &=~ flg_cblk();

        $nd=$nd->{parent};
        --$root->{lvl};
      };
    };

  # straight up fasm stuff ;>
  } elsif($c eq 'end macro') {
    $nd=$root->{branch}->{parent};
  };

  $root->{branch}=$nd;
  return $root->{branch};
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
  my $root = $self->root();
  my $out  = ref($self)->new();

  $out->{string}=$root->{string};

  my $expr    = null;
  my @pending = (@{$self->{leaves}});
  while(@pending) {
    my $nd = shift @pending;
    my $c  = $nd->{value};

    if($c eq ';') {
      strip($expr);
      if( ($root->{flg} & flg_macro())
      &&! ($root->{flg} & flg_cblk())) {
        $out->commit("$expr;");
      } else {
        $out->commit($expr);
      };
      $expr=null;

    } else {
      if($c eq 'macro' || $c eq 'C') {
        # toggle flags
        my $bit=0;
        if($c eq 'macro') {
          $bit=flg_macro();
        } else {
          $bit=flg_cblk();
        };

        $root->{flg} |= $bit;
        my $rec=$nd->to_exprtree();
        $rec->{value}=$c;
        $out->pushlv($rec);
        $expr=null;

        $root->{flg} &=~ $bit;

      } elsif(($root->{flg} & flg_macro())
        &&!   ($root->{flg} & flg_cblk())) {

        if(@{$nd->{leaves}}) {
          my $rec=$nd->to_exprtree();
          if($rec->{value} ne 'root') {
            $expr .= (is_null($expr))
              ? $root
              : " $root"
              ;
          };

          $rec->{value}="$expr";
          $out->pushlv($rec);
          $expr=null;

        } elsif(! ($c=~ qr{^[\{\}]$})) {
          $expr .= (is_null($expr)) ? $c : " $c" ;
        };

      } elsif($c=~ qr{^[\{\}]$}) {
        my $rec=$nd->to_exprtree();
        $rec->{value}=$expr;
        $out->pushlv($rec);
        $expr=null;

      } else {
        $expr .= (is_null($expr)) ? $c : " $c" ;
      };
    };
  };

  if(! is_null($expr)) {
    $out->commit($expr);
  };

  if( ($root->{flg} & flg_macro())
  &&! ($root->{flg} & flg_cblk())) {
    my @pending=(@{$out->{leaves}});

    while(@pending) {
      my $nd = shift @pending;
      my $c  = $nd->{value};

      next if $c eq 'C';
      next if has_suffix($c,';');

      my @have=($nd);
      my $join=0;
      while(@pending) {
        my $sib=shift @pending;
        push @have,$sib;

        if(has_suffix($sib->{value},';')) {
          $join=1;
          last;
        };
      };

      if($join) {
        my $s=cat(map {$ARG->wstir('{','}')} @have);
        $nd->{value}=$s;

        shift @have;
        $ARG->discard() for @have;
        $nd->pluck_all();
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
  return grep {
    $ARG->{type} ne 'null'

  } map {
    map {
      if($ARG->{type} eq 'null') {
        @{$ARG->{blk}};

      } else {$ARG};

    } $ARG->node_to_expr();

  } @{$_[0]->{leaves}};
};


# ---   *   ---   *   ---
# ^breaks down single expression

sub node_to_expr {
  # early exit?
  my ($nd)=@_;

  strip($nd->{value});
  my $expr=$nd->{value};

  return {
    type => 'null',
    cmd  => null,
    expr => null,
    args => null,
    blk  => [$nd->to_expr_impl()],

  } if is_null($expr);


  # patterns used to break down the expression
  my $name_re = Ftype::Text->name_re();
  my $cmd_re  = qr{^(?<cmd> $name_re)}x;
  my $args_re = qr{\((?<args>[^\)]*)\)$};
  my $asg_re  = qr{
    (?:[\|\&\^\+\-\/\*\%]|\s)
    = [^[:alnum:]]*
  }x;

  # get first appearance of arguments
  my $have_args = int($expr=~ s[$args_re][]);
  my $args      = $+{args} // null;

  # asm/peso rules: first token is instruction
  # everything else is arguments!
  $expr=~ s[$cmd_re][];
  my $cmd  = $+{cmd} // null;
  my $full = "$cmd $expr";

  strip($ARG) for $full,$cmd,$expr,$args;

  my $type = 'expr';
  my @blk  = $nd->to_expr_impl();

  # do we have a {block} on this expression?
  if( @blk

  # does it match "[expr] (...)"?
  &&  $have_args
  &&! is_null($full)

  # 'C' as first token is special cased as
  # we use it to make strings from C code
  #
  # so we check for this as well
  && $cmd ne 'C'
  && $cmd ne 'macro'
  ) {
    # ^ if all that is true,
    #   then it *is* a function!
    $type = 'proc';
    $args = [gsplit($args,qr{\s*,\s*})];


  # not a C function, so it gets... funky
  } else {
    $expr .= "($args)" if $have_args;
    $args  = null;

    if($cmd=~ qr{^(?:C|macro)$}) {
      # perl code, so don't even bother parsing ;>
      if($cmd eq 'macro') {
        $type='asis';
        my $csume=shift @blk;
        if($csume->{type} ne 'proc') {
          throw "Invalid macro: "
          .     fatdump(\$csume,mute=>1)
        };

        $expr = "$csume->{cmd} $csume->{expr}";
        $cmd  = 'macro';
        $args = $csume->{args};
        @blk  = @{$csume->{blk}};


      # treat this entire node like a string
      # containing C code?
      } elsif($cmd eq 'C') {
        $type='code';

        my $semi_re=qr{^ *; *};
        $expr=~ s[$semi_re][];

        my ($beg,$end)=(! is_null($expr))
          ? ('{','}')
          : (null,null)
          ;

        my $ct=join("\n",
          "q[$expr $beg",
            $nd->expr_to_code_impl(@blk),
          "$end;]",
        );

        $ct=join("\n",
          'local *cmamclip=sub(%O) {',
            "my \$out=$ct;",
            'use Arstd::Re qw(crepl);',
            'return crepl($out,%O);',
          '};',
        );

        my $ar  = $nd->root()->{string};
        my $tok = sprintf(strtok_fmat(),int(@$ar));
        push @$ar,$ct;

        $cmd  = '';
        $expr = $tok;
        @blk  = ();
      };

    # common expressions
    } else {
      my $fctl_re=qr{^(?:
        if|elsif|else|while|do|switch
      )$}x;

      my $struc_re=qr{\b(?<keyw>union|struct?)\b};
      my $utype_re=qr{^(?:public +)?(?:typedef +)};

      @blk=$nd->to_expr_impl();

      # if/else
      if($cmd=~ $fctl_re) {
        $type='fctl';

      # [type]? [name]=[value]
      } elsif($expr=~ $asg_re) {
        $type='asg';

      # (standard) preprocessor line
      } elsif(is_cpre($cmd,$expr)) {
        $type='cpre';

      # typedef
      } elsif("$cmd $expr"=~ $utype_re) {
        if(@blk && "$cmd $expr"=~ $struc_re) {
          $type=$+{keyw};

        } else {
          $type='utype';
        };

      # ^struc
      } elsif(@blk && "$cmd $expr"=~ $struc_re) {
        $type=$+{keyw};
      };

      $type='struc' if $type eq 'struct';
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
# we use the '#' kush character for
# concatenating tokens inside some CMAM macros,
# and so we need to run an additional check
# to make sure such an expression isn't itself
# interpreted as a C preprocessor line!

sub is_cpre {
  my ($cmd,$expr)=@_;
  return 1 if has_prefix($cmd,'#');

  return (has_prefix($expr,'#'))
  &&     (is_null($cmd) || $cmd eq 'public');
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
    if($ARG->{type} eq 'asis') {
      $ARG->{type}='asis' for @{$ARG->{blk}};
    };

    # include <file.h> is effed as < file.h >
    # so catch that here
    if($ARG->{type} eq 'cpre'
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
        : ($ARG->{args})
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
        : (($ARG->{type}=~ qr{^(?:proc|struc)})
            ? ';' : null)
        ;

      if($ARG->{type} eq 'asg') {
        $blk   =~ s[;$][];
        $post .=  ';';
      };
      "$out\n${pad}{\n$blk\n${pad}}$post";

    } elsif($ARG->{type}=~
        qr{^(?:cpre|code|asis)$}) {
      "$out";

    } else {
      "$out;"
    };

  } grep {is_hashref($ARG)} @ar;

  --$lvl;

  my $re=qr{;+};
  $s=~ s[$re][;]g;
  return $s;
};


# ---   *   ---   *   ---
1; # ret
