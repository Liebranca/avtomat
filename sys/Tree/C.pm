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
    spacecat
    strip
    wstrip
    gstrip
    gsplit
    ident
    has_prefix
    has_suffix
  );
  use Arstd::strtok qw(strtok unstrtok);
  use Arstd::seq qw(seqtok_push);
  use Arstd::throw;
  use Arstd::fatdump;
  use Ftype::Text;

  use parent 'Tree';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.5a';
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
  strtok(
    $self->root()->{string},
    $_[0],

    # sequences to tokenize
    syx=>[
      # comments
      Arstd::seq->com()->{cline},
      Arstd::seq->com()->{cmulti},

      # strings
      values %{Arstd::seq->str()},

      # we're not using peso escapes in C
      # right now, but in case we ever do...
      Arstd::seq->pproc()->{peso},
    ],
  );

  # cleanup extra whitespace
  wstrip($_[0]);

  # for passing F state around
  my $ctx={
    tok  => null,
    opr  => 0,
    cmd  => 0,
    root => $self->root(),
    char => [split '',$_[0]],
  };

  # parse source
  while(@{$ctx->{char}}) {
    # inside body of macro?
    if(apply_perl_rules($ctx)) {
      $self->rd_perl($ctx);

    # ^nope, C code!
    } else {
      $self->rd_c($ctx);
    };
  };

  # push any leftovers
  if(! is_null($ctx->{tok})) {
    $ctx->{root}->commit($ctx->{tok});
  };

  # ^ensure the last expression is terminated
  my $lv=$self->{leaves};
  if(@$lv && $lv->[-1]->{value} ne ';') {
    $ctx->{root}->commit(';');
  };
  return $self;
};


# ---   *   ---   *   ---
# behavior is slightly different when
# inside of a macro, due to perl code
# being mixed in, so we change parsing
# rules a little bit there
#
# this here just detects whether we need
# to apply those different rules

sub apply_perl_rules($ctx) {
  return (
      ($ctx->{root}->{flg} & flg_macro())
  &&! ($ctx->{root}->{flg} & flg_cblk())
  );
};


# ---   *   ---   *   ---
# char ipret for perl

sub rd_perl($self,$ctx) {
  # get next character
  my $c=shift @{$ctx->{char}};

  # handle `{}` curlies
  return if is_curly($ctx,$c);

  # commit token on end of expression
  if($c eq ';') {
    $ctx->{cmd}=1;
    $ctx->{root}->commit("$ctx->{tok};");
    $ctx->{tok}=null;

  # anything that is not whitespace just
  # gets added right in
  } elsif(! ($c=~ qr{\s+})) {
    $ctx->{tok} .= $c;

  # ^whitespace separates tokens
  } else {
    # beggining of C block?
    if($ctx->{cmd} && $ctx->{tok} eq 'C') {
      $ctx->{root}->commit($ctx->{tok},1);
      $ctx->{tok}=null;
    };

    # ^ whitespace. don't cat this to the current
    #   token unless there's something there
    #   already!
    if(! is_null($ctx->{tok})) {
      $ctx->{tok} .= $c;
      $ctx->{cmd}  = 0;
    };
  };
  return;
};


# ---   *   ---   *   ---
# char ipret for C

sub rd_c($self,$ctx) {
  # get next character
  my $c=shift @{$ctx->{char}};

  # handle `{}` curlies
  return if is_curly($ctx,$c);

  # alphanumeric character, so just cat it
  # to the current token
  if($c=~ qr{[[:alnum:]_]}) {
    # if the previous character was an operator,
    # we want to commit what we have and *then*
    # start a new token to cat to
    if($ctx->{opr}) {
      $ctx->{root}->commit($ctx->{tok});
      $ctx->{opr}=0;
      $ctx->{tok}=null;
    };
    # save this character to the current token
    $ctx->{tok} .= $c;

  # anything that's not alphanumeric
  } else {
    # only `;` semis and whitespace are special
    # cased here; semis terminate expressions,
    # and whitespace terminates tokens
    my $ws   = $c=~ qr{\s+};
    my $term = $c eq ';';

    # not an operator means we've encountered
    # either whitespace or a terminator
    if(! $ctx->{opr} || $term) {
      # in either case, it means save the
      # current token and start a new one
      $ctx->{root}->commit(
        $ctx->{tok},
        $ctx->{cmd}
      );

      # signal that the next token is the
      # beggining of a new expression
      if($term) {
        $ctx->{root}->commit(';');
        $ctx->{cmd}=1;

      # ^inverse
      } elsif(! is_null($ctx->{tok})) {
        $ctx->{cmd}=0;
      };

      # clear the token as we've already
      # saved it to the tree
      $ctx->{tok}=null;
    };

    # add non alphanumeric chars to token,
    # but skip whitespace
    if(! $ws &&! $term) {
      $ctx->{opr}  = 1;
      $ctx->{tok} .= $c;
    };
  };
  return;
};

# ---   *   ---   *   ---
# `{}` curlies start and end a new branch
#
# the behavior is the same for all parser
# states during the rd stage, so we reuse this bit

sub curly_re {return qr{^[\{\}]$}};
sub is_curly($ctx,$c) {
  if($c=~ curly_re()) {
    # so save the current token to the tree
    # and *then* handle the branch switch
    $ctx->{root}->commit($ctx->{tok});
    $ctx->{root}->branch($c);
    $ctx->{tok}=null;

    return 1;
  };
  return 0;
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
  $self->{clvl}   = inactive_lvl();
  $self->{plvl}   = inactive_lvl();

  return $self;
};


# ---   *   ---   *   ---
# flags

sub flg_macro    {return  0x01};
sub flg_cblk     {return  0x02};

sub inactive_lvl {return -0xFF};


# ---   *   ---   *   ---
# adds token as a new node to the tree

sub commit($root,$tok,$cmd=0) {
  return if is_null($tok);

  if(ref($root)->is_valid($tok)) {
    $root->{branch}->pushlv($tok);
    $root->{branch}->contract();
    return $tok;
  };

  # when 'macro' and 'C' appear as the *first*
  # token in a branch, that effectively commands
  # the parser to switch parsing logic
  if($tok=~ qr{^(?:macro|C)$} && $cmd) {
    # in such cases, we start a new branch
    return $root->branch($tok);
  };
  # ^else just push a node to the current branch!
  return $root->{branch}->new($tok);
};


# ---   *   ---   *   ---
# handles enter/leave

sub branch($root,$c) {
  my $nd=undef;

  # go down one level
  if($c=~ qr{^(?:\{|macro|C)$}) {
    $nd=$root->{branch}->new($c);

    # switch on flags for C blocks and macros
    if($c eq 'C') {
      throw "Error: 'C' block outside of macro"
      if ! ($root->{flg} & flg_macro());

      $root->{flg}  |= flg_cblk();
      $root->{clvl}  = $root->{lvl};

    } elsif($c eq 'macro') {
      $root->{flg}  |= flg_macro();
      $root->{plvl}  = $root->{lvl};
    };

    # ^and *then* increment level
    ++$root->{lvl};

  # go up one level
  } elsif($c eq '}') {
    $root->{branch}->new($c);
    $nd=$root->{branch}->{parent};

    # decrement level first
    --$root->{lvl};

    # ^ and *then* switch off flags for
    #   C blocks and macros
    if($root->{flg} & flg_macro()) {
      my $rept=0;

      # we go up another level because the
      # tokens 'C' and 'macro' generate
      # a scope of their own
      if(($root->{flg} & flg_cblk())
      && ($root->{lvl}-1 <= $root->{clvl})) {
        $root->{clvl}  =  inactive_lvl();
        $root->{flg}  &=~ flg_cblk();
        $rept          =  1;

      } elsif($root->{lvl}-1 <= $root->{plvl}) {
        $root->{plvl}  =  inactive_lvl();
        $root->{flg}  &=~ flg_macro();
        $rept          =  1;
      };

      # ^so backtrack whenever that happens ;>
      if($rept) {
        $nd=$nd->{parent};
        --$root->{lvl};
      };
    };
  };

  # from here on out, commits are done to
  # the branch we've swapped to
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

  # copy the tokenized string ids over
  $out->{string}=$root->{string};

  # for passing F state around
  my $ctx={
    tok  => null,
    nd   => undef,
    out  => $out,
    root => $root,
    dst  => $out->root(),
  };

  # walk original tree to generate the new one
  my @pending=(@{$self->{leaves}});
  while(@pending) {
    $ctx->{nd}=shift @pending;

    # terminate expression?
    if(has_suffix($ctx->{nd}->{value},';')) {
      $ctx->{tok}=spacecat(
        $ctx->{tok},
        $ctx->{nd}->{value}
      );
      strip($ctx->{tok});

      $ctx->{dst}->commit($ctx->{tok});
      $ctx->{tok}=null;

    # entering macro scopes?
    } elsif($ctx->{nd}->{value}=~
        qr{^(?:C|macro)$}) {
      # toggle flags
      my $bit=0;
      if($ctx->{nd}->{value} eq 'macro') {
        $bit=flg_macro();
      } else {
        $bit=flg_cblk();
      };

      # same as the recurse for subtree below,
      # but we set and unset the appropriate
      # flag before and after recursing!
      $ctx->{root}->{flg} |=  $bit;
      to_exprtree_recurse(
        $ctx,
        $ctx->{nd}->{value}
      );

      # patch for supporting a subset of perl
      # inside a C parser...
      if(apply_perl_rules($ctx)) {
        # get the last leaf
        my $scope=$ctx->{out}->{leaves}->[-1];

        # consume the top node
        ($scope)=$scope->flatten_branch();

        # now apply the fix
        fix_perl_arrow($scope);
        $scope->{value}=spacecat(
          'macro',
          $scope->{value}
        );
      };

      $ctx->{root}->{flg} &=~ $bit;

    # recurse for sub tree?
    } elsif(($ctx->{nd}->{value}=~ curly_re())
      ||    @{$ctx->{nd}->{leaves}}) {
      to_exprtree_recurse($ctx,$ctx->{tok});

    # save node value?
    } else {
      $ctx->{tok}=spacecat(
        $ctx->{tok},
        $ctx->{nd}->{value},
      );
    };
  };

  # handle leftovers
  if(! is_null($ctx->{tok})) {
    $ctx->{dst}->commit($ctx->{tok});
  };
  return $ctx->{out};
};


# ---   *   ---   *   ---
# we repeat this bit, so separating for reuse

sub to_exprtree_recurse {
  my ($ctx,$over)=@_;
  if($ctx->{nd}->{value} eq '}') {
    return;
  };

  # make subtree for this node
  my $rec=$ctx->{nd}->to_exprtree();

  # ^preserve value?
  if($rec->{value} ne 'root') {
    $over=spacecat($over,$rec->{value});
  };

  # push subtree to destination and
  # clear out the current token
  $rec->{value}=$over;
  $ctx->{dst}->commit($rec);
  $ctx->{tok}=null;

  return;
};


# ---   *   ---   *   ---
# handles perl's "$obj->{attr}" mambo,
# which greatly confuses the parser :B

sub fix_perl_arrow($scope) {
  # walk the output tree
  my @pending=(@{$scope->{leaves}});
  while(@pending) {
    my $nd = shift @pending;
    my $c  = $nd->{value};

    # C blocks and terminated expressions
    # don't need this fix
    next if $c eq 'C';
    next if has_suffix($c,';');

    # OK, we've stepped on a node that is not
    # a C block nor a terminated expression
    #
    # what we do now is collect it's sibling
    # nodes until we find one that *is* terminated
    my @have=($nd);
    my $join=0;
    while(@pending) {
      # collect sibling regardless of whether
      # it is terminated
      my $sib=shift @pending;
      push @have,$sib;

      # ^ and stop collecting siblings once we
      #   find one which *is* terminated!
      if(has_suffix($sib->{value},';')) {
        $join=1;
        last;
      };
    };

    # if we found a terminated sibling, then
    # we can apply the fix
    if($join) {
      # cat the nodes together
      $nd->{value}=cat(map {
        # ^ where each node gives:
        #   "node value {leaf values}"
        $ARG->wstir('{','}')

      } @have);

      # now remove the node whose values
      # we just modified from the list...
      shift @have;

      # ^ so as to keep it within the tree,
      #   because now we free all the siblings
      $ARG->discard() for @have;
      $nd->pluck_all();
    };
  };
  return;
};


# ---   *   ---   *   ---
# breaks down expressions for whole tree

sub to_expr {
  my ($self)=@_;
  my $tree=$self->to_exprtree();

  # we generate `;` semi tokens to help
  # with parsing perl (yes)
  #
  # `to_exprtree()` should've consumed these
  # tokens at this point, so it's safe to
  # remove them
  $tree->sweep(qr{^ *; *$});

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

  my $semi_re=qr{(?:^ *; *)|(?: *; *$)};
  $nd->{value}=~ s[$semi_re][]g;
  strip($nd->{value});

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

  # get first appearance of arguments
  my $have_args = int($expr=~ s[$args_re][]);
  my $args      = $+{args} // null;

  # asm/peso rules: first token is instruction
  # everything else is arguments!
  $expr=~ s[$cmd_re][];
  my $cmd=$+{cmd} // null;

  strip($ARG) for $cmd,$expr,$args;

  my $type='expr';

  # do we have a {block} on this expression?
  if( @blk

  # does it match "[expr] (...)"?
  &&  $have_args
  &&! is_null(spacecat($cmd,$expr))

  # 'C' as first token is special cased as
  # we use it to make strings from C code
  #
  # so we check for this as well
  && $cmd ne 'C'
  ) {
    # ^ if all that is true,
    #   then it *is* a function!
    if($cmd ne 'macro') {
      $type='proc';

    # macros are "functions" too, but they're
    # written in perl ;>
    } else {
      $type='asis';
    };
    $args=[gsplit($args,qr{\s*,\s*})];


  # ^everything else is not a function
  } else {
    # and so we put the args back into
    # the expression, if there's any
    $expr .= "($args)" if $have_args;
    $args  = null;

    # a special case where we treat a block
    # of C code within a macro as a string
    if($cmd eq 'C') {
      $type='code';

      # only wrap the block in `{}` curlies
      # if it's preceded by an expression
      my ($beg,$end)=(! is_null($expr))
        ? ('{','};')
        : (null,null)
        ;

      # ^make a string out of the entire block
      my $ct=join("\n",
        "q[" . spacecat($expr,$beg),
          ident($nd->expr_to_code_impl(@blk),3),
        "    $end]",
      );

      # ^ and then construct a convenience handle
      #   to it, with token replacement built-in
      $ct=join("\n",
        'local *cmamclip=sub(%O) {',
        "    my \$out=$ct;",
        '    use Arstd::Re qw(crepl);',
        '    return crepl($out,%O);',
        '  };',
      );

      # the final touch, and this is just to make
      # sure the code doesn't get mangled, is to
      # turn it into a single token which will be
      # replaced *after* processing is done on
      # everything else!
      my $tok=seqtok_push(
        $nd->root()->{string},
        $ct
      );

      # erase the cmd and block to make sure that
      # this expression isn't interpreted
      #
      # we also set the expression to the value
      # of the string token we just produced
      $cmd  = '';
      $expr = $tok;
      @blk  = ();


    # ^in all other cases, it's *just* C code ;>
    } else {
      # just some patterns we use to tell
      # expression types appart
      my $fctl_re=qr{^(?:
        if|elsif|else|while|do|switch
      )$}x;

      my $struc_re=qr{\b(?<keyw>union|struct?)\b};
      my $utype_re=qr{^(?:public +)?(?:typedef +)};

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
  unstrtok($out,$self->root()->{string});

  return $out;
};
sub expr_to_code_impl($self,@ar) {
  # we up the level each time we enter
  # this F; it's an easy way to handle padding
  #
  # formatting the code is not strictly needed,
  # but since i have to check it to verify that
  # the generation is working, i'd much rather
  # be at least somewhat able to read it
  state $lvl=0;
  my $pad='  ' x $lvl++;

  # walk all nodes
  my $s=join "\n",map {
    # the 'asis' type currently does nothing,
    # but we might use it for something later...
    #
    # main point here is we want to be able to
    # identify blocks of perl code as we generally
    # have to treat them differently
    if($ARG->{type} eq 'asis') {
      $ARG->{type}='asis' for @{$ARG->{blk}};
    };

    # include <file.h> is effed as < file.h >
    # so catch that here
    if(($ARG->{type} eq 'cpre')
    && ($ARG->{expr}=~ qr{include})) {
      my $sysinc_re=qr{< (.+) >};
      $ARG->{expr}=~ s[$sysinc_re][<$1>]g;
    };

    # make single line from this expression
    my @blk=@{$ARG->{blk}};
    my $out=$pad . spacecat(
      $ARG->{cmd},
      $ARG->{expr},
      (is_arrayref($ARG->{args}))
        ? '(' . join(',',@{$ARG->{args}}) . ')'
        : ($ARG->{args})
        ,
    );

    # this here is just because the parser adds
    # a bunch of whitespace and it annoys me to
    # no end whenever i have to check the code
    # i'm generating, so we try and remove that
    my $lparens_re = qr{ *\( *};
    my $rparens_re = qr{ *\) *};
    my $comma_re   = qr{ *\, *};
    my $dot_re     = qr{ *\. *};
    $out=~ s[$lparens_re][(]g;
    $out=~ s[$rparens_re][)]g;
    $out=~ s[$comma_re][,]g;
    $out=~ s[$dot_re][.]g;

    # recurse for block
    if(int @blk) {
      my $blk  = $self->expr_to_code_impl(@blk);
      my $post = (exists $ARG->{_afterblk})
        # this part is just here to make up for
        # the fact that i don't like this syntax:
        #
        # "typedef struct N {...} N;"
        #
        # so we sneakily add in the last bit
        ? "$ARG->{_afterblk};"
        : (($ARG->{type}=~ qr{^(?:proc|struc)})
            ? ';' : null)
        ;

      # assignment here would be something like:
      #
      # "struc_t n={f=0,v=0};"
      #
      # we don't want a terminator within
      # that scope, so we remove that
      if($ARG->{type} eq 'asg') {
        $blk   =~ s[;$][];
        $post .=  ';';
      };

      # confused yet? ;>
      # this gives you the following:
      #
      # [this expression]
      # {
      #   [expressions in block]
      # } [whatever goes after]
      #
      # the padding is handled by this F
      # when we recurse for the block
      "$out\n${pad}{\n$blk\n${pad}}$post";


    # nothing much for expressions without a
    # block; we just make sure not to cat a
    # needless `;` semi
    } elsif($ARG->{type}=~ qr{^(?:cpre|code)$}) {
      "$out";

    } else {
      "$out;"
    };

  # validate the nodes, as sometimes we
  # get empty ones during the chaos of
  # executing CMAM macros
  } grep {is_hashref($ARG) && %$ARG} @ar;


  # remove `;;` double semi. the reason we
  # bother doing this is the aforementioned
  # annoyance i feel when reading the
  # generated code
  my $re=qr{;+};
  $s=~ s[$re][;]g;

  # go up one level and give code string
  --$lvl;
  return $s;
};


# ---   *   ---   *   ---
1; # ret
