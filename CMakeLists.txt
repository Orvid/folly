cmake_minimum_required(VERSION 3.0.0 FATAL_ERROR)

# includes
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/CMake" ${CMAKE_MODULE_PATH})
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

# package information
set(PACKAGE_NAME      "folly")
set(PACKAGE_VERSION   "0.58.0-dev")
set(PACKAGE_STRING    "${PACKAGE_NAME} ${PACKAGE_VERSION}")
set(PACKAGE_TARNAME   "${PACKAGE_NAME}-${PACKAGE_VERSION}")
set(PACKAGE_BUGREPORT "https://github.com/facebook/folly/issues")

set_property(GLOBAL PROPERTY USE_FOLDERS ON)

project(${PACKAGE_NAME} CXX)

# Check architecture OS
if (NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "Folly requires a 64bit OS")
endif()
if(NOT "${CMAKE_SYSTEM_NAME}" STREQUAL "Windows")
  message(FATAL_ERROR "You should only be using CMake to build Folly on Windows!")
endif()

find_package(Boost 1.55.0 COMPONENTS chrono date_time system program_options filesystem regex context REQUIRED)
link_directories(${Boost_LIBRARY_DIRS})

find_package(double-conversion REQUIRED)
find_package(gflags REQUIRED)
find_package(Glog REQUIRED)
find_package(LibEvent REQUIRED)
find_package(OpenSSL REQUIRED)
find_package(PThread REQUIRED)

set(FOLLY_DIR "${CMAKE_CURRENT_SOURCE_DIR}/folly")

include(FollyFunctions)
include(FollyCompiler)

# Main folly library files
auto_sources(files "*.cpp" "RECURSE" "${FOLLY_DIR}")
auto_sources(hfiles "*.h" "RECURSE" "${FOLLY_DIR}")

# No need for tests or benchmarks, and we can't build most experimental stuff.
REMOVE_MATCHES_FROM_LISTS(files hfiles MATCHES
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
  ${FOLLY_DIR}/build/GenerateFingerprintTables.cpp
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
  ${FOLLY_DIR}/Subprocess.h
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

add_library(folly SHARED ${files} ${hfiles})
auto_source_group(folly ${FOLLY_DIR} ${files} ${hfiles})

target_compile_definitions(folly
  PUBLIC
    HAVE_MODE_T
    HAVE_BOOST1_49
    FOLLY_HAVE_WEAK_SYMBOLS=0
    FOLLY_HAVE_MEMRCHR=0
    FOLLY_HAVE_PREADV=0
    FOLLY_HAVE_PWRITEV=0
    FOLLY_HAVE_LIBGFLAGS=1
    FOLLY_HAVE_VLA=0
    FOLLY_NO_CONFIG=1
    FOLLY_HAVE_PTHREAD_SPINLOCK_T=1
    FOLLY_HAVE_MALLOC_H=1
    FOLLY_HAVE_UNALIGNED_ACCESS=1
    FOLLY_HAVE_STD__IS_TRIVIALLY_COPYABLE=1
  PRIVATE
    "FOLLY_VERSION=\"${PACKAGE_VERSION}\""
)

target_include_directories(folly
  PUBLIC
    ${Boost_INCLUDE_DIRS}
    ${OPENSSL_INCLUDE_DIR}
)

target_link_libraries(folly
  PUBLIC
    #boost::chrono
    #boost::date_time
    #boost::system
    #boost::program_options
    #boost::filesystem
    #boost::regex
    #boost::context
    ${Boost_LIBRARIES}
    double-conversion
    event
    glog::glog
    pthread
    ${OPENSSL_LIBRARIES}
    Ws2_32.lib
  PRIVATE
    gflags
)

install(TARGETS folly
  EXPORT folly
  RUNTIME DESTINATION bin
  LIBRARY DESTINATION bin
  ARCHIVE DESTINATION lib)
install(FILES ${hfiles} DESTINATION include)
install(EXPORT folly DESTINATION share/folly FILE folly-config.cmake)

option(BUILD_TESTS "If enabled, compile the tests." OFF)
if (BUILD_TESTS)
  add_definitions(
    -DGTEST_ENV_HAS_STD_TUPLE_=1
    -DGTEST_LANG_CXX11=1
  )

  folly_test(constexpr_test "${FOLLY_DIR}/portability/" "portability/"  ${FOLLY_DIR}/portability/test/ConstexprTest.cpp)
  folly_test(libgen-test "${FOLLY_DIR}/portability/" "portability/"  ${FOLLY_DIR}/portability/test/LibgenTest.cpp)
  folly_test(time-test "${FOLLY_DIR}/portability/" "portability/"  ${FOLLY_DIR}/portability/test/TimeTest.cpp)
  folly_test(async_timeout_test "${FOLLY_DIR}/io/async/test/" "io/async/"  ${FOLLY_DIR}/io/async/test/AsyncTimeoutTest.cpp)
  folly_test(async_test "${FOLLY_DIR}/io/async/test/" "io/async/"
    ${FOLLY_DIR}/io/async/test/AsyncPipeTest.cpp
    ${FOLLY_DIR}/io/async/test/AsyncSocketExceptionTest.cpp
    ${FOLLY_DIR}/io/async/test/AsyncSocketTest.cpp
    ${FOLLY_DIR}/io/async/test/AsyncSocketTest2.cpp
    ${FOLLY_DIR}/io/async/test/AsyncSSLSocketTest.cpp
    ${FOLLY_DIR}/io/async/test/AsyncSSLSocketTest2.cpp
    ${FOLLY_DIR}/io/async/test/AsyncSSLSocketWriteTest.cpp
    ${FOLLY_DIR}/io/async/test/AsyncTransportTest.cpp
    ${FOLLY_DIR}/io/async/test/EventHandlerTest.cpp
    ${FOLLY_DIR}/io/async/test/AsyncSocketTest.h
    ${FOLLY_DIR}/io/async/test/AsyncSSLSocketTest.h
    ${FOLLY_DIR}/io/async/test/BlockingSocket.h
  )
  folly_test(HHWheelTimerTest "${FOLLY_DIR}/io/async/test/" "io/async/"  ${FOLLY_DIR}/io/async/test/HHWheelTimerTest.cpp)
  folly_test(HHWheelTimerSlowTests "${FOLLY_DIR}/io/async/test/" "io/async/"  ${FOLLY_DIR}/io/async/test/HHWheelTimerSlowTests.cpp)
  folly_test(DelayedDestructionBaseTest "${FOLLY_DIR}/io/async/test/" "io/async/"  ${FOLLY_DIR}/io/async/test/DelayedDestructionBaseTest.cpp)
  folly_test(DelayedDestructionTest "${FOLLY_DIR}/io/async/test/" "io/async/"  ${FOLLY_DIR}/io/async/test/DelayedDestructionTest.cpp)
  folly_test(EventBaseTest "${FOLLY_DIR}/io/async/test/" "io/async/"  ${FOLLY_DIR}/io/async/test/EventBaseTest.cpp)
  folly_test(EventBaseLocalTest "${FOLLY_DIR}/io/async/test/" "io/async/"  ${FOLLY_DIR}/io/async/test/EventBaseLocalTest.cpp)
  folly_test(AsyncUDPSocketTest "${FOLLY_DIR}/io/async/test/" "io/async/"  ${FOLLY_DIR}/io/async/test/AsyncUDPSocketTest.cpp)
  folly_test(ScopedEventBaseThreadTest "${FOLLY_DIR}/io/async/test/" "io/async/"  ${FOLLY_DIR}/io/async/test/ScopedEventBaseThreadTest.cpp)
  folly_test(NotificationQueueTest "${FOLLY_DIR}/io/async/test/" "io/async/"  ${FOLLY_DIR}/io/async/test/NotificationQueueTest.cpp)
  folly_test(RequestContextTest "${FOLLY_DIR}/io/async/test/" "io/async/"  ${FOLLY_DIR}/io/async/test/RequestContextTest.cpp)
  folly_test(writechain_test "${FOLLY_DIR}/io/async/test/" "io/async/"  ${FOLLY_DIR}/io/async/test/WriteChainAsyncTransportWrapperTest.cpp)
  folly_test(openssl_hash_test "${FOLLY_DIR}/ssl/test/" "ssl/"  ${FOLLY_DIR}/ssl/test/OpenSSLHashTest.cpp)
  folly_test(fibers_test "${FOLLY_DIR}/fibers/test/" "fibers/"  ${FOLLY_DIR}/fibers/test/FibersTest.cpp)
  folly_test(iobuf_test "${FOLLY_DIR}/io/test/" "io/"  ${FOLLY_DIR}/io/test/IOBufTest.cpp)
  folly_test(iobuf_cursor_test "${FOLLY_DIR}/io/test/" "io/"  ${FOLLY_DIR}/io/test/IOBufCursorTest.cpp)
  folly_test(iobuf_queue_test "${FOLLY_DIR}/io/test/" "io/"  ${FOLLY_DIR}/io/test/IOBufQueueTest.cpp)
  folly_test(record_io_test "${FOLLY_DIR}/io/test/" "io/"  ${FOLLY_DIR}/io/test/RecordIOTest.cpp)
  folly_test(ShutdownSocketSetTest "${FOLLY_DIR}/io/test/" "io/"  ${FOLLY_DIR}/io/test/ShutdownSocketSetTest.cpp)
  folly_test(combine_test "${FOLLY_DIR}/gen/test/" "gen/"  ${FOLLY_DIR}/gen/test/CombineTest.cpp)
  folly_test(fs_util_test "${FOLLY_DIR}/experimental/io/test/" "experimental/io/"  ${FOLLY_DIR}/experimental/io/test/FsUtilTest.cpp)
  folly_test(ssl_errors_test "${FOLLY_DIR}/io/async/ssl/test/" "io/async/ssl/"  ${FOLLY_DIR}/io/async/ssl/test/SSLErrorsTest.cpp)
  folly_test(traits_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/TraitsTest.cpp)
  folly_test(container_traits_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ContainerTraitsTest.cpp)
  folly_test(locks_test "${FOLLY_DIR}/test/" ""
    ${FOLLY_DIR}/test/SmallLocksTest.cpp
    ${FOLLY_DIR}/test/SpinLockTest.cpp
  )
  folly_test(packed_sync_ptr_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/PackedSyncPtrTest.cpp)
  folly_test(merge "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/MergeTest.cpp)
  folly_test(sorted_vector_types_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/sorted_vector_test.cpp)
  folly_test(small_vector_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/small_vector_test.cpp)
  folly_test(foreach_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ForeachTest.cpp)
  folly_test(checksum_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ChecksumTest.cpp)
  folly_test(hash_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/HashTest.cpp)
  folly_test(thread_cached_int_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ThreadCachedIntTest.cpp)
  folly_test(thread_local_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ThreadLocalTest.cpp)
  folly_test(apply_tuple_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ApplyTupleTest.cpp)
  folly_test(fbvector_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/FBVectorTest.cpp)
  folly_test(ascii_check_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/AsciiCaseInsensitiveTest.cpp)
  folly_test(dynamic_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/DynamicTest.cpp)
  folly_test(dynamic_other_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/DynamicOtherTest.cpp)
  folly_test(dynamic_converter_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/DynamicConverterTest.cpp)
  folly_test(json_other_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/JsonOtherTest.cpp)
  folly_test(scope_guard_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ScopeGuardTest.cpp)
  folly_test(timeout_queue_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/TimeoutQueueTest.cpp)
  folly_test(conv_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ConvTest.cpp)
  folly_test(range_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/RangeTest.cpp)
  folly_test(bits_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/BitsTest.cpp)
  folly_test(bit_iterator_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/BitIteratorTest.cpp)
  folly_test(discriminated_ptr_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/DiscriminatedPtrTest.cpp)
  folly_test(endian_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/EndianTest.cpp)
  folly_test(r_w_spin_lock_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/RWSpinLockTest.cpp)
  folly_test(synchronized_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/SynchronizedTest.cpp)
  folly_test(lock_traits_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/LockTraitsTest.cpp)
  folly_test(histogram_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/HistogramTest.cpp)
  folly_test(group_varint_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/GroupVarintTest.cpp)
  folly_test(group_varint_test_ssse3 "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/GroupVarintTest.cpp)
  folly_test(map_util_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/MapUtilTest.cpp)
  folly_test(string_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/StringTest.cpp)
  folly_test(uri_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/UriTest.cpp)
  folly_test(producer_consumer_queue_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ProducerConsumerQueueTest.cpp)
  folly_test(atomic_hash_array_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/AtomicHashArrayTest.cpp)
  folly_test(atomic_hash_map_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/AtomicHashMapTest.cpp)
  folly_test(memory_mapping_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/MemoryMappingTest.cpp)
  folly_test(thread_cached_arena_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ThreadCachedArenaTest.cpp)
  folly_test(arena_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ArenaTest.cpp)
  folly_test(arena_smartptr_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ArenaSmartPtrTest.cpp)
  folly_test(clock_gettime_wrappers_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ClockGettimeWrappersTest.cpp)
  folly_test(has_member_fn_traits_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/HasMemberFnTraitsTest.cpp)
  folly_test(demangle_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/DemangleTest.cpp)
  folly_test(format_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/FormatTest.cpp)
  folly_test(format_other_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/FormatOtherTest.cpp)
  folly_test(portability_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/PortabilityTest.cpp)
  folly_test(cpu_id_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/CpuIdTest.cpp)
  folly_test(random_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/RandomTest.cpp)
  folly_test(optional_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/OptionalTest.cpp)
  folly_test(expected_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ExpectedTest.cpp)
  folly_test(lazy_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/LazyTest.cpp)
  folly_test(spooky_hash_v1_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/SpookyHashV1Test.cpp)
  folly_test(spooky_hash_v2_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/SpookyHashV2Test.cpp)
  folly_test(timeseries_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/TimeseriesTest.cpp)
  folly_test(timeseries_histogram_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/TimeseriesHistogramTest.cpp)
  folly_test(padded_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/PaddedTest.cpp)
  folly_test(file_lock_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/FileLockTest.cpp)
  folly_test(file_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/FileTest.cpp)
  folly_test(file_util_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/FileUtilTest.cpp)
  folly_test(memory_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/MemoryTest.cpp)
  folly_test(exception_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ExceptionTest.cpp)
  folly_test(deterministic_schedule_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/DeterministicScheduleTest.cpp)
  folly_test(futex_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/FutexTest.cpp)
  folly_test(mpmc_queue_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/MPMCQueueTest.cpp)
  folly_test(ahm_int_stress_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/AHMIntStressTest.cpp)
  folly_test(mpmc_pipeline_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/MPMCPipelineTest.cpp)
  folly_test(varint_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/VarintTest.cpp)
  folly_test(atomic_unordered_map_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/AtomicUnorderedMapTest.cpp)
  folly_test(atomic_bit_set_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/AtomicBitSetTest.cpp)
  folly_test(move_wrapper_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/MoveWrapperTest.cpp)
  folly_test(safe_assert_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/SafeAssertTest.cpp)
  folly_test(cache_locality_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/CacheLocalityTest.cpp)
  folly_test(atomic_struct_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/AtomicStructTest.cpp)
  folly_test(indexed_mem_pool_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/IndexedMemPoolTest.cpp)
  folly_test(baton_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/BatonTest.cpp)
  folly_test(logging_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/LoggingTest.cpp)
  folly_test(memory_idler_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/MemoryIdlerTest.cpp)
  folly_test(lifosem_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/LifoSemTests.cpp)
  folly_test(network_address_test "${FOLLY_DIR}/test/" ""
    ${FOLLY_DIR}/test/IPAddressTest.cpp
    ${FOLLY_DIR}/test/MacAddressTest.cpp
    ${FOLLY_DIR}/test/SocketAddressTest.cpp
  )
  folly_test(exception_wrapper_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ExceptionWrapperTest.cpp)
  folly_test(evicting_cache_map_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/EvictingCacheMapTest.cpp)
  folly_test(array_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ArrayTest.cpp)
  folly_test(function_scheduler_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/FunctionSchedulerTest.cpp)
  folly_test(singletonvault_c_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/SingletonVaultCTest.cpp)
  folly_test(singleton_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/SingletonTest.cpp)
  folly_test(singleton_test_global "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/SingletonTestGlobal.cpp)
  folly_test(token_bucket_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/TokenBucketTest.cpp)
  folly_test(sparse_byte_set_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/SparseByteSetTest.cpp)
  folly_test(thread_name_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/ThreadNameTest.cpp)
  folly_test(memcpy_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/MemcpyTest.cpp)
  folly_test(call_once_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/CallOnceTest.cpp)
  folly_test(indestructible_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/IndestructibleTest.cpp)
  folly_test(function_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/FunctionTest.cpp)
  folly_test(atomic_linked_list_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/AtomicLinkedListTest.cpp)
  folly_test(unit_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/UnitTest.cpp)
  folly_test(try_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/TryTest.cpp)
  folly_test(enumerate_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/EnumerateTest.cpp)
  folly_test(mallctl_helper_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/MallctlHelperTest.cpp)
  folly_test(partial_test "${FOLLY_DIR}/test/" ""  ${FOLLY_DIR}/test/PartialTest.cpp)
  folly_test(test_util_test "${FOLLY_DIR}/experimental/test/" "experimental/"  ${FOLLY_DIR}/experimental/test/TestUtilTest.cpp)
  folly_test(bits_test_2 "${FOLLY_DIR}/experimental/test/" "experimental/"  ${FOLLY_DIR}/experimental/test/BitsTest.cpp)
  folly_test(eliasfano_test "${FOLLY_DIR}/experimental/test/" "experimental/"  ${FOLLY_DIR}/experimental/test/EliasFanoCodingTest.cpp)
  folly_test(bitvector_test "${FOLLY_DIR}/experimental/test/" "experimental/"  ${FOLLY_DIR}/experimental/test/BitVectorCodingTest.cpp)
  folly_test(stringkeyed_test "${FOLLY_DIR}/experimental/test/" "experimental/"  ${FOLLY_DIR}/experimental/test/StringKeyedTest.cpp)
  folly_test(autotimer_test "${FOLLY_DIR}/experimental/test/" "experimental/"  ${FOLLY_DIR}/experimental/test/AutoTimerTest.cpp)
  folly_test(json_schema_test "${FOLLY_DIR}/experimental/test/" "experimental/"  ${FOLLY_DIR}/experimental/test/JSONSchemaTest.cpp)
  folly_test(function_scheduler_test_2 "${FOLLY_DIR}/experimental/test/" "experimental/"  ${FOLLY_DIR}/experimental/test/FunctionSchedulerTest.cpp)
  folly_test(future_dag_test "${FOLLY_DIR}/experimental/test/" "experimental/"  ${FOLLY_DIR}/experimental/test/FutureDAGTest.cpp)
  folly_test(tuple_ops_test "${FOLLY_DIR}/experimental/test/" "experimental/"  ${FOLLY_DIR}/experimental/test/TupleOpsTest.cpp)
  folly_test(lock_free_ring_buffer_test "${FOLLY_DIR}/experimental/test/" "experimental/"  ${FOLLY_DIR}/experimental/test/LockFreeRingBufferTest.cpp)
endif()
