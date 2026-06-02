#!/usr/bin/perl
# ---   *   ---   *   ---
# AVTO SWITCH
# -Wl,--fuse-arcane-solutions
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto::switch;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use Cwd qw(abs_path);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_file);

  use Arstd::String qw(gsplit);
  use Arstd::Array qw(dupop);
  use Arstd::throw;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.2a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# generates switches from project struc

sub proc {
  my ($px)=@_;
  my $sw={
    proc_def($px),
    proc_path($px),
    proc_bld($px),
  };
  $sw->{ldarch}  = [ldarch($sw)];
  $sw->{ldentry} = "--entry=$px->{entry}";

  # determine output path
  my $path=$px->{bld}->{path};
  if($px->{shared}) {
    $sw->{output}=$path->{so};

  } elsif($px->{bld}->{mode} eq 'ar') {
    $sw->{output}=$path->{ar};

  } else {
    $sw->{output}=$path->{ex};
  };

  return $sw;
};


# ---   *   ---   *   ---
# handles `-D` defines

sub proc_def {
  my ($px)=@_;
  my $def=[@{$px->{def}}];

  push @$def,"DEBUG=" . int($px->{debug});

  $ARG="-D$ARG" for @$def;
  return (def=>$def);
};


# ---   *   ---   *   ---
# adds `-I`, `-L` and `-l`
# to includes and libs

sub proc_path {
  my ($px)=@_;
  my $lib=$px->{lib};

  return (
    lib=>[
      (map {"-L$ARG"} @{$lib->{dir}}),
      (map {"-l$ARG"} @{$lib->{file}}),
    ],
    inc=>[map {"-I$ARG"} @{$px->{inc}}],
  );
};


# ---   *   ---   *   ---
# makes switches for `bld`

sub proc_bld {
  my ($px)=@_;
  return (
    obc  => proc_bld_obc($px),
    link => proc_bld_link($px),
    arch => proc_bld_arch($px),
  );
};


# ---   *   ---   *   ---
# handles the `obc` switch

sub proc_bld_obc {
  my ($px)=@_;

  # make copy of switch value
  my $sw=switch_rd($px->{bld}->{obc});

  # debug mode takes precedence
  @$sw=qw(debug) if $px->{debug};

  # necessary adjustments for linking mode
  my $link={map {$ARG=>1} @{$px->{bld}->{link}}};
  push @$sw,'shared' if $px->{shared};
  push @$sw,'flat'   if $link->{flat}
                     || $link->{fflat};

  # put optimization level,
  # and *then* replace presets from table
  unshift @$sw,proc_bld_obc_lvl($sw);
  xlate($sw,'obc',xlate_obc_tab(
    @{$px->{preset}->{obc}}
  ));

  # give back modified copy
  return $sw;
};


# ---   *   ---   *   ---
# determines optimization level
# based on the selected `obc` mode

sub proc_bld_obc_lvl {
  my ($sw)=@_;

  # if the user passed in an optimization
  # level flag, then give priority to that
  my $re  = qr{^-O[gzsf0123]};
  my $tab = {map {
    return $ARG if $ARG=~ $re;
    $ARG=>1;

  } @$sw};

  # -O0 should work here too, but
  # some of the flags we're using for
  # debug builds don't seem to work so
  # well with that, so we'll try -Og instead
  return '-Og' if $tab->{debug};

  # byte size matters
  return '-Oz' if $tab->{tiny};
  return '-Os' if $tab->{light};

  # ^except when it doesn't
  return '-Ofast' if $tab->{sonic};
  return '-O3'    if $tab->{heavy};

  # in all other cases just give the default ;>
  return '-O2';
};


# ---   *   ---   *   ---
# translation table for the `--obc` switch

sub xlate_obc_tab {
  return {
    lto => [qw(
      -flto
      -ffunction-sections
      -fdata-sections
      -fsingle-precision-constant
    )],

    # arlitarch's choice
    swan => [qw(cstd -fpermissive -w)],
    cstd => [qw(
      lto
      -ffast-math
      -ftree-vectorize
      -fno-semantic-interposition
      -fno-trapping-math
    )],

    # POV: sacrifing your firstborn for code size
    tiny  => [qw(light)],
    light => [qw(
      lto
      -fomit-frame-pointer
      -fipa-pta
      -fno-exceptions
      -fno-unwind-tables
      -fno-asynchronous-unwind-tables
      -fno-ident
    )],

    # gotta go fast
    heavy => [qw(
      cstd
      -funroll-loops
      -fipa-ra
      -floop-nest-optimize
      -fmodulo-sched
    )],
    sonic => [qw(
      heavy
      -funsafe-math-optimizations
      -fno-rounding-math
      -fno-signed-zeros
      -fassociative-math
    )],

    # dont touch my stack trace
    debug => [qw(
      -g3
      -ggdb3
      -fvar-tracking
      -fvar-tracking-assignments
      -fno-eliminate-unused-debug-types
      -fno-eliminate-unused-debug-symbols
      -fno-omit-frame-pointer
      -fno-inline
    )],

    # generic options that avto adds by itself
    shared => [qw(-fPIC)],
    flat   => [qw(-no-pie -nostdlib)],
    fflat  => [qw(flat)],

    # put user-defined presets at the end
    @_
  };
};


# ---   *   ---   *   ---
# handles the `link` switch

sub proc_bld_link {
  my ($px)=@_;

  # make copy of switch value
  my $sw=switch_rd($px->{bld}->{link});

  # sync linking mode with compilation one
  my $obc={map {$ARG=>1} @{$px->{bld}->{obc}}};
  if($obc->{tiny}) {
    @$sw=grep {$ARG ne 'cstd'} @$sw;
    push @$sw,'tiny';
  };

  # fflat controls whether we link with
  # a direct call to lld instead of gcc,
  # so we detect that here
  $px->{flat}=1 if int grep {$ARG eq 'fflat'} @$sw;

  # replace presets from table
  xlate($sw,'link',xlate_link_tab(
    @{$px->{preset}->{link}}
  ));

  # give modified copy
  return $sw;
};


# ---   *   ---   *   ---
# translation table for the `--link` switch

sub xlate_link_tab {
  return {
    # the safe default
    lto  => [qw(-fuse-ld=lld -flto --gc-sections)],
    cstd => [qw(lto --icf=safe)],

    # ^OK, throw 'safe' out the window...
    flat => [qw(
      cstd
      -no-pie
      -nostdlib
      --relax
      -d
      --build-id=none
    )],

    # programming languages?
    # real men use SUMERIAN CUNEIFORM
    fflat => [qw(
      flat
      --omagic
      --no-rosegment
      --no-dynamic-linker
      --no-demangle
    )],

    # avto adds these by itself,
    # accto the `obc` mode
    tiny => [qw(lto --icf=all)],

    # user defined
    @_
  };
};


# ---   *   ---   *   ---
# handles the `link` switch

sub proc_bld_arch {
  my ($px)=@_;

  # straight up copy and replace
  my $sw=switch_rd($px->{bld}->{arch});
  xlate($sw,'arch',xlate_arch_tab(
    @{$px->{preset}->{arch}}
  ));

  return $sw;
};


# ---   *   ---   *   ---
# translation table for the `--arch` switch

sub xlate_arch_tab {
  return {
    # compatibility modes
    x64 => [qw(-m64 -march=x86-64 -mtune=generic)],
    x86 => [qw(-m32 -march=i686 -mtune=generic)],

    # performance modes
    modern => [qw(
      -march=x86-64-v3 -mtune=skylake
    )],
    nitro => [qw(
      -march=x86-64-v4 -mtune=alderlake-avx512
    )],
    native => [qw(
      -march=native -mtune=native
    )],

    # achieving memehood
    toaster => [qw(
      -m32 -march=i486 -mtune=i486
      -mno-sse -mno-mmx
    )],
    abacus => [qw(
      -m32 -march=i386 -mtune=i386
      -msoft-float -mno-sse -mno-mmx
    )],

    # user defined
    @_
  };
};


# ---   *   ---   *   ---
# reads values passed to a switch,
# and then expands them recursively,
# IF any of these values are found in
# the provided table

sub xlate {
  my ($sw,$tname,$tab)=@_;

  # map presets to switches
  rept:

  my $change = 0;
  my @tmp    = ();
  for(@$sw) {
    # preset found?
    if(exists $tab->{$ARG}) {
      push @tmp,@{$tab->{$ARG}};
      $change |= 1;

    # ^nope!
    } else {
      push @tmp,$ARG;
    };
  };

  # save expanded list and recurse,
  # only if the list actually changed
  @$sw=@tmp;
  goto rept if $change;

  # cleanup and give
  for(@$sw) {
    throw "avto: unrecognized '$tname' "
    .     "preset '$ARG'"

    if!   ($ARG=~ qr{^-});
  };
  dupop($sw);
  return;
};


# ---   *   ---   *   ---
# turns string of switches into array

sub switch_rd {
  return [map {gsplit($ARG)} @{$_[0]}];
};


# ---   *   ---   *   ---
# maps gcc architecture flags
# to linker emulation mode

sub ldarch {
  my ($sw)=@_;

  # catch 64-bit
  my $re = qr{^-m(?:64|arch=x86-64)};
  my $ok = int grep {$ARG=~ $re} @{$sw->{arch}};

  return ldarch_elf64() if $ok;

  # catch OLD 32-bit
  $re = qr{^-m(?:32|arch=i386)};
  $ok = int grep {$ARG=~ $re} @{$sw->{arch}};

  return ldarch_elfi386() if $ok;

  # ^then other variants
  $re = qr{^-m(?:32|arch=i[654]86)};
  $ok = int grep {$ARG=~ $re} @{$sw->{arch}};

  return ldarch_elf32() if $ok;

  # lastly, if we can't detect any specific
  # architecture from the flags, then we
  # check the cpuinfo and default to native
  #
  # NOTE we don't count i386 as a possible
  #      native for obvious reasons; that
  #      compilation target is called 'abacus'
  #      for a very obvious reason
  return (cpuflag('lm'))
    ? ldarch_elf64()
    : ldarch_elf32()
    ;
};


# ---   *   ---   *   ---
# ^values

sub ldarch_elf64   {return qw(-m elf_x86_64)};
sub ldarch_elf32   {return qw(-m elf32_x86_64)};
sub ldarch_elfi386 {return qw(-m elf_i386)};


# ---   *   ---   *   ---
# grabs selected linker from link flags
#
# we do this in case that the user
# wants to invoke the linker directly,
# rather than through gcc

sub ldget {
  my ($sw) = @_;
  my @link = (@{$sw->{link}},$sw->{ldentry});
  my $re   = qr{^\-fuse\-ld=};

  my ($which)=grep {$ARG=~ $re} @link;
  @link=grep {! ($ARG=~ $re)} @link;

  $which //= 'bfd';
  return ($which,@link);
};


# ---   *   ---   *   ---
1; # ret
