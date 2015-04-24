part of libffi_support;

class ForeignClosure {
  final FfiAbi callingConvention;

  final FunctionType functionType;

  final FfiPlatform platform;

  final DataModel systemDataModel;

  Function _action;

  bool _binary;

  Function _callback;

  int _executable;

  int _ffiAbi;

  _FfiTypes _ffiTypes;

  LibffiLibrary _library;

  bool _running = false;

  BinaryData _userData;

  int _writable;

  ForeignClosure(FunctionType functionType, FfiAbi callingConvention, FfiPlatform platform, DataModel systemDataModel,
      dynamic callback(List arguments))
      : this._internal(functionType, callingConvention, platform, systemDataModel, callback, false);

  ForeignClosure.binary(FunctionType functionType, FfiAbi callingConvention, FfiPlatform platform,
      DataModel systemDataModel, void callback(List<BinaryData> arguments, BinaryData returns))
      : this._internal(functionType, callingConvention, platform, systemDataModel, callback, true);

  ForeignClosure._internal(
      this.functionType, this.callingConvention, this.platform, this.systemDataModel, this._callback, this._binary) {
    if (functionType == null) {
      throw new ArgumentError.notNull("function");
    }

    if (callingConvention == null) {
      throw new ArgumentError.notNull("callingConvention");
    }

    if (platform == null) {
      throw new ArgumentError.notNull("platform");
    }

    if (systemDataModel == null) {
      throw new ArgumentError.notNull("systemDataModel");
    }

    if (_callback == null) {
      throw new ArgumentError.notNull("_callback");
    }

    if (_binary == null) {
      throw new ArgumentError.notNull("_binary");
    }

    if (functionType.variadic) {
      throw new ArgumentError("Variadic functions not supported");
    }

    if (LibffiLibrary.current == null) {
      throw new StateError("To work 'foreign closure' requires dynamic library 'libffi'");
    }

    _ffiAbi = _Helper.platformAbi[platform][callingConvention];
    if (_ffiAbi == null) {
      throw new UnsupportedError("Unsupported calling convention: $callingConvention");
    }

    _ffiTypes = new _FfiTypes(systemDataModel);
    _library = LibffiLibrary.current;
    _build();
  }

  int get address {
    return _executable;
  }

  BinaryData get functionCode {
    return functionType.extern(_executable);
  }

  void _build() {
    var cif = new _CifContext(functionType, _ffiTypes, _ffiAbi, _library);
    var code = <int>[null];
    _writable = _library.ffiClosureAlloc(_ffiTypes.ffi_closure.size, code);
    _executable = code[0];
    _action = (int args, int ret) => _handler(args, ret);
    var handle = Unsafe.memoryPeer(_action, 0, 0);
    _userData = _ffiTypes["uintptr_t"].alloc(handle);
    int status;
    try {
      var closureHandler = _library.closureHandler;
      status = _library.ffiPrepClosureLoc(_writable, cif.cif.address, closureHandler, _userData.address, _executable);
      _library.registerClosure(this, _writable);
      switch (status) {
        case _FfiStatus.OK:
          break;
        case _FfiStatus.BAD_ABI:
          throw new StateError("Error preparing closure: Bad calling convention");
        case _FfiStatus.BAD_TYPEDEF:
          throw new StateError("Error preparing closure: Bad typedef");
        default:
          throw new StateError("Unknown ffi_status: $status");
      }
    } finally {
      if (status != _FfiStatus.OK) {
        _library.ffiClosureFree(_writable);
      }
    }
  }

  void _handler(int args, int ret) {
    if (_running) {
      throw new StateError("Recursive calls does not supported");
    }

    _running = true;
    var address = args;
    var sizeOfPointer = functionType.returnType.dataModel.sizeOfPointer;
    var arity = functionType.arity;
    var parameters = functionType.parameters;
    var arguments = new List(arity);
    for (var i = 0, offset = 0; i < arity; i++, offset += sizeOfPointer) {
      var type = parameters[i];
      var data = type.extern(address, offset);
      if (_binary) {
        arguments[i] = data;
      } else {
        arguments[i] = data.value;
      }
    }

    var type = functionType.returnType;
    if (_binary) {
      arguments = new UnmodifiableListView<BinaryData>(arguments);
      _callback(arguments, type.extern(ret));
    } else {
      var result = _callback(arguments);
      if (type.kind != BinaryKind.VOID) {
        var data = type.extern(ret);
        data.value = result;
      }
    }

    _running = false;
  }
}
