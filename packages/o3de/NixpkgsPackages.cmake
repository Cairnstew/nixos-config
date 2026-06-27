# =============================================================================
# NixpkgsPackages.cmake — CMake alias overlay for O3DE 3rd-party packages
# =============================================================================
# Injected via CMAKE_PROJECT_INCLUDE so it runs during project() before O3DE's
# own 3rdParty.cmake (included at line 91 of CMakeLists.txt).
#
# Gating: ly_add_external_target checks if(NOT TARGET 3rdParty::${NAME})
# before downloading.  Pre-defining the target here skips the CDN.
#
# Uses INTERFACE IMPORTED (not ALIAS) so O3DE's BuiltInPackages.cmake can
# still create lowercase aliases.
# =============================================================================

function(_np_import_find pkg target)
  if(TARGET 3rdParty::${target})
    return()
  endif()
  find_package(${pkg} QUIET)
  foreach(cand IN ITEMS ${pkg}::${pkg} ${target}::${target} ${pkg}::${target})
    if(TARGET ${cand})
      _np_make_imported(${target} ${cand})
      return()
    endif()
  endforeach()
  # pkg-config fallback
  find_package(PkgConfig QUIET)
  if(PkgConfig_FOUND)
    string(TOLOWER "${target}" _lower)
    pkg_check_modules(PKG_${target} ${_lower} QUIET IMPORTED_TARGET)
    if(PKG_${target}_FOUND AND TARGET PkgConfig::${_lower})
      _np_make_imported(${target} PkgConfig::${_lower})
      return()
    endif()
  endif()
  message(STATUS "NixpkgsPackages: 3rdParty::${target} NOT found")
endfunction()

function(_np_make_imported target linked_target)
  add_library(3rdParty::${target} INTERFACE IMPORTED GLOBAL)
  target_link_libraries(3rdParty::${target} INTERFACE ${linked_target})
  get_target_property(_inc ${linked_target} INTERFACE_INCLUDE_DIRECTORIES)
  if(_inc)
    target_include_directories(3rdParty::${target} INTERFACE ${_inc})
  endif()
  message(STATUS "NixpkgsPackages: 3rdParty::${target} ← ${linked_target}")
endfunction()

function(_np_header_or_stub target header_subpath)
  if(TARGET 3rdParty::${target})
    return()
  endif()
  find_path(${target}_INCLUDE_DIR ${header_subpath})
  if(${target}_INCLUDE_DIR)
    add_library(3rdParty::${target} INTERFACE IMPORTED GLOBAL)
    target_include_directories(3rdParty::${target} INTERFACE "${${target}_INCLUDE_DIR}")
    message(STATUS "NixpkgsPackages: 3rdParty::${target} ← ${${target}_INCLUDE_DIR}")
  else()
    # Create stub anyway — O3DE's if(NOT TARGET) gating requires the target to exist
    _np_stub(${target})
  endif()
endfunction()

macro(_np_stub target)
  if(NOT TARGET 3rdParty::${target})
    add_library(3rdParty::${target} INTERFACE IMPORTED GLOBAL)
    message(STATUS "NixpkgsPackages: 3rdParty::${target} stubbed")
  endif()
endmacro()

# =============================================================================
# Tier 1 — standard find_package
# =============================================================================

# ZLIB — use find_library directly with INTERFACE IMPORTED so O3DE's runtime
# dependency resolver can find the actual library location (ZLIB::ZLIB is
# IMPORTED and the resolver can't trace through it).
find_package(ZLIB QUIET)
if(ZLIB_FOUND AND NOT TARGET 3rdParty::ZLIB)
  add_library(3rdParty::ZLIB INTERFACE IMPORTED GLOBAL)
  target_link_libraries(3rdParty::ZLIB INTERFACE "${ZLIB_LIBRARIES}")
  target_include_directories(3rdParty::ZLIB INTERFACE "${ZLIB_INCLUDE_DIRS}")
  message(STATUS "NixpkgsPackages: 3rdParty::ZLIB ← ${ZLIB_LIBRARIES}")
elseif(NOT TARGET 3rdParty::ZLIB)
  _np_stub(ZLIB)
endif()
# For packages where we need to find the actual library paths (not IMPORTED
# cmake config targets) so O3DE's runtime dependency resolver can locate
# the files for bundling.  We use find_package for discovery but link to
# the real files, not to IMPORTED config targets.
function(_np_find_real pkg target libname)
  if(TARGET 3rdParty::${target})
    return()
  endif()
  find_package(${pkg} QUIET)
  if(${pkg}_FOUND)
    add_library(3rdParty::${target} INTERFACE IMPORTED GLOBAL)
    set(_libs "")
    foreach(_hint IN ITEMS "${${pkg}_LIBRARIES}" "${${target}_LIBRARIES}" "${libname}")
      if(_hint MATCHES "^-l" OR _hint MATCHES "^/")
        list(APPEND _libs "${_hint}")
      elseif(_hint)
        find_library(_found_${target} "${_hint}" PATHS "${${pkg}_LIBRARY_DIRS}" NO_DEFAULT_PATH)
        if(_found_${target})
          list(APPEND _libs "${_found_${target}}")
        endif()
      endif()
    endforeach()
    if(NOT _libs)
      find_library(_fallback_${target} "${libname}")
      if(_fallback_${target})
        set(_libs "${_fallback_${target}}")
      endif()
    endif()
    if(_libs)
      target_link_libraries(3rdParty::${target} INTERFACE "${_libs}")
    endif()
    if(${pkg}_INCLUDE_DIRS)
      target_include_directories(3rdParty::${target} INTERFACE "${${pkg}_INCLUDE_DIRS}")
    endif()
    message(STATUS "NixpkgsPackages: 3rdParty::${target} ← ${_libs}")
  else()
    message(STATUS "NixpkgsPackages: 3rdParty::${target} NOT found via find_package")
  endif()
endfunction()

_np_find_real(PNG PNG png16)
_np_find_real(EXPAT expat expat)
_np_find_real(Freetype Freetype freetype)
_np_find_real(TIFF TIFF tiff)
_np_find_real(OpenEXR OpenEXR OpenEXR)
_np_find_real(assimp assimp assimp)
_np_find_real(glslang glslang glslang)
_np_find_real(Imath Imath Imath)
_np_find_real(meshoptimizer meshoptimizer meshoptimizer)
_np_import_find(Lua Lua)            # → Lua::Lua
if(NOT TARGET 3rdParty::Lua)
  _np_stub(Lua)  # fallback if find_package misses during project()
endif()

# OpenSSL — find real libs so O3DE's runtime dep resolver can locate them
find_package(OpenSSL QUIET)
if(OpenSSL_FOUND AND NOT TARGET 3rdParty::OpenSSL)
  add_library(3rdParty::OpenSSL INTERFACE IMPORTED GLOBAL)
  foreach(_ossl IN ITEMS OpenSSL::SSL OpenSSL::Crypto)
    get_target_property(_loc ${_ossl} IMPORTED_LOCATION)
    if(_loc)
      target_link_libraries(3rdParty::OpenSSL INTERFACE "${_loc}")
    endif()
    get_target_property(_loc_r ${_ossl} IMPORTED_LOCATION_RELEASE)
    if(_loc_r)
      target_link_libraries(3rdParty::OpenSSL INTERFACE "${_loc_r}")
    endif()
  endforeach()
  target_include_directories(3rdParty::OpenSSL INTERFACE "${OPENSSL_INCLUDE_DIR}")
  message(STATUS "NixpkgsPackages: 3rdParty::OpenSSL ← direct libs")
elseif(NOT TARGET 3rdParty::OpenSSL)
  message(STATUS "NixpkgsPackages: 3rdParty::OpenSSL NOT found")
endif()

# lz4 — use find_library directly so O3DE's runtime dep resolver can find
# the actual library file (LZ4::lz4_shared is IMPORTED without location).
find_package(lz4 QUIET)
if(lz4_FOUND AND NOT TARGET 3rdParty::lz4)
  add_library(3rdParty::lz4 INTERFACE IMPORTED GLOBAL)
  target_link_libraries(3rdParty::lz4 INTERFACE "${LZ4_LIBRARIES}")
  target_include_directories(3rdParty::lz4 INTERFACE "${LZ4_INCLUDE_DIRS}")
  message(STATUS "NixpkgsPackages: 3rdParty::lz4 ← ${LZ4_LIBRARIES}")
elseif(NOT TARGET 3rdParty::lz4)
  _np_stub(lz4)
endif()

# SQLite — cmake built‑in FindSQLite3 creates SQLite::SQLite3
find_package(SQLite3 QUIET)
if(TARGET SQLite::SQLite3 AND NOT TARGET 3rdParty::SQLite)
  _np_make_imported(SQLite SQLite::SQLite3)
elseif(NOT TARGET 3rdParty::SQLite)
  _np_stub(SQLite)
endif()

# xxHash — find real lib for O3DE runtime dep resolver
find_package(xxHash QUIET)
if(xxHash_FOUND AND NOT TARGET 3rdParty::xxhash)
  add_library(3rdParty::xxhash INTERFACE IMPORTED GLOBAL)
  get_target_property(_xx_loc xxHash::xxhash IMPORTED_LOCATION)
  if(_xx_loc)
    target_link_libraries(3rdParty::xxhash INTERFACE "${_xx_loc}")
  else()
    find_library(_xx_fallback xxhash)
    if(_xx_fallback)
      target_link_libraries(3rdParty::xxhash INTERFACE "${_xx_fallback}")
    endif()
  endif()
  get_target_property(_xx_inc xxHash::xxhash INTERFACE_INCLUDE_DIRECTORIES)
  if(_xx_inc)
    target_include_directories(3rdParty::xxhash INTERFACE "${_xx_inc}")
  endif()
  message(STATUS "NixpkgsPackages: 3rdParty::xxhash ← direct libs")
elseif(NOT TARGET 3rdParty::xxhash)
  _np_stub(xxhash)
endif()

# SPIRVCross — try spirv-cross-core, spirv_cross_core, or spirv-cross
foreach(_spirv IN ITEMS spirv-cross-core spirv_cross_core spirv-cross)
  if(NOT TARGET 3rdParty::SPIRVCross)
    find_package(${_spirv} QUIET)
    foreach(_cand IN ITEMS ${_spirv}::${_spirv} ${_spirv}::spirv-cross-core)
      if(TARGET ${_cand})
        _np_make_imported(SPIRVCross ${_cand})
        break()
      endif()
    endforeach()
  endif()
endforeach()
if(NOT TARGET 3rdParty::SPIRVCross)
  _np_stub(SPIRVCross)
endif()

# RapidJSON (header‑only, fall back to stub)
_np_header_or_stub(RapidJSON rapidjson/rapidjson.h)

# RapidXML (header‑only, fall back to stub)
if(NOT TARGET 3rdParty::RapidXML)
  find_path(RapidXML_INCLUDE_DIR rapidxml/rapidxml.hpp)
  if(RapidXML_INCLUDE_DIR)
    add_library(3rdParty::RapidXML INTERFACE IMPORTED GLOBAL)
    target_include_directories(3rdParty::RapidXML INTERFACE "${RapidXML_INCLUDE_DIR}")
    include_directories("${RapidXML_INCLUDE_DIR}")
    message(STATUS "NixpkgsPackages: 3rdParty::RapidXML ← ${RapidXML_INCLUDE_DIR}")
  else()
    _np_stub(RapidXML)
  endif()
endif()

# zstd — NOT defined here.  O3DE's libzstd_linux.cmake handles it via pkg-config.

# =============================================================================
# Qt — stub the cmake function that O3DE expects from the Qt SDK package
function(ly_qt_uic_target target_name)
  message(STATUS "NixpkgsPackages: ly_qt_uic_target(${target_name}) stubbed")
endfunction()

# Qt — real Qt6 targets from nixpkgs
# scout-qt confirmed all 10 private headers O3DE uses are standard and ship
# with nixpkgs qtbase's dev output.  O3DE does NOT need the custom Qt5 build
# from 3p-package-source — nixpkgs Qt6 works for building Framework code.
# =============================================================================
set(_qt_components Core Gui Widgets Svg Xml Network OpenGL Qml Quick QuickControls2 PrintSupport Concurrent Test DBus OpenGLWidgets)
find_package(Qt6 QUIET COMPONENTS ${_qt_components})
if(Qt6_FOUND)
  message(STATUS "NixpkgsPackages: Qt6 found at ${Qt6_DIR}")
  foreach(_comp ${_qt_components})
    if(TARGET Qt6::${_comp} AND NOT TARGET 3rdParty::Qt::${_comp})
      add_library(3rdParty::Qt::${_comp} INTERFACE IMPORTED GLOBAL)
      target_link_libraries(3rdParty::Qt::${_comp} INTERFACE Qt6::${_comp})
      message(STATUS "NixpkgsPackages: 3rdParty::Qt::${_comp} ← Qt6::${_comp}")
    endif()
  endforeach()
  # Set QT_LRELEASE_EXECUTABLE so LmbrCentral's lrelease_linux.cmake finds it
  if(NOT QT_LRELEASE_EXECUTABLE)
    find_program(_qt_lrelease NAMES lrelease)
    if(_qt_lrelease)
      set(QT_LRELEASE_EXECUTABLE "${_qt_lrelease}" CACHE FILEPATH "Qt lrelease executable")
      message(STATUS "NixpkgsPackages: QT_LRELEASE_EXECUTABLE ← ${_qt_lrelease}")
    else()
      message(STATUS "NixpkgsPackages: QT_LRELEASE_EXECUTABLE not found")
    endif()
  endif()

  # Also create bare 3rdParty::Qt alias so O3DE's gating succeeds
  if(NOT TARGET 3rdParty::Qt)
    add_library(3rdParty::Qt INTERFACE IMPORTED GLOBAL)
    target_link_libraries(3rdParty::Qt INTERFACE Qt6::Core)
  endif()
else()
  message(STATUS "NixpkgsPackages: Qt6 NOT found — stubbing Qt targets")
  foreach(_qt IN ITEMS Qt Qt::Core Qt::Gui Qt::Widgets Qt::Svg Qt::Xml Qt::Network Qt::OpenGL Qt::Qml Qt::Quick Qt::QuickControls2 Qt::PrintSupport Qt::Concurrent Qt::Test Qt::DBus Qt::OpenGLWidgets Qt::UiTools)
    if(NOT TARGET 3rdParty::${_qt})
      add_library(3rdParty::${_qt} INTERFACE IMPORTED GLOBAL)
      message(STATUS "NixpkgsPackages: 3rdParty::${_qt} stubbed")
    endif()
  endforeach()
endif()

# =============================================================================
# Python — stub to skip ly_download_associated_package(Python)
# Also ensure Python_HOME/Python_PATHS are set so LYPython.cmake validation
# passes and it properly sets LY_PYTHON_CMD + installs pip requirements.
# =============================================================================
if(NOT TARGET 3rdParty::Python)
  add_library(3rdParty::Python INTERFACE IMPORTED GLOBAL)
  message(STATUS "NixpkgsPackages: 3rdParty::Python stubbed")
endif()
find_package(Python3 QUIET COMPONENTS Interpreter)
if(Python3_EXECUTABLE)
  if(NOT Python_HOME)
    get_filename_component(Python_HOME "${Python3_EXECUTABLE}" DIRECTORY)
    get_filename_component(Python_HOME "${Python_HOME}" DIRECTORY)
    set(Python_HOME "${Python_HOME}" CACHE PATH "Python home directory")
  endif()
  if(NOT Python_PATHS)
    execute_process(COMMAND "${Python3_EXECUTABLE}" -c "import sys; print(\";\".join(sys.path))"
                    OUTPUT_VARIABLE Python_PATHS OUTPUT_STRIP_TRAILING_WHITESPACE)
    set(Python_PATHS "${Python_PATHS}" CACHE STRING "Python sys.path")
  endif()
  message(STATUS "NixpkgsPackages: Python_HOME=${Python_HOME}")
endif()

# =============================================================================
# googletest — find real libs for O3DE runtime dep resolver
# =============================================================================
find_package(GTest QUIET)
if(GTest_FOUND AND NOT TARGET 3rdParty::googletest::GTest)
  add_library(3rdParty::googletest::GTest INTERFACE IMPORTED GLOBAL)
  find_library(_gtest_lib gtest)
  if(_gtest_lib)
    target_link_libraries(3rdParty::googletest::GTest INTERFACE "${_gtest_lib}")
  endif()
  target_include_directories(3rdParty::googletest::GTest INTERFACE "${GTEST_INCLUDE_DIRS}")
  message(STATUS "NixpkgsPackages: 3rdParty::googletest::GTest ← ${_gtest_lib}")
endif()
if(GTest_FOUND AND NOT TARGET 3rdParty::googletest::GMock)
  add_library(3rdParty::googletest::GMock INTERFACE IMPORTED GLOBAL)
  find_library(_gmock_lib gmock)
  if(_gmock_lib)
    target_link_libraries(3rdParty::googletest::GMock INTERFACE "${_gmock_lib}")
  endif()
  target_include_directories(3rdParty::googletest::GMock INTERFACE "${GTEST_INCLUDE_DIRS}")
  message(STATUS "NixpkgsPackages: 3rdParty::googletest::GMock ← ${_gmock_lib}")
endif()

# =============================================================================
# pybind11 — nixpkgs has it via find_package
# =============================================================================
_np_import_find(pybind11 pybind11)

# =============================================================================
# vulkan-validationlayers — stub (O3DE downloads this separately)
# =============================================================================
if(NOT TARGET 3rdParty::vulkan-validationlayers)
  add_library(3rdParty::vulkan-validationlayers INTERFACE IMPORTED GLOBAL)
  target_include_directories(3rdParty::vulkan-validationlayers INTERFACE "${Vulkan_INCLUDE_DIR}")
  target_link_libraries(3rdParty::vulkan-validationlayers INTERFACE Vulkan::Vulkan)
  message(STATUS "NixpkgsPackages: 3rdParty::vulkan-validationlayers ← Vulkan::Vulkan")
endif()

# =============================================================================
# Generic 3rdParty stub handler — patches Find*.cmake files in Gems to skip
# FetchContent and use a generic stub target so configure can proceed.
# Each Gem has its own FindXXX.cmake; we intercept by pre-defining the target.
# =============================================================================

# meshoptimizer — used by Atom RPI gem
_np_import_find(meshoptimizer meshoptimizer)

# OpenMesh — nixpkgs openmesh, header+lib (no cmake config)
if(NOT TARGET 3rdParty::OpenMesh)
  find_path(OpenMesh_INCLUDE_DIR OpenMesh/Core/Mesh/PolyMeshT.hh)
  find_library(OpenMeshCore_LIBRARY OpenMeshCore)
  if(OpenMesh_INCLUDE_DIR AND OpenMeshCore_LIBRARY)
    add_library(3rdParty::OpenMesh INTERFACE IMPORTED GLOBAL)
    target_include_directories(3rdParty::OpenMesh INTERFACE "${OpenMesh_INCLUDE_DIR}")
    target_link_libraries(3rdParty::OpenMesh INTERFACE "${OpenMeshCore_LIBRARY}")
    message(STATUS "NixpkgsPackages: 3rdParty::OpenMesh ← ${OpenMeshCore_LIBRARY}")
  else()
    _np_stub(OpenMesh)
  endif()
endif()

# miniaudio_libvorbis — used by MiniAudio gem for Vorbis decoding via miniaudio
_np_stub(miniaudio_libvorbis)

# miniaudio — header-only library in nixpkgs
if(NOT TARGET 3rdParty::miniaudio)
  find_path(miniaudio_INCLUDE_DIR miniaudio.h)
  if(miniaudio_INCLUDE_DIR)
    add_library(3rdParty::miniaudio INTERFACE IMPORTED GLOBAL)
    target_include_directories(3rdParty::miniaudio INTERFACE "${miniaudio_INCLUDE_DIR}")
    message(STATUS "NixpkgsPackages: 3rdParty::miniaudio ← ${miniaudio_INCLUDE_DIR}")
  else()
    _np_stub(miniaudio)
  endif()
endif()

# Ogg/Vorbis — nixpkgs libogg + libvorbis (no cmake configs)
_np_header_or_stub(Ogg ogg/ogg.h)
_np_header_or_stub(Vorbis vorbis/codec.h)

# mcpp — C preprocessor for Atom shader compiler
find_package(mcpp QUIET)
if(TARGET mcpp::mcpp AND NOT TARGET 3rdParty::mcpp)
  add_library(3rdParty::mcpp INTERFACE IMPORTED GLOBAL)
  target_link_libraries(3rdParty::mcpp INTERFACE mcpp::mcpp)
  message(STATUS "NixpkgsPackages: 3rdParty::mcpp ← mcpp::mcpp")
elseif(NOT TARGET 3rdParty::mcpp)
  _np_stub(mcpp)
endif()

# DirectXShaderCompilerDxc — HLSL→SPIRV shader compiler for Atom pipeline
# nixpkgs directx-shader-compiler provides the `dxc` binary.
# O3DE finds it via FindDirectXShaderCompilerDxc.cmake which calls find_package
# with CONFIG (if cmake config exists) or falls back to find_program.
# Use find_program first so O3DE's find_package picks it up.
if(NOT TARGET 3rdParty::DirectXShaderCompilerDxc)
  find_program(DXC_EXECUTABLE NAMES dxc)
  if(DXC_EXECUTABLE)
    add_executable(3rdParty::DirectXShaderCompilerDxc IMPORTED GLOBAL)
    set_target_properties(3rdParty::DirectXShaderCompilerDxc PROPERTIES
      IMPORTED_LOCATION "${DXC_EXECUTABLE}")
    message(STATUS "NixpkgsPackages: 3rdParty::DirectXShaderCompilerDxc ← ${DXC_EXECUTABLE}")
  else()
    _np_stub(DirectXShaderCompilerDxc)
  endif()
endif()

# azslc — O3DE's shader compiler tool (part of SDK packages)
if(NOT TARGET 3rdParty::azslc)
  _np_stub(azslc)
endif()

# libsamplerate — audio sample rate conversion for Microphone gem
_np_stub(libsamplerate)

# OpenImageIO — find real libs for O3DE runtime dep resolver
find_package(OpenImageIO QUIET)
if(TARGET OpenImageIO::OpenImageIO AND NOT TARGET 3rdParty::OpenImageIO)
  add_library(3rdParty::OpenImageIO INTERFACE IMPORTED GLOBAL)
  foreach(_oiio IN ITEMS OpenImageIO::OpenImageIO OpenImageIO::OpenImageIO_Util)
    get_target_property(_loc ${_oiio} IMPORTED_LOCATION)
    if(_loc)
      target_link_libraries(3rdParty::OpenImageIO INTERFACE "${_loc}")
    endif()
  endforeach()
  foreach(_hdr IN ITEMS OpenImageIO::OpenImageIO OpenImageIO::OpenImageIO_Util)
    get_target_property(_inc ${_hdr} INTERFACE_INCLUDE_DIRECTORIES)
    if(_inc)
      target_include_directories(3rdParty::OpenImageIO INTERFACE "${_inc}")
    endif()
  endforeach()
  # Also search for libs directly as fallback
  find_library(_oiio_lib OpenImageIO)
  if(_oiio_lib)
    target_link_libraries(3rdParty::OpenImageIO INTERFACE "${_oiio_lib}")
  endif()
  find_library(_oiio_util_lib OpenImageIO_Util)
  if(_oiio_util_lib)
    target_link_libraries(3rdParty::OpenImageIO INTERFACE "${_oiio_util_lib}")
  endif()
  message(STATUS "NixpkgsPackages: 3rdParty::OpenImageIO ← direct libs")
endif()
# Also stub component targets that O3DE references in RUNTIME_DEPENDENCIES
# These include the full 3rdParty:: prefix since they're sub-targets
if(NOT TARGET 3rdParty::OpenImageIO::Tools::Binaries)
  add_library(3rdParty::OpenImageIO::Tools::Binaries INTERFACE IMPORTED GLOBAL)
  target_link_libraries(3rdParty::OpenImageIO::Tools::Binaries INTERFACE 3rdParty::OpenImageIO)
  message(STATUS "NixpkgsPackages: 3rdParty::OpenImageIO::Tools::Binaries ← 3rdParty::OpenImageIO")
endif()
if(NOT TARGET 3rdParty::OpenImageIO::Tools::PythonPlugins)
  add_library(3rdParty::OpenImageIO::Tools::PythonPlugins INTERFACE IMPORTED GLOBAL)
  target_link_libraries(3rdParty::OpenImageIO::Tools::PythonPlugins INTERFACE 3rdParty::OpenImageIO)
  message(STATUS "NixpkgsPackages: 3rdParty::OpenImageIO::Tools::PythonPlugins ← 3rdParty::OpenImageIO")
endif()

# mikkelsen — normal map computation, not in nixpkgs
_np_stub(mikkelsen)

# NvCloth — NVIDIA cloth simulation, not in nixpkgs
_np_stub(NvCloth)

# squish-ccr — texture compression, not in nixpkgs
_np_stub(squish-ccr)

# PhysX — NVIDIA physics engine, proprietary
_np_stub(PhysX4)
_np_stub(PhysX5)

# RecastNavigation — navmesh, fetched via FetchContent/git in Gems/RecastNavigation/Code/CMakeLists.txt
# Pre-declare to skip the git clone during configure.  O3DE creates the target
# in FindRecastNavigation.cmake which checks TARGET 3rdParty::RecastNavigation
# first; our INTERFACE IMPORTED GLOBAL target satisfies the guard.
if(NOT TARGET 3rdParty::RecastNavigation)
  add_library(3rdParty::RecastNavigation INTERFACE IMPORTED GLOBAL)
  message(STATUS "NixpkgsPackages: 3rdParty::RecastNavigation stubbed (FetchContent)")
endif()
# Also pre-populate FetchContent so FetchContent_MakeAvailable returns immediately.
# The stub CMakeLists.txt must define the targets that O3DE's code expects
# (Recast, Detour, DetourCrowd, DetourTileCache, DebugUtils) as INTERFACE
# libraries since we don't have the actual source.
set(FETCHCONTENT_SOURCE_DIR_RECASTNAVIGATION "${CMAKE_CURRENT_BINARY_DIR}/_deps/recastnavigation-src" CACHE PATH "Pre-populated RecastNavigation source")
file(MAKE_DIRECTORY "${FETCHCONTENT_SOURCE_DIR_RECASTNAVIGATION}")
file(WRITE "${FETCHCONTENT_SOURCE_DIR_RECASTNAVIGATION}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.22)\n"
  "project(RecastNavigation)\n"
  "foreach(lib IN ITEMS Recast Detour DetourCrowd DetourTileCache DebugUtils)\n"
  "  add_library(\${lib} INTERFACE)\n"
  "  add_library(RecastNavigation::\${lib} ALIAS \${lib})\n"
  "  target_include_directories(\${lib} INTERFACE \${CMAKE_CURRENT_SOURCE_DIR}/\${lib})\n"
  "endforeach()\n"
)

# v-hacd — convex decomposition for PhysX, fetched via FetchContent
_np_stub(v-hacd)

# poly2tri — polygon triangulation, not in nixpkgs
_np_stub(poly2tri)

# Stubs — not in nixpkgs
_np_stub(cityhash)
_np_stub(GoogleBenchmark)

# astc-encoder — nixpkgs has it, header+lib (may need find_package aliasing)
if(NOT TARGET 3rdParty::astc-encoder)
  find_path(astc_encoder_INCLUDE_DIR astcenc.h)
  find_library(astc_encoder_LIBRARY astcenc)
  if(astc_encoder_INCLUDE_DIR AND astc_encoder_LIBRARY)
    add_library(3rdParty::astc-encoder INTERFACE IMPORTED GLOBAL)
    target_include_directories(3rdParty::astc-encoder INTERFACE "${astc_encoder_INCLUDE_DIR}")
    target_link_libraries(3rdParty::astc-encoder INTERFACE "${astc_encoder_LIBRARY}")
    message(STATUS "NixpkgsPackages: 3rdParty::astc-encoder ← ${astc_encoder_LIBRARY}")
  else()
    _np_stub(astc-encoder)
  endif()
endif()
_np_stub(ISPCTexComp)
_np_stub(pyside2)
# pyside2::Tools sub-target needed by QtForPython.Editor
if(NOT TARGET 3rdParty::pyside2::Tools)
  add_library(3rdParty::pyside2::Tools INTERFACE IMPORTED GLOBAL)
  target_link_libraries(3rdParty::pyside2::Tools INTERFACE 3rdParty::pyside2)
  message(STATUS "NixpkgsPackages: 3rdParty::pyside2::Tools stubbed")
endif()
# pyside2 needs a Find module because O3DE's ly_parse_third_party_dependencies
# doesn't always respect the pre-existing target.  Write a module file that
# sets up the target if missing AND declares pyside2_FOUND.
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/Findpyside2.cmake"
  "if(NOT TARGET 3rdParty::pyside2)\n"
  "  add_library(3rdParty::pyside2 INTERFACE IMPORTED GLOBAL)\n"
  "endif()\n"
  "set(pyside2_FOUND TRUE CACHE BOOL \"pyside2 found by NixpkgsPackages overlay\")\n"
)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_BINARY_DIR}")
_np_stub(AWSNativeSDK)
_np_stub(pix)

# Stub for ly_add_translations — not defined in O3DE source, provided by SDK
# packages that are blocked from download.  The function is only called in the
# Editor, which is an optional component.
function(ly_add_translations)
  message(STATUS "NixpkgsPackages: ly_add_translations(${ARGV}) stubbed")
endfunction()

# GCC 15 hardened tuple_element static_assert breaks SFINAE in O3DE's
# conditional explicit(bool) pair-like constructor.  Disabling the conditional
# explicit avoids the non-SFINAE get<I> ADL lookup that triggers it.
add_definitions(-DO3DE_DISABLE_CONDITIONAL_EXPLICIT)

# Suppress GCC 14+ -Werror compatibility issues (null args to memcpy, unused inline vars)
# These flags need to be APPENDED to the existing ones which O3DE configures.
foreach(_lang IN ITEMS C CXX)
  string(APPEND CMAKE_${_lang}_FLAGS " -Wno-nonnull -Wno-unused-variable")
endforeach()
message(STATUS "NixpkgsPackages: overlay loaded")
