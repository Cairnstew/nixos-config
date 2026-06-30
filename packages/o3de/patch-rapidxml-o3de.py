"""Patch nixpkgs rapidxml headers for O3DE compatibility.

1. Replaces the NO_EXCEPTIONS RAPIDXML_PARSE_ERROR macro to store
   errors on document (no return — parse_node has its own return 0;).
2. Adds isError()/getError()/clearError()/try_parse() to xml_document.
3. Adds forward declarations to rapidxml_print.hpp for GCC 15+.
"""
import sys, os

rapidxml_dir = sys.argv[1]

hpp_path = os.path.join(rapidxml_dir, 'rapidxml.hpp')
with open(hpp_path) as f:
    content = f.read()

old_noex_block = """\
#if defined(RAPIDXML_NO_EXCEPTIONS)

#define RAPIDXML_PARSE_ERROR(what, where) { parse_error_handler(what, where); assert(0); }

namespace rapidxml
{
    //! When exceptions are disabled by defining RAPIDXML_NO_EXCEPTIONS, 
    //! this function is called to notify user about the error.
    //! It must be defined by the user.
    //! <br><br>
    //! This function cannot return. If it does, the results are undefined.
    //! <br><br>
    //! A very simple definition might look like that:
    //! <pre>
    //! void %rapidxml::%parse_error_handler(const char *what, void *where)
    //! {
    //!     std::cout << "Parse error: " << what << "\\n";
    //!     std::abort();
    //! }
    //! </pre>
    //! \\param what Human readable description of the error.
    //! \\param where Pointer to character data where error was detected.
    void parse_error_handler(const char *what, void *where);
}"""

new_noex_block = """\
#if defined(RAPIDXML_NO_EXCEPTIONS)

// Nixpkgs patch: O3DE-compatible error handling using a global error
// store (works from both static and non-static member functions).
struct _o3de_parse_error
{
    bool occurred = false;
    const char* msg = nullptr;
    void* ptr = nullptr;
};
static _o3de_parse_error _o3de_err;

#define RAPIDXML_PARSE_ERROR(what, where) \\
    do { \\
        _o3de_err.occurred = true; \\
        _o3de_err.msg = (what); \\
        _o3de_err.ptr = static_cast<void*>((where)); \\
    } while(0)

namespace rapidxml
{
    //! Stub: O3DE patch — error handling is via global _o3de_err.
    void parse_error_handler(const char *what, void *where);
}"""

if old_noex_block in content:
    content = content.replace(old_noex_block, new_noex_block)
    print("Replaced RAPIDXML_NO_EXCEPTIONS block")
else:
    print("ERROR: Could not find RAPIDXML_NO_EXCEPTIONS block")
    sys.exit(1)

# Find the xml_document class end: "};" at 4 spaces followed by
# a blank line then "//! \\cond internal" or "} // namespace..."
# From analysis: class ends at line 2300 with "    };"
# followed by "    //! \\cond internal"
class_end_marker = '    };\n\n    //! \\cond internal'
class_end = content.find(class_end_marker)
if class_end < 0:
    # Fallback: find the last "};" at 4-space indent
    lines = content.split('\n')
    for i in range(len(lines) - 1, -1, -1):
        if lines[i].strip() == '};' and lines[i].startswith('    '):
            class_end = len('\n'.join(lines[:i]))
            break

if class_end < 0:
    print("ERROR: Could not find xml_document class end")
    sys.exit(1)

# Find the start of the line containing "    };"
eol_before = content.rfind('\n', 0, class_end)
if eol_before >= 0:
    class_end = eol_before + 1

o3de_members = """\
        // -- O3DE compatibility extensions (added by Nixpkgs patch) --
        #ifdef RAPIDXML_NO_EXCEPTIONS
        public:
            bool isError() const { return _o3de_err.occurred; }
            const char* getError() const { return _o3de_err.msg ? _o3de_err.msg : ""; }
            void clearError() { _o3de_err.occurred = false; _o3de_err.msg = nullptr; _o3de_err.ptr = nullptr; }

            template <int Flags>
            bool try_parse(Ch *text)
            {
                clearError();
                parse<Flags>(text);
                return !_o3de_err.occurred;
            }
        #endif
"""

content = content[:class_end] + o3de_members + content[class_end:]
print(f"Inserted O3DE members at position {class_end}")

with open(hpp_path, 'w') as f:
    f.write(content)

# Patch rapidxml_print.hpp with GCC 15+ forward declarations
print_path = os.path.join(rapidxml_dir, 'rapidxml_print.hpp')
with open(print_path) as f:
    content = f.read()

# Insert forward declarations right after "namespace internal\n    {"
# to ensure they're visible to all template definitions in this namespace.
ns_marker = 'namespace internal\n    {'
ns_pos = content.find(ns_marker)
if ns_pos >= 0:
    # Find the end of the opening line to insert right after {
    after_brace = content.find('\n', ns_pos + len(ns_marker))
    if after_brace >= 0:
        after_brace += 1  # start of next line
    fwd_decls = """\
        // Forward declarations for GCC 15+ two-phase lookup (Nixpkgs O3DE patch)
        template<class OutIt, class Ch> OutIt print_children(OutIt, const xml_node<Ch>*, int, int);
        template<class OutIt, class Ch> OutIt print_element_node(OutIt, const xml_node<Ch>*, int, int);
        template<class OutIt, class Ch> OutIt print_data_node(OutIt, const xml_node<Ch>*, int, int);
        template<class OutIt, class Ch> OutIt print_cdata_node(OutIt, const xml_node<Ch>*, int, int);
        template<class OutIt, class Ch> OutIt print_declaration_node(OutIt, const xml_node<Ch>*, int, int);
        template<class OutIt, class Ch> OutIt print_comment_node(OutIt, const xml_node<Ch>*, int, int);
        template<class OutIt, class Ch> OutIt print_doctype_node(OutIt, const xml_node<Ch>*, int, int);
        template<class OutIt, class Ch> OutIt print_pi_node(OutIt, const xml_node<Ch>*, int, int);

"""
    content = content[:after_brace] + fwd_decls + content[after_brace:]
    print("Inserted forward declarations after namespace internal {")
else:
    print("ERROR: Could not find 'namespace internal' in rapidxml_print.hpp")
    sys.exit(1)

with open(print_path, 'w') as f:
    f.write(content)
