find_package(Boost 1.55.0 MODULE
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
find_package(Double-Conversion CONFIG REQUIRED)
find_package(GFlags CONFIG REQUIRED)
find_package(GLog CONFIG REQUIRED)
find_package(LibEvent CONFIG REQUIRED)
find_package(OpenSSL MODULE REQUIRED)
find_package(PThread CONFIG REQUIRED)
