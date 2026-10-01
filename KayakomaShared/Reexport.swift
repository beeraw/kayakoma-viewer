// The only copy of the rendering engine in the app bundle: the app and the
// Quick Look extension link this framework instead of the KayakomaKit package,
// which would otherwise be linked statically into each of their binaries.
@_exported import KayakomaKit
