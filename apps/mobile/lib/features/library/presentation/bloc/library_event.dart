sealed class LibraryEvent {
  const LibraryEvent();
}

class LibraryStarted extends LibraryEvent {
  const LibraryStarted();
}

class LibraryRefreshed extends LibraryEvent {
  const LibraryRefreshed();
}
