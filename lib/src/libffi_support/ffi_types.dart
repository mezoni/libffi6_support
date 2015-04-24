part of libffi_support;

class _FfiTypes extends BinaryTypes {
  static Map<DataModel, BinaryTypes> _ffiTypesForModels = <DataModel, BinaryTypes>{};

  static const Map<String, String> _headers = const <String, String>{"ffi.h": _ffi_header};

  factory _FfiTypes(DataModel dataModel) {
    var types = _ffiTypesForModels[dataModel];
    if (types != null) {
      return types;
    }

    types = new _FfiTypes._internal(dataModel);
    _ffiTypesForModels[dataModel] = types;
    return types;
  }

  static const String _ffi_header = '''
#include <stddef.h>;
#include <stdint.h>;

typedef int ffi_abi;

typedef struct _ffi_type {
  size_t size;
  unsigned short alignment;
  unsigned short type;
  struct _ffi_type **elements;
} ffi_type;

#if __ARCH == ARM
#define FFI_EXTRA_CIF_FIELDS_ARM
#elif __ARCH == MIPS
#define FFI_EXTRA_CIF_FIELDS_MIPS
#endif

typedef struct {
  ffi_abi abi;
  unsigned int nargs;
  ffi_type **arg_types;
  ffi_type *rtype;
  unsigned int bytes;
  unsigned int flags;
#if defined(FFI_EXTRA_CIF_FIELDS_MIPS)
  unsigned int rstruct_flag;
#elif defined(FFI_EXTRA_CIF_FIELDS_ARM)
  int vfp_used;
  unsigned short vfp_reg_free;
  unsigned short vfp_nargs;
  signed char vfp_args[16];
#endif
} ffi_cif;

#if __ARCH == X86
#if __OS == macos
#define FFI_TRAMPOLINE_SIZE 24
#elif __OS == windows
#define FFI_TRAMPOLINE_SIZE 52
#else
#define FFI_TRAMPOLINE_SIZE 10
#endif

#elif __ARCH == X86_64
#if __OS == macos
#define FFI_TRAMPOLINE_SIZE 24
#elif __OS == windows
#define FFI_TRAMPOLINE_SIZE 29
#else
#define FFI_TRAMPOLINE_SIZE 10
#endif

#elif __ARCH == ARM
#define FFI_TRAMPOLINE_SIZE 20

#elif __ARCH == AARCH64
#define FFI_TRAMPOLINE_SIZE 36

#else
#error Unsupported architecture
#endif

typedef struct {
  char tramp[FFI_TRAMPOLINE_SIZE];
  ffi_cif *cif;
  void (*fun)(ffi_cif*, void*, void**, void*);
  void *user_data;
} ffi_closure __attribute__((aligned(8)));
''';

  BinaryType _ffi_cif;

  BinaryType _ffi_closure;

  BinaryType _ffi_type;

  BinaryType _ffi_ptype;

  _FfiTypes._internal(DataModel dataModel) : super(dataModel: dataModel) {
    var environment = <String, String>{};
    var helper = new BinaryTypeHelper(this);
    var architecture = SysInfo.processors.first.architecture;
    switch (architecture) {
      case ProcessorArchitecture.X86:
      case ProcessorArchitecture.X86_64:
      case ProcessorArchitecture.MIPS:
      case ProcessorArchitecture.ARM:
        //case ProcessorArchitecture.ARM64:
        break;
      default:
        throw new UnsupportedError("Unsupported processor architecture: $architecture");
    }

    helper.addHeaders(LIBC_HEADERS);
    helper.addHeaders(_headers);
    helper.declare("ffi.h", environment: environment);
  }

  BinaryType get ffi_cif {
    if (_ffi_cif == null) {
      _ffi_cif = this["ffi_cif"];
    }

    return _ffi_cif;
  }

  BinaryType get ffi_closure {
    if (_ffi_closure == null) {
      _ffi_closure = this["ffi_closure"];
    }

    return _ffi_closure;
  }

  BinaryType get ffi_ptype {
    if (_ffi_ptype == null) {
      _ffi_ptype = this["ffi_type*"];
    }

    return _ffi_ptype;
  }

  BinaryType get ffi_type {
    if (_ffi_type == null) {
      _ffi_type = this["ffi_type"];
    }

    return _ffi_type;
  }
}
