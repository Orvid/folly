cmake_minimum_required(VERSION 3.4.0 FATAL_ERROR)

# Unfortunately, CMake doesn't easily provide us a way to merge static
# libraries, which is what we want to do to generate the main folly library, so
# we do a bit of a workaround here to inject a property into the generated
# project files that will only get enabled for the folly target. Ugly, but
# the alternatives are far, far worse.
set(CMAKE_GENERATOR_TOOLSET "v141</PlatformToolset></PropertyGroup><ItemDefinitionGroup Condition=\"'$(ProjectName)'=='folly'\"><ProjectReference><LinkLibraryDependencies>true</LinkLibraryDependencies></ProjectReference></ItemDefinitionGroup><PropertyGroup><PlatformToolset>v141")

# includes
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/CMake" ${CMAKE_MODULE_PATH})
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

# package information
set(PACKAGE_NAME      "folly")
set(PACKAGE_VERSION   "0.58.0-dev")
set(PACKAGE_STRING    "${PACKAGE_NAME} ${PACKAGE_VERSION}")
set(PACKAGE_TARNAME   "${PACKAGE_NAME}-${PACKAGE_VERSION}")
set(PACKAGE_BUGREPORT "https://github.com/facebook/folly/issues")

# 100+ tests in the root folder anyone? No? I didn't think so.
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

project(${PACKAGE_NAME} CXX)

# Check architecture OS
if (NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "Folly requires a 64bit OS")
endif()
if(NOT "${CMAKE_SYSTEM_NAME}" STREQUAL "Windows")
  message(FATAL_ERROR "You should only be using CMake to build Folly if you are on Windows!")
endif()

set(FOLLY_DIR "${CMAKE_CURRENT_SOURCE_DIR}/folly")

# Generate a few tables and create the main config file.
find_package(PythonInterp REQUIRED)
add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/folly/build/EscapeTables.cpp
  COMMAND ${PYTHON_EXECUTABLE} "${FOLLY_DIR}/build/generate_escape_tables.py"
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/folly/build/
  COMMENT "Generating the escape tables..." VERBATIM
)
add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/folly/build/FormatTables.cpp
  COMMAND ${PYTHON_EXECUTABLE} "${FOLLY_DIR}/build/generate_format_tables.py"
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/folly/build/
  COMMENT "Generating the format tables..." VERBATIM
)
add_custom_command(
  OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/folly/build/GroupVarintTables.cpp"
  COMMAND ${PYTHON_EXECUTABLE} "${FOLLY_DIR}/build/generate_varint_tables.py"
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/folly/build/
  COMMENT "Generating the group varint tables..." VERBATIM
)
configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/CMake/folly-config.h.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/folly/folly-config.h
)

include(FollyCompiler)
include(FollyFunctions)

# Main folly library files
auto_sources(files "*.cpp" "RECURSE" "${FOLLY_DIR}")
auto_sources(hfiles "*.h" "RECURSE" "${FOLLY_DIR}")

# No need for tests or benchmarks, and we can't build most experimental stuff.
REMOVE_MATCHES_FROM_LISTS(files hfiles
  MATCHES
    "/build/"
    "/experimental/exception_tracer/"
    "/experimental/hazptr/example/"
    "/experimental/symbolizer/"
    "/futures/exercises/"
    "/gen/"
    "/test/"
    "Benchmark.cpp$"
    "Test.cpp$"
  IGNORE_MATCHES
    "/Benchmark.cpp$"
)
list(REMOVE_ITEM files
  ${FOLLY_DIR}/SingletonStackTrace.cpp
  ${FOLLY_DIR}/Subprocess.cpp
  ${FOLLY_DIR}/experimental/DynamicParser.cpp
  ${FOLLY_DIR}/experimental/JSONSchemaTester.cpp
  ${FOLLY_DIR}/experimental/NestedCommandLineApp.cpp
  ${FOLLY_DIR}/experimental/ProgramOptions.cpp
  ${FOLLY_DIR}/experimental/RCUUtils.cpp
  ${FOLLY_DIR}/experimental/io/AsyncIO.cpp
  ${FOLLY_DIR}/experimental/io/HugePageUtil.cpp
  ${FOLLY_DIR}/init/Init.cpp
  ${FOLLY_DIR}/io/Compression.cpp
  ${FOLLY_DIR}/futures/test/Benchmark.cpp
)
list(REMOVE_ITEM hfiles
  ${FOLLY_DIR}/Fingerprint.h
  ${FOLLY_DIR}/Subprocess.h
  ${FOLLY_DIR}/detail/SlowFingerprint.h
  ${FOLLY_DIR}/detail/FingerprintPolynomial.h
  ${FOLLY_DIR}/experimental/DynamicParser.h
  ${FOLLY_DIR}/experimental/DynamicParser-inl.h
  ${FOLLY_DIR}/experimental/NestedCommandLineApp.h
  ${FOLLY_DIR}/experimental/ProgramOptions.h
  ${FOLLY_DIR}/experimental/RCURefCount.h
  ${FOLLY_DIR}/experimental/RCUUtils.h
  ${FOLLY_DIR}/experimental/TLRefCount.h
  ${FOLLY_DIR}/experimental/io/AsyncIO.h
  ${FOLLY_DIR}/init/Init.h
  ${FOLLY_DIR}/io/Compression.h
)

add_library(folly_base STATIC
  ${files} ${hfiles}
  ${CMAKE_CURRENT_BINARY_DIR}/folly/folly-config.h
  ${CMAKE_CURRENT_BINARY_DIR}/folly/build/EscapeTables.cpp
  ${CMAKE_CURRENT_BINARY_DIR}/folly/build/FormatTables.cpp
  ${CMAKE_CURRENT_BINARY_DIR}/folly/build/GroupVarintTables.cpp
)
auto_source_group(folly ${FOLLY_DIR} ${files} ${hfiles})
apply_folly_compile_options_to_target(folly_base)
target_include_directories(folly_base PUBLIC ${CMAKE_CURRENT_BINARY_DIR})
# Add the generated files to the correct source group.
source_group("folly" FILES ${CMAKE_CURRENT_BINARY_DIR}/folly/folly-config.h)
source_group("folly\\build" FILES
  ${CMAKE_CURRENT_BINARY_DIR}/folly/build/EscapeTables.cpp
  ${CMAKE_CURRENT_BINARY_DIR}/folly/build/FingerprintTables.cpp
  ${CMAKE_CURRENT_BINARY_DIR}/folly/build/FormatTables.cpp
  ${CMAKE_CURRENT_BINARY_DIR}/folly/build/GroupVarintTables.cpp
)

find_package(Boost 1.55.0
  COMPONENTS
    context
    chrono
    date_time
    filesystem
    program_options
    regex
    system
    thread
  REQUIRED
)
find_package(double-conversion REQUIRED)
find_package(gflags REQUIRED)
find_package(Glog REQUIRED)
find_package(LibEvent REQUIRED)
find_package(OpenSSL REQUIRED)
find_package(PThread REQUIRED)
target_link_libraries(folly_base
  PUBLIC
    Boost::chrono
    Boost::context
    Boost::date_time
    Boost::filesystem
    Boost::program_options
    Boost::regex
    Boost::system
    double-conversion
    event
    gflags
    glog::glog
    pthread
    OpenSSL::SSL
    OpenSSL::Crypto
    Ws2_32.lib
)

# Now to generate the fingerprint tables
add_executable(GenerateFingerprintTables
  ${FOLLY_DIR}/build/GenerateFingerprintTables.cpp
)
apply_folly_compile_options_to_target(GenerateFingerprintTables)
set_property(TARGET GenerateFingerprintTables PROPERTY FOLDER "Build")
target_link_libraries(GenerateFingerprintTables PRIVATE folly_base)
source_group("" FILES ${FOLLY_DIR}/build/GenerateFingerprintTables.cpp)

# Compile the fingerprint tables.
add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/folly/build/FingerprintTables.cpp
  COMMAND GenerateFingerprintTables
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/folly/build/
  COMMENT "Generating the fingerprint tables..."
)
add_library(folly_fingerprint STATIC
  ${CMAKE_CURRENT_BINARY_DIR}/folly/build/FingerprintTables.cpp
  ${FOLLY_DIR}/Fingerprint.h
  ${FOLLY_DIR}/detail/SlowFingerprint.h
  ${FOLLY_DIR}/detail/FingerprintPolynomial.h
)
apply_folly_compile_options_to_target(folly_fingerprint)
target_link_libraries(folly_fingerprint PRIVATE folly_base)

# We want to generate a single library and target for folly, but we needed a
# two-stage compile for the fingerprint tables, so we create a phony source
# file that we modify whenever the base libraries change, causing folly to be
# re-linked, making things happy.
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/folly_dep.cpp
  COMMAND ${CMAKE_COMMAND} -E touch ${CMAKE_CURRENT_BINARY_DIR}/folly_dep.cpp
  DEPENDS folly_base folly_fingerprint
)
add_library(folly ${CMAKE_CURRENT_BINARY_DIR}/folly_dep.cpp)
apply_folly_compile_options_to_target(folly)
source_group("" FILES ${CMAKE_CURRENT_BINARY_DIR}/folly_dep.cpp)

# Rather than list the dependencies in two places, we apply them directly on
# the folly_base target and then copy them over to the folly target.
get_target_property(FOLLY_LINK_LIBRARIES folly_base INTERFACE_LINK_LIBRARIES)
target_link_libraries(folly PUBLIC ${FOLLY_LINK_LIBRARIES})
target_include_directories(folly PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>)

install(TARGETS folly
  EXPORT folly
  RUNTIME DESTINATION bin
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib)
auto_install_files(folly ${FOLLY_DIR}
  ${hfiles}
  ${FOLLY_DIR}/Fingerprint.h
  ${FOLLY_DIR}/detail/SlowFingerprint.h
  ${FOLLY_DIR}/detail/FingerprintPolynomial.h
)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/folly/folly-config.h DESTINATION include/folly)
install(EXPORT folly DESTINATION share/folly)

option(BUILD_TESTS "If enabled, compile the tests." OFF)
option(BUILD_HANGING_TESTS "If enabled, compile tests that are known to hang." OFF)
option(BUILD_SLOW_TESTS "If enabled, compile tests that take a while to run in debug mode." OFF)
if (BUILD_TESTS)
  find_package(gmock REQUIRED)

  add_library(folly_test_support
    ${FOLLY_DIR}/init/Init.cpp
    ${FOLLY_DIR}/init/Init.h
    ${FOLLY_DIR}/test/DeterministicSchedule.cpp
    ${FOLLY_DIR}/test/DeterministicSchedule.h
    ${FOLLY_DIR}/test/SocketAddressTestHelper.cpp
    ${FOLLY_DIR}/test/SocketAddressTestHelper.h
    ${FOLLY_DIR}/io/async/test/BlockingSocket.h
    ${FOLLY_DIR}/io/async/test/MockAsyncServerSocket.h
    ${FOLLY_DIR}/io/async/test/MockAsyncSocket.h
    ${FOLLY_DIR}/io/async/test/MockAsyncSSLSocket.h
    ${FOLLY_DIR}/io/async/test/MockAsyncTransport.h
    ${FOLLY_DIR}/io/async/test/MockAsyncUDPSocket.h
    ${FOLLY_DIR}/io/async/test/MockTimeoutManager.h
    ${FOLLY_DIR}/io/async/test/ScopedBoundPort.cpp
    ${FOLLY_DIR}/io/async/test/ScopedBoundPort.h
    ${FOLLY_DIR}/io/async/test/SocketPair.cpp
    ${FOLLY_DIR}/io/async/test/SocketPair.h
    ${FOLLY_DIR}/io/async/test/TimeUtil.cpp
    ${FOLLY_DIR}/io/async/test/TimeUtil.h
    ${FOLLY_DIR}/io/async/test/UndelayedDestruction.h
    ${FOLLY_DIR}/io/async/test/Util.h
  )
  target_link_libraries(folly_test_support
    PUBLIC
      Boost::thread
      folly
      gmock
  )
  apply_folly_compile_options_to_target(folly_test_support)

  folly_define_tests(
    DIRECTORY experimental/test/
      TEST autotimer_test SOURCES AutoTimerTest.cpp
      TEST bits_test_2 SOURCES BitsTest.cpp
      TEST bitvector_test SOURCES BitVectorCodingTest.cpp
      TEST eliasfano_test SOURCES EliasFanoCodingTest.cpp
      TEST function_scheduler_test_2 SOURCES FunctionSchedulerTest.cpp
      TEST future_dag_test SOURCES FutureDAGTest.cpp
      TEST json_schema_test SOURCES JSONSchemaTest.cpp
      TEST lock_free_ring_buffer_test SOURCES LockFreeRingBufferTest.cpp
      TEST stringkeyed_test SOURCES StringKeyedTest.cpp
      TEST test_util_test SOURCES TestUtilTest.cpp
      TEST tuple_ops_test SOURCES TupleOpsTest.cpp

    DIRECTORY experimental/io/test/
      TEST fs_util_test SOURCES FsUtilTest.cpp

    DIRECTORY fibers/test/
      TEST fibers_test SOURCES FibersTest.cpp

    DIRECTORY gen/test/
      TEST combine_test SOURCES CombineTest.cpp

    DIRECTORY io/test/
      TEST iobuf_test SOURCES IOBufTest.cpp
      TEST iobuf_cursor_test SOURCES IOBufCursorTest.cpp
      TEST iobuf_queue_test SOURCES IOBufQueueTest.cpp
      TEST record_io_test SOURCES RecordIOTest.cpp
      TEST ShutdownSocketSetTest HANGING
        SOURCES ShutdownSocketSetTest.cpp

    DIRECTORY io/async/test/
      TEST async_test
        CONTENT_DIR certs/
        HEADERS
          AsyncSocketTest.h
          AsyncSSLSocketTest.h
        SOURCES
          AsyncPipeTest.cpp
          AsyncSocketExceptionTest.cpp
          AsyncSocketTest.cpp
          AsyncSocketTest2.cpp
          AsyncSSLSocketTest.cpp
          AsyncSSLSocketTest2.cpp
          AsyncSSLSocketWriteTest.cpp
          AsyncTransportTest.cpp
      TEST async_timeout_test SOURCES AsyncTimeoutTest.cpp
      TEST AsyncUDPSocketTest SOURCES AsyncUDPSocketTest.cpp
      TEST DelayedDestructionTest SOURCES DelayedDestructionTest.cpp
      TEST DelayedDestructionBaseTest SOURCES DelayedDestructionBaseTest.cpp
      TEST EventBaseTest SOURCES EventBaseTest.cpp
      TEST EventBaseLocalTest SOURCES EventBaseLocalTest.cpp
      TEST HHWheelTimerTest SOURCES HHWheelTimerTest.cpp
      TEST HHWheelTimerSlowTests SLOW
        SOURCES HHWheelTimerSlowTests.cpp
      TEST NotificationQueueTest SOURCES NotificationQueueTest.cpp
      TEST RequestContextTest SOURCES RequestContextTest.cpp
      TEST ScopedEventBaseThreadTest SOURCES ScopedEventBaseThreadTest.cpp
      TEST writechain_test SOURCES WriteChainAsyncTransportWrapperTest.cpp

    DIRECTORY io/async/ssl/test/
      TEST ssl_errors_test SOURCES SSLErrorsTest.cpp

    DIRECTORY portability/test/
      TEST constexpr_test SOURCES ConstexprTest.cpp
      TEST libgen-test SOURCES LibgenTest.cpp
      TEST time-test SOURCES TimeTest.cpp

    DIRECTORY ssl/test/
      TEST openssl_hash_test SOURCES OpenSSLHashTest.cpp

    DIRECTORY test/
      TEST ahm_int_stress_test SOURCES AHMIntStressTest.cpp
      TEST apply_tuple_test SOURCES ApplyTupleTest.cpp
      TEST arena_test SOURCES ArenaTest.cpp
      TEST arena_smartptr_test SOURCES ArenaSmartPtrTest.cpp
      TEST array_test SOURCES ArrayTest.cpp
      TEST ascii_check_test SOURCES AsciiCaseInsensitiveTest.cpp
      TEST atomic_bit_set_test SOURCES AtomicBitSetTest.cpp
      TEST atomic_hash_array_test SOURCES AtomicHashArrayTest.cpp
      TEST atomic_hash_map_test HANGING
        SOURCES AtomicHashMapTest.cpp
      TEST atomic_linked_list_test SOURCES AtomicLinkedListTest.cpp
      TEST atomic_struct_test SOURCES AtomicStructTest.cpp
      TEST atomic_unordered_map_test SOURCES AtomicUnorderedMapTest.cpp
      TEST baton_test SOURCES BatonTest.cpp
      TEST bit_iterator_test SOURCES BitIteratorTest.cpp
      TEST bits_test SOURCES BitsTest.cpp
      TEST cache_locality_test SOURCES CacheLocalityTest.cpp
      TEST call_once_test SOURCES CallOnceTest.cpp
      TEST checksum_test SOURCES ChecksumTest.cpp
      TEST clock_gettime_wrappers_test SOURCES ClockGettimeWrappersTest.cpp
      TEST container_traits_test SOURCES ContainerTraitsTest.cpp
      TEST conv_test SOURCES ConvTest.cpp
      TEST cpu_id_test SOURCES CpuIdTest.cpp
      TEST demangle_test SOURCES DemangleTest.cpp
      TEST deterministic_schedule_test SOURCES DeterministicScheduleTest.cpp
      TEST discriminated_ptr_test SOURCES DiscriminatedPtrTest.cpp
      TEST dynamic_test SOURCES DynamicTest.cpp
      TEST dynamic_converter_test SOURCES DynamicConverterTest.cpp
      TEST dynamic_other_test SOURCES DynamicOtherTest.cpp
      TEST endian_test SOURCES EndianTest.cpp
      TEST enumerate_test SOURCES EnumerateTest.cpp
      TEST evicting_cache_map_test SOURCES EvictingCacheMapTest.cpp
      TEST exception_test SOURCES ExceptionTest.cpp
      TEST exception_wrapper_test SOURCES ExceptionWrapperTest.cpp
      TEST expected_test SOURCES ExpectedTest.cpp
      TEST fbvector_test SOURCES FBVectorTest.cpp
      TEST file_test SOURCES FileTest.cpp
      TEST file_util_test HANGING SOURCES FileUtilTest.cpp
      TEST foreach_test SOURCES ForeachTest.cpp
      TEST format_other_test SOURCES FormatOtherTest.cpp
      TEST format_test SOURCES FormatTest.cpp
      TEST function_scheduler_test SOURCES FunctionSchedulerTest.cpp
      TEST function_test SOURCES FunctionTest.cpp
      TEST futex_test SOURCES FutexTest.cpp
      TEST group_varint_test SOURCES GroupVarintTest.cpp
      TEST group_varint_test_ssse3 SOURCES GroupVarintTest.cpp
      TEST has_member_fn_traits_test SOURCES HasMemberFnTraitsTest.cpp
      TEST hash_test SOURCES HashTest.cpp
      TEST histogram_test SOURCES HistogramTest.cpp
      TEST indestructible_test SOURCES IndestructibleTest.cpp
      TEST indexed_mem_pool_test SOURCES IndexedMemPoolTest.cpp
      TEST json_other_test
        CONTENT_DIR json_test_data/
        SOURCES
          JsonOtherTest.cpp
      TEST lazy_test SOURCES LazyTest.cpp
      TEST lifosem_test SOURCES LifoSemTests.cpp
      TEST lock_traits_test SOURCES LockTraitsTest.cpp
      TEST locks_test SOURCES SmallLocksTest.cpp SpinLockTest.cpp
      TEST logging_test SOURCES LoggingTest.cpp
      TEST mallctl_helper_test SOURCES MallctlHelperTest.cpp
      TEST map_util_test SOURCES MapUtilTest.cpp
      TEST memcpy_test SOURCES MemcpyTest.cpp
      TEST memory_idler_test SOURCES MemoryIdlerTest.cpp
      TEST memory_mapping_test SOURCES MemoryMappingTest.cpp
      TEST memory_test SOURCES MemoryTest.cpp
      TEST merge SOURCES MergeTest.cpp
      TEST move_wrapper_test SOURCES MoveWrapperTest.cpp
      TEST mpmc_pipeline_test SOURCES MPMCPipelineTest.cpp
      TEST mpmc_queue_test SLOW
        SOURCES MPMCQueueTest.cpp
      TEST network_address_test HANGING
        SOURCES
          IPAddressTest.cpp
          MacAddressTest.cpp
          SocketAddressTest.cpp
      TEST optional_test SOURCES OptionalTest.cpp
      TEST packed_sync_ptr_test HANGING
        SOURCES PackedSyncPtrTest.cpp
      TEST padded_test SOURCES PaddedTest.cpp
      TEST partial_test SOURCES PartialTest.cpp
      TEST portability_test SOURCES PortabilityTest.cpp
      TEST producer_consumer_queue_test SLOW
        SOURCES ProducerConsumerQueueTest.cpp
      TEST r_w_spin_lock_test SOURCES RWSpinLockTest.cpp
      TEST random_test SOURCES RandomTest.cpp
      TEST range_test SOURCES RangeTest.cpp
      TEST safe_assert_test SOURCES SafeAssertTest.cpp
      TEST scope_guard_test SOURCES ScopeGuardTest.cpp
      TEST singleton_test_global
        SOURCES
          SingletonTestGlobal.cpp
          SingletonTestStructs.cpp
      TEST singletonvault_c_test SOURCES SingletonVaultCTest.cpp
      TEST small_vector_test SOURCES small_vector_test.cpp
      TEST sorted_vector_types_test SOURCES sorted_vector_test.cpp
      TEST sparse_byte_set_test SOURCES SparseByteSetTest.cpp
      TEST spooky_hash_v1_test SOURCES SpookyHashV1Test.cpp
      TEST spooky_hash_v2_test SOURCES SpookyHashV2Test.cpp
      TEST string_test SOURCES StringTest.cpp
      TEST synchronized_test SOURCES SynchronizedTest.cpp
      TEST thread_cached_arena_test SOURCES ThreadCachedArenaTest.cpp
      TEST thread_cached_int_test SOURCES ThreadCachedIntTest.cpp
      TEST thread_local_test SOURCES ThreadLocalTest.cpp
      TEST thread_name_test SOURCES ThreadNameTest.cpp
      TEST timeout_queue_test SOURCES TimeoutQueueTest.cpp
      TEST timeseries_histogram_test SOURCES TimeseriesHistogramTest.cpp
      TEST timeseries_test SOURCES TimeseriesTest.cpp
      TEST token_bucket_test SOURCES TokenBucketTest.cpp
      TEST traits_test SOURCES TraitsTest.cpp
      TEST try_test SOURCES TryTest.cpp
      TEST unit_test SOURCES UnitTest.cpp
      TEST uri_test SOURCES UriTest.cpp
      TEST varint_test SOURCES VarintTest.cpp
  )
endif()
