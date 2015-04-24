part of libffi_support;

enum FfiAbi { CDECL, DEFAULT, FASTCALL, PASCAL, REGISTER, STDCALL, SYSV, THISCALL, UNIX64, VFP, WIN64 }

enum FfiPlatform { ARM_ANDROID, ARM_UNIX, X86_64_UNIX, X86_64_WINDOWS, X86_UNIX, X86_WINDOWS }

class _FfiStatus {
  static const int OK = 0;

  static const int BAD_TYPEDEF = 1;

  static const int BAD_ABI = 2;
}

enum _FfiType {
  VOID,
  INT,
  FLOAT,
  DOUBLE,
  LONGDOUBLE,
  UINT8,
  SINT8,
  UINT16,
  SINT16,
  UINT32,
  SINT32,
  UINT64,
  SINT64,
  STRUCT,
  POINTER,
  COMPLEX
}
