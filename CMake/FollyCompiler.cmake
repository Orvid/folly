# Some additional configuration options.
option(MSVC_ENABLE_ALL_WARNINGS "If enabled, pass /Wall to the compiler." ON)
option(MSVC_ENABLE_DEBUG_INLINING "If enabled, enable inlining in the debug configuration. This allows /Zc:inline to be far more effective." OFF)
option(MSVC_ENABLE_FAST_LINK "If enabled, pass /DEBUG:FASTLINK to the linker. This makes linking faster, but the gtest integration for Visual Studio can't currently handle the .pdbs generated." OFF)
option(MSVC_ENABLE_LTCG "If enabled, use Link Time Code Generation for Release builds." OFF)
option(MSVC_ENABLE_PARALLEL_BUILD "If enabled, build multiple source files in parallel." ON)
option(MSVC_ENABLE_STATIC_ANALYSIS "If enabled, do more complex static analysis and generate warnings appropriately." OFF)
option(MSVC_USE_STATIC_RUNTIME "If enabled, build against the static, rather than the dynamic, runtime." OFF)

# Alas, option() doesn't support string values.
set(MSVC_FAVORED_ARCHITECTURE "blend" CACHE STRING "One of 'blend', 'AMD64', 'INTEL64', or 'ATOM'. This tells the compiler to generate code optimized to run best on the specified architecture.")
# Validate, and then add the favored architecture.
if (NOT MSVC_FAVORED_ARCHITECTURE STREQUAL "blend" AND NOT MSVC_FAVORED_ARCHITECTURE STREQUAL "AMD64" AND NOT MSVC_FAVORED_ARCHITECTURE STREQUAL "INTEL64" AND NOT MSVC_FAVORED_ARCHITECTURE STREQUAL "ATOM")
  message(FATAL_ERROR "MSVC_FAVORED_ARCHITECTURE must be set to one of exactly, 'blend', 'AMD64', 'INTEL64', or 'ATOM'! Got '${MSVC_FAVORED_ARCHITECTURE}' instead!")
endif()

############################################################
# We need to adjust a couple of the default option sets.
############################################################

# If the static runtime is requested, we have to
# overwrite some of CMake's defaults.
if (MSVC_USE_STATIC_RUNTIME)
  foreach(flag_var
      CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE
      CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_RELWITHDEBINFO
      CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_DEBUG CMAKE_CXX_FLAGS_RELEASE
      CMAKE_CXX_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_RELWITHDEBINFO)
    if (${flag_var} MATCHES "/MD")
      string(REGEX REPLACE "/MD" "/MT" ${flag_var} "${${flag_var}}")
    endif()
  endforeach()
endif()

# In order for /Zc:inline, which speeds up the build significantly, to work
# we need to remove the /Ob0 parameter that CMake adds by default, because that
# would normally disable all inlining.
foreach(flag_var CMAKE_C_FLAGS_DEBUG CMAKE_CXX_FLAGS_DEBUG)
  if (${flag_var} MATCHES "/Ob0")
    string(REGEX REPLACE "/Ob0" "" ${flag_var} "${${flag_var}}")
  endif()
endforeach()

# Apply the option set for Folly to the specified target.
function(apply_folly_compile_options_to_target THETARGET)
  # The general options passed:
  target_compile_options(${THETARGET}
    PUBLIC
      /std:c++latest # Build in C++17 mode
      /EHa # Enable both SEH and C++ Exceptions.
      /Zc:referenceBinding # Disallow temporaries from binding to non-const lvalue references.
      /Zc:rvalueCast # Enforce the standard rules for explicit type conversion.
      /Zc:implicitNoexcept # Enable implicit noexcept specifications where required, such as destructors.
      /Zc:strictStrings # Don't allow conversion from a string literal to mutable characters.
      /Zc:threadSafeInit # Enable thread-safe function-local statics initialization.
      /Zc:throwingNew # Assume operator new throws on failure.
    PRIVATE
      /bigobj # Support objects with > 65k sections. Needed due to templates.
      /favor:${MSVC_FAVORED_ARCHITECTURE} # Architecture to prefer when generating code.
      /Zc:inline # Have the compiler eliminate unreferenced COMDAT functions and data before emitting the object file.

      $<$<BOOL:${MSVC_ENABLE_ALL_WARNINGS}>:/Wall> # Enable all warnings if requested.
      $<$<BOOL:${MSVC_ENABLE_PARALLEL_BUILD}>:/MP> # Enable multi-processor compilation if requested.
      $<$<BOOL:${MSVC_ENABLE_STATIC_ANALYSIS}>:/analyze> # Enable static analysis if requested.

      # Debug builds
      $<$<CONFIG:DEBUG>:
        /Gy- # Disable function level linking.
        /GF- # Disable string pooling.

        $<$<BOOL:${MSVC_ENABLE_DEBUG_INLINING}>:/Ob2> # Add /Ob2 if allowing inlining in debug mode.
      >

      # Non-debug builds
      $<$<NOT:$<CONFIG:DEBUG>>:
        /GF # Enable string pooling. (this is enabled by default by the optimization level, but we enable it here for clarity)
        /Gw # Optimize global data. (-fdata-sections)
        /Gy # Enable function level linking. (-ffunction-sections)
        /Qpar # Enable parallel code generation.
        /Oi # Enable intrinsic functions.
        /Ot # Favor fast code.

        $<$<BOOL:${MSVC_ENABLE_LTCG}>:/GL> # Enable link time code generation.
      >
  )

  target_compile_options(${THETARGET}
    PUBLIC
      # The warnings that are disabled:
      /wd4068 # Unknown pragma.
      /wd4091 # 'typedef' ignored on left of '' when no variable is declared.
      /wd4101 # Unused variables
      /wd4146 # Unary minus applied to unsigned type, result still unsigned.
      /wd4800 # Values being forced to bool, this happens many places, and is a "performance warning".

      # Warnings disabled to keep it quiet for now,
      # most of these should be reviewed and re-enabled:
      /wd4018 # Signed/unsigned mismatch.
      /wd4242 # Possible loss of data when returning a value.
      /wd4244 # Implicit truncation of data.
      /wd4267 # Implicit truncation of data. This really shouldn't be disabled.
      /wd4804 # Unsafe use of type 'bool' in operation. (comparing if bool is <=> scalar)
      /wd4805 # Unsafe mix of scalar type and type 'bool' in operation. (comparing if bool is == scalar)

      # These warnings are disabled because we've
      # enabled all warnings. If all warnings are
      # not enabled, we still need to disable them
      # for consuming libs.
      /wd4061 # Enum value not handled by a case in a switch on an enum. This isn't very helpful because it is produced even if a default statement is present.
      /wd4100 # Unreferenced formal parameter.
      /wd4127 # Conditional expression is constant.
      /wd4200 # Non-standard extension, zero sized array.
      /wd4201 # Non-standard extension used: nameless struct/union.
      /wd4245 # Implicit change from signed/unsigned when initializing.
      /wd4255 # Implicitly converting function prototype from `()` to `(void)`.
      /wd4287 # Unsigned/negative constant mismatch.
      /wd4296 # '<' Expression is always false.
      /wd4324 # Structure was padded due to alignment specifier.
      /wd4355 # 'this' used in base member initializer list.
      /wd4365 # Signed/unsigned mismatch.
      /wd4371 # Layout of class may have changed due to fixes in packing.
      /wd4388 # Signed/unsigned mismatch on relative comparison operator.
      /wd4389 # Signed/unsigned mismatch on equality comparison operator.
      /wd4435 # Object layout under /vd2 will change due to virtual base.
      /wd4456 # Declaration of local hides previous definition of local by the same name.
      /wd4457 # Declaration of local hides function parameter.
      /wd4458 # Declaration of parameter hides class member.
      /wd4459 # Declaration of parameter hides global declaration.
      /wd4505 # Unreferenced local function has been removed. This is mostly the result of things not being needed under MSVC.
      /wd4514 # Unreferenced inline function has been removed. (caused by /Zc:inline)
      /wd4548 # Expression before comma has no effect. I wouldn't disable this normally, but malloc.h triggers this warning.
      /wd4574 # ifdef'd macro was defined to 0.
      /wd4582 # Constructor is not implicitly called.
      /wd4583 # Destructor is not implicitly called.
      /wd4619 # Invalid warning number used in #pragma warning.
      /wd4623 # Default constructor was implicitly defined as deleted.
      /wd4625 # Copy constructor was implicitly defined as deleted.
      /wd4626 # Assignment operator was implicitly defined as deleted.
      /wd4668 # Macro was not defined, replacing with 0.
      /wd4701 # Potentially uninitialized local variable used.
      /wd4702 # Unreachable code.
      /wd4706 # Assignment within conditional expression.
      /wd4710 # Function was not inlined.
      /wd4711 # Function was selected for automated inlining. This produces tens of thousands of warnings in release mode if you leave it enabled, which will completely break Visual Studio, so don't enable it.
      /wd4714 # Function marked as __forceinline not inlined.
      /wd4820 # Padding added after data member.
      /wd5026 # Move constructor was implicitly defined as deleted.
      /wd5027 # Move assignment operator was implicitly defined as deleted.
      /wd5031 # #pragma warning(pop): likely mismatch, popping warning state pushed in different file. This is needed because of how boost does things.

      # Warnings to treat as errors:
      /we4099 # Mixed use of struct and class on same type names.
      /we4129 # Unknown escape sequence. This is usually caused by incorrect escaping.
      /we4566 # Character cannot be represented in current charset. This is remidied by prefixing string with "u8".

    PRIVATE
      # Warnings disabled for /analyze
      $<$<BOOL:${MSVC_ENABLE_STATIC_ANALYSIS}>:
        /wd6001 # Using uninitialized memory. This is disabled because it is wrong 99% of the time.
        /wd6011 # Dereferencing potentially NULL pointer.
        /wd6031 # Return value ignored.
        /wd6235 # (<non-zero constant> || <expression>) is always a non-zero constant.
        /wd6237 # (<zero> && <expression>) is always zero. <expression> is never evaluated and may have side effects.
        /wd6239 # (<non-zero constant> && <expression>) always evaluates to the result of <expression>.
        /wd6240 # (<expression> && <non-zero constant>) always evaluates to the result of <expression>.
        /wd6246 # Local declaration hides declaration of same name in outer scope.
        /wd6248 # Setting a SECURITY_DESCRIPTOR's DACL to NULL will result in an unprotected object. This is done by one of the boost headers.
        /wd6255 # _alloca indicates failure by raising a stack overflow exception.
        /wd6262 # Function uses more than x bytes of stack space.
        /wd6271 # Extra parameter passed to format function. The analysis pass doesn't recognize %j or %z, even though the runtime does.
        /wd6285 # (<non-zero constant> || <non-zero constant>) is always true.
        /wd6297 # 32-bit value is shifted then cast to 64-bits. The places this occurs never use more than 32 bits.
        /wd6308 # Realloc might return null pointer: assigning null pointer to '<name>', which is passed as an argument to 'realloc', will cause the original memory to leak.
        /wd6326 # Potential comparison of a constant with another constant.
        /wd6330 # Unsigned/signed mismatch when passed as a parameter.
        /wd6340 # Mismatch on sign when passed as format string value.
        /wd6387 # '<value>' could be '0': This does not adhere to the specification for a function.
        /wd28182 # Dereferencing NULL pointer. '<value>' contains the same NULL value as '<expression>'.
        /wd28251 # Inconsistent annotation for function. This is because we only annotate the declaration and not the definition.
        /wd28278 # Function appears with no prototype in scope.
      >
  )

  # And the extra defines:
  target_compile_definitions(${THETARGET}
    PUBLIC
      _HAS_AUTO_PTR_ETC=1 # We're building in C++ 17 mode, but certain dependencies (Boost) still have dependencies on unary_function and binary_function, so we have to make sure not to remove them.
      NOMINMAX # This is needed because, for some absurd reason, one of the windows headers tries to define "min" and "max" as macros, which messes up most uses of std::numeric_limits.
      _CRT_NONSTDC_NO_WARNINGS # Don't deprecate posix names of functions.
      _CRT_SECURE_NO_WARNINGS # Don't deprecate the non _s versions of various standard library functions, because safety is for chumps.
      _SCL_SECURE_NO_WARNINGS # Don't deprecate the non _s versions of various standard library functions, because safety is for chumps.
      _WINSOCK_DEPRECATED_NO_WARNINGS # Don't deprecate pieces of winsock
      WIN32_LEAN_AND_MEAN # Don't include most of Windows.h
  )

  # Ignore a warning about an object file not defining any symbols,
  # these are known, and we don't care.
  set_property(TARGET ${THETARGET} APPEND_STRING PROPERTY STATIC_LIBRARY_FLAGS " /ignore:4221")

  # The options to pass to the linker:
  set_property(TARGET ${THETARGET} APPEND_STRING PROPERTY LINK_FLAGS_DEBUG " /INCREMENTAL") # Do incremental linking.
  if (NOT $<TARGET_PROPERTY:${THETARGET},TYPE> STREQUAL "STATIC_LIBRARY")
    set_property(TARGET ${THETARGET} APPEND_STRING PROPERTY LINK_FLAGS_DEBUG " /OPT:NOREF") # No unreferenced data elimination.
    set_property(TARGET ${THETARGET} APPEND_STRING PROPERTY LINK_FLAGS_DEBUG " /OPT:NOICF") # No Identical COMDAT folding.

    set_property(TARGET ${THETARGET} APPEND_STRING PROPERTY LINK_FLAGS_RELEASE " /OPT:REF") # Remove unreferenced functions and data.
    set_property(TARGET ${THETARGET} APPEND_STRING PROPERTY LINK_FLAGS_RELEASE " /OPT:ICF") # Identical COMDAT folding.
  endif()

  if (MSVC_ENABLE_FAST_LINK)
    set_property(TARGET ${THETARGET} APPEND_STRING PROPERTY LINK_FLAGS_DEBUG " /DEBUG:FASTLINK") # Generate a partial PDB file that simply references the original object and library files.
  endif()

  # Add /GL to the compiler, and /LTCG to the linker
  # if link time code generation is enabled.
  if (MSVC_ENABLE_LTCG)
    set_property(TARGET ${THETARGET} APPEND_STRING PROPERTY LINK_FLAGS_RELEASE " /LTCG")
  endif()
endfunction()
