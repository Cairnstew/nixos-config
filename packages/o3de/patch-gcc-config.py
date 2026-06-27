import sys

path = sys.argv[1] if len(sys.argv) > 1 else 'cmake/Platform/Common/GCC/Configurations_gcc.cmake'
content = open(path).read()

# Add -Wno-nonnull and -Wno-unused-variable to suppression list
content = content.replace('-Wno-unused-result', '-Wno-unused-result -Wno-nonnull -Wno-unused-variable -Wno-maybe-uninitialized -Wno-dangling-pointer -Wno-cast-function-type -Wno-volatile -Wno-invalid-offsetof')

# Remove PRIVATE from DISABLE_FAST_MATH (it leaks into CMAKE_CXX_FLAGS)
content = content.replace(
    'set(O3DE_COMPILE_OPTION_DISABLE_FAST_MATH PRIVATE -fno-fast-math)',
    'set(O3DE_COMPILE_OPTION_DISABLE_FAST_MATH -fno-fast-math)')
content = content.replace(
    'set(O3DE_TARGET_COMPILE_OPTION_DISABLE_FAST_MATH PRIVATE ${O3DE_COMPILE_OPTION_DISABLE_FAST_MATH})',
    'set(O3DE_TARGET_COMPILE_OPTION_DISABLE_FAST_MATH ${O3DE_COMPILE_OPTION_DISABLE_FAST_MATH})')

open(path, 'w').write(content)
print('Patched GCC config')
