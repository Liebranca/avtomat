#!/usr/bin/perl
# ---   *   ---   *   ---
# AVT
# avtomat utils as a package
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb
# ---   *   ---   *   ---

# deps
package Avt;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use Storable;

  use Cwd qw(abs_path getcwd);

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::String;
  use Arstd::Hash;
  use Arstd::IO;

  use Shb7;
  use Vault 'ARPATH';

  use Cli;

  use lib $ENV{'ARPATH'}.'/lib/hacks';
  use Shwl;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Emit::Std;
  use Emit::C;

  use Lang;
  use Lang::C;
  use Lang::Perl;
  use Lang::Peso;

  use Peso::St;
  use Peso::Rd;
  use Peso::Ipret;

  use Avt::Sieve;
  use Makescript;

# ---   *   ---   *   ---
# info

  our $VERSION=v3.21.4;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $CONFIG_DEFAULT=>{

    name=>$NULLSTR,

    scan=>$NULLSTR,
    build=>$NULLSTR,

    xcpy=>[],
    lcpy=>[],
    incl=>[],
    libs=>[],

    gens=>{},

    tests=>{},
    utils=>{},

    defs=>[],
    xprt=>[],
    deps=>[],

    pre_build=>$NULLSTR,
    post_build=>$NULLSTR,

  };

  Readonly my $BIND=>'./bin';
  Readonly my $LIBD=>'./lib';
  Readonly my $INCD=>'./include';

# ---   *   ---   *   ---
# lenkz

  Readonly our $GITHUB=>q{https://github.com};
  Readonly our $LYEB=>$GITHUB.q{/Liebranca};

# ---   *   ---   *   ---
# global storage

  my %Cache=(

    _config=>{},
    _scan=>[],
    _modules=>[],

    _post_build=>{},
    _pre_build=>{},

    cli=>Cli->nit(
      {id=>'update',short=>'-u',argc=>0}

    ),

    cli_in=>[],

  );

# ---   *   ---   *   ---
# command line interface

sub read_cli($mod) {

  my $c  = $Cache{cli};
  my $ar = $Cache{cli_in};

  if(!@$ar) {
    @$ar=$c->take(@ARGV);

  };

  if($c->{update} ne $NULL) {
    my $fname=Vault::px_file($mod);
    unlink $fname if -f $fname;

    Shb7::empty_trash($mod);

  };

};

# ---   *   ---   *   ---

sub MODULES {return @{$Cache{_modules}}};

# ---   *   ---   *   ---
# looks at a single file for symbols

sub file_sbl($f) {

  my $found='';
  my $langname=Lang::file_ext($f);

  if(!defined $langname) {

    errout(

      q{Can't determine language for file '%s'},
      args=>[$f],
      lvl=>$AR_FATAL,

    );

  };

# ---   *   ---   *   ---

  my $object={

    utypes=>{},

    functions=>{},
    variables=>{},
    constants=>{},

  };

# ---   *   ---   *   ---
# read source file

  my $lang=Lang->$langname;

  my $rd=Peso::Rd::parse(
    $lang,$f

  );

  my $block=$rd->select_block(-ROOT);
  my $tree=$block->{tree};

  $rd->recurse($tree);
  $lang->hier_sort($rd);

# ---   *   ---   *   ---
# mine the tree

  $rd->fn_search(

    $tree,
    $object->{functions},

  );

  $rd->utype_search(

    $tree,
    $object->{utypes},

  );

  return $object;

};

# ---   *   ---   *   ---
# in:modname,[files]
# write symbol typedata (return,args) to shadow lib

sub symscan($mod,$dst,$deps,@fnames) {

  Shb7::push_includes(
    Shb7::dir($mod)

  );

  my @files=();

# ---   *   ---   *   ---
# iter filelist

  { for my $fname(@fnames) {

      if( ($fname=~ m/\%/) ) {
        push @files,@{ Shb7::wfind($fname) };

      } else {
        push @files,Shb7::ffind($fname);

      };

    };

  };

# ---   *   ---   *   ---

  my $shwl={

    deps=>$deps,
    objects=>{},

  };

# ---   *   ---   *   ---
# iter through files

  for my $f(@files) {

    if(!$f) {next};

    my $o=Shb7::obj_from_src($f);
    $o=Shb7::shpath($o);

    $shwl->{objects}->{$o}=file_sbl($f);

  };

  store($shwl,$dst) or croak strerr($dst);

};

# ---   *   ---   *   ---
# in: filepaths dst,src
# extends one perl file with another

sub plext($dst_path,$src_path) {

  $dst_path=Shb7::file($dst_path);
  $src_path=Shb7::file($src_path);

  my $src=orc($src_path);
  $src=~ s/.+#:CUT;>\n//sg;

  my $dst=orc($dst_path);
  $dst=~ s/1; # ret\n//sg;

  $dst.=$src;
  open FH,'>',$dst_path
  or croak strerr($dst_path);

  print FH $dst;
  close FH;

};

# ---   *   ---   *   ---

sub ex($name,$opts,$tail) {

  my @opts=@{ $opts };

  for(my $i=0;$i<@opts;$i++) {
    if(($opts[$i]=~ m/\s/)) {
      $opts[$i]=dqwrap($opts[$i]);

    };
  };

  return `$ENV{'ARPATH'}/bin/$name @opts $tail`;

};

# ---   *   ---   *   ---
# path utils

# args=chkpath,name,repo-url,actions
# pulls what you need

sub depchk($chkpath,$deps) {

  $chkpath=abs_path($chkpath);

  my $old_cwd=abs_path(getcwd());
  chdir $chkpath;

# ---   *   ---   *   ---

  while(@$deps) {
    my ($name,$url,$act)=@{ shift @$deps };

# ---   *   ---   *   ---
# pull if dir not found in provided path

    if(!(-e $chkpath."/$name")) {
      `git clone $url`;

# ---   *   ---   *   ---
# blank for now, use this for building extdeps

    };if($act) {
      ;

    };

# ---   *   ---   *   ---

  };

  chdir $old_cwd;

};

# ---   *   ---   *   ---
# ensures trsh and bin exist
# outs file/dir list

sub scan() {

  my $fpath=Shb7::cache("avto-modules");

  # ensure we have these standard paths
  for my $path(

    Shb7::dir("bin"),
    Shb7::dir("lib"),
    Shb7::dir("include"),

    $Shb7::Path::Trash,
    $Shb7::Path::Cache,
    $Shb7::Path::Mem,

  ) {if(! -e $path) {mkdir $path}};

# ---   *   ---   *   ---
# iter provided names

  my @ar=@{$Cache{_scan}};
  while(@ar) {

    my ($mod,$excluded)=split
      m[\s+(?: -x | --excluded)\s+]x,
      (shift @ar)

    ;

    $excluded//=$NULLSTR;
    $excluded=[
      Lang::ws_split($COMMA_RE,$excluded)

    ];

# ---   *   ---   *   ---
# read module tree

    read_cli($mod);

    my $tree=Vault::check_module(
      $mod,$excluded

    );

    my $trsh=Shb7::obj_dir($mod);
    my $modpath=Shb7::dir($mod);

    # ensure there is a trashcan
    if(!(-e $trsh)) {
      system 'mkdir',('-p',"$trsh");

    };

# ---   *   ---   *   ---
# walk module path

    my @dirs=$tree->get_dir_list(
      full_path=>0,
      keep_root=>1

    );

# ---   *   ---   *   ---
# get relative paths

    for my $dir(@dirs) {

      my ($root,$ddepth)=$dir->root();
      my $ances=$NULLSTR;

      if($dir ne $root) {

        $ances=$dir->ances(
          $NULLSTR,max_depth=>$ddepth

        );

      };

# ---   *   ---   *   ---
# ensure trash directories exist

      my $tdir=$trsh.$ances;

      if(!(-e $tdir)) {
        `mkdir -p $tdir`;

      };

    };

  };

};

# ---   *   ---   *   ---

sub get_config_build($M,$config) {

  $M->{fswat}=$config->{name};

  my ($lmode,$mkwat)=($NULLSTR,$NULLSTR);

  if(length $config->{build}) {

    ($lmode,$mkwat)=
      Lang::ws_split($COLON_RE,$config->{build});

  };

# ---   *   ---   *   ---

  if($lmode eq 'so') {
    $lmode='-shared ';

  } elsif($lmode ne 'ar') {
    $lmode=$NULLSTR;

  };

  $M->{lmode}=$lmode;
  $M->{mkwat}=$lmode;

# ---   *   ---   *   ---

  if(length $mkwat) {

    $M->{ilib}="$LIBD/.$mkwat";

    if($lmode eq 'ar') {
      $M->{main}="$LIBD/lib$mkwat.a";
      $M->{mlib}=undef;

    } elsif($lmode eq '-shared ') {
      $M->{main}="$LIBD/lib$mkwat.so";
      $M->{mlib}=undef;

    } else {
      $M->{main}="$BIND/$mkwat";
      $M->{mlib}="$LIBD/lib$mkwat.a";

    };

  } else {
    $M->{ilib}=undef;
    $M->{main}=undef;
    $M->{mlib}=undef;

  };

};

# ---   *   ---   *   ---

sub get_config_paths($M,$config) {

  $M->{libs}=[
    q{-L}.$LIBD,
    @{$config->{libs}},

  ];

  $M->{incl}=[

    q{-I}.$INCD,
    q{-I./},

    q{-I./}.$config->{name}.q{/},

    @{$config->{incl}},

  ];

};

# ---   *   ---   *   ---
# filters out file list using config
# writes results to makescript

sub get_config_files($M,$C,$module) {

  my @dirs=$module->get_dir_list(
    full_path=>0,
    keep_root=>1

  );

  my $sieve=Avt::Sieve->nit(
    makescript => $M,
    config     => $C,
    bindir     => $BIND,
    libdir     => $LIBD,

  );

  $sieve->iter(\@dirs);

};

# ---   *   ---   *   ---
# invert generator hash
#
#   > from: generated=>[generator,dependencies]
#     to: generator=>[generated,dependencies]
#
# the reason why is the first form makes more
# sense visually (at least to me), so that's
# what i'd rather write to a config file
#
# however, the second form is more convenient
# for a file search, so...

sub invert_generator($dst) {

  my %inverted=();

  for my $outfile(keys %$dst) {

    my @srcs=@{$dst->{$outfile}};
    my $exec=$srcs[0];

    $inverted{$exec}=[
      $outfile,@srcs[1..$#srcs]

    ];

  };

  $dst={%inverted};

};

# ---   *   ---   *   ---
# registers module configuration

sub set_config(%C) {

  state $sep_re=Lang::ws_split_re(q{,});
  state $list_to_hash=qr{(?:

    lcpy
  | xcpy
  | xprt

  )}x;

# ---   *   ---   *   ---

  my $modules=$Cache{_modules};
  my $scan=$Cache{_scan};

  # ensure all needed fields are there
  for my $key(keys %{$CONFIG_DEFAULT}) {
    if(!(exists $C{$key})) {
      $C{$key}=$CONFIG_DEFAULT->{$key};

    };
  };

# ---   *   ---   *   ---
# convert file lists to hashes

  for my $key(keys %C) {

    if($key=~ $list_to_hash) {

      if(@{$C{$key}}) {
        $C{$key}={
          map {$ARG=>1} @{$C{$key}}

        };

      } else {
        $C{$key}={};

      };

    };

  };

# ---   *   ---   *   ---
# run dependency checks

  depchk(

    Shb7::dir($C{name}),
    $C{deps}

  ) if $C{deps};

# ---   *   ---   *   ---
# prepare the libs && includes

  for my $lib(@{$C{libs}}) {
    if((index $lib,q{/})>=0) {
      $lib=q{-L}.$lib;

    } else {
      $lib=q{-l}.$lib;

    };
  };

  for my $include(@{$C{incl}}) {
    $include=q{-I./}.$include;

  };

# ---   *   ---   *   ---
# from result=>[src,deps]
# to   src=>[result,deps]

  invert_generator($C{gens});
  invert_generator($C{tests});
  invert_generator($C{utils});

map {
  say {*STDOUT} '>>'.$ARG;
  map {say {*STDOUT} $ARG} @{$C{utils}->{$ARG}};

} keys %{$C{utils}};

# ---   *   ---   *   ---
# append

  push @$modules,$C{name};

  if(length $C{scan}) {
    push @$scan,
      $C{name}.q{ }.$C{scan}

  } else {
    push @$scan,$C{name};

  };

  $Cache{_config}->{$C{name}}=\%C;

};

# ---   *   ---   *   ---
# ^saves whole project configuration to file

sub config() {

  my $src=Shb7::cache("avto-config");
  my $config=$Cache{_config};

  # overwrite old values
  if(-e $src) {

    my $h=retrieve($src);
    $config={%$h,%$config};

  };

  store($config,$src) or croak strerr($src);

};

# ---   *   ---   *   ---
# ^reads it in

sub read_config() {

  my $src=Shb7::cache("avto-config");
  my $config=retrieve($src)
  or croak strerr($src);

};

# ---   *   ---   *   ---
# emits builders

sub make() {

  # fetch project data
  my $configs=read_config();

  # now iter
  for my $name(keys %$configs) {

    my $module=Vault::check_module($name);
    my $C=$configs->{$name};

    my $avto_path=Shb7::file("$name/avto");

    # build the makescript object
    my $M=Makescript->nit();
    get_config_build($M,$C);
    get_config_paths($M,$C);
    get_config_files($M,$C,$module);

    # save it to disk
    my $cache_path=Shb7::file("$name/.avto-cache");

    store($M,$cache_path)
    or croak strerr($cache_path);

# ---   *   ---   *   ---
# now dump the boiler

    open my $FH,'>',$avto_path
    or croak strerr($avto_path);

    my $FILE=$NULLSTR;

    # write notice
    $FILE.='#!/usr/bin/perl'."\n";
    $FILE.=Emit::Std::note('IBN-3DILA','#');

    # paste in the pre-build hook

    if(length $C->{pre_build}) {
      $FILE.=

      "\n\n".

      'INIT {'."\n\n".

        'print {*STDERR} "'.
        $Emit::Std::ARSEP.
        'running pre-build hook... \n";'.

        $C->{pre_build}.';'.
        "\n\n".

      "};\n";

    };

    $FILE.=<<'EOF'

# ---   *   ---   *   ---
#deps

  use 5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use Storable;

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Path;
  use Shb7;
  use Cli;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Makescript;

# ---   *   ---   *   ---

my $cli=Cli->nit(

  { id=>'debug',short=>'-d',
    long=>'--debug',argc=>0

  },

);

my @args=$cli->take(@ARGV);

# ---   *   ---   *   ---

my $root=parof(__FILE__);
my $M=retrieve(

  dirof(__FILE__).
  '/.avto-cache'

);

chdir Shb7::set_root($root);
$M=Makescript->nit_build($M,$cli);

# ---   *   ---   *   ---

print {*STDERR}
  $Emit::Std::ARTAG."upgrading $M->{fswat}\n";

$M->set_build_paths();
$M->update_generated();

my $objblt=$M->update_objects();

$M->build_binaries($objblt);
$M->update_regular();

$M->side_builds();

print {*STDERR}
  $Emit::Std::ARSEP."done\n\n";

EOF
;

# ---   *   ---   *   ---
# paste in the post-build hook

    if(length $C->{post_build}) {
      $FILE.=

      #"\n".
      '# ---   *   ---   *   ---'.
      "\n\n".

      "END {\n\n".

        'print {*STDERR} "'.
        $Emit::Std::ARSEP.
        'running post-build hook... \n";'.

        $C->{post_build}.';'.
        '$M->depsmake();'.

      "\n\n};".

      "\n\n".

      '# ---   *   ---   *   ---'.
      "\n\n"

      ;

    } else {
      $FILE.="\n".'$M->depsmake();';

    };

# ---   *   ---   *   ---

    print {$FH} $FILE;
    close $FH;

    `chmod +x "$avto_path"`;

  };

};

# ---   *   ---   *   ---
1; # ret
