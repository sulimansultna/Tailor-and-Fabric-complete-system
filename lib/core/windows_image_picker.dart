import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

final class _OpenFileNameW extends Struct {
  @Uint32()
  external int lStructSize;

  @IntPtr()
  external int hwndOwner;

  @IntPtr()
  external int hInstance;

  external Pointer<Uint16> lpstrFilter;
  external Pointer<Uint16> lpstrCustomFilter;

  @Uint32()
  external int nMaxCustFilter;

  @Uint32()
  external int nFilterIndex;

  external Pointer<Uint16> lpstrFile;

  @Uint32()
  external int nMaxFile;

  external Pointer<Uint16> lpstrFileTitle;

  @Uint32()
  external int nMaxFileTitle;

  external Pointer<Uint16> lpstrInitialDir;
  external Pointer<Uint16> lpstrTitle;

  @Uint32()
  external int flags;

  @Uint16()
  external int nFileOffset;

  @Uint16()
  external int nFileExtension;

  external Pointer<Uint16> lpstrDefExt;

  @IntPtr()
  external int lCustData;

  external Pointer<Void> lpfnHook;
  external Pointer<Uint16> lpTemplateName;
  external Pointer<Void> pvReserved;

  @Uint32()
  external int dwReserved;

  @Uint32()
  external int flagsEx;
}

typedef _GetOpenFileNameNative = Int32 Function(Pointer<_OpenFileNameW>);
typedef _GetOpenFileNameDart = int Function(Pointer<_OpenFileNameW>);

String? saveRecoveryCodePath() {
  if (!Platform.isWindows) {
    throw UnsupportedError('The recovery code picker is available on Windows.');
  }
  const bufferLength = 32768;
  final fileBuffer = calloc<Uint16>(bufferLength);
  final filterParts = ['Text files', '*.txt', ''];
  final filterBuffer = calloc<Uint16>(
    filterParts.fold<int>(1, (n, s) => n + s.length + 1),
  );
  final units = filterParts.expand((s) => [...s.codeUnits, 0]).toList();
  for (var i = 0; i < units.length; i++) {
    filterBuffer[i] = units[i];
  }
  final title = 'Save recovery code'.toNativeUtf16();
  final ext = 'txt'.toNativeUtf16();
  final dialog = calloc<_OpenFileNameW>();
  try {
    dialog.ref
      ..lStructSize = sizeOf<_OpenFileNameW>()
      ..hwndOwner = 0
      ..hInstance = 0
      ..lpstrFilter = filterBuffer
      ..lpstrCustomFilter = nullptr
      ..nMaxCustFilter = 0
      ..nFilterIndex = 1
      ..lpstrFile = fileBuffer
      ..nMaxFile = bufferLength
      ..lpstrFileTitle = nullptr
      ..nMaxFileTitle = 0
      ..lpstrInitialDir = nullptr
      ..lpstrTitle = title.cast<Uint16>()
      ..flags = 0x00000002 | 0x00000004 | 0x00080000
      ..nFileOffset = 0
      ..nFileExtension = 0
      ..lpstrDefExt = ext.cast<Uint16>()
      ..lCustData = 0
      ..lpfnHook = nullptr
      ..lpTemplateName = nullptr
      ..pvReserved = nullptr
      ..dwReserved = 0
      ..flagsEx = 0;
    final saveDialog = DynamicLibrary.open('comdlg32.dll')
        .lookupFunction<_GetOpenFileNameNative, _GetOpenFileNameDart>(
          'GetSaveFileNameW',
        );
    if (saveDialog(dialog) == 0) return null;
    return fileBuffer.cast<Utf16>().toDartString();
  } finally {
    calloc.free(dialog);
    calloc.free(ext);
    calloc.free(title);
    calloc.free(filterBuffer);
    calloc.free(fileBuffer);
  }
}

/// Opens the native Windows file dialog for selecting a shop logo.
String? pickShopLogoPath() {
  if (!Platform.isWindows) {
    throw UnsupportedError('The shop logo picker is available on Windows.');
  }

  const bufferLength = 32768;
  final fileBuffer = calloc<Uint16>(bufferLength);
  final filterValues = [
    'Logo images',
    '*.png;*.jpg;*.jpeg;*.webp',
    'PNG images',
    '*.png',
    'JPEG images',
    '*.jpg;*.jpeg',
    'WebP images',
    '*.webp',
    '',
  ];
  final filterLength = filterValues.fold<int>(
    1,
    (size, part) => size + part.length + 1,
  );
  final filterBuffer = calloc<Uint16>(filterLength);
  final filterUnits = filterValues
      .expand((part) => [...part.codeUnits, 0])
      .toList();
  for (var index = 0; index < filterUnits.length; index++) {
    filterBuffer[index] = filterUnits[index];
  }

  final dialog = calloc<_OpenFileNameW>();
  try {
    dialog.ref
      ..lStructSize = sizeOf<_OpenFileNameW>()
      ..hwndOwner = 0
      ..hInstance = 0
      ..lpstrFilter = filterBuffer
      ..lpstrCustomFilter = nullptr
      ..nMaxCustFilter = 0
      ..nFilterIndex = 1
      ..lpstrFile = fileBuffer
      ..nMaxFile = bufferLength
      ..lpstrFileTitle = nullptr
      ..nMaxFileTitle = 0
      ..lpstrInitialDir = nullptr
      ..lpstrTitle = nullptr
      ..flags = 0x00000008 | 0x00001000 | 0x00000800 | 0x00080000
      ..nFileOffset = 0
      ..nFileExtension = 0
      ..lpstrDefExt = nullptr
      ..lCustData = 0
      ..lpfnHook = nullptr
      ..lpTemplateName = nullptr
      ..pvReserved = nullptr
      ..dwReserved = 0
      ..flagsEx = 0;

    final showDialog = DynamicLibrary.open('comdlg32.dll')
        .lookupFunction<_GetOpenFileNameNative, _GetOpenFileNameDart>(
          'GetOpenFileNameW',
        );
    if (showDialog(dialog) == 0) return null;
    return fileBuffer.cast<Utf16>().toDartString();
  } finally {
    calloc.free(dialog);
    calloc.free(filterBuffer);
    calloc.free(fileBuffer);
  }
}

String? pickBackupFilePath() {
  if (!Platform.isWindows) {
    throw UnsupportedError('The backup picker is available on Windows.');
  }
  const bufferLength = 32768;
  final fileBuffer = calloc<Uint16>(bufferLength);
  final filter = [
    'Tailor Shop backups',
    '*.zip',
    'ZIP archives',
    '*.zip',
    '',
    '',
  ];
  final units = filter.expand((part) => [...part.codeUnits, 0]).toList();
  final filterBuffer = calloc<Uint16>(units.length);
  for (var i = 0; i < units.length; i++) {
    filterBuffer[i] = units[i];
  }
  final title = 'Select a backup archive'.toNativeUtf16();
  final dialog = calloc<_OpenFileNameW>();
  try {
    dialog.ref
      ..lStructSize = sizeOf<_OpenFileNameW>()
      ..hwndOwner = 0
      ..hInstance = 0
      ..lpstrFilter = filterBuffer
      ..lpstrCustomFilter = nullptr
      ..nMaxCustFilter = 0
      ..nFilterIndex = 1
      ..lpstrFile = fileBuffer
      ..nMaxFile = bufferLength
      ..lpstrFileTitle = nullptr
      ..nMaxFileTitle = 0
      ..lpstrInitialDir = nullptr
      ..lpstrTitle = title.cast<Uint16>()
      ..flags = 0x00000008 | 0x00001000 | 0x00000800 | 0x00080000
      ..nFileOffset = 0
      ..nFileExtension = 0
      ..lpstrDefExt = nullptr
      ..lCustData = 0
      ..lpfnHook = nullptr
      ..lpTemplateName = nullptr
      ..pvReserved = nullptr
      ..dwReserved = 0
      ..flagsEx = 0;
    final show = DynamicLibrary.open('comdlg32.dll')
        .lookupFunction<_GetOpenFileNameNative, _GetOpenFileNameDart>(
          'GetOpenFileNameW',
        );
    if (show(dialog) == 0) {
      return null;
    }
    return fileBuffer.cast<Utf16>().toDartString();
  } finally {
    calloc.free(dialog);
    calloc.free(title);
    calloc.free(filterBuffer);
    calloc.free(fileBuffer);
  }
}

/// Opens the native Windows folder picker. Returns null when the user cancels.
String? pickBackupFolderPath() {
  if (!Platform.isWindows) {
    throw UnsupportedError('The folder picker is available on Windows.');
  }
  final shell = DynamicLibrary.open('shell32.dll');
  final ole = DynamicLibrary.open('ole32.dll');
  final title = 'Choose backup folder'.toNativeUtf16();
  final display = calloc<Uint16>(32768);
  final info = calloc<_BrowseInfoW>();
  try {
    info.ref
      ..owner = 0
      ..root = nullptr
      ..displayName = display
      ..title = title.cast<Uint16>()
      ..flags = 0x00000001 | 0x00000040 | 0x00000010
      ..callback = nullptr
      ..parameter = 0
      ..image = 0;
    final browse = shell.lookupFunction<_BrowseNative, _BrowseDart>(
      'SHBrowseForFolderW',
    );
    final getPath = shell.lookupFunction<_GetPathNative, _GetPathDart>(
      'SHGetPathFromIDListW',
    );
    final free = ole.lookupFunction<_CoTaskFreeNative, _CoTaskFreeDart>(
      'CoTaskMemFree',
    );
    final item = browse(info);
    if (item == nullptr) return null;
    try {
      final path = calloc<Uint16>(32768);
      try {
        if (getPath(item, path) == 0) return null;
        return path.cast<Utf16>().toDartString();
      } finally {
        calloc.free(path);
      }
    } finally {
      free(item.cast());
    }
  } finally {
    calloc.free(info);
    calloc.free(display);
    calloc.free(title);
  }
}

final class _BrowseInfoW extends Struct {
  @IntPtr()
  external int owner;
  external Pointer<Void> root;
  external Pointer<Uint16> displayName;
  external Pointer<Uint16> title;
  @Uint32()
  external int flags;
  external Pointer<Void> callback;
  @IntPtr()
  external int parameter;
  @Int32()
  external int image;
}

typedef _BrowseNative = Pointer<Void> Function(Pointer<_BrowseInfoW>);
typedef _BrowseDart = Pointer<Void> Function(Pointer<_BrowseInfoW>);
typedef _GetPathNative = Int32 Function(Pointer<Void>, Pointer<Uint16>);
typedef _GetPathDart = int Function(Pointer<Void>, Pointer<Uint16>);
typedef _CoTaskFreeNative = Void Function(Pointer<Void>);
typedef _CoTaskFreeDart = void Function(Pointer<Void>);
