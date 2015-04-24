part of libffi_support;

class _CifContext {
  static final Map<_FfiType, Map<int, BinaryObject>> _ffiTypeToBinaryObject = new Map<_FfiType, Map<int, BinaryObject>>();

  BinaryObject atypes;

  BinaryObject cif;

  List<BinaryObject> fixedTypeObjects;

  List<BinaryObject> fixedTypes;

  BinaryObject rtype;

  List<BinaryObject> types;

  List<BinaryObject> variableTypes;

  List<BinaryObject> variableTypeObjects;

  _FfiTypes _ffiTypes;

  _CifContext(FunctionType functionType, _FfiTypes ffiTypes, int ffiAbi, LibffiLibrary library,
      {_CifContext previous, List<BinaryType> vartypes}) {
    if (functionType == null) {
      throw new ArgumentError.notNull("functionType");
    }

    if (ffiTypes == null) {
      throw new ArgumentError.notNull("ffiTypes");
    }

    if (ffiAbi == null) {
      throw new ArgumentError.notNull("ffiAbi");
    }

    if (library == null) {
      throw new ArgumentError.notNull("library");
    }

    _ffiTypes = ffiTypes;
    if (vartypes == null) {
      vartypes = const <BinaryType>[];
    }

    var arity = functionType.arity;
    var returnType = functionType.returnType;
    var variableLength = vartypes.length;
    var totalLength = arity + variableLength;
    if (previous == null) {
      var fixedTypeObjects = <BinaryObject>[];
      var fixedTypes = <BinaryObject>[];
      var parameters = functionType.parameters;
      for (var i = 0; i < arity; i++) {
        var parameter = parameters[i];
        var data = _getFfiTypeForBinaryType(parameter, parameter.align, fixedTypeObjects);
        fixedTypes.add(data);
      }

      var returnTypeAlign = 1;
      if (returnType is! VoidType) {
        returnTypeAlign = returnType.align;
      }

      rtype = _getFfiTypeForBinaryType(returnType, returnTypeAlign, fixedTypeObjects);
      this.fixedTypeObjects = fixedTypeObjects;
      this.fixedTypes = fixedTypes;
    } else {
      this.fixedTypeObjects = previous.fixedTypeObjects;
      this.fixedTypes = previous.fixedTypes;
      rtype = previous.rtype;
    }

    if (variableLength != 0) {
      var variableTypeObjects = <BinaryObject>[];
      var variableTypes = <BinaryObject>[];
      for (var i = 0; i < variableLength; i++) {
        var parameter = vartypes[i];
        var ffiType = _getFfiTypeForBinaryType(parameter, parameter.align, variableTypeObjects);
        variableTypes.add(ffiType);
      }

      this.variableTypeObjects = variableTypeObjects;
      this.variableTypes = variableTypes;
    } else {
      this.variableTypeObjects = const <BinaryObject>[];
      this.variableTypes = const <BinaryObject>[];
    }

    cif = ffiTypes.ffi_cif.alloc({});
    if (totalLength != 0) {
      atypes = ffiTypes["void*"].array(totalLength).alloc();
    } else {
      atypes = ffiTypes["void*"].nullPtr;
    }

    var currentTypes = fixedTypes;
    for (var i = 0; i < arity; i++) {
      atypes[i].value = currentTypes[i];
    }

    currentTypes = variableTypes;
    for (var i = 0; i < variableLength; i++) {
      atypes[arity + i].value = currentTypes[i];
    }

    int status;
    if (!functionType.variadic) {
      status = library.ffiPrepCif(cif.address, ffiAbi, totalLength, rtype.address, atypes.address);
    } else {
      status = library.ffiPrepCifVar(cif.address, ffiAbi, arity, totalLength, rtype.address, atypes.address);
    }

    switch (status) {
      case _FfiStatus.OK:
        break;
      case _FfiStatus.BAD_ABI:
        throw new StateError("Error preparing calling interface: Bad calling convention");
      case _FfiStatus.BAD_TYPEDEF:
        throw new StateError("Error preparing calling interface: Bad typedef");
      default:
        throw new StateError("Unknown ffi_status: $status");
    }
  }

  BinaryObject _allocFfiType(_FfiType type, BinaryType binaryType, int align, List<BinaryObject> objects) {
    var data = _ffiTypes.ffi_type.alloc(const {});
    if (binaryType.kind == BinaryKind.VOID) {
      data["alignment"].value = 1;
      data["size"].value = 1;
    } else {
      var size = binaryType.size;
      if (size == 0) {
        throw new ArgumentError("Unable allocate incomplete type '$binaryType'");
      }

      data["alignment"].value = align;
      data["size"].value = size;
    }

    var definedFfiType = type.index;
    if (definedFfiType == null) {
      _errorUnsupportedBinaryType(binaryType);
    }

    data["type"].value = definedFfiType;
    switch (type) {
      case _FfiType.STRUCT:
        if (binaryType is StructType) {
          return _allocFfiTypeStruct(data, binaryType, objects);
        } else if (binaryType is UnionType) {
          return _allocFfiTypeUnion(data, binaryType, objects);
        } else {
          throw new UnsupportedError("Unsupported type '$binaryType'");
        }

        break;
      case _FfiType.COMPLEX:
        _errorUnsupportedBinaryType(binaryType);
        break;
      default:
        break;
    }

    if (objects != null) {
      objects.add(data);
    }

    return data;
  }

  BinaryObject _allocFfiTypeStruct(BinaryObject data, StructType binaryType, List<BinaryObject> objects) {
    if (objects == null) {
      throw new ArgumentError.notNull("objects");
    }

    var storageUnits = binaryType.storageUnits.elements;
    var length = storageUnits.length;
    var elements = _ffiTypes.ffi_ptype.array(length + 1).alloc(const []);
    for (var i = 0; i < length; i++) {
      var storageUnit = storageUnits[i];
      var data = _getFfiTypeForBinaryType(storageUnit.type, storageUnit.align, objects);
      elements[i].value = data;
    }

    data["elements"].value = elements;
    objects.add(elements);
    return data;
  }

  BinaryObject _allocFfiTypeUnion(BinaryObject data, UnionType binaryType, List<BinaryObject> objects) {
    var storageUnits = binaryType.storageUnits.elements;
    StorageUnit storageUnit;
    for (var element in storageUnits) {
      if (storageUnit.size < element.size) {
        storageUnit = element;
      }
    }

    var elements = _ffiTypes.ffi_ptype.array(2).alloc(const []);
    elements[0].value = _getFfiTypeForBinaryType(storageUnit.type, storageUnit.align, objects);
    data["elements"].value = elements;
    objects.add(elements);
    return data;
  }

  void _errorUnsupportedBinaryType(BinaryType type) {
    throw new UnsupportedError("Unsupported binary type: '$type'");
  }

  BinaryObject _getFfiTypeForBinaryType(BinaryType type, int align, List<BinaryObject> objects) {
    var kind = type.kind;
    var ffiType = _Helper.binaryKindToFfiType[type.kind];
    if (ffiType == null) {
      _errorUnsupportedBinaryType(type);
    }

    var alignments = _ffiTypeToBinaryObject[ffiType];
    if (alignments == null) {
      alignments = <int, BinaryObject>{};
      _ffiTypeToBinaryObject[ffiType] = alignments;
    }

    var object = alignments[align];
    if (object == null) {
      object = _allocFfiType(ffiType, type, align, objects);
      switch (kind) {
        case BinaryKind.STRUCT:
          break;
        default:
          alignments[align] = object;
          break;
      }
    }

    return object;
  }
}
