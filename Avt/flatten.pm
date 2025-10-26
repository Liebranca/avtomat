#!/usr/bin/perl
# ---   *   ---   *   ---
# FLATTEN
# flat assembler frontend
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Avt::flatten;
  use v5.42.0;
  use strict;
  use warnings;

  use Cwd qw(abs_path);
  use English qw($ARG);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;
  use Tree::File;

  use parent 'Shb7::Bk::front';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.8a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {
  my $self=Shb7::Bk::front::new(
    $class,

    lang    => 'fasm',
    bk      => 'flat',
    entry   => 'start',
    pproc   => 'Avt::flatten::pproc',

    %O,

    linking => (! $O{linking})
      ? 'flat'
      : 'half-flat'
      ,

  );

};


# ---   *   ---   *   ---
# invoke pproc

sub cpproc($class,$f,@args) {
  return Avt::flatten::pproc->$f(@args);

};


# ---   *   ---   *   ---
# ^fasm preprocessor
#
# NOTE:
#
# this is for the old AR/forge
# system, which we don't currently
# use anymore...
#
# mostly because fasm2 came out ;>
#
# some of this code could be
# reused though. i did a 'cleanup pass'
# and will reread it some more if we
# need a fasm2 preprocessor later on
#
# (we may need it; can't tell yet)

package Avt::flatten::pproc;
  use v5.42.0;
  use strict;
  use warnings;

  use Cwd qw(abs_path);
  use English;
  use lib "$ENV{ARPATH}/lib/sys/";

  use Style;

  use Arstd::Array qw(array_dupop);
  use Arstd::String qw(recapts);
  use Arstd::Path qw(extwap);
  use Arstd::Re qw(
    re_escaped
    re_nonscaped
    re_delim

  );

  use Arstd::IO qw(orc owc);

  use Shb7::Path;

  use lib "$ENV{ARPATH}/lib/";

  use Emit;
  use Emit::Std;

  use parent 'St';


# ---   *   ---   *   ---
# ROM

my $PKG=__PACKAGE__;
St::vconst {
  INCFILE_RE => qr{\.inc$},
  NTERM_RE   => re_escaped('\n',mod=>'*',sigws=>1),
  TERM_RE    => re_nonscaped('\n'),
  BODY_RE    => re_delim('{','}',capt=>'body'),
  WS_RE      => qr{[\s\\]},

  MACRO_RE   => sub {
    my ($ws,$body)=(
      $_[0]->WS_RE,
      $_[0]->BODY_RE,

    );

    return qr{
      macro (?:$ws+)
      (?<name> [^\s]+) (?:$ws*)
      (?<args> [^\{]*) (?:$ws*)

      $body

    }x;

  },

  STR_RE=>qr{
    (?: ['] [^']+ ['])
  | (?: ["] [^"]+ ["])

  }x,

  STRSTRIP_RE=>qr{
    (?: ^['"]  )
  | (?:  ['"]$ )

  }x,


  LIB_OPEN_RE=>sub {
    my ($ws,$str,$term)=(
      $_[0]->WS_RE,
      $_[0]->STR_RE,
      $_[0]->TERM_RE,

    );

    return qr{
      library (?:$ws+)
      (?<env> [^\s]+) (?:$ws+)

      (?<path> $str) (?:$ws*)
      (?:$term)

    }x;

  },

  LIB_CLOSE_RE=>sub {
    my $term=$_[0]->TERM_RE;
    return qr{library\.import (?:$term)}x;

  },


  USING_RE=>sub {
    my ($ws,$str,$term)=(
      $_[0]->WS_RE,
      $_[0]->STR_RE,
      $_[0]->TERM_RE,

    );

    return qr{
      \s* use (?:$ws+)
      (?<ext> $str) (?:$ws+)
      (?<name> [^\s]+) (?:$ws*)
      (?:$term)

    }x;

  },

  LIB_RE=>sub {
    my ($lib_open,$using,$lib_close)=(
      $_[0]->LIB_OPEN_RE,
      $_[0]->USING_RE,
      $_[0]->LIB_CLOSE_RE,

    );

    return qr{
      (?<head> $lib_open)
      (?<uses> (?:$using)+)

      $lib_close

    }x;

  },

  PROC_BODY_RE=>qr{(?<body>
    (?:proc\.new)
    (?:
      (?!proc\.leave|proc.new)
      (?:.|\s)

    )*

    (?:proc\.leave)

  )}x,

  PROC_RE=>sub {
    my ($proc_body,$ws)=(
      $_[0]->PROC_BODY_RE,
      $_[0]->WS_RE,

    );

    return qr{
      $proc_body (?: $ws*)
      (?: ret|exit [^\n]*\n)?

    }x;

  },

  IPROC_RE=>qr{
    (?<body>
      proc.new
      (?: (?! inline)(.|\s)+)

    )

    (?: inline [^\n]*\n)
    (?:
      (?: (?! ret|exit)(.|\s)+)
      (?: ret|exit [^\n]*\n)

    )?

  }x,

  LCOM_RE => qr{^ \s* ; (?: .*) (?: \n|$)}x;
  SEG_RE  => sub {
    my $nterm=$_[0]->NTERM_RE;
    return qr{(?:
      (?: (?:ROM|RAM|EXE) SEG)
    | (?: (?:section|segment))
    | (?: constr \s+ (?: ROM|RAM))

    ) $nterm}x;

  },

  SEGR_RE=>qr{(?:
    (?: (?: ROM|RAM) SEG)
    (?: (?! EXESEG) (?: .|\s)+ )

    EXESEG?

  )}x;

  REG_RE=>sub {
    my ($term,$nterm)=(
      $_[0]->TERM_RE,
      $_[0]->NTERM_RE,

    );

    return qr{
      (?: reg\.new) $nterm
      (?<! \,public) $term

      (?:
        (?: (?! reg\.end) (?: .|\s) )+
      | (?R)

      )*

      reg\.end

    }x;

  },

  REGICE_RE=>sub {
    my $nterm=$_[0]->NTERM_RE;
    return qr{(?: reg\.ice) $nterm}x;

  },

  GETIMP_STR=>(join "\n",
    q[if ~ defined loaded?Imp],
    q[include '%ARPATH%/forge/Imp.inc'],

    q[end if],

  ),

  PREIMP_STR=>(join "\n",
    q[MAM.xmode='__MODE__'],
    q[MAM.head __ENTRY__],

  ),

  FOOT_STR=>(join "\n",
    q[MAM.avto]
    q[MAM.foot]

  ),

  GET_AUTHOR_RE=>sub {
    my $nterm=$_[0]->NTERM_RE;
    return qr{AUTHOR  \s+ ($nterm)}x;

  },

};


# ---   *   ---   *   ---
# scrap non-binary data
# (ie code) from file

sub get_nonbin($class,$fpath) {
  my $body=orc($fpath);
  $class->strip_meta(\$body);

  my $macros = $class->strip_macros(\$body);
  my $procs  = $class->strip_procs(\$body);
  my $deps   = $class->get_imp_deps(\$body);
  my $extrn  = $class->get_extrn($fpath);

  $class->strip_codestr(\$body);


  return join "\n",(
    $deps,
    $extrn,
    @$macros,
    $body,
    @$procs,

  );

};


# ---   *   ---   *   ---
# ^remove macros from codestr
# save them to out

sub strip_macros($class,$sref) {
  return [recapts $sref,$PKG->MACRO_RE];

};


# ---   *   ---   *   ---
# separate dependency blocks

sub get_imp_deps($clas,$sref) {
  return join "\n",(recapts $sref,$PKG->LIB_RE);

};


# ---   *   ---   *   ---
# get exported symbols

sub get_extrn($class,$fpath) {

  # get symbol file
  my $src=obj_from_src(
    $fpath,

    ext       => '.preshwl',
    use_trash => 1,

  );

  # ^skip if non-existent
  return null if ! -f $src;

  # ^read file and get extrn decls
  return join "\n",grep {
    $ARG=~ qr{^extrn};

  } split($NEWLINE_RE,orc($src));

};


# ---   *   ---   *   ---
# ^remove private data

sub strip_codestr($class,$sref) {
  state $constr_re=qr{constr\.new};
  my ($segr,$seg,$reg,$regice)=(
    $PKG->SEGR_RE,
    $PKG->SEG_RE,
    $PKG->REG_RE,
    $PKG->REGICE_RE,

  );

  $$sref=~ s[$segr][]sxmg;
  $$sref=~ s[$seg][]sxmg;
  $$sref=~ s[$reg][]sxmg;
  $$sref=~ s[$regice][]sxmg;
  $$sref=~ s[$constr_re][constr._ns_new]sxmg;

  return;

};


# ---   *   ---   *   ---
# ^remove code, but leave
# proc macros for inlining

sub strip_procs($class,$sref) {
  state $line_re=qr{^\s*proc\.};
  state $keep_re=qr{^\s*proc\.new};

  my $out   = [];
  my $proc  = $PKG->PROC_RE;
  my $iproc = $PKG->IPROC_RE;
  $$sref=~ s[$proc][]sxmg;

  while($$sref=~ s[$iproc][]) {
    my $s=$+{body};

    push  @$out,grep {$ARG=~ $line_re}
    split $NEWLINE_RE,$s;

    $out->[-1]=~ s[$keep_re][proc._ns_new];

  };


  return $out;

};


# ---   *   ---   *   ---
# ^remove metadata

sub strip_meta($class,$sref) {
  my $re=$PKG->LCOM_RE;
  my @out=grep {
    ! ($ARG=~ m[$re]sxm)
  &&! ($ARG=~ m[^\s*$]sxm)

  } split $NEWLINE_RE,$$sref;

  $$sref=join "\n",@out;
  return;

};

# ---   *   ---   *   ---
# scrap deps meta from
# importer cmd

sub read_deps($class,$base,$deps) {
  my ($using_re,$strip_re)=(
    $PKG->USING_RE,
    $PKG->STRSTRIP_RE,

  );

  my @out=();
  while($deps=~ s[$using_re][]sxm) {

    # get file name and extension
    my $ext  = $+{ext};
    my $name = $+{name};

    # ^clean
    $ext  =~ s[$strip_re][]sxmg;
    $name =~ s[$DCOLON_RE][/]sxmg;

    # ^get fullpath
    my $fpath="$base$name$ext";

    # ^Q for expansion
    push @out,$fpath;

  };


  return @out;

};


# ---   *   ---   *   ---
# ^read in importer cmd

sub get_file_deps($class,$body) {
  state $is_fake=qr{\.hed$};

  my ($lib_re,$strip_re)=(
    $PKG->LIB_RE,
    $PKG->STRSTRIP_RE,

  );

  my @out=();
  while($body=~ s[$lib_re][]sxm) {
    my $head=$+{head};
    my $uses=$+{uses};

    # ^scrap import meta
    my $env  = $+{env};
    my $path = $+{path};

    # ^get import path
    $env=($env ne '_')
      ? $ENV{$env}
      : null
      ;

    $path=~ s[$strip_re][]sxmg;

    my $base="$env$path";
    my $have=$class->read_deps($base,$uses);


    # ^cleanup and give
    $have=extwap($ARG,'asm')
    if $ARG=~ $is_fake;

    push @out,$have;

  };


  return @out;

};


# ---   *   ---   *   ---
# ^recursively expand deps

sub get_deps($class,@flist) {
  my @out=();
  while(@flist) {

    # open new file
    my $elem=shift @flist;
    my $body=orc($elem);

    # ^keep track of deps
    unshift @out,$elem;

    # recurse
    unshift @flist,$class->get_file_deps($body);

  };


  return @out;

};


# ---   *   ---   *   ---
# build dependency files

sub build_deps($class,@flist) {
  my @order;
  for(@flist) {

    # get src
    my $fpath = $ARG->{src};
    my $dst   = $class->get_altsrc($fpath);
    my $body  = orc($fpath);

    # get deps file
    my $depsf=extwap($dst,'asmd');

    # ^recursive depscrap chk
    if(moo($dst,$depsf)) {

      my @deps=$class->get_file_deps($body);
      unshift @deps,$class->get_deps(@deps);

      array_dupop(\@deps);
      owc($depsf,join "\n",@deps);

      unshift @order,@deps;

    } else {
      unshift @order,split $NEWLINE_RE,orc($depsf);

    };

  };


  # cleanup and give
  array_dupop(\@order);
  return @order;

};


# ---   *   ---   *   ---
# get out path in trashfold

sub get_altsrc($class,$fpath) {
  return obj_from_src(
    $fpath,

    ext       => '.asmx3',
    use_trash => 1,

  );

};


# ---   *   ---   *   ---
# get out path in own fold

sub get_altout($class,$fpath) {
  return obj_from_src(
    $fpath,

    ext       => '.bin',
    use_trash => 1,

  );

};


# ---   *   ---   *   ---
# make pre-build trashfile

sub prebuild($class,$bfile,%O) {

  # defaults
  $O{mode}  //= 'obj';
  $O{entry} //= null;


  # get build mode
  my $pre  = $PKG->PREIMP_STR;
  my $get  = $PKG->GETIMP_STR;
  my $foot = $PKG->FOOT_STR;

  $pre=~ s[__MODE__][$O{mode}];
  $pre=~ s[__ENTRY__][$O{entry}];


  # get src
  my $fpath = $bfile->{src};
  my $dst   = $class->get_altsrc($fpath);
  my $body  = orc($fpath);

  $class->strip_meta(\$body);

  # ^cat chunks
  my $inc=int ($fpath=~ $PKG->INCFILE_RE);

  $bfile->{__alt_out}=($inc)
    ? $class->get_altout($fpath)
    : undef
    ;

  my $out=($inc)
    ? "$get$body"
    : "$get$pre$body$foot"
    ;


  # emit
  $bfile->{_pproc_src} = $fpath;
  $bfile->{src}        = $dst;
  owc($dst,$out);

  return $dst;

};


# ---   *   ---   *   ---
# ^make post-build header

sub postbuild($class,$bfile) {
  my $get_author=GET_AUTHOR_RE;

  my $out=null;
  $bfile->{src}=$bfile->{_pproc_src};

  # get src
  my $fpath = $bfile->{src};
  my $body  = orc($fpath);

  # scrap info
     $body     =~ $get_author;
  my $author   =  $1;
     $author //=  Emit->ON_NO_AUTHOR;

  # ^make src
  $out.=Emit::Std::note($author,';')."\n";
  $out.=$class->get_nonbin($fpath);

  # emit
  my $dst=obj_from_src(
    $fpath,

    ext       => '.hed',
    use_trash => 0,

  );

  owc($dst,$out);
  return $dst;

};


# ---   *   ---   *   ---
# fasm rules ;>
#
# because we can generate any
# kind of code with it, we
# add this additional step
#
# it sifts through non-pproc
# files and moves them to
# the base folder

sub binfilter($class,$bfile) {

  # get dir
  my $fpath = $bfile->{__alt_out};
  my $base  = dirof $fpath;

  # ^relocate the others
  my @keep=$class->ffilter($base);
  map {rename $ARG,src_from_obj($ARG)} @keep;

  return;

};


# ---   *   ---   *   ---
# ^filters out unwanted files

sub ffilter($class,$base,$wanted=undef) {
  # get all files in base path
  my $tree=Tree::File->new($base);
  $tree->expand(-x=>qr{(?:
    .+\.hed$
  | .+\.asm$
  | .+\.asmx3$
  | .+\.preshwl$
  | .+\.asmd$

  )}x);

  # ^remove empty bins
  my @keep=grep {
    if(! -s $ARG) {unlink $ARG;0}
    else {1};

  } $tree->get_filepath_list(full=>1);


  # apply a second filter?
  @keep=grep {$ARG=~ $wanted} @keep
  if defined $wanted;

  # give filtered list
  return @keep;
};


# ---   *   ---   *   ---
1; # ret
