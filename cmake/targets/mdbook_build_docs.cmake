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
include(JsonUtils)
include(GettextUtils)


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


message(STATUS "Copying .po files to the local repository...")
if (NOT LANGUAGE STREQUAL "all")
    set(PO_SRC_DIR  "${PROJ_L10N_VERSION_LOCALE_DIR}/${LANGUAGE}")
    set(PO_DST_DIR  "${PROJ_OUT_REPO_DOCS_LOCALE_DIR}/${LANGUAGE}")
else()
    set(PO_SRC_DIR  "${PROJ_L10N_VERSION_LOCALE_DIR}")
    set(PO_DST_DIR  "${PROJ_OUT_REPO_DOCS_LOCALE_DIR}")
endif()
remove_cmake_message_indent()
message("")
message("From: ${PO_SRC_DIR}/")
message("To:   ${PO_DST_DIR}/")
message("")
copy_po_from_src_to_dst(
    IN_SRC_DIR  "${PO_SRC_DIR}"
    IN_DST_DIR  "${PO_DST_DIR}")
message("")
restore_cmake_message_indent()


file(READ "${LANGUAGES_JSON_PATH}" LANGUAGES_JSON_CNT)
if (NOT LANGUAGE STREQUAL "all")
    set(LANGUAGE_LIST "${LANGUAGE}")
endif()


foreach(_LANGUAGE ${LANGUAGE_LIST})
    get_json_value_by_dot_notation(
        IN_JSON_OBJECT      "${LANGUAGES_JSON_CNT}"
        IN_DOT_NOTATION     ".${_LANGUAGE}.langtag"
        OUT_JSON_VALUE      _LANGTAG)


    if (NOT _LANGUAGE STREQUAL LANGUAGE_SOURCE)
        # TODO: Remove this workaround once mdbook-i18n-helpers supports multiple .po files.
        #
        # Refer to: https://github.com/google/mdbook-i18n-helpers/issues/185
        #
        # Currently, mdbook-i18n-helpers cannot translate the book with a tree of .po files.
        # Therefore, we need to concatenate all .po files for each language into a single
        # file using msgcat before mdbook can process the translations. Once the issue is
        # resolved, this entire concatenation step can be removed.
        message(STATUS "Running 'msgcat' command to concatenate translations of '${VERSION}' version for '${_LANGUAGE}' language...")
        set(PO_LOCALE_DIR   "${PROJ_OUT_REPO_DOCS_LOCALE_DIR}/${_LANGUAGE}")
        set(PO_SINGLE_FILE  "${PROJ_OUT_REPO_DOCS_LOCALE_DIR}/${_LANGUAGE}.po")
        remove_cmake_message_indent()
        message("")
        concat_po_from_locale_to_single(
            IN_LOCALE_PO_DIR        "${PO_LOCALE_DIR}"
            IN_SINGLE_PO_FILE       "${PO_SINGLE_FILE}"
            IN_WRAP_WIDTH           "${GETTEXT_WRAP_WIDTH}")
        message("")
        restore_cmake_message_indent()
    endif()


    message(STATUS "Running 'mdbook build' command to build documentation for '${_LANGUAGE}' language...")
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
    block(PROPAGATE MDBOOK_BOOK__SRC
                    MDBOOK_BOOK__LANGUAGE)
        set(MDBOOK_BOOK__SRC        "${SRC_TO_BOOK_DIR}")
        set(MDBOOK_BOOK__LANGUAGE   "${_LANGUAGE}")
    endblock()
    block(PROPAGATE MDBOOK_OUTPUT)
        execute_process(
            COMMAND ${Dasel_EXECUTABLE}
                    --file book.toml
                    --read toml
                    --write json
                    "output.${MDBOOK_RENDERER}"
            WORKING_DIRECTORY ${PROJ_OUT_REPO_DOCS_BOOK_DIR}
            RESULT_VARIABLE RES_VAR
            OUTPUT_VARIABLE OUT_VAR OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_VARIABLE  ERR_VAR ERROR_STRIP_TRAILING_WHITESPACE)
        if (RES_VAR EQUAL 0)
            set(MDBOOK_OUTPUT__RENDERER "${OUT_VAR}")
        else()
            set(MDBOOK_OUTPUT__RENDERER "{}")
        endif()
        string(JSON MDBOOK_OUTPUT__RENDERER SET "${MDBOOK_OUTPUT__RENDERER}" "theme" "\"${THEME_TO_BOOK_DIR}\"")
        string(JSON MDBOOK_OUTPUT           SET "{}" "${MDBOOK_RENDERER}" "${MDBOOK_OUTPUT__RENDERER}")
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
        set(MDBOOK_PREPROCESSOR__GETTEXT "{}")
        string(JSON MDBOOK_PREPROCESSOR__GETTEXT SET "${MDBOOK_PREPROCESSOR__GETTEXT}" "after"  "[\"links\"]")
        string(JSON MDBOOK_PREPROCESSOR__GETTEXT SET "${MDBOOK_PREPROCESSOR__GETTEXT}" "po-dir" "\"${LOCALE_TO_BOOK_DIR}\"")
        string(JSON MDBOOK_PREPROCESSOR          SET "${MDBOOK_PREPROCESSOR}" "gettext" "${MDBOOK_PREPROCESSOR__GETTEXT}")
    endblock()
    set(ENV_MDBOOK_BOOK__SRC            "${MDBOOK_BOOK__SRC}")          # [book.src]
    set(ENV_MDBOOK_BOOK__LANGUAGE       "${MDBOOK_BOOK__LANGUAGE}")     # [book.language]
    set(ENV_MDBOOK_OUTPUT               "${MDBOOK_OUTPUT}")             # [output]
    set(ENV_MDBOOK_PREPROCESSOR         "${MDBOOK_PREPROCESSOR}")       # [preprocessor]
    set(ENV_MDBOOK_SUBSTITUTE_SEARCH    "${PROJ_OUT_REPO_BOOK_SRC_DIR}")
    set(ENV_VARS_OF_COMMON              MDBOOK_BOOK__SRC=${ENV_MDBOOK_BOOK__SRC}
                                        MDBOOK_BOOK__LANGUAGE=${ENV_MDBOOK_BOOK__LANGUAGE}
                                        MDBOOK_OUTPUT=${ENV_MDBOOK_OUTPUT}
                                        MDBOOK_PREPROCESSOR=${ENV_MDBOOK_PREPROCESSOR}
                                        MDBOOK_SUBSTITUTE_SEARCH=${ENV_MDBOOK_SUBSTITUTE_SEARCH})
    remove_cmake_message_indent()
    message("")
    message("ENV_MDBOOK_BOOK__SRC         = ${ENV_MDBOOK_BOOK__SRC}")
    message("ENV_MDBOOK_BOOK__LANGUAGE    = ${ENV_MDBOOK_BOOK__LANGUAGE}")
    message("ENV_MDBOOK_OUTPUT            = ${ENV_MDBOOK_OUTPUT}")
    message("ENV_MDBOOK_PREPROCESSOR      = ${ENV_MDBOOK_PREPROCESSOR}")
    message("ENV_MDBOOK_SUBSTITUTE_SEARCH = ${ENV_MDBOOK_SUBSTITUTE_SEARCH}")
    message("")
    message("mdbook build:")
    message("  ${PROJ_OUT_REPO_DOCS_BOOK_DIR}")
    message("  --dest-dir ${PROJ_OUT_RENDERER_DIR}/${_LANGTAG}/${VERSION}")
    message("  [work-dir] ${PROJ_OUT_REPO_DOCS_DIR}")
    message("")
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E env
                ${ENV_VARS_OF_SYSTEM}
                ${ENV_VARS_OF_COMMON}
                ${mdBook_EXECUTABLE} build
                ${PROJ_OUT_REPO_DOCS_BOOK_DIR}
                --dest-dir ${PROJ_OUT_RENDERER_DIR}/${_LANGTAG}/${VERSION}
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
endforeach()
unset(_LANGUAGE)


#[============================================================[
# Configure redirecting index.html files.
#]============================================================]


set(REDIRECT_LANGTAG    "en-us")
set(REDIRECT_VERSION    "master")


message(STATUS "Configuring 'index.html' file to the root of the renderer directory...")
set(REDIRECT_URL        "${REDIRECT_LANGTAG}/${REDIRECT_VERSION}/index.html")
file(MAKE_DIRECTORY     "${PROJ_OUT_RENDERER_DIR}")
configure_file(
    "${PROJ_CMAKE_CUSTOM_DIR}/index.html.in"
    "${PROJ_OUT_RENDERER_DIR}/index.html"
    @ONLY)
remove_cmake_message_indent()
message("")
message("From: ${PROJ_CMAKE_CUSTOM_DIR}/index.html.in")
message("To:   ${PROJ_OUT_RENDERER_DIR}/index.html")
message("")
restore_cmake_message_indent()


message(STATUS "Configuring 'index.html' file to the langtag subdir of the renderer directory...")
remove_cmake_message_indent()
message("")
message("From: ${PROJ_CMAKE_CUSTOM_DIR}/index.html.in")
foreach(_LANGUAGE ${LANGUAGE_LIST})
    get_json_value_by_dot_notation(
        IN_JSON_OBJECT      "${LANGUAGES_JSON_CNT}"
        IN_DOT_NOTATION     ".${_LANGUAGE}.langtag"
        OUT_JSON_VALUE      _LANGTAG)
    set(REDIRECT_URL        "${REDIRECT_VERSION}/index.html")
    file(MAKE_DIRECTORY     "${PROJ_OUT_RENDERER_DIR}/${_LANGTAG}")
    configure_file(
        "${PROJ_CMAKE_CUSTOM_DIR}/index.html.in"
        "${PROJ_OUT_RENDERER_DIR}/${_LANGTAG}/index.html"
        @ONLY)
    message("To:   ${PROJ_OUT_RENDERER_DIR}/${_LANGTAG}/index.html")
endforeach()
unset(_LANGUAGE)
message("")
restore_cmake_message_indent()


#[============================================================[
# Configure the provenance dropdown.
#]============================================================]


set(UPSTREAM_DOCS   "https://nix.dev/manual/nix/latest/")
set(UPSTREAM_REPO   "https://github.com/nixos/nix")
set(INSERT_POINT    "main")


message(STATUS "Configuring 'ltd-provenance.js' file to the version subdir of the renderer directory...")
remove_cmake_message_indent()
message("")
message("From: ${PROJ_CMAKE_PLUGINS_DIR}/provenance/ltd-sphinx.js.in")
foreach(_LANGUAGE ${LANGUAGE_LIST})
    get_json_value_by_dot_notation(
        IN_JSON_OBJECT      "${LANGUAGES_JSON_CNT}"
        IN_DOT_NOTATION     ".${_LANGUAGE}.langtag"
        OUT_JSON_VALUE      _LANGTAG)
    set(CURRENT_VERSION     "${VERSION}")
    set(CURRENT_LANGUAGE    "${_LANGTAG}")
    file(MAKE_DIRECTORY "${PROJ_OUT_RENDERER_DIR}/${_LANGTAG}/${VERSION}")
    configure_file(
        "${PROJ_CMAKE_PLUGINS_DIR}/provenance/ltd-sphinx.js.in"
        "${PROJ_OUT_RENDERER_DIR}/${_LANGTAG}/${VERSION}/ltd-provenance.js"
        @ONLY)
    message("To:   ${PROJ_OUT_RENDERER_DIR}/${_LANGTAG}/${VERSION}/ltd-provenance.js")
endforeach()
message("")
restore_cmake_message_indent()


#[============================================================[
# Configure the flyout navigation menu.
#]============================================================]


message(STATUS "Configuring 'ltd-config.js' file to the root of the renderer directory...")
file(MAKE_DIRECTORY "${PROJ_OUT_RENDERER_DIR}")
configure_file(
    "${PROJ_CMAKE_CUSTOM_DIR}/ltd-config.js"
    "${PROJ_OUT_RENDERER_DIR}/ltd-config.js"
    @ONLY)
remove_cmake_message_indent()
message("")
message("From: ${PROJ_CMAKE_CUSTOM_DIR}/ltd-config.js")
message("To:   ${PROJ_OUT_RENDERER_DIR}/ltd-config.js")
message("")
restore_cmake_message_indent()


message(STATUS "Configuring 'ltd-flyout.js' file to the root of the renderer directory...")
file(MAKE_DIRECTORY "${PROJ_OUT_RENDERER_DIR}")
configure_file(
    "${PROJ_CMAKE_PLUGINS_DIR}/flyout/ltd-flyout.js"
    "${PROJ_OUT_RENDERER_DIR}/ltd-flyout.js"
    @ONLY)
remove_cmake_message_indent()
message("")
message("From: ${PROJ_CMAKE_PLUGINS_DIR}/flyout/ltd-flyout.js")
message("To:   ${PROJ_OUT_RENDERER_DIR}/ltd-flyout.js")
message("")
restore_cmake_message_indent()


message(STATUS "Configuring 'ltd-icon.svg' file to the root of the renderer directory...")
file(MAKE_DIRECTORY "${PROJ_OUT_RENDERER_DIR}")
configure_file(
    "${PROJ_CMAKE_PLUGINS_DIR}/flyout/ltd-icon.svg"
    "${PROJ_OUT_RENDERER_DIR}/ltd-icon.svg"
    @ONLY)
remove_cmake_message_indent()
message("")
message("From: ${PROJ_CMAKE_PLUGINS_DIR}/flyout/ltd-icon.svg")
message("To:   ${PROJ_OUT_RENDERER_DIR}/ltd-icon.svg")
message("")
restore_cmake_message_indent()


message(STATUS "Configuring 'ltd-current.js' file to the version subdir of the renderer directory...")
remove_cmake_message_indent()
message("")
message("From: ${PROJ_CMAKE_PLUGINS_DIR}/flyout/ltd-current.js.in")
foreach(_LANGUAGE ${LANGUAGE_LIST})
    get_json_value_by_dot_notation(
        IN_JSON_OBJECT      "${LANGUAGES_JSON_CNT}"
        IN_DOT_NOTATION     ".${_LANGUAGE}.langtag"
        OUT_JSON_VALUE      _LANGTAG)
    set(CURRENT_VERSION     "${VERSION}")
    set(CURRENT_LANGUAGE    "${_LANGTAG}")
    file(MAKE_DIRECTORY "${PROJ_OUT_RENDERER_DIR}/${_LANGTAG}/${VERSION}")
    configure_file(
        "${PROJ_CMAKE_PLUGINS_DIR}/flyout/ltd-current.js.in"
        "${PROJ_OUT_RENDERER_DIR}/${_LANGTAG}/${VERSION}/ltd-current.js"
        @ONLY)
    message("To:   ${PROJ_OUT_RENDERER_DIR}/${_LANGTAG}/${VERSION}/ltd-current.js")
endforeach()
unset(_LANGUAGE)
message("")
restore_cmake_message_indent()


#[============================================================[
# Display home pages of the built documentation.
#]============================================================]


message(STATUS "The '${MDBOOK_RENDERER}' documentation is built succesfully!")
remove_cmake_message_indent()
message("")
foreach(_LANGUAGE ${LANGUAGE_LIST})
    get_json_value_by_dot_notation(
        IN_JSON_OBJECT      "${LANGUAGES_JSON_CNT}"
        IN_DOT_NOTATION     ".${_LANGUAGE}.langtag"
        OUT_JSON_VALUE      _LANGTAG)
    message("${_LANGUAGE} : ${PROJ_OUT_RENDERER_DIR}/${_LANGTAG}/${VERSION}/index.html")
endforeach()
message("")
restore_cmake_message_indent()
