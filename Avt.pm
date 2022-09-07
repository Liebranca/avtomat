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

# ---   *   ---   *   ---
# info

  our $VERSION=v3.21.2;
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

  );

# ---   *   ---   *   ---

sub MODULES {return @{$Cache{_modules}}};

# ---   *   ---   *   ---
# Python emitter tools

sub cpyboil($name,$closed) {

  return

    q{#!/usr/bin/python}."\n".
    q{$:NOTE;>}."\n"

  ;

};

sub wrcpyboil {

  my $dir=shift;
  my $fname=shift;
  my $author=shift;
  my $call=shift;
  my $call_args=shift;

  # create file
  my $path=Shb7::file($dir."$fname.py");

  open my $FH,'>',$path
  or croak strerr($path);

# ---   *   ---   *   ---

  # generate notice
  my $n=note($author,'#');

  # open boiler and subst notice
  my $op=cpyboil(uc($fname),0);
  $op=~ s/\$\:NOTE\;\>/${ n }/;

  # write it to file
  print $FH $op;

  # write the code through the generator
  $call->($FH,@$call_args);

#  # close boiler
#  print $FH Avt::cplboil_pm uc($fname),1;
  close $FH or croak strerr($path);

};

# ---   *   ---   *   ---

sub py_typecon($type) {

  state %types=qw{

    string c_char_p
    string* POINTER(c_char_p)

    void None
    void* c_void_p

    size_t c_size_t

    float c_float
    float* POINTER(c_float)

    char c_int8_t
    uchar c_uint8_t

    uchar* POINTER(c_uint8_t)

    short c_int16_t
    ushort c_uint16_t

    short* POINTER(c_int16_t)
    ushort* POINTER(c_uint16_t)

    int c_int32_t
    uint c_uint32_t

    int* POINTER(c_int32_t)
    uint* POINTER(c_uint32_t)

    long c_int64_t
    ulong c_uint64_t

    long* POINTER(c_int64_t)
    ulong* POINTER(c_uint64_t)


  };

# ---   *   ---   *   ---

  if(exists $types{$type}) {
    $type=$types{$type};

  };

  return $type;

};

# ---   *   ---   *   ---

sub ctopy($FH,$soname,$libs_ref) {
  my %symtab=%{soregen($soname,$libs_ref)};

# ---   *   ---   *   ---

my $code=q{

from ctypes import *;
ROOT='/'.join(__file__.split("/")[0:-1]);

$:structs;>

class $:soname;>:

  @classmethod
  def nit():
    self=cdll.LoadLibrary(
      ROOT+"lib$:soname;>.so"

    );

$:iter (

      x0=>[@{$O{names}}],
      x1=>[@{$O{rtypes}}],
      x2=>[@{$O{arg_types}}],

    )

      "    self.call_$x0=self.__getattr__".
      "('$x0');\n".

      "    self.call_$x0.restype=$x1;\n".
      "    self.call_$x0.argtypes=$x2;\n\n"

    ;>

    return self;

};

# ---   *   ---   *   ---
# walk the symbol table

  my @names=();
  my @rtypes=();
  my @arg_types=();

  my $structs=$NULLSTR;

  for my $o(keys %{$symtab{objects}}) {

    my $obj=$symtab{objects}->{$o};
    my $funcs=$obj->{functions};

# ---   *   ---   *   ---
# functions in object

    for my $fn_name(keys %$funcs) {

      my $fn=$funcs->{$fn_name};

      my $rtype=$fn->{type};
      $rtype=py_typecon($rtype);

      my @arg_names=keys %{$fn->{args}};

      my @args=map
        {py_typecon($ARG)}
        values %{$fn->{args}}

      ;

      push @names,$fn_name;
      push @rtypes,$rtype;

      push @arg_types,
        '['.(join q{,},@args).']';

    };

# ---   *   ---   *   ---
# user-defined types in object

    my $utypes=$obj->{utypes};

    for my $ut_name(keys %$utypes) {

      $structs.="class $ut_name(Structure):\n";
      $structs.="  _fields_=[\n";

      my $utype=$utypes->{$ut_name};

      my @field_names=keys %$utype;
      my @field_types=map

        {py_typecon($ARG)}
        values %$utype

      ;

# ---   *   ---   *   ---

      while(@field_names && @field_types) {
        my $field_name=shift @field_names;
        my $field_type=shift @field_types;

        $structs.=q{    }.
          "('$field_name',".
          "$field_type),\n"

        ;

      };

      $structs.="  ];\n\n";

# ---   *   ---   *   ---

    };

  };

  # replace the $:escapes;>
  Peso::Ipret::pesc(

    \$code,

    structs=>$structs,
    soname=>$soname,

    names=>\@names,
    rtypes=>\@rtypes,
    arg_types=>\@arg_types,

  );

  # spit it out
  return print {$FH} "$code\n";

};

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

  Shb7::stinc(Shb7::dir($mod));

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

  my $fpath=Shb7::cache_file("avto-modules");

  # ensure we have these standard paths
  for my $path(

    Shb7::dir("bin"),
    Shb7::dir("lib"),
    Shb7::dir("include"),

    $Shb7::Trash,
    $Shb7::Cache,
    $Shb7::Mem,

  ) {if(!(-e $path)) {mkdir $path}};

# ---   *   ---   *   ---
# iter provided names

  my @ar=@{$Cache{_scan}};
  while(@ar) {

    my ($mod,$excluded)=split m[\s],shift @ar;

    if(defined $excluded) {

      # handle exclude flag short
      if($excluded=~ m/-x/) {
        $excluded=~ s/-x\s*//;

      # handle exclude flag long
      } elsif($excluded=~
          m/\-\-exclude\=[\w|\d]*/

      ) {
        $excluded=~ s/\-\-exclude\=//;

      };

    };

    $excluded//=$NULLSTR;
    $excluded=[
      Lang::ws_split($COMMA_RE,$excluded)

    ];

# ---   *   ---   *   ---
# read module tree

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

# ---   *   ---   *   ---

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

  $M->{libs}=q{-L}.$LIBD.q{ }.(
    join q{ },@{$config->{libs}}

  );

  $M->{incl}=q{-I}.$INCD.q{ -I./ }.(
    join q{ },@{$config->{incl}}

  );

};

# ---   *   ---   *   ---

sub get_config_files($M,$config,$module) {

  state $c_ext=qr{\.c$};
  state $perl_ext=qr{\.pm$};

  $M->{fcpy}=[];
  $M->{xprt}=[];
  $M->{gens}=[];
  $M->{srcs}=[];
  $M->{objs}=[];

# ---   *   ---   *   ---

  my @dirs=$module->get_dir_list(
    full_path=>0,
    keep_root=>1

  );

  for my $dir_node(@dirs) {

    my $name=$config->{name};
    my $trsh=$NULLSTR;

    my @files=$dir_node->get_file_list(
      full_path=>1,
      max_depth=>1,

    );

    map {$ARG=Shb7::shpath($ARG)} @files;
    map {$ARG=~ s[^${name}/?][]} @files;

    my $dir=$dir_node->{value};

    # get path to
    $dir="./$name";
    $trsh=Shb7::rel(Shb7::obj_dir($name));

# ---   *   ---   *   ---

    my $matches=lfind(
      $config->{gens},\@files

    );

    while(@$matches) {

      my $match=shift @$matches;
      my ($outfile,$srcs)=@{
        $config->{gens}->{$match}

      };

      delete $config->{gens}->{$match};
      $match=~ s[\*][];

      map {$ARG="$dir/$ARG"} @$srcs;

      push @{$M->{gens}},(
        "$dir/$match",
        "$dir/$outfile",

        (join q{,},@$srcs)

      );

    };

# ---   *   ---   *   ---

    $matches=lfind($config->{xcpy},\@files);

    while(@$matches) {

      my $match=shift @$matches;
      delete $config->{xcpy}->{$match};

      $match=~ s[\*][];
      $match=~ s[\\][]g;

      push @{$M->{fcpy}},(
        "$dir/$match",
        "$BIND/$match"

      );

    };

# ---   *   ---   *   ---

    $matches=lfind($config->{lcpy},\@files);

    while(@$matches) {
      my $match=shift @$matches;
      delete $config->{lcpy}->{$match};

      $match=~ s[\\][]g;

      my $lmod=$dir;
      $lmod=~ s[${Shb7::Root}/${name}][];
      $lmod.=($lmod) ? q{/} : $NULLSTR;

      push @{$M->{fcpy}},(
        "$dir/$match",
        "$LIBD/$lmod$match"

      );

    };

# ---   *   ---   *   ---

    $matches=lfind($config->{xprt},\@files);

    while(@$matches) {
      my $match=shift @$matches;
      delete $config->{xprt}->{$match};

      $match=~ s[\\][]g;
      push @{$M->{xprt}},"$dir/$match";

    };

# ---   *   ---   *   ---

    my @matches=grep m/$c_ext/,@files;

    while(@matches) {
      my $match=shift @matches;
      $match=~ s[\\][]g;

      my $ob=$match;$ob=(substr $ob,0,
        (length $ob)-1).'o';

      my $dep=$match;$dep=(substr $dep,0,
        (length $dep)-1).'d';

      push @{$M->{srcs}},"$dir/$match";
      push @{$M->{objs}},(
        "$trsh/$ob",
        "$trsh/$dep"

      );

    };

# ---   *   ---   *   ---

    @matches=grep m/$perl_ext/,@files;

    while(@matches) {
      my $match=shift @matches;
      $match=~ s[\\][]g;

      my $dep=$match;
      $dep.='d';

      push @{$M->{srcs}},"$dir/$match";

      my $lmod=$dir;
      $lmod=~ s([.]/${name})();

      push @{$M->{objs}},(
        "$LIBD$lmod/$match",
        "$trsh$dep"

      );

    };

# ---   *   ---   *   ---

  };

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

  my %gens=();

  for my $outfile(keys %{$C{gens}}) {

    my $srcs=$C{gens}->{$outfile};
    my $exec=shift @$srcs;

    $gens{$exec}=[$outfile,$srcs];

  };

  $C{gens}=\%gens;

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

  my $src=Shb7::cache_file("avto-config");
  my $config=$Cache{_config};

  # overwrite old values
  if(-e $src) {
    my $h=retrieve($src);
    $config={%$config,%$h};

  };

  store($config,$src) or croak strerr($src);

};

# ---   *   ---   *   ---
# ^reads it in

sub read_config() {

  my $src=Shb7::cache_file("avto-config");
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
    my $M={};
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

  use Storable;

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use lib $ENV{'ARPATH'}.'/lib/';

  use Arstd::Path;

  use Shb7;
  use Makescript;

# ---   *   ---   *   ---

my $PFLG='-m64';
my $DFLG='';

my $root=parof(__FILE__);
my $M=retrieve(

  dirof(__FILE__).
  '/.avto-cache'

);

chdir Shb7::set_root($root);
$M=Makescript->nit($M);

# ---   *   ---   *   ---

print {*STDERR}
  $Emit::Std::ARTAG."upgrading $M->{fswat}\n";

$M->set_build_paths();
$M->update_generated();

my ($OBJS,$objblt)=
  $M->update_objects($DFLG,$PFLG);

$M->build_binaries($PFLG,$OBJS,$objblt);
$M->update_regular();

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
