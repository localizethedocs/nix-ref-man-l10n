# Distributed under the OSI-approved BSD 3-Clause License.
# See accompanying file LICENSE-BSD for details.

cmake_minimum_required(VERSION 3.25)
get_filename_component(SCRIPT_NAME "${CMAKE_CURRENT_LIST_FILE}" NAME_WE)
set(CMAKE_MESSAGE_INDENT "[${VERSION}][${LANGUAGE}] ")
set(CMAKE_MESSAGE_INDENT_BACKUP "${CMAKE_MESSAGE_INDENT}")
message(STATUS "-------------------- ${SCRIPT_NAME} --------------------")


set(CMAKE_MODULE_PATH   "${PROJ_CMAKE_MODULES_DIR}")
set(CMAKE_PROGRAM_PATH  "${PROJ_CONDA_DIR}"
                        "${PROJ_CONDA_DIR}/Library")
find_package(Git        MODULE REQUIRED)
find_package(Gettext    MODULE REQUIRED COMPONENTS Msgcat Msgmerge)
find_package(Dasel      MODULE REQUIRED)
find_package(mdBook     MODULE REQUIRED COMPONENTS mdBook)
include(LogUtils)
include(GitUtils)
include(JsonUtils)
include(GettextUtils)


message(STATUS "Determining whether it is required to update .pot files...")
file(READ "${REFERENCES_JSON_PATH}" REFERENCES_JSON_CNT)
get_reference_of_latest_from_repo_and_current_from_json(
    IN_LOCAL_PATH                   "${PROJ_OUT_REPO_DIR}"
    IN_JSON_CNT                     "${REFERENCES_JSON_CNT}"
    IN_VERSION_TYPE                 "${VERSION_TYPE}"
    IN_BRANCH_NAME                  "${BRANCH_NAME}"
    IN_TAG_PATTERN                  "${TAG_PATTERN}"
    IN_TAG_SUFFIX                   "${TAG_SUFFIX}"
    IN_DOT_NOTATION                 ".pot"
    OUT_LATEST_OBJECT               LATEST_POT_OBJECT
    OUT_LATEST_REFERENCE            LATEST_POT_REFERENCE
    OUT_CURRENT_OBJECT              CURRENT_POT_OBJECT
    OUT_CURRENT_REFERENCE           CURRENT_POT_REFERENCE)
if (MODE_OF_UPDATE STREQUAL "COMPARE")
    if (NOT CURRENT_POT_REFERENCE STREQUAL LATEST_POT_REFERENCE)
        set(UPDATE_POT_REQUIRED     ON)
    else()
        set(UPDATE_POT_REQUIRED     OFF)
    endif()
elseif (MODE_OF_UPDATE STREQUAL "ALWAYS")
    set(UPDATE_POT_REQUIRED         ON)
elseif (MODE_OF_UPDATE STREQUAL "NEVER")
    if (NOT CURRENT_POT_REFERENCE)
        set(UPDATE_POT_REQUIRED     ON)
    else()
        set(UPDATE_POT_REQUIRED     OFF)
    endif()
else()
    message(FATAL_ERROR "Invalid MODE_OF_UPDATE value. (${MODE_OF_UPDATE})")
endif()
remove_cmake_message_indent()
message("")
message("LATEST_POT_OBJECT      = ${LATEST_POT_OBJECT}")
message("CURRENT_POT_OBJECT     = ${CURRENT_POT_OBJECT}")
message("LATEST_POT_REFERENCE   = ${LATEST_POT_REFERENCE}")
message("CURRENT_POT_REFERENCE  = ${CURRENT_POT_REFERENCE}")
message("MODE_OF_UPDATE         = ${MODE_OF_UPDATE}")
message("UPDATE_POT_REQUIRED    = ${UPDATE_POT_REQUIRED}")
message("")
restore_cmake_message_indent()


if (NOT UPDATE_POT_REQUIRED)
    message(STATUS "No need to update .pot files.")
    return()
else()
    message(STATUS "Prepare to update .pot files.")
endif()


message(STATUS "Removing directory '${PROJ_OUT_REPO_DOCS_LOCALE_DIR}/'...")
if (EXISTS "${PROJ_OUT_REPO_DOCS_LOCALE_DIR}")
    file(REMOVE_RECURSE "${PROJ_OUT_REPO_DOCS_LOCALE_DIR}")
    remove_cmake_message_indent()
    message("")
    message("Directory '${PROJ_OUT_REPO_DOCS_LOCALE_DIR}/' exists.")
    message("Removed '${PROJ_OUT_REPO_DOCS_LOCALE_DIR}/'.")
    message("")
    restore_cmake_message_indent()
else()
    remove_cmake_message_indent()
    message("")
    message("Directory '${PROJ_OUT_REPO_DOCS_LOCALE_DIR}/' does NOT exist.")
    message("No need to remove '${PROJ_OUT_REPO_DOCS_LOCALE_DIR}/'.")
    message("")
    restore_cmake_message_indent()
endif()


message(STATUS "Running 'mdbook build' command to generate .pot files...")
if (CMAKE_HOST_LINUX)
    set(ENV_PATH                "${PROJ_CONDA_DIR}/bin:$ENV{PATH}")
    set(ENV_LD_LIBRARY_PATH     "${PROJ_CONDA_DIR}/lib:$ENV{LD_LIBRARY_PATH}")
    set(ENV_CARGO_INSTALL_ROOT  "${PROJ_CONDA_DIR}")
    set(ENV_VARS_OF_SYSTEM      PATH=${ENV_PATH}
                                LD_LIBRARY_PATH=${ENV_LD_LIBRARY_PATH}
                                CARGO_INSTALL_ROOT=${ENV_CARGO_INSTALL_ROOT})
elseif (CMAKE_HOST_WIN32)
    set(ENV_PATH                "${PROJ_CONDA_DIR}/bin"
                                "${PROJ_CONDA_DIR}/Scripts"
                                "${PROJ_CONDA_DIR}/Library/bin"
                                "${PROJ_CONDA_DIR}"
                                "$ENV{PATH}")
    set(ENV_CARGO_INSTALL_ROOT  "${PROJ_CONDA_DIR}/Library")
    string(REPLACE ";" "\\\\;" ENV_PATH "${ENV_PATH}")
    set(ENV_VARS_OF_SYSTEM      PATH=${ENV_PATH}
                                CARGO_INSTALL_ROOT=${ENV_CARGO_INSTALL_ROOT})
else()
    message(FATAL_ERROR "Invalid OS platform. (${CMAKE_HOST_SYSTEM_NAME})")
endif()
block(PROPAGATE MDBOOK_BOOK__SRC)
    set(MDBOOK_BOOK__SRC        "${SRC_TO_BOOK_DIR}")
endblock()
block(PROPAGATE MDBOOK_OUTPUT)
    set(MDBOOK_OUTPUT "{}")
    set(MDBOOK_OUTPUT__XGETTEXT "{}")
    string(JSON MDBOOK_OUTPUT__XGETTEXT SET "${MDBOOK_OUTPUT__XGETTEXT}" "depth" "${MDBOOK_XGETTEXT_DEPTH}")
    string(JSON MDBOOK_OUTPUT           SET "${MDBOOK_OUTPUT}" "xgettext" "${MDBOOK_OUTPUT__XGETTEXT}")
endblock()
block(PROPAGATE MDBOOK_PREPROCESSOR)
    execute_process(
        COMMAND ${Dasel_EXECUTABLE}
                --file book.toml
                --read toml
                --write json
                "preprocessor"
        WORKING_DIRECTORY ${PROJ_OUT_REPO_DOCS_BOOK_DIR}
        RESULT_VARIABLE RES_VAR
        OUTPUT_VARIABLE OUT_VAR OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_VARIABLE  ERR_VAR ERROR_STRIP_TRAILING_WHITESPACE)
    if (RES_VAR EQUAL 0)
        set(MDBOOK_PREPROCESSOR "${OUT_VAR}")
    else()
        set(MDBOOK_PREPROCESSOR "{}")
    endif()
endblock()
set(ENV_MDBOOK_BOOK__SRC            "${MDBOOK_BOOK__SRC}")      # [book.src]
set(ENV_MDBOOK_OUTPUT               "${MDBOOK_OUTPUT}")         # [output]
set(ENV_MDBOOK_PREPROCESSOR         "${MDBOOK_PREPROCESSOR}")   # [preprocessor]
set(ENV_MDBOOK_SUBSTITUTE_SEARCH    "${PROJ_OUT_REPO_BOOK_SRC_DIR}")
set(ENV_VARS_OF_COMMON              MDBOOK_BOOK__SRC=${ENV_MDBOOK_BOOK__SRC}
                                    MDBOOK_OUTPUT=${ENV_MDBOOK_OUTPUT}
                                    MDBOOK_PREPROCESSOR=${ENV_MDBOOK_PREPROCESSOR}
                                    MDBOOK_SUBSTITUTE_SEARCH=${ENV_MDBOOK_SUBSTITUTE_SEARCH})
remove_cmake_message_indent()
message("")
message("ENV_MDBOOK_BOOK__SRC         = ${ENV_MDBOOK_BOOK__SRC}")
message("ENV_MDBOOK_OUTPUT            = ${ENV_MDBOOK_OUTPUT}")
message("ENV_MDBOOK_PREPROCESSOR      = ${ENV_MDBOOK_PREPROCESSOR}")
message("ENV_MDBOOK_SUBSTITUTE_SEARCH = ${ENV_MDBOOK_SUBSTITUTE_SEARCH}")
message("")
message("mdbook build:")
message("  ${PROJ_OUT_REPO_DOCS_BOOK_DIR}")
message("  --dest-dir ${PROJ_OUT_REPO_DOCS_LOCALE_DIR}/pot")
message("  [work-dir] ${PROJ_OUT_REPO_DOCS_DIR}")
message("")
execute_process(
    COMMAND ${CMAKE_COMMAND} -E env
            ${ENV_VARS_OF_SYSTEM}
            ${ENV_VARS_OF_COMMON}
            ${mdBook_EXECUTABLE} build
            ${PROJ_OUT_REPO_DOCS_BOOK_DIR}
            --dest-dir ${PROJ_OUT_REPO_DOCS_LOCALE_DIR}/pot
    WORKING_DIRECTORY ${PROJ_OUT_REPO_DOCS_DIR}
    ECHO_OUTPUT_VARIABLE
    ECHO_ERROR_VARIABLE
    RESULT_VARIABLE RES_VAR
    OUTPUT_VARIABLE OUT_VAR OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_VARIABLE  ERR_VAR ERROR_STRIP_TRAILING_WHITESPACE)
if (RES_VAR EQUAL 0)
else()
    string(CONCAT FAILURE_REASON
    "The command failed with fatal errors.\n"
    "    result:\n${RES_VAR}\n"
    "    stderr:\n${ERR_VAR}")
    message(FATAL_ERROR "${FAILURE_REASON}")
endif()
message("")
restore_cmake_message_indent()


message(STATUS "Running 'msgmerge/msgcat' command to update .pot files...")
set(SRC_POT_DIR "${PROJ_OUT_REPO_DOCS_LOCALE_DIR}/pot")
set(DST_POT_DIR "${PROJ_L10N_VERSION_LOCALE_DIR}/pot")
remove_cmake_message_indent()
message("")
message("From: ${SRC_POT_DIR}/")
message("To:   ${DST_POT_DIR}/")
message("")
update_pot_from_src_to_dst(
    IN_SRC_DIR      "${SRC_POT_DIR}"
    IN_DST_DIR      "${DST_POT_DIR}"
    IN_WRAP_WIDTH   "${GETTEXT_WRAP_WIDTH}")
message("")
restore_cmake_message_indent()


set_json_value_by_dot_notation(
    IN_JSON_OBJECT      "${REFERENCES_JSON_CNT}"
    IN_DOT_NOTATION     ".pot"
    IN_JSON_VALUE       "${LATEST_POT_OBJECT}"
    OUT_JSON_OBJECT     REFERENCES_JSON_CNT)


file(WRITE "${REFERENCES_JSON_PATH}" "${REFERENCES_JSON_CNT}")
