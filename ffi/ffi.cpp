#include <ffi_platypus_bundle.h>
#include <unistd.h>
#include <stdio.h>
#include <rtmidi_c.h>

#ifdef __MINGW32__
#include <windows.h>
#include <fcntl.h>
#define pipe(fds) _pipe( fds, 1024, _O_BINARY )
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int fd;
} _cb_descriptor;

void _callback( double deltatime, const unsigned char *message, size_t size, _cb_descriptor *data ) {
    if( size < 1 ) {
        return;
    }
    write( data->fd, message, size );
}

RTMIDIAPI
int callback_fd( RtMidiInPtr device ) {
    int pipefd[2], err;
    err = pipe(pipefd);
    if ( err < 0 ) {
        exit( err );
    }
    _cb_descriptor *data = (_cb_descriptor*)malloc( sizeof( _cb_descriptor ) );
    data->fd = pipefd[1];

    rtmidi_in_set_callback( device, (RtMidiCCallback)&_callback, data );

    fcntl( pipefd[0], F_SETFL, O_NONBLOCK );
    return pipefd[0];
}

RTMIDIAPI
void _free_userdata( RtMidiInPtr device ) {
    free( device->data );
}

#ifdef __cplusplus
}
#endif


