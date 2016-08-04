# This file exists because, in order to handle the multi-config environment that
# Visual Studio allows, we'd have to modify quite a few of CMake's built-in
# scripts for finding specific libraries. Instead of doing that, we just set the
# required variables here if the /deps/ directory is present.

# We assume in this that, if the directory exists, all libs that are part of
# the package are present.
if (EXISTS "${FOLLY_DIR}/../deps/")
  message(STATUS "Using default paths for MSVC libs.")

  set(depRoot "${FOLLY_DIR}/../deps")
  set(incRoot "${depRoot}/include")
  set(libRoot "${depRoot}/lib")

  # First up a few variables to make things configure the first time.

  # We need to link against the static library version of boost targeting the static
  # runtime, so set the vars required by default.
  set(BOOST_INCLUDEDIR "${incRoot}" CACHE PATH "")
  set(BOOST_LIBRARYDIR "${libRoot}/lib64-msvc-14.0" CACHE PATH "")
  set(Boost_USE_STATIC_LIBS ON CACHE BOOL "")
  set(Boost_USE_STATIC_RUNTIME ON CACHE BOOL "")

  set(DOUBLE_CONVERSION_INCLUDE_DIR "${incRoot}" CACHE PATH "")
  set(DOUBLE_CONVERSION_LIBRARY "debug;${libRoot}/double-conversionMTd.lib;optimized;${libRoot}/double-conversionMT.lib" CACHE FILEPATH "")

  set(LIBEVENT_INCLUDE_DIR "${incRoot}" CACHE PATH "")
  set(LIBEVENT_LIB "general;Ws2_32.lib;debug;${libRoot}/eventMTd.lib;debug;${libRoot}/event_coreMTd.lib;debug;${libRoot}/event_extraMTd.lib;optimized;${libRoot}/eventMT.lib;optimized;${libRoot}/event_coreMT.lib;optimized;${libRoot}/event_extraMT.lib" CACHE FILEPATH "")

  set(LIBGLOG_INCLUDE_DIR "${incRoot}" CACHE PATH "")
  set(LIBGLOG_LIBRARY "debug;${libRoot}/libglogMTd.lib;optimized;${libRoot}/libglogMT.lib" CACHE FILEPATH "")
  set(LIBGLOG_STATIC ON CACHE BOOL "")

  set(LIBPTHREAD_INCLUDE_DIRS "${incRoot}" CACHE PATH "")
  set(LIBPTHREAD_LIBRARIES "debug;${libRoot}/libpthreadMTd.lib;optimized;${libRoot}/libpthreadMT.lib" CACHE FILEPATH "")
  set(LIBPTHREAD_STATIC ON CACHE BOOL "")

  set(OPENSSL_INCLUDE_DIR "${incRoot}" CACHE PATH "")
  set(LIB_EAY_DEBUG "${libRoot}/libeay32MTd.lib" CACHE FILEPATH "")
  set(LIB_EAY_RELEASE "${libRoot}/libeay32MT.lib" CACHE FILEPATH "")
  set(SSL_EAY_DEBUG "${libRoot}/ssleay32MTd.lib" CACHE FILEPATH "")
  set(SSL_EAY_RELEASE "${libRoot}/ssleay32MT.lib" CACHE FILEPATH "")
endif()
