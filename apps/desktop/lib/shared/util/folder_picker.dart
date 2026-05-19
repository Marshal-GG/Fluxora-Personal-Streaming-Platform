/// Folder-picker shim — Plex-style "save dialog with phantom filename"
/// on Windows so the picker shows files inside folders as read-only
/// context (the standard Windows `IFileOpenDialog` with
/// `FOS_PICKFOLDERS` hides files entirely, which operators read as
/// "the picker is broken").
///
/// On non-Windows platforms (macOS, Linux), this falls back to
/// `file_selector.getDirectoryPath()` which already uses each
/// platform's modern native folder picker.
///
/// **The Win32 trick:**
/// 1. Open `IFileSaveDialog` (the SAVE variant — shows files for
///    context).
/// 2. Pre-fill the filename with `"Select this folder."` and set the
///    OK button label to `"Select Folder"` so the dialog reads as a
///    folder picker, not as a save dialog.
/// 3. Call `IFileDialog::GetFolder()` after the user clicks OK —
///    returns the folder the dialog is currently viewing, regardless
///    of what's typed in the filename box.
///
/// Used by Plex, Sonarr, Radarr, etc. — the closest you can get to
/// "native folder picker with files visible" on Windows.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:win32/win32.dart';

/// Returns the absolute path of the folder the operator selected, or
/// `null` if they cancelled.
Future<String?> pickFolderPath({String? title}) async {
  if (Platform.isWindows) {
    return _pickFolderWindowsSaveDialog(title: title);
  }
  return file_selector.getDirectoryPath(confirmButtonText: 'Select Folder');
}

String? _pickFolderWindowsSaveDialog({String? title}) {
  // COM init is per-thread on Windows.  Apartment-threaded matches
  // what the file_selector_windows plugin uses and is required for
  // the shell COM objects we're about to instantiate.
  final coInitHr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  // S_FALSE (1) is also "success" — means COM was already initialised
  // on this thread.  Only bail on real failure.
  final coInitOk = SUCCEEDED(coInitHr) || coInitHr == S_FALSE;
  if (!coInitOk) return null;

  final dialog = FileSaveDialog.createInstance();
  try {
    // Configure dialog labels so it reads as a folder picker even
    // though it's the SAVE dialog under the hood.
    final titlePtr = (title ?? 'Select Folder').toNativeUtf16();
    final fileNamePtr = 'Select this folder.'.toNativeUtf16();
    final okLabelPtr = 'Select Folder'.toNativeUtf16();
    try {
      dialog.setTitle(titlePtr);
      dialog.setFileName(fileNamePtr);
      dialog.setOkButtonLabel(okLabelPtr);
    } finally {
      free(titlePtr);
      free(fileNamePtr);
      free(okLabelPtr);
    }

    // OR in `FOS_FORCEFILESYSTEM` (skip non-fs items like virtual
    // shell namespaces) + `FOS_PATHMUSTEXIST` (the chosen folder
    // must exist on disk).  Crucially do NOT set `FOS_PICKFOLDERS`
    // — that's what hides files in the listing.
    final optsPtr = calloc<Uint32>();
    try {
      final getHr = dialog.getOptions(optsPtr);
      if (FAILED(getHr)) return null;
      final newOpts =
          optsPtr.value | FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST;
      dialog.setOptions(newOpts);
    } finally {
      free(optsPtr);
    }

    // Show the dialog — blocks until the operator picks or cancels.
    // `HWND_DESKTOP` (NULL) parents to the desktop; we don't have a
    // straightforward way to grab Flutter's HWND from Dart, so the
    // dialog floats free.  Functional, just not modal-to-Flutter.
    final showHr = dialog.show(NULL);
    if (FAILED(showHr)) return null;

    // `GetFolder()` returns the directory the dialog is currently
    // VIEWING (regardless of the filename in the text box) — exactly
    // the semantic we want.  Returns an IShellItem; we extract the
    // file-system path via `SIGDN_FILESYSPATH`.
    final folderItemPtr = calloc<COMObject>();
    try {
      final getFolderHr = dialog.getFolder(folderItemPtr.cast());
      if (FAILED(getFolderHr)) return null;
      final folderItem = IShellItem(folderItemPtr);
      final pathPtrPtr = calloc<Pointer<Utf16>>();
      try {
        final dispHr =
            folderItem.getDisplayName(SIGDN_FILESYSPATH, pathPtrPtr);
        if (FAILED(dispHr)) return null;
        final path = pathPtrPtr.value.toDartString();
        // The shell allocates this string via CoTaskMemAlloc; we own
        // freeing it.
        CoTaskMemFree(pathPtrPtr.value);
        return path;
      } finally {
        free(pathPtrPtr);
      }
    } finally {
      free(folderItemPtr);
    }
  } finally {
    CoUninitialize();
  }
}
