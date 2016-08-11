############################################################
# First we setup and account for the option sets.
############################################################

set(MSVC_GENERAL_OPTIONS)
set(MSVC_DISABLED_WARNINGS)
set(MSVC_WARNINGS_AS_ERRORS)
set(MSVC_ADDITIONAL_DEFINES)
set(MSVC_EXE_LINKER_OPTIONS)
set(MSVC_DEBUG_OPTIONS)
set(MSVC_RELEASE_OPTIONS)
set(MSVC_RELEASE_LINKER_OPTIONS)
set(MSVC_DEBUG_EXE_LINKER_OPTIONS)
set(MSVC_RELEASE_EXE_LINKER_OPTIONS)

# Some addional configuration options.
set(MSVC_ENABLE_ALL_WARNINGS ON CACHE BOOL "If enabled, pass /Wall to the compiler.")
set(MSVC_ENABLE_DEBUG_INLINING ON CACHE BOOL "If enabled, enable inlining in the debug configuration. This allows /Zc:inline to be far more effective, resulting in hphp_runtime_static being ~450mb smaller.")
set(MSVC_ENABLE_LTCG OFF CACHE BOOL "If enabled, use Link Time Code Generation for Release builds.")
set(MSVC_ENABLE_PARALLEL_BUILD ON CACHE BOOL "If enabled, build multiple source files in parallel.")
set(MSVC_ENABLE_STATIC_ANALYSIS OFF CACHE BOOL "If enabled, do more complex static analysis and generate warnings appropriately.")
set(MSVC_FAVORED_ARCHITECTURE "blend" CACHE STRING "One of 'blend', 'AMD64', 'INTEL64', or 'ATOM'. This tells the compiler to generate code optimized to run best on the specified architecture.")

# The general options passed:
list(APPEND MSVC_GENERAL_OPTIONS
  "std:c++latest" # Build in C++17 mode
  "bigobj" # Support objects with > 65k sections. Needed for due to templates.
  "fp:precise" # Precise floating point model used in every other build, use it here as well.
  "EHa" # Enable both SEH and C++ Exceptions.
  "Oy-" # Disable elimination of stack frames.
  "Zc:inline" # Have the compiler eliminate unreferenced COMDAT functions and data before emitting the object file. This produces significantly less input to the linker, resulting in MUCH faster linking.
  "Zc:referenceBinding" # Disallow temproaries from binding to non-const lvalue references.
  "Zc:rvalueCast" # Enforce the standard rules for explicit type conversion.
  "Zc:implicitNoexcept" # Enable implicit noexcept specifications where required, such as destructors.
  "Zc:strictStrings" # Don't allow conversion from a string literal to mutable characters.
  "Zc:threadSafeInit" # Enable thread-safe function-local statics initialization.
  "Zc:throwingNew" # Assume operator new throws on failure.
  "Zo" # Enable enhanced optimized debugging. Produces slightly larger pdb files, but the resulting optimized code is much much easier to debug.
)

# Enable all warnings if requested.
if (MSVC_ENABLE_ALL_WARNINGS)
  list(APPEND MSVC_GENERAL_OPTIONS "Wall")
endif()

# Enable static analysis if requested.
if (MSVC_ENABLE_STATIC_ANALYSIS)
  list(APPEND MSVC_GENERAL_OPTIONS "analyze")
endif()

# Enable multi-processor compilation if requested.
if (MSVC_ENABLE_PARALLEL_BUILD)
  list(APPEND MSVC_GENERAL_OPTIONS "MP")
endif()

# Validate, and then add the favored architecture.
if (NOT MSVC_FAVORED_ARCHITECTURE STREQUAL "blend" AND NOT MSVC_FAVORED_ARCHITECTURE STREQUAL "AMD64" AND NOT MSVC_FAVORED_ARCHITECTURE STREQUAL "INTEL64" AND NOT MSVC_FAVORED_ARCHITECTURE STREQUAL "ATOM")
  message(FATAL_ERROR "MSVC_FAVORED_ARCHITECTURE must be set to one of exactly, 'blend', 'AMD64', 'INTEL64', or 'ATOM'! Got '${MSVC_FAVORED_ARCHITECTURE}' instead!")
endif()
list(APPEND MSVC_GENERAL_OPTIONS "favor:${MSVC_FAVORED_ARCHITECTURE}")

# The warnings that are disabled:
list(APPEND MSVC_DISABLED_WARNINGS
  "4068" # Unknown pragma.
  "4091" # 'typedef' ignored on left of '' when no variable is declared.
  "4101" # Unused variables
  #"4103" # Alignment changed after including header. This is needed because boost includes an ABI header that does some #pragma pack push/pop stuff, and we've passed our own packing
  "4146" # Unary minus applied to unsigned type, result still unsigned.
  #"4250" # Function was inherited via dominance.
  "4800" # Values being forced to bool, this happens many places, and is a "performance warning".
)

if (MSVC_ENABLE_ALL_WARNINGS)
  # These warnings are disabled because we've
  # enabled all warnings. If all warnings are
  # not enabled, then these don't need to be
  # disabled.
  list(APPEND MSVC_DISABLED_WARNINGS
    "4061" # Enum value not handled by a case in a switch on an enum. This isn't very helpful because it is produced even if a default statement is present.
    "4100" # Unreferenced formal parameter.
    "4127" # Conditional expression is constant.
    #"4131" # Old style declarator used. This is triggered by ext_bc's backend code.
    #"4189" # Local variable is initialized but not referenced.
    #"4191" # Unsafe type cast.
    "4200" # Non-standard extension, zero sized array.
    "4201" # Non-standard extension used: nameless struct/union.
    #"4232" # Non-standard extension used: 'pCurrent': address of dllimport.
    "4245" # Implicit change from signed/unsigned when initializing.
    "4255" # Implicitly converting fucntion prototype from `()` to `(void)`.
    #"4265" # Class has virtual functions, but destructor is not virtual.
    "4287" # Unsigned/negative constant mismatch.
    "4296" # '<' Expression is always false.
    #"4315" # 'this' pointer for member may not be aligned to 8 bytes as expected by the constructor.
    "4324" # Structure was padded due to alignment specifier.
    "4355" # 'this' used in base member initializer list.
    "4365" # Signed/unsigned mismatch.
    "4371" # Layout of class may have changed due to fixes in packing.
    "4388" # Signed/unsigned mismatch on relative comparison operator.
    "4389" # Signed/unsigned mismatch on equality comparison operator.
    "4435" # Object layout under /vd2 will change due to virtual base.
    "4456" # Declaration of local hides previous definition of local by the same name.
    "4457" # Declaration of local hides function parameter.
    "4458" # Declaration of parameter hides class member.
    "4459" # Declaration of parameter hides global declaration.
    #"4464" # Relative include path contains "..". This is triggered by the TBB headers.
    "4505" # Unreferenced local function has been removed. This is mostly the result of things not being needed under MSVC.
    "4514" # Unreferenced inline function has been removed. (caused by /Zc:inline)
    "4548" # Expression before comma has no effect. I wouldn't disable this normally, but malloc.h triggers this warning.
    #"4555" # Expression has no effect; expected expression with side-effect. This is triggered by boost/variant.hpp.
    "4574" # ifdef'd macro was defined to 0.
    "4582" # Constructor is not implicitly called.
    "4583" # Destructor is not implicitly called.
    #"4608" # Member has already been initialized by another union member initializer.
    "4619" # Invalid warning number used in #pragma warning.
    "4623" # Default constructor was implicitly defined as deleted.
    "4625" # Copy constructor was implicitly defined as deleted.
    "4626" # Assignment operator was implicitly defined as deleted.
    #"4647" # __is_pod() has a different value in pervious versions of MSVC.
    "4668" # Macro was not defined, replacing with 0.
    "4701" # Potentially uninitialized local variable used.
    "4702" # Unreachable code.
    "4706" # Assignment within conditional expression.
    #"4709" # Comma operator within array index expression. This currently just produces false-positives.
    "4710" # Function was not inlined.
    "4711" # Function was selected for automated inlining. This produces tens of thousands of warnings in release mode if you leave it enabled, which will completely break Visual Studio, so don't enable it.
    "4714" # Function marked as __forceinline not inlined.
    #"4774" # Format string expected in argument is not a string literal.
    "4820" # Padding added after data member.
    #"4917" # A GUID can only be associated with a class. This is triggered by some standard windows headers.
    #"4946" # reinterpret_cast used between related types.
    "5026" # Move constructor was implicitly defined as deleted.
    "5027" # Move assignment operator was implicitly defined as deleted.
    "5031" # #pragma warning(pop): likely mismatch, popping warning state pushed in different file. This is needed because of how boost does things.
  )
endif()

if (MSVC_ENABLE_STATIC_ANALYSIS)
  # Warnings disabled for /analyze
  list(APPEND MSVC_DISABLED_WARNINGS
    "6001" # Using uninitialized memory. This is disabled because it is wrong 99% of the time.
    "6011" # Dereferencing potentially NULL pointer.
    "6031" # Return value ignored.
    "6235" # (<non-zero constant> || <expression>) is always a non-zero constant.
    "6237" # (<zero> && <expression>) is always zero. <expression> is never evaluated and may have side effects.
    "6239" # (<non-zero constant> && <expression>) always evaluates to the result of <expression>.
    "6240" # (<expression> && <non-zero constant>) always evaluates to the result of <expression>.
    "6246" # Local declaration hides declaration of same name in outer scope.
    "6248" # Setting a SECURITY_DESCRIPTOR's DACL to NULL will result in an unprotected object. This is done by one of the boost headers.
    "6255" # _alloca indicates failure by raising a stack overflow exception.
    "6262" # Function uses more than x bytes of stack space.
    "6271" # Extra parameter passed to format function. The analysis pass doesn't recognize %j or %z, even though the runtime does.
    "6285" # (<non-zero constant> || <non-zero constant>) is always true.
    "6297" # 32-bit value is shifted then cast to 64-bits. The places this occurs never use more than 32 bits.
    "6308" # Realloc might return null pointer: assigning null pointer to '<name>', which is passed as an argument to 'realloc', will cause the original memory to leak.
    "6326" # Potential comparison of a constant with another constant.
    "6330" # Unsigned/signed mismatch when passed as a parameter.
    "6340" # Mismatch on sign when passed as format string value.
    "6387" # '<value>' could be '0': This does not adhere to the specification for a function.
    "28182" # Dereferencing NULL pointer. '<value>' contains the same NULL value as '<expression>'.
    "28251" # Inconsistent annotation for function. This is because we only annotate the declaration and not the definition.
    "28278" # Function appears with no prototype in scope.
  )
endif()

# Warnings disabled to keep it quiet for now,
# most of these should be reviewed and re-enabled:
list(APPEND MSVC_DISABLED_WARNINGS
  #"4005" # Macro redefinition
  "4018" # Signed/unsigned mismatch.
  "4242" # Possible loss of data when returning a value.
  "4244" # Implicit truncation of data.
  "4267" # Implicit truncation of data. This really shouldn't be disabled.
  #"4291" # No matching destructor found.
  #"4302" # Pointer casting size difference
  #"4311" # Pointer casting size difference
  #"4312" # Pointer casting size difference
  #"4477" # Parameter to a formatting function isn't the same type as was passed in the format string.
  #"4624" # Destructor was implicitly undefined.
  "4804" # Unsafe use of type 'bool' in operation. (comparing if bool is <=> scalar)
  "4805" # Unsafe mix of scalar type and type 'bool' in operation. (comparing if bool is == scalar)
)

# Warnings to treat as errors:
list(APPEND MSVC_WARNINGS_AS_ERRORS
  "4099" # Mixed use of struct and class on same type names. This was absolutely everywhere, and can cause errors at link-time if not fixed.
  "4129" # Unknown escape sequence. This is usually caused by incorrect escaping.
  "4566" # Character cannot be represented in current charset. This is remidied by prefixing string with "u8".
)

# And the extra defines:
list(APPEND MSVC_ADDITIONAL_DEFINES
  "NOMINMAX" # This is needed because, for some absurd reason, one of the windows headers tries to define "min" and "max" as macros, which messes up most uses of std::numeric_limits.
  "_CRT_NONSTDC_NO_WARNINGS" # Don't deprecate posix names of functions.
  "_CRT_SECURE_NO_WARNINGS" # Don't deprecate the non _s versions of various standard library functions, because safety is for chumps.
  "_SCL_SECURE_NO_WARNINGS" # Don't deprecate the non _s versions of various standard library functions, because safety is for chumps.
  "_WINSOCK_DEPRECATED_NO_WARNINGS" # Don't deprecate pieces of winsock
  "WIN32_LEAN_AND_MEAN" # Don't include most of Windows.h
)

# The options passed to the linker for EXE targets:
list(APPEND MSVC_EXE_LINKER_OPTIONS
  "BASE:0x10000" # Base the program at just over 64k in memory, to play nice with the JIT.
  "DYNAMICBASE:NO" # Don't randomize the base address.
  "FIXED" # The program can only be loaded at its preferred base address.
  "STACK:8388608,8388608" # Set the stack reserve,commit to 8mb. Reserve should probably be higher.
  "time" # Output some timing information about the link.
  "ignore:4099" # Don't complain about missing pdbs.
)

# The options to pass to the compiler for debug builds:
list(APPEND MSVC_DEBUG_OPTIONS
  "Gy-" # Disable function level linking.
  "GF-" # Disable string pooling.
)

# Add /Ob2 if allowing inlining in debug mode:
if (MSVC_ENABLE_DEBUG_INLINING)
  list(APPEND MSVC_DEBUG_OPTIONS "Ob2")
endif()

# The options to pass to the compiler for release builds:
list(APPEND MSVC_RELEASE_OPTIONS
  "GF" # Enable string pooling. (this is enabled by default by the optimization level, but we enable it here for clarity)
  "Gw" # Optimize global data. (-fdata-sections)
  "Gy" # Enable function level linking. (-ffunction-sections)
  "Qpar" # Enable parallel code generation. HHVM itself doesn't currently use this, but it's dependencies, TBB for instance, might, so enable it.
  "Oi" # Enable intrinsic functions.
  "Ot" # Favor fast code.
)

# Add /GL to the compiler, and /LTCG to the linker
# if link time code generation is enabled.
if (MSVC_ENABLE_LTCG)
  list(APPEND MSVC_RELEASE_OPTIONS "GL")
  list(APPEND MSVC_RELEASE_LINKER_OPTIONS "LTCG")
endif()

# The options to pass to the linker for debug builds for EXE targets:
list(APPEND MSVC_DEBUG_EXE_LINKER_OPTIONS
  "OPT:NOREF" # No unreferenced data elimination. (well, mostly)
  "OPT:NOICF" # No Identical COMDAT folding.
)

# The options to pass to the linker for release builds for EXE targets:
list(APPEND MSVC_RELEASE_EXE_LINKER_OPTIONS
  "OPT:REF" # Remove unreferenced functions and data.
  "OPT:ICF" # Identical COMDAT folding.
)

############################################################
# Now we need to adjust a couple of the default option sets.
############################################################

# We need the static runtime.
foreach(flag_var
    CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE
    CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_RELWITHDEBINFO
    CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_DEBUG CMAKE_CXX_FLAGS_RELEASE
    CMAKE_CXX_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_RELWITHDEBINFO)
  if (${flag_var} MATCHES "/MD")
    string(REGEX REPLACE "/MD" "/MT" ${flag_var} "${${flag_var}}")
  endif()
endforeach()

# In order for /Zc:inline, which speeds up the build significantly, to work
# we need to remove the /Ob0 parameter that CMake adds by default, because that
# would normally disable all inlining.
foreach(flag_var CMAKE_C_FLAGS_DEBUG CMAKE_CXX_FLAGS_DEBUG)
  if (${flag_var} MATCHES "/Ob0")
    string(REGEX REPLACE "/Ob0" "" ${flag_var} "${${flag_var}}")
  endif()
endforeach()

# Ignore a warning about an object file not defining any symbols,
# these are known, and we don't care.
set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} /ignore:4221")

############################################################
# And finally, we can set all the flags we've built up.
############################################################

foreach(opt ${MSVC_GENERAL_OPTIONS})
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /${opt}")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /${opt}")
endforeach()

foreach(opt ${MSVC_DISABLED_WARNINGS})
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /wd${opt}")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /wd${opt}")
endforeach()

foreach(opt ${MSVC_WARNINGS_AS_ERRORS})
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /we${opt}")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /we${opt}")
endforeach()

foreach(opt ${MSVC_ADDITIONAL_DEFINES})
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /D ${opt}")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /D ${opt}")
endforeach()

foreach(opt ${MSVC_EXE_LINKER_OPTIONS})
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /${opt}")
endforeach()

foreach(opt ${MSVC_RELEASE_LINKER_OPTIONS})
  foreach(flag_var
      CMAKE_EXE_LINKER_FLAGS_RELEASE CMAKE_EXE_LINKER_FLAGS_MINSIZEREL CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO
      CMAKE_SHARED_LINKER_FLAGS_RELEASE CMAKE_SHARED_LINKER_FLAGS_MINSIZEREL CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO
      CMAKE_STATIC_LINKER_FLAGS_RELEASE CMAKE_STATIC_LINKER_FLAGS_MINSIZEREL CMAKE_STATIC_LINKER_FLAGS_RELWITHDEBINFO)
    set(${flag_var} "${${flag_var}} /${opt}")
  endforeach()
endforeach()

foreach(opt ${MSVC_DEBUG_OPTIONS})
  set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} /${opt}")
  set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /${opt}")
endforeach()

foreach(opt ${MSVC_RELEASE_OPTIONS})
  foreach(flag_var
      CMAKE_C_FLAGS_RELEASE CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_RELWITHDEBINFO
      CMAKE_CXX_FLAGS_RELEASE CMAKE_CXX_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_RELWITHDEBINFO)
    set(${flag_var} "${${flag_var}} /${opt}")
  endforeach()
endforeach()

foreach(opt ${MSVC_DEBUG_EXE_LINKER_OPTIONS})
  set(CMAKE_EXE_LINKER_FLAGS_DEBUG "${CMAKE_EXE_LINKER_FLAGS_DEBUG} /${opt}")
endforeach()

foreach(opt ${MSVC_RELEASE_EXE_LINKER_OPTIONS})
  set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} /${opt}")
  set(CMAKE_EXE_LINKER_FLAGS_MINSIZEREL "${CMAKE_EXE_LINKER_FLAGS_MINSIZEREL} /${opt}")
  set(CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO "${CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO} /${opt}")
endforeach()
