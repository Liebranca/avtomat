#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD PPROC
# kinda like the C preprocessor
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::pproc;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_blessref);
  use Ftype;

  use Arstd::String qw(spacecat linecnt lineof);
  use Arstd::Bin qw(orc);
  use Arstd::strtok qw(
    strtok
    unstrtok
    strarmut
    strarvoid
    strarex
  );
  use Arstd::peso qw(peval);
  use Arstd::throw;

  use Shb7::Find qw(ffind);

  use lib "$ENV{ARPATH}/lib";
  use AR;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(pproc);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.5a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# we use this to record state across
# all subroutines

sub pproc_mem {
  state $mem={
    inc   => {},
    def   => {-stk=>{}},
    pkg   => {-cur=>null},
    if    => [],
    depth => 0,
    lnoff => 0,
    retry => 0,
    imap  => [],

    lang  => undef,
    syx   => undef,
    sref  => undef,
    stk   => [],
  };
  return $mem;
};


# ---   *   ---   *   ---
# entry point
#
# [0]: byte pptr ; array to save token contents to
# [1]: byte ptr  ; string to process
# [2]: byte pptr ; options
#
# [!]: overwrites input string

sub pproc {
  my $strar = shift;
  my $sref  = \$_[0];
  shift;

  # set defaults
  my %O=@_;
  $O{lang}     //= "C";
  $O{strtok}   //= 0;
  $O{unstrtok} //= 0;

  # up the recursion depth
  my $depth = pproc_enter($sref,$O{lang});
  my $mem   = pproc_mem();

  # generally, we perform tokenization before
  # invoking the preprocessor, but its nice to
  # have this option as well
  strtok($strar,$$sref,syx=>$mem->{syx})
  if $O{strtok};

  # we're only interested in preprocessor
  # lines, so fetch the indices of those
  my @pline=Arstd::strtok::fetln(
    $strar,
    $$sref,
    "pproc"
  );
  while(@pline) {
    # fetch and run command
    my ($i,$cmd,@args)=pproc_take($strar,\@pline);
    push @{$mem->{imap}},[$i,$cmd];

    my $ok=symtab($cmd)->($i,$strar,@args);

    # need to skip lines?
    while(@pline &&! $ok) {
      # jump to next clause...
      my ($si,$scmd,@sargs)=
        pproc_take($strar,\@pline);

      # ^invalid!! strip it!
      if($scmd ne "end" && $scmd ne "e$cmd") {
        strarvoid($strar,$mem->{sref},$si->[0],"vpproc");
        next;
      };
      # ^valid, so run it!
      push @{$mem->{imap}},[$si,$scmd];
      $ok=symtab($scmd)->($si,$strar,@sargs);
    };
  };
  # some directives (like `#catin`) generate
  # further clauses, so naturally they signal
  # that a second pass is needed
  if($mem->{retry}) {
    pproc(
      $strar,
      $$sref,
      lang   => $mem->{lang},
      strtok => 1,
    );
    $mem->{retry}=0;
  };
  # perform textual replacements last...
  #
  # we wait until this point to do it because
  # those substitutions might trigger further
  # recursion, see the comments on the F
  # we're calling for more info on that
  pproc_txtrepl($strar,$sref) if! $depth;

  # same story as with the strtok option
  unstrtok($$sref,$strar)
  if $O{unstrtok};

  # go down one recursion level
  return pproc_leave();
};


# ---   *   ---   *   ---
# saves current state before recursing

sub pproc_enter {
  my ($sref,$lang)=@_;

  # we cap the recursion depth here JIC
  #
  # NOTE: not sure if this limit is set too low,
  #       but it seems sensible to me...
  my $mem=pproc_mem();
  throw "pproc: recursion caphit"
  if    $mem->{depth} > 0x40;

  # save state
  my $stk=$mem->{stk};
  my $ctx={
    sref  => $mem->{sref},
    lang  => $mem->{lang},
    syx   => $mem->{syx},
    retry => $mem->{retry},
    pkg   => $mem->{pkg}->{-cur},
  };
  push @$stk,$ctx;

  # get tokenizer rules...
  ($mem->{lang},$mem->{syx})=get_lang($lang);

  # overwrite generic values
  $mem->{sref}        = $sref;
  $mem->{retry}       = 0;
  $mem->{pkg}->{-cur} = null;
  $mem->{honor}       = honor_need();

  # give depth *before* increment
  return $mem->{depth}++;
};


# ---   *   ---   *   ---
# ^iv

sub pproc_leave {
  my $mem=pproc_mem();
  my $stk=$mem->{stk};
  my $ctx=pop @$stk;

  throw "pproc: <leave> without <enter>"
  if    is_null($ctx);

  # restore previous state
  $mem->{sref}        = $ctx->{sref};
  $mem->{lang}        = $ctx->{lang};
  $mem->{syx}         = $ctx->{syx};
  $mem->{retry}       = $ctx->{retry};
  $mem->{pkg}->{-cur} = $ctx->{pkg};
  $mem->{honor}       = honor_need();

  # give depth *after* decrement
  return --$mem->{depth};
};


# ---   *   ---   *   ---
# reads next line!

sub pproc_take {
  # get next line
  my ($strar,$pline)=@_;
  my $i=shift @$pline;

  # ^make copy of value and untokenize it
  my $cpy=$strar->[$i->[0]];
  unstrtok($cpy,$strar);

  # ^fetch command and give
  return ($i,Arstd::peso::getcmd($cpy));
};


# ---   *   ---   *   ---
# opens file,
# recurses to process it,
# and then pastes it on original
#
# [0]: qword     ; token idex
# [1]: byte pptr ; token array
# [2]: byte ptr  ; filepath

sub pproc_fpaste {
  # either finds the file or throws
  my ($i,$dst,$fpath)=@_;
  $fpath=ffind(peval($fpath));

  # ^it's a nop if file already included ;>
  my $mem=pproc_mem();
  if($mem->{inc}->{$fpath}) {
    strarvoid($dst,$mem->{sref},$i->[0],"vpproc");
    return;
  };
  $mem->{inc}->{$fpath}=1;

  # note how we adjust the line-number offset
  # before recursing!
  $mem->{lnoff} += $i->[1];

  # read the file and recurse...
  my $strar = [];
  my $body  = orc($fpath);
  pproc(
    $strar,
    $body,
    lang     => Ftype::from_ext($fpath),
    strtok   => 1,
    unstrtok => 1,
  );
  # ^adjust offset again
  $mem->{lnoff} += linecnt($body);

  # overwrite preprocessor directive
  # with the body of the file
  strarmut($dst,$mem->{sref},$i->[0],code=>$body);
  return 1;
};


# ---   *   ---   *   ---
# OK this bit was implemented solely because
# it was needed to simplify some "assembling"
# of web files!!
#
# we might add some language sensitivity to it
# later, but currently it doesn matter as we
# don't use this feature anywhere else ;>

sub pproc_package {
  my ($i,$dst,$name,@attr)=@_;
  throw "pproc: <package> without name"
  if    is_null($name);

  my $mem=pproc_mem();
  throw "pproc: redeclaration of package '$name'"
  if    exists $mem->{pkg}->{$name};

  $mem->{pkg}->{$name} = {map {$ARG=>1} @attr};
  $mem->{pkg}->{-cur}  = $name;

  my $body=join("\n",
    "#define __PACKAGE__ $name",
    $mem->{lang}->package_open($name),
    null,
  );
  strarex(
    $dst,
    $mem->{sref},
    $i->[0],
    $body,
  );
  $mem->{retry}=1;

  return 1;
};
sub pproc_package_end {
  my ($i,$dst,$sref)=@_;

  my $mem  = pproc_mem();
  my $name = $mem->{pkg}->{-cur};
  my $flg  = $mem->{pkg}->{$name};
  my $out  = join("\n",
    $mem->{lang}->package_close($name,$flg,$sref),
    "#undef __PACKAGE__",
    null,
  );
  return $out;
};


# ---   *   ---   *   ---
# sets [key=>value]
#
# [0]: qword     ; token idex
# [1]: byte pptr ; token array
# [2]: byte ptr  ; key
# [3]: byte ptr  ; value

sub pproc_define {
  # value is optional...
  my ($i,$dst,$k,$v)=@_;
  $v //= null;

  # ^the key is not
  throw "pproc: <define> without a key"
  if    is_null($k);

  # saving the value is not quite as
  # straight-forward, given that it can
  # be re-or-un-defined later...
  #
  # what we do is save the idex of each token
  # that performs such an operation, so as to
  # have a coordinate that tells us *when* to
  # use each value for the replacement!
  my $mem = pproc_mem();
  my $ar  = $mem->{def}->{$k} //= [];
  my $stk = $mem->{def}->{-stk}->{$k} //= [];
  my $top = [$i->[1] + $mem->{lnoff},$v];

  push @$ar,$top;
  push @$stk,$top;

  # clear directive;
  # the replacement will be done later on
  strarvoid($dst,$mem->{sref},$i->[0],"vpproc");
  return 1;
};


# ---   *   ---   *   ---
# ^ same, but cats input to
#   an existing [key=>value]

sub pproc_cat {
  my ($i,$dst,$k,$v)=@_;
  $v //= null;

  throw "pproc: <defcat> without a key"
  if    is_null($k);

  my $mem=pproc_mem();
  throw "pproc: undefined key for <defcat> '$k'"
  if!   exists $mem->{def}->{$k};

  my $ar=$mem->{def}->{$k};
  $ar->[-1]->[1] .= $v;

  strarvoid($dst,$mem->{sref},$i->[0],"vpproc");
  return 1;
};


# ---   *   ---   *   ---
# ^also same, but adds newline ;>

sub pproc_catline {
  my ($i,$dst,$k,$v)=@_;
  $v //= null;
  $v  .= "\n";

  return pproc_cat($i,$dst,$k,$v);
};


# ---   *   ---   *   ---
# ^adds an `#include` line!! :O

sub pproc_catin {
  my ($i,$dst,$k,$v)=@_;
  $v //= null;
  $v   = "\n#include $v\n";

  # signal that a second pass will be required!
  pproc_mem()->{retry}=1;

  return pproc_cat($i,$dst,$k,$v);
};


# ---   *   ---   *   ---
# roll back to the *last* definition of key,
# or set it to null if no previous definition
# exists

sub pproc_undef {
  my ($i,$dst,$k)=@_;

  throw "pproc: <undef> without a key"
  if    is_null($k);

  my $mem = pproc_mem();
  my $ar  = $mem->{def}->{$k};
  my $stk = $mem->{def}->{-stk}->{$k};
  my $top = pop @$stk // [0,null];

  push @$ar,[$i->[1] + $mem->{lnoff},$top->[1]];

  # clear directive;
  # the replacement will be done later on
  strarvoid($dst,$mem->{sref},$i->[0],"vpproc");

  return 1;
};


# ---   *   ---   *   ---
# evaluates condition
#
# [0]: qword     ; token idex
# [1]: byte pptr ; token array
# [2]: byte pptr ; expr

sub pproc_if {
  # we strip the expression right away
  my ($i,$dst,@expr)=@_;
  my $mem=pproc_mem();
  strarvoid($dst,$mem->{sref},$i->[0],"vpproc");

  # get truth of this statement...
  my $ok=pproc_ifeval(0,@expr);

  # remember line where this clause appeared;
  # we'll need it for stripping it later if
  # it evaluates to false
  my $ar  = [];
  push @$ar,[$i->[1] + $mem->{lnoff},$ok];
  push @{$mem->{if}},$ar;

  return $ok;
};
sub pproc_eif {
  my ($i,$dst,@expr)=@_;
  my $mem=pproc_mem();
  strarvoid($dst,$mem->{sref},$i->[0],"vpproc");

  # get truth of this statement...
  my $ok=pproc_ifeval(1,@expr);

  # remember line where this clause appeared;
  # we'll need it for stripping it later if
  # it evaluates to false
  my $ar=$mem->{if}->[-1];
  throw "pproc: <eif> without preceding <if>"
  if!   $ar;

  push @$ar,[$i->[1] + $mem->{lnoff},$ok];
  return $ok;
};


# ---   *   ---   *   ---
# evaluate expression for if/eif...

sub pproc_ifeval {
  # we give default value when there is
  # no expression!
  my ($ok,@expr)=@_;
  my $mem  = pproc_mem();
  my $have = int(@expr);

  return $ok if! $have;

  # checking if a value is defined...
  if($have && $expr[0] eq "def") {
    $ok=exists $mem->{def}->{$expr[1]};

  # ^checking if it's *not* defined!
  } elsif($have && $expr[0] eq "ndef") {
    $ok=! exists $mem->{def}->{$expr[1]};

  # ^checking truth of a statement!! \( ^ .^)/
  } else {
    for(@expr) {
      # we want to use the latest definition
      # of this value, *if* it was `#define`-d
      if(exists $mem->{def}->{$ARG}) {
        $ARG=$mem->{def}->{$ARG}->[-1]->[1];
      };
    };
    # ^and then we can just eval :D
    $ok=eval(spacecat(@expr));
  };
  return $ok;
};


# ---   *   ---   *   ---
# terminates multi-line clause (!!)
#
# [0]: qword     ; token idex
# [1]: byte pptr ; token array
# [2]: byte pptr ; expr

sub pproc_end {
  # you gotta tell me what to end...
  my ($i,$dst,$clause)=@_;
  throw "pproc: <end> without clause"
  if    is_null($clause);

  my $mem  = pproc_mem();
  my $imap = $mem->{imap};
  my $beg;
  for(reverse @$imap) {
    my ($bi,$cmd)=@$ARG;
    if($cmd eq $clause) {
      $beg=$bi;
      last;
    };
  };
  my $cpy=${$mem->{sref}};

  honor_line(\$cpy,"pproc","vpproc");
  my @line=split("\n",$cpy);
  my $body=join("\n",@line[$beg->[1]..$i->[1]]);

  # clauses can have a "close" F to mutate
  # the code!! \( ^ .^)/
  my $fn={
    package=>\&pproc_package_end,

  }->{$clause} // \&null;

  my $foot=$fn->($i,$dst,\$body);

  # ^ and it *may* also modify the enclosed
  #   code via the reference to $body :D
  @line[$beg->[1]..$i->[1]]=($body);
  @line=grep {$ARG} @line;
  $cpy=join("\n",@line);
  dishonor_line(\$cpy,"pproc","vpproc");
  ${$mem->{sref}}=$cpy;

  # ^ it determines what we repl this line with;
  #   defaults to null
  strarex(
    $dst,
    $mem->{sref},
    $i->[0],
    $foot
  );
  # mark the line where this clause ends ;>
  my $ar=[];
  push @$ar,[$i->[1] + $mem->{lnoff},1];
  push @{$mem->{$clause}},$ar;

  return 1;
};


# ---   *   ---   *   ---
# fetch from function table
#
# [0]: byte ptr ; F name

sub symtab {
  my $out={
    include => \&pproc_fpaste,
    define  => \&pproc_define,
    undef   => \&pproc_undef,
    package => \&pproc_package,
    cat     => \&pproc_cat,
    catline => \&pproc_catline,
    catin   => \&pproc_catin,
    if      => \&pproc_if,
    eif     => \&pproc_eif,
    end     => \&pproc_end,

  }->{$_[0]}

  or throw "pproc: undefined function '$_[0]'";

  return $out;
};


# ---   *   ---   *   ---
# performs textual replacement of
# any `#define`-d symbols ;>

sub pproc_txtrepl {
  my ($strar,$sref)=@_;

  # we need to put the line that terminates
  # the expression back in there, so as to
  # get the actual number of lines
  honor_line($sref,"pproc","vpproc");

  # walk definitions!
  my $mem=pproc_mem();
  for my $k(keys %{$mem->{def}}) {
    next if $k eq "-stk";

    # replace KEY within tokenized body...
    my $re=qr{(?<!\\)\b$k\b};
    while($$sref=~ $re) {
      last if! pproc_txtrepl_inner($k,$sref,$re);
    };

    # ^unescape
    $re=qr{\\\b$k\b};
    $$sref=~ s[$re][$k];

    # replace #KEY; inside strings!! /YES
    $re=qr{(?<!\\)\#$k;};
    pproc_txtrepl_inner(
      $k,
      \$strar->[$ARG->[0]],
      $re,
      $sref,
      Arstd::seq::tok_re("str",$ARG->[0])

    ) for Arstd::strtok::fetln(
      $strar,
      $$sref,
      "str"
    );
    # ^also unescape!
    $re=qr{\\\b$k\b};
    $$sref=~ s[$re][$k];
  };
  # remove the lines we added
  dishonor_line($sref,"pproc","vpproc");

  # here comes the """esoteric""" bit...
  #
  # what happens is that it's entirely possible
  # that performing these substitutions generates
  # new preprocessor directives, which means that
  # a recursion check is necessary!! :o
  #
  # so what we do is re-run the tokenizer to see
  # if any such directives are present, and if so,
  # recurse right here and now!
  my $have=strtok($strar,$$sref,syx=>$mem->{syx});

  # ^ it's safe to do it like this because the call
  #   to the tokenizer will only give us how many
  #   *new* preprocessor lines it has encountered;
  #   the ones we have already processed do not
  #   count towards this total ;>
  pproc($strar,$$sref,lang=>$mem->{lang})
  if $have->{pproc} > 0;

  return;
};
sub pproc_txtrepl_inner {
  my ($k,$dst,$dst_re,$src,$src_re)=@_;
  $src    //= $dst;
  $src_re //= $dst_re;

  # get line number for this match...
  my $lnx=lineof($$src,$src_re);

  # ^select definition accto line number!
  my $ok=0;
  for(reverse @{pproc_mem()->{def}->{$k}}) {
    my ($lny,$v)=@$ARG;
    if($lnx >= $lny) {
      ($dst ne $src)
        ? $$dst=~ s[$dst_re][$v]g
        : $$dst=~ s[$dst_re][$v]
        ;
      last;
      $ok=1;
    };
  };
  return $ok;
};


# ---   *   ---   *   ---
# the tokenizer removes newline characters
# on preprocessor lines, and sometimes we
# need to put them back in

sub honor_line {
  return if! pproc_mem()->{honor};

  my ($sref,@t)=@_;
  my $nl="\n";
  for(@t) {
    my $tok_re=Arstd::seq::tok_re($ARG);
    $$sref=~ s[$tok_re][$+{full}$nl]g;
  };
  return;
};

# ---   *   ---   *   ---
# ^undo

sub dishonor_line {
  return if! pproc_mem()->{honor};

  my ($sref,@t)=@_;
  for(@t) {
    my $tok_re=Arstd::seq::tok_re($ARG)."\n";
    $$sref=~ s[$tok_re][$+{full}]g;
  };
  return;
};


# ---   *   ---   *   ---
# ^checks whether such a thing is necessary ;>
#
# what we do here is just check whether
# preprocessor lines for the current syntax
# are actually terminated by a newline;
#
# in that case, we have to honor/dishonor lines!
#
# note that in say 90% of the codebase this
# is currently true -- this check is just here
# to support different syntaxes! \( ^ .^)/

sub honor_need {
  my $syx=pproc_mem()->{syx};
  return int grep {
     $ARG->{type} eq "pproc"
  && $ARG->{end}  eq "\n"

  } @$syx;
};


# ---   *   ---   *   ---
# get rules for the tokenizer

sub get_lang {
  # set defaults
  my ($lang,%O)=@_;
  $O{com}   //= 1;
  $O{pproc} //= 1;

  # fetch package containing defs
  if(! is_blessref($lang)) {
    $lang="Ftype\::Text\::$lang";
    AR::load($lang);

    $lang=$lang->selfet();
  };
  # ^make copy of syntax rules
  my $syx=[@{$lang->strtok_syx()}];

  # ^modify rules to conserve comments...
  if($O{com}) {
    $ARG->{keep}=1
    for grep {$ARG->{type} eq 'com'} @$syx;
  };
  # ^ and strip preprocessor lines, just
  #   to make them easier to read!
  if($O{pproc}) {
    $ARG->{strip}=1
    for grep {$ARG->{type} eq 'pproc'} @$syx;
  };
  return ($lang,$syx);
};


# ---   *   ---   *   ---
1; # ret
