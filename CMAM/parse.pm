#!/usr/bin/perl
# ---   *   ---   *   ---
# CMAM PARSE
# dont do this!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package CMAM::parse;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(
    is_null
    is_arrayref
  );

  use Arstd::String qw(
    strip
    gstrip
    gsplit
    has_suffix
  );
  use Arstd::Repl;
  use Arstd::throw;

  use Type qw(typefet);
  use Ftype::Text;

  use lib "$ENV{ARPATH}/lib/";
  use CMAM::token qw(tokenshift semipop);
  use CMAM::static qw(
    cmamout
    cmamdef
    cmamlol
    cmamgbl

    is_local_scope
    set_local_scope
    unset_local_scope
  );


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT_OK=qw(
    blkparse
    blkparse_re
    type2expr
    blk2expr
  );


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.8a';
  our $AUTHOR  = 'IBN-3DILA';

  sub errsafe {return 1};


# ---   *   ---   *   ---
# block parser
#
# [0]: byte ptr ; code string
# [<]: bool     ; string is not null
#
# [!]: overwrites input string

sub blkparse {
  # strip comments
  comstrip($_[0]);
  return 0 if is_null $_[0];

  # make struct for textual replacement;
  # it'll match blocks of code, replace them
  # with a placeholder, and _then_ run
  # blkrepv for each
  my $repl=Arstd::Repl->new(
    pre  => 'CBLK',
    inre => blkparse_re(),
    repv => \&blkrepv,
  );

  # ^run blkrepv on all expressions
  # ^matching blkparse_re
  $repl->proc($_[0]);
  return ! is_null $_[0];
};


# ---   *   ---   *   ---
# processing done for each parsed block/expr
#
# [0]: mem ptr ; repl ice
# [1]: word    ; string uid
#
# [<]: byte ptr ; string to replace placeholder

sub blkrepv {
  my $capt=$_[0]->{capt}->[$_[1]];

  # early exit if no command to process
  return $_[0]->{asis}->[$_[1]]
  if ! exists $capt->{cmd};

  # ^else recursively expand macros...
  return exprproc($capt);
};


# ---   *   ---   *   ---
# processes expressions
#
# [0]: mem  ptr ; code block capture
# <[<]: byte ptr ; modified block (new string)
#
# [!]: overwrites fields of input mem

sub exprproc {
  my $out=null;
  stripcapt($_[0]);

  # we process top level commands first
  if(exists $_[0]->{cmd}
  && exists cmamdef()->{$_[0]->{cmd}}) {
    # run command
    my $key=$_[0]->{cmd};
    $out=cmamdef()->{$_[0]->{cmd}}->($_[0]);

    # ^get first token from output...
    my $nkey = tokenshift($out);
       $out  = "$nkey $out";

    # ^recurse only if the command did not
    # ^return it's own name as first token!
    if($nkey ne $key) {
      $out=expand($out);
    };

    # no need to keep recursing if the command
    # consumed the entire input
    return null if ! strip($out);
    $_[0]->{cmd}=null;

    # ^else take the command's output and
    # ^feed that back to the next recursion
    my $re=blkparse_re();
    if($out=~ $re) {
      $_[0]={%+};
    } else {
      $_[0]->{cmd}=$out;
    };
    stripcapt($_[0]);
  };

  # turn blk into array of expressions
  # and expand them as well
  if( exists $_[0]->{blk}
  &&! exists $_[0]->{name}) {
    # check whether we're inside a function
    if(exists $_[0]->{type}) {
      # if so, start a new scope
      set_local_scope();
      %{cmamlol()}=();
    };
    # run through expressions and expand them
    blk2expr($_[0]->{blk});
    $_[0]->{blk}= "{\n" . join("\n;",
      gstrip(
        map {expand($ARG)}
        @{$_[0]->{blk}}
      )

    ) . ";\n};\n";

    # terminate scope if we're inside a function
    unset_local_scope()
    if(exists $_[0]->{type});
  };

  $_[0]->{cmd}  //= null;
  $_[0]->{expr} //= null;


  # now we join capture groups
  # how we do that depends on what they are

  # cmd type (args) {blk};
  if(exists $_[0]->{type}) {
    $out=join ' ',(
      $_[0]->{cmd},
      $_[0]->{type},
      "($_[0]->{args})",
      $_[0]->{blk}
    );

  # cmd name {blk};
  } elsif(exists $_[0]->{name}) {
    throw "NYI -- cmd name {blk}; have:\n"
    .     "$_[0]->{cmd} : $_[0]->{expr}"

    if $_[0]->{name} ne 'struct';

  # cmd expr;
  } else {

    # typedefs and structs themselves should
    # be catched by command execution
    #
    # here we want to catch variable decls,
    # just to populate the appropriate scope
    #
    # this is done to allow macros like
    # typename to retrieve type data about the
    # names they are passed

    # first, get the entire expression and
    # split it at the assignment part if any
    my $full     = "$_[0]->{cmd} $_[0]->{expr}";
    my $asg_re   = qr{[\s\d\w](=[^=].+)};
    my ($lh,@rh) = gsplit($full,$asg_re);

    # we don't actually use the right-hand side
    # right now, but we _may_ do so later
    #
    # anyway, convert the left-hand side to an
    # array so we can check whether this is
    # a value declaration
    type2expr($lh);
    my $name=pop @$lh;
    my $type=join ' ',grep {
      ! ($ARG=~ spec_t())

    } @$lh;

    semipop($name);


    # is the joined string in the type-table?
    if(Type->is_valid($type)) {
      # what scope are we in?
      my $scope=(is_local_scope())
        ? cmamlol()
        : cmamgbl()
        ;

      # catch redecl
      throw "Redeclaration of '$name'\n"
      if exists $scope->{$name};

      # record typedata about this value
      $scope->{$name}=typefet($type);
    };

    # give full expression back
    $out="$_[0]->{cmd} $_[0]->{expr}";
  };


  # cleanup and give expansion result
  my $semi_re = qr{;\s*;+\s*};
  my $nl      = "\n";
  $out=~ s[$semi_re][;$nl]smg;

  return $out;
};


# ---   *   ---   *   ---
# evaluates expression and recurses into
# exprproc if it finds anything to expand
#
# [0]: byte ptr ; expr
# [<]: byte ptr ; modified expr (new string)
#
# [!]: has recursion limit

sub expand {
  # early exit if nothing to expand
  return null if is_null($_[0]);

  # ^else check against block pattern;
  # ^stop here if there's no matches
  my $re=blkparse_re();
  return $_[0] if ! ($_[0]=~ $re);


  # exprproc can call expand, thus entering
  # recursion...
  #
  # the cmd _should_ consume tokens from the
  # expression, but if that doesn't happen,
  # we'll end up in an endless loop
  #
  # this static is just here to catch that

  state $depth=0;
  throw "Recursion limit reached "
  .     "in macro expansion"

  if ++$depth > 0x40;

  # execute any macros within expression...
  my $capt = {%+};
  my $out  = exprproc($capt);

  # ^go down one depth level and
  # ^give modified expr
  --$depth;
  return $out;
};


# ---   *   ---   *   ---
# strips keys in capture
#
# [0]: mem  ptr ; code block capture
# [!]: overwrites fields of input mem

sub stripcapt {
  for(keys %{$_[0]}) {
    if(is_arrayref($_[0]->{$ARG})) {
      @{$_[0]->{$ARG}}=gstrip(@{$_[0]->{$ARG}});
    } else {
      strip($_[0]->{$ARG});
    };
  };
  return;
};


# ---   *   ---   *   ---
# pattern for matching specifiers
#
# [*]: const
# [<]: re

sub spec_t {
  return qr{(?:
    IX | CX | CIX | static | inline
  )};
};


# ---   *   ---   *   ---
# a generic pattern for grabbing
# symbols
#
# [<]: re ; new/cached pattern
#
# [!]: conventional wisdom is, of course,
#      you shouldn't parse using regexes.
#
#      and true to said wisdom: this is not perfect.
#      it will not account for strings, for instance
#
#      this is only used as a quick way to
#      process the code for the parser proper

sub blkparse_re {
  # basic rule for what is a valid symbol name
  my $name_re=Ftype::Text->name_re;

  # grabs things between `()` parens
  my $args_re=qr{\s*\((?<args>[^\)]*)\)\s*}s;

  # this one looks scary, but all it's doing is
  # grab `{}` scoped blocks recursively
  #
  # saves us from writing an actual parser
  # just for the bootstrap...
  my $blk_re=qr{(?<blk>(?<!\-\>)
    (?<rec> \{
      ([^\{\}]+
    | (?&rec))+

    \})+

  )}sx;

  # function is (re): type+ name args blk
  my $fn_re=qr{(?<expr>
    (?<type> [^\(=;]+)
    $args_re
    $blk_re
    ;

  )}sx;

  # ^call skips type ;>
  my $call_re=qr{(?<expr>$args_re)}sx;

  # struc or union is (re): name blk
  my $struc_re=qr{(?<expr>
    (?<name> [^\{=;]+) \s*
    $blk_re
    [^;]*
    ;

  )}sx;

  # straight decl just takes everything until
  # it hits a semicolon
  my $value_re=qr{(?<expr>(?:[^;]|\\;)+;)}s;


  # asm rules; first valid name in expression
  # is assumed to be an instruction
  #
  # if it's not recognized as a CMAM macro
  # by later checks, then it's plain C and
  # we won't touch it
  return qr{
    # we catch C preprocessor lines so as
    # to restore them later; we won't touch em
    (?:(?<expr>\# ([^\n]|\\\n)+\n))

  | (?:(?<cmd> (?!REPL) $name_re) \s+
    (?:$fn_re|$struc_re|$value_re))

  | (?:(?<cmd> (?!REPL) $name_re) \s*
    (?:$call_re))

  }sx;
};


# ---   *   ---   *   ---
# strips comments
#
# [0]: byte ptr ; code string
# [<]: bool     ; string is not null
#
# [!]: overwrites input string

sub comstrip {
  return 0 if is_null($_[0]);

  my $re=qr{(?://[^\n]*\n+)+}sm;
  $_[0]=~ s[$re][]g;

  return ! is_null($_[0]);
};


# ---   *   ---   *   ---
# turns type specifiers into array
#
# [0]: byte ptr ; type specifiers (string)
# [!]: overwrites input string

sub type2expr {
  my @type=gsplit($_[0]);
  push @type,'void' if ! @type;

  $_[0]=\@type;

  return;
};


# ---   *   ---   *   ---
# turns a code block into an array
# of expressions
#
# [0]: byte ptr ; code block
# [!]: overwrites input string

sub blk2expr {
  my $curly_re=qr{(?:
    (?:^\s*\{\s*)
  | (?:\s*\}\s*;?\s*$)

  )}smx;
  $_[0]=~ s[$curly_re][]g;

  my $join_re=qr{\s*\\\n\s*}sm;
  $_[0]=~ s[$join_re][ ]g;

  my $expr_re=qr{([^\n;]+)\s*;\s*\n}sm;
  my $semi_re=qr{\s*;\s*$};
  $_[0]=[map {
    $ARG .= ';' if ! has_suffix($ARG,';');
    $ARG;
  } gsplit($_[0],$expr_re)];

  return;
};


# ---   *   ---   *   ---
1; # ret
