#include <ffi_platypus_bundle.h>
#include <unistd.h>
#include <stdio.h>
#include <rtmidi_c.h>
#include <fcntl.h>

#ifdef __MINGW32__
#include <winsock2.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int fd;
} _cb_descriptor;

void _callback( double deltatime, const char *message, size_t size, _cb_descriptor *data ) {
    if( size < 1 ) {
        return;
    }

#ifdef __MINGW32__

    int total = 0;
    int remains = size;
    while ( total < size ) {
        int sent = send( data->fd, message + total, remains, 0 );
        if ( sent < 0 ) {
            fprintf(stderr, "socket error\n");
            exit(668);
        }
        remains -= sent;
        total += sent;
    }

#else

    write( data->fd, message, size );

#endif
}

RTMIDIAPI
int callback_fd( RtMidiInPtr device, int fd ) {

    _cb_descriptor *data = (_cb_descriptor*)malloc( sizeof( _cb_descriptor ) );
    int pipefd[2] = { 0, 0 };

#ifdef __MINGW32__

    if ( fd <= 0 ) {
        fprintf(stderr, "fd parameter required on win32\n");
        exit(666);
    }

    fd = _get_osfhandle( fd );
    if ( fd <= 0 ) {
        fprintf(stderr, "Unable to retrieve SOCKET for passed fd\n");
        exit(667);
    }

    data->fd = fd;

#else

    if ( pipe(pipefd) < 0 ) {
        fprintf(stderr, "Cannot create pipe!\n");
        exit(1);
    }
    fcntl( pipefd[0], F_SETFL, O_NONBLOCK );
    data->fd = pipefd[1];

#endif

    rtmidi_in_set_callback( device, (RtMidiCCallback)&_callback, data );

    return pipefd[0];
}

RTMIDIAPI
void _free_userdata( RtMidiInPtr device ) {

    free( device->data );
}

#ifdef __cplusplus
}
#endif


