part of libffi_support;

class _Helper {
  static final Map<BinaryKind, _FfiType> binaryKindToFfiType = _createBinaryKindToFfiTypeMap();

  static final Map<FfiPlatform, Map<FfiAbi, int>> platformAbi = _generatePlatformAbi();

  static Map<FfiAbi, int> _buildAbi(List<FfiAbi> conventions, FfiAbi defaultConvention) {
    var map = <FfiAbi, int>{};
    var length = conventions.length;
    for (var i = 0; i < length; i++) {
      var convention = conventions[i];
      map[convention] = i + 1;
    }

    var abi = map[defaultConvention];
    if (abi == null) {
      throw new ArgumentError("Default convention '$defaultConvention' not found in list of conventions.");
    }

    map[FfiAbi.DEFAULT] = abi;
    return new UnmodifiableMapView<FfiAbi, int>(map);
  }

  static void _checkFillingPlatforms(Map<FfiPlatform, dynamic> plarforms) {
    for (var platform in FfiPlatform.values) {
      if (plarforms[platform] == null) {
        throw new StateError("Mising platform '$platform'");
      }
    }
  }

  static Map<BinaryKind, _FfiType> _createBinaryKindToFfiTypeMap() {
    var result = <BinaryKind, _FfiType>{};
    result[BinaryKind.BOOL] = _FfiType.UINT8;
    result[BinaryKind.DOUBLE] = _FfiType.DOUBLE;
    result[BinaryKind.ENUM] = _FfiType.SINT32;
    result[BinaryKind.FLOAT] = _FfiType.FLOAT;
    result[BinaryKind.POINTER] = _FfiType.POINTER;
    result[BinaryKind.SINT16] = _FfiType.SINT16;
    result[BinaryKind.SINT32] = _FfiType.SINT32;
    result[BinaryKind.SINT64] = _FfiType.SINT64;
    result[BinaryKind.SINT8] = _FfiType.SINT8;
    result[BinaryKind.STRUCT] = _FfiType.STRUCT;
    result[BinaryKind.UINT16] = _FfiType.UINT16;
    result[BinaryKind.UINT32] = _FfiType.UINT32;
    result[BinaryKind.UINT64] = _FfiType.UINT64;
    result[BinaryKind.UINT8] = _FfiType.UINT8;
    result[BinaryKind.VOID] = _FfiType.VOID;
    return result;
  }

  static Map<FfiPlatform, Map<FfiAbi, int>> _generatePlatformAbi() {
    var result = <FfiPlatform, Map<FfiAbi, int>>{};
    // X86 windows
    var conventions = <FfiAbi>[];
    conventions.add(FfiAbi.SYSV);
    conventions.add(FfiAbi.STDCALL);
    conventions.add(FfiAbi.THISCALL);
    conventions.add(FfiAbi.FASTCALL);
    conventions.add(FfiAbi.CDECL);
    conventions.add(FfiAbi.PASCAL);
    conventions.add(FfiAbi.REGISTER);
    result[FfiPlatform.X86_WINDOWS] = _buildAbi(conventions, FfiAbi.CDECL);
    // X86_64 windows
    conventions.clear();
    conventions.add(FfiAbi.WIN64);
    result[FfiPlatform.X86_64_WINDOWS] = _buildAbi(conventions, FfiAbi.WIN64);
    // X86 Unix
    conventions.clear();
    conventions.add(FfiAbi.SYSV);
    conventions.add(FfiAbi.UNIX64);
    conventions.add(FfiAbi.THISCALL);
    conventions.add(FfiAbi.FASTCALL);
    conventions.add(FfiAbi.STDCALL);
    conventions.add(FfiAbi.PASCAL);
    conventions.add(FfiAbi.REGISTER);
    result[FfiPlatform.X86_UNIX] = _buildAbi(conventions, FfiAbi.SYSV);
    // X86_64 Unix
    result[FfiPlatform.X86_64_UNIX] = _buildAbi(conventions, FfiAbi.UNIX64);
    // ARM android
    conventions.clear();
    conventions.add(FfiAbi.SYSV);
    conventions.add(FfiAbi.VFP);
    result[FfiPlatform.ARM_ANDROID] = _buildAbi(conventions, FfiAbi.SYSV);
    // ARM Unix
    conventions.clear();
    conventions.add(FfiAbi.SYSV);
    conventions.add(FfiAbi.VFP);
    result[FfiPlatform.ARM_UNIX] = _buildAbi(conventions, FfiAbi.SYSV);

    // Check filling platforms
    _checkFillingPlatforms(result);
    return new UnmodifiableMapView<FfiPlatform, Map<FfiAbi, int>>(result);
  }
}
