# Threaded Upload

Worker threads create buffers and textures and upload through the queue while
the main thread renders. It doubles as a live stress test for the backend's
thread safety: every validation error is counted and traps at shutdown.

Native only: it uses `core:thread` and is not part of the web showcase.
