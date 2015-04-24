part of libffi_support;

class ForeignFunction {
  static Map<DataModel, BinaryTypes> _ffiTypesForModels = <DataModel, BinaryTypes>{};

  final int address;

  final FfiAbi callingConvention;

  final FunctionType functionType;

  final FfiPlatform platform;

  final DataModel systemDataModel;

  int _arity;

  _CifContext _context;

  int _ffiAbi;

  _FfiTypes _ffiTypes;

  LibffiLibrary _library;

  int _recursion;

  BinaryType _returnType;

  bool _variadic;

  _Values _values;

  ForeignFunction(this.address, this.functionType, this.callingConvention, this.platform, this.systemDataModel) {
    if (address == null || address == 0) {
      throw new ArgumentError("address: $address");
    }

    if (functionType == null) {
      throw new ArgumentError.notNull("functionType");
    }

    if (platform == null) {
      throw new ArgumentError.notNull("platform");
    }

    if (callingConvention == null) {
      throw new ArgumentError.notNull("callingConvention");
    }

    if (systemDataModel == null) {
      throw new ArgumentError.notNull("systemDataModel");
    }

    if (LibffiLibrary.current == null) {
      throw new StateError("To work 'foreign function' requires dynamic library 'libffi'");
    }

    _ffiAbi = _Helper.platformAbi[platform][callingConvention];
    if (_ffiAbi == null) {
      throw new UnsupportedError("Unsupported calling convention: $callingConvention");
    }

    _arity = functionType.arity;
    _ffiTypes = new _FfiTypes(systemDataModel);
    _library = LibffiLibrary.current;
    _recursion = 0;
    _returnType = functionType.returnType;
    _variadic = functionType.variadic;
    _initialize();
  }

  dynamic invoke(List<dynamic> arguments, [List<BinaryType> vartypes]) {
    if (arguments == null) {
      arguments = const [];
    }

    if (vartypes == null) {
      vartypes = const <BinaryType>[];
    }

    var variableLength = vartypes.length;
    var totalLength = arguments.length;
    var fixedLength = totalLength - variableLength;
    if (fixedLength != _arity) {
      throw new ArgumentError("Wrong number of fixed arguments.");
    }

    var context = _context;
    var values = _values;
    if (_recursion++ != 0 || _variadic) {
      values = new _Values(functionType, _ffiTypes, vartypes);
      if (_variadic) {
        context = _buildContext(_context, vartypes);
      }
    }

    var data = values.data;
    var objects = values.objects;
    for (var i = 0; i < totalLength; i++) {
      var object = objects[i];
      object.value = arguments[i];
    }

    var returnValue = values.returnValue;
    _library.ffiCall(context.cif.address, address, returnValue.address, data.address);
    _recursion--;
    if (_returnType.size == 0) {
      return null;
    }

    return returnValue.value;
  }

  _CifContext _buildContext(_CifContext previous, List<BinaryType> vartypes) {
    return new _CifContext(functionType, _ffiTypes, _ffiAbi, _library, previous: previous, vartypes: vartypes);
  }

  void _initialize() {
    _context = _buildContext(null, null);
    if (!_variadic) {
      _values = new _Values(functionType, _ffiTypes);
    }
  }
}

class _Values {
  BinaryObject data;

  List<BinaryObject> objects;

  BinaryObject returnValue;

  _Values(FunctionType functionType, BinaryTypes systemTypes, [List<BinaryType> vartypes]) {
    if (functionType == null) {
      throw new ArgumentError.notNull("functionType");
    }

    if (systemTypes == null) {
      throw new ArgumentError.notNull("systemTypes");
    }

    if (vartypes == null) {
      vartypes = const <BinaryType>[];
    }

    var fixedParameters = functionType.parameters;
    var fixedLength = functionType.arity;
    var variableLength = vartypes.length;
    var totalLength = fixedLength + variableLength;
    if (totalLength != 0) {
      data = systemTypes["void*"].array(totalLength).alloc();
    } else {
      data = systemTypes["void*"].nullPtr;
    }

    objects = new List<BinaryObject>(totalLength);
    for (var i = 0; i < fixedLength; i++) {
      var object = fixedParameters[i].alloc();
      objects[i] = object;
      data[i].value = object;
    }

    for (var i = 0, k = fixedLength; i < variableLength; i++, k++) {
      var object = vartypes[i].alloc();
      objects[k] = object;
      data[k].value = object;
    }

    var returnType = functionType.returnType;
    if (returnType.size != 0) {
      returnValue = functionType.returnType.alloc();
    } else {
      returnValue = functionType.returnType.nullPtr;
    }
  }
}
