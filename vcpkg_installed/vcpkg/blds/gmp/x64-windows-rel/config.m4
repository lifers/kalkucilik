dnl config.m4.  Generated automatically by configure.
changequote(<,>)
ifdef(<__CONFIG_M4_INCLUDED__>,,<
define(<CONFIG_TOP_SRCDIR>,<`.././../src/v6.3.0-036e54f1a3.clean'>)
define(<WANT_ASSERT>,0)
define(<WANT_PROFILING>,<`no'>)
define(<M4WRAP_SPURIOUS>,<no>)
define(<TEXT>, <.text>)
define(<DATA>, <.data>)
define(<LABEL_SUFFIX>, <:>)
define(<GLOBL>, <.globl>)
define(<GLOBL_ATTR>, <>)
define(<GSYM_PREFIX>, <>)
define(<RODATA>, <.data>)
define(<TYPE>, <>)
define(<SIZE>, <>)
define(<LSYM_PREFIX>, <L>)
define(<W32>, <.word>)
define(<ALIGN_LOGARITHMIC>,<no>)
define(<ALIGN_FILL_0x90>,<yes>)
define(<HAVE_COFF_TYPE>, <yes>)
define(<SQR_TOOM2_THRESHOLD>,<34>)
define(<BMOD_1_TO_MOD_1_THRESHOLD>,<16>)
define(<SIZEOF_UNSIGNED>,<4>)
define(<GMP_LIMB_BITS>,64)
define(<GMP_NAIL_BITS>,0)
define(<GMP_NUMB_BITS>,eval(GMP_LIMB_BITS-GMP_NAIL_BITS))
>)
changequote(`,')
ifdef(`__CONFIG_M4_INCLUDED__',,`
include(CONFIG_TOP_SRCDIR`/mpn/asm-defs.m4')
include_mpn(`x86_64/x86_64-defs.m4')
include_mpn(`x86_64/dos64.m4')
define_not_for_expansion(`HAVE_HOST_CPU_x86_64')
define_not_for_expansion(`HAVE_ABI_64')
define_not_for_expansion(`HAVE_LIMB_LITTLE_ENDIAN')
define_not_for_expansion(`HAVE_DOUBLE_IEEE_LITTLE_ENDIAN')
')
define(`__CONFIG_M4_INCLUDED__')
