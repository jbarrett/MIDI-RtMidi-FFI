#include <ffi_platypus_bundle.h>
#include <fcntl.h>
#include <stdio.h>
#include <rtmidi_c.h>

#ifdef __MINGW32__
#define pipe(fds) _pipe(fds, 1024, _O_BINARY)
#endif

//int callback_fd( void *device ) {
int callback_fd( const char* foo ) {
    printf( "%s : %s\n", rtmidi_get_version(), foo );
}
