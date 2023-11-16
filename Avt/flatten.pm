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
# lyeb,

# ---   *   ---   *   ---
# deps

package Avt::flatten;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Cwd qw(abs_path);
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

  use parent 'Shb7::Bk::front';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  my $self=Shb7::Bk::front::new(

    $class,

    lang  => 'fasm',

    bk    => 'flat',
    entry => 'crux',
    flat  => 1,

    pproc => 'Avt::flatten::pproc',

    %O

  );

};

# ---   *   ---   *   ---
# invoke pproc

sub cpproc($class,$f,@args) {
  return Avt::flatten::pproc->$f(@args);

}

# ---   *   ---   *   ---
# ^fasm preprocessor

package Avt::flatten::pproc;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Cwd qw(abs_path);
  use English qw(-no_match_vars);
  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::Path;
  use Arstd::Re;
  use Arstd::IO;

  use Shb7::Path;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Emit;
  use Emit::Std;

# ---   *   ---   *   ---
# ROM

  Readonly my $NTERM => re_escaped(
    '\n',

      mod   => '*',
      sigws => 1,

  );

  Readonly my $TERM  => re_nonscaped('\n');

  Readonly my $BODY  => re_delim(
    '{','}',capt=>'body'

  );

  Readonly my $WS    => qr{[\s\\]};

  Readonly my $MACRO => qr{

    macro
    (?:$WS+)

    (?<name> [^\s]+)
    (?:$WS*)

    (?<args> [^\{]*)
    (?:$WS*)

    $BODY

  }x;


  Readonly my $STR => qr{
    (?: ['] [^']+ ['])
  | (?: ["] [^"]+ ["])

  }x;

  Readonly my $STRSTRIP => qr{
    (?: ^['"]  )
  | (?:  ['"]$ )

  }x;


  Readonly my $LIB_OPEN => qr{

    library
    (?:$WS+)

    (?<env> [^\s]+)
    (?:$WS+)

    (?<path> $STR)
    (?:$WS*)
    (?:$TERM)

  }x;

  Readonly my $LIB_CLOSE => qr{
    library\.import (?:$TERM)

  }x;


  Readonly my $USE => qr{

    \s*

    use
    (?:$WS+)

    (?<ext> $STR)
    (?:$WS+)

    (?<name> [^\s]+)
    (?:$WS*)
    (?:$TERM)

  }x;

  Readonly my $LIB => qr{

    (?<head> $LIB_OPEN)
    (?<uses> (?:$USE)+)

    $LIB_CLOSE

  }x;


  Readonly my $PROC_BODY => qr{

  (?<body>

    (?:proc\.new)

    (?:

      (?!proc\.leave)
      (?:.|\s)

    )*

    (?:proc\.leave)

  )

  }x;

  Readonly my $PROC => qr{

    $PROC_BODY

    (?: $WS*)
    (?: ret|exit [^\n]*\n)?

  }x;

  Readonly my $IPROC => qr{

    (?<body>

      proc.new
      (?: (?! inline)(.|\s)+)

    )

    (?: inline [^\n]*\n)

    (?:

      (?: (?! ret|exit)(.|\s)+)
      (?: ret|exit [^\n]*\n)

    )?

  }x;



  Readonly my $LCOM => qr{

    ^ \s* ;

    (?: .*)
    (?: \n|$)

  }x;

  Readonly my $SEG  => qr{(?:

    (?: (?:ROM|RAM|EXE) SEG)
  | (?: (?:section|segment))

  | (?: constr \s+ (?: ROM|RAM))

  ) $NTERM}x;

  Readonly my $REG => qr{

    (?: reg\.new) $NTERM
    (?<! \,public) $TERM


    (?:

      (?: (?! reg\.end) (?: .|\s) )+
    | (?R)

    )*


    reg\.end

  }x;

  Readonly my $REGICE => qr{
    (?: reg\.ice) $NTERM

  }x;

  Readonly my $GETIMP => q[

if ~ defined loaded?Imp
  include '%ARPATH%/forge/Imp.inc'

end if

];

  Readonly our $PREIMP => q[

MAM.xmode='__MODE__'
MAM.head __ENTRY__

];

  Readonly my $FOOT => q[

MAM.avto
MAM.foot

];

# ---   *   ---   *   ---
# scrap non-binary data
# (ie code) from file

sub get_nonbin($class,$fpath) {

  my $body   = orc($fpath);

  $class->strip_meta(\$body);

  my $macros = $class->strip_macros(\$body);
  my $procs  = $class->strip_procs(\$body);
  my $extrn  = $class->get_extrn($fpath);

  $class->strip_codestr(\$body);


  return

    "$extrn\n"

  . (join "\n",@$macros) . "\n"
  . "$body\n"

  . (join "\n",@$procs)  . "\n"

  ;

};

# ---   *   ---   *   ---
# ^remove macros from codestr
# save them to out

sub strip_macros($class,$sref) {

  my $out=[];

  while($$sref=~ s[$MACRO][]) {
    push @$out,
      "macro $+{name} $+{args} $+{body}";

  };


  return $out;

};

# ---   *   ---   *   ---
# get exported symbols

sub get_extrn($class,$fpath) {

  state $re = qr{^extrn};

  # get symbol file
  my @out=();
  my $src=obj_from_src(

    $fpath,

    ext       => '.preshwl',
    use_trash => 1,

  );

  # ^skip if non-existent
  goto TAIL if ! -f $src;

  # ^read file and get extrn decls
  my $body = orc($src);
     @out  = grep {$ARG=~ $re} split "\n",$body;

TAIL:
  return join "\n",@out;

};

# ---   *   ---   *   ---
# ^remove private data

sub strip_codestr($class,$sref) {

  state $constr_re=qr{constr\.new};

  $$sref=~ s[$SEG][]sxmg;
  $$sref=~ s[$REG][]sxmg;
  $$sref=~ s[$REGICE][]sxmg;

  $$sref=~ s[$constr_re][constr._ns_new]sxmg;

};

# ---   *   ---   *   ---
# ^remove code, but leave
# proc macros for inlining

sub strip_procs($class,$sref) {

  state $line_re=qr{^\s*proc\.};
  state $keep_re=qr{^\s*proc\.new};

  my $out=[];

  $$sref=~ s[$PROC][]sxmg;

  while($$sref=~ s[$IPROC][]) {

    my $s=$+{body};

    push @$out,grep {
      $ARG=~ $line_re

    } split $NEWLINE_RE,$s;

  };

  map {$ARG=~ s[$keep_re][proc._ns_new]} @$out;

  return $out;

};

# ---   *   ---   *   ---
# ^remove metadata

sub strip_meta($class,$sref) {

  my @out=grep {
    ! ($ARG=~ m[$LCOM]sxm)
  &&! ($ARG=~ m[^\s*$]sxm)

  } split "\n",$$sref;

  $$sref=join "\n",@out;

};

# ---   *   ---   *   ---
# scrap deps meta from
# importer cmd

sub read_deps($class,$base,$deps) {

  my @out=();

  while($deps=~ s[$USE][]sxm) {

    # get file name and extension
    my $ext  = $+{ext};
    my $name = $+{name};

    # ^clean
    $ext  =~ s[$STRSTRIP][]sxmg;
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

  my @out=();

  while($body=~ s[$LIB][]sxm) {

    my $head=$+{head};
    my $uses=$+{uses};

    # ^scrap import meta
    my $env  = $+{env};
    my $path = $+{path};

    # ^get import path
    $env=($env ne '_')
      ? $ENV{$env}
      : $NULLSTR
      ;

    $path=~ s[$STRSTRIP][]sxmg;

    my $base="$env$path";

    push @out,$class->read_deps($base,$uses);

  };


  # cleanup and give
  map {
     $ARG =  extwap($ARG,'asm')
  if $ARG =~ $is_fake;

  } @out;

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
    unshift @flist,
      $class->get_file_deps($body);

  };


  # cleanup and give
  return @out;

};

# ---   *   ---   *   ---
# build dependency files

sub build_deps($class,@flist) {

  my @order=();

  for my $bfile(@flist) {

    # get src
    my $fpath = $bfile->{src};
    my $dst   = $class->get_altsrc($fpath);
    my $body  = orc($fpath);


    # get deps file
    my $depsf=extwap($dst,'asmd');

    # ^recursive depscrap chk
    if(moo($dst,$depsf)) {

      my @deps=$class->get_file_deps($body);
      unshift @deps,$class->get_deps(@deps);

      array_dupop(\@deps);
      unshift @order,@deps;

      owc($depsf,join "\n",@deps);

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
# make pre-build trashfile

sub prebuild($class,$bfile,%O) {

  # defaults
  $O{mode}  //= 'obj';
  $O{entry} //= $NULLSTR;


  # get build mode
  my $pre=$PREIMP;

  $pre=~ s[__MODE__][$O{mode}];
  $pre=~ s[__ENTRY__][$O{entry}];


  # get src
  my $fpath = $bfile->{src};
  my $dst   = $class->get_altsrc($fpath);
  my $body  = orc($fpath);

  $class->strip_meta(\$body);

  # ^cat chunks
  my $out="$GETIMP$pre$body$FOOT";


  # emit
  $bfile->{_pproc_src} = $fpath;
  $bfile->{src}        = $dst;
  owc($dst,$out);

  return $dst;

};

# ---   *   ---   *   ---
# ^make post-build header

sub postbuild($class,$bfile) {

  state $get_author=qr{AUTHOR  \s+ ($NTERM)}x;


  my $out=$NULLSTR;
  $bfile->{src}=$bfile->{_pproc_src};

  # get src
  my $fpath = $bfile->{src};
  my $body  = orc($fpath);

  # scrap info
     $body     =~ $get_author;
  my $author   =  $1;
     $author //=  $Emit::ON_NO_AUTHOR;

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
1; # ret
