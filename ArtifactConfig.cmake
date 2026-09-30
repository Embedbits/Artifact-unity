set(UNITY_CURRENT_LIST_DIR ${CMAKE_CURRENT_LIST_DIR})
#------------------------------------------------------------------------------#
# Returns artifact version.
#
# The name of function must consist of folder name (unity) and postfix
# (_GetArtifactVersion). Otherwise the buildprocess will fail.
#
# Unlike a compiler/tool artifact (gcc-arm-none-eabi, probe-rs, ...), Unity
# ships no executable to query "--version" from - it is plain C source
# compiled straight into the test project. The version is therefore not
# re-discovered here; it is only returned from the cache variable that
# unity_ArtifactInit() populated. This means unity_ArtifactInit() MUST be
# called before unity_GetArtifactVersion().
#
# RET_VERSION [out]: Version of artifact in format X.Y.Z
#------------------------------------------------------------------------------#
function(unity_GetArtifactVersion RET_VERSION)

    if(NOT DEFINED UNITY_ARTIFACT_VERSION)
        message(FATAL_ERROR "unity_GetArtifactVersion called before unity_ArtifactInit() - UNITY_ARTIFACT_VERSION is not set.")
    endif()

    set(${RET_VERSION} "${UNITY_ARTIFACT_VERSION}" PARENT_SCOPE)

endfunction()


#------------------------------------------------------------------------------#
# Initialize artifact for build.
#
# The name of function must consist of folder name (unity) and postfix
# (_ArtifactInit). Otherwise the buildprocess will fail.
#
# Binary part contains the Unity source tree packaged by Unity_Importer.sh
# (OS independent, released as Bin/<version> without platform suffix).
#
# This does NOT define a "unity" library target - the consumers
# (UnitTesting.cmake for host, IntegrationTesting.cmake for MCU) build
# src/unity.c themselves with different compile definitions. It only
# exposes:
#   - UNITY_ROOT             (CACHE PATH)   - root of the Unity source tree
#                                             (src/unity.c, auto/*.rb, ...)
#   - UNITY_ARTIFACT_VERSION (CACHE STRING) - version read from the VERSION
#                                             marker, or from unity.h if the
#                                             marker is missing
#
# The Ruby scripts in auto/ (generate_test_runner.rb, ...) require a Ruby
# interpreter - use the "ruby" artifact (RUBY_EXECUTABLE).
#
# ARTIFACT_BIN_PATH_ARG [in]: Path to the binary (here: source) part of artifact
#------------------------------------------------------------------------------#
function(unity_ArtifactInit ARTIFACT_BIN_PATH_ARG)

    file(GLOB_RECURSE UNITY_SOURCES "${ARTIFACT_BIN_PATH_ARG}/*/unity.c")

    # Only the framework itself - skips copies vendored in examples/ or in
    # other packages (e.g. CMock's vendor/unity).
    list(FILTER UNITY_SOURCES INCLUDE REGEX "/src/unity\\.c$")
    list(FILTER UNITY_SOURCES EXCLUDE REGEX "/vendor/")

    if(NOT UNITY_SOURCES)

        message(FATAL_ERROR "File src/unity.c not found in: ${ARTIFACT_BIN_PATH_ARG}")

    endif()

    list(GET UNITY_SOURCES 0 UNITY_SOURCE)

    get_filename_component(UNITY_SRC_DIR "${UNITY_SOURCE}" DIRECTORY)
    get_filename_component(RESOLVED_ROOT_DIR "${UNITY_SRC_DIR}" DIRECTORY)

    message(STATUS "Unity source found in: ${RESOLVED_ROOT_DIR}")

    if(EXISTS "${RESOLVED_ROOT_DIR}/VERSION")

        # VERSION marker added by Unity_Importer.sh
        file(READ "${RESOLVED_ROOT_DIR}/VERSION" READ_VERSION)
        string(STRIP "${READ_VERSION}" READ_VERSION)

    else()

        # Fallback for source trees not packaged by Unity_Importer.sh
        file(STRINGS "${UNITY_SRC_DIR}/unity.h" VERSION_LINES
             REGEX "#define[ \t]+UNITY_VERSION_(MAJOR|MINOR|BUILD)[ \t]")

        set(READ_VERSION "")

        foreach(VERSION_PART IN ITEMS MAJOR MINOR BUILD)
            string(REGEX MATCH "UNITY_VERSION_${VERSION_PART}[ \t]+([0-9]+)" _ "${VERSION_LINES}")
            list(APPEND READ_VERSION "${CMAKE_MATCH_1}")
        endforeach()

        string(REPLACE ";" "." READ_VERSION "${READ_VERSION}")

    endif()

    if(NOT READ_VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")

        message(FATAL_ERROR "Unity version could not be resolved in ${RESOLVED_ROOT_DIR}: '${READ_VERSION}'")

    endif()

    set(UNITY_ROOT "${RESOLVED_ROOT_DIR}" CACHE PATH "Root of the resolved Unity source tree" FORCE)
    set(UNITY_ARTIFACT_VERSION "${READ_VERSION}" CACHE STRING "Resolved Unity artifact version" FORCE)

    message(STATUS "Unity version: ${UNITY_ARTIFACT_VERSION}")

endfunction()
