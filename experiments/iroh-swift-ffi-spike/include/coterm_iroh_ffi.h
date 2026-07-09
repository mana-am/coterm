// Minimal C FFI over iroh for the coterm mobile transport spike.
// See rust/src/lib.rs for semantics. All blocking; call off the main thread.

#ifndef COTERM_IROH_FFI_H
#define COTERM_IROH_FFI_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct CotermIrohEndpoint CotermIrohEndpoint;
typedef struct CotermIrohConnection CotermIrohConnection;

CotermIrohEndpoint *coterm_iroh_endpoint_bind(
    bool enable_relay,
    bool accept_connections,
    char *err_buf,
    size_t err_cap);

char *coterm_iroh_endpoint_id(const CotermIrohEndpoint *endpoint);

char *coterm_iroh_endpoint_route_json(const CotermIrohEndpoint *endpoint);

int coterm_iroh_endpoint_online(
    CotermIrohEndpoint *endpoint,
    uint64_t timeout_ms,
    char *err_buf,
    size_t err_cap);

CotermIrohConnection *coterm_iroh_endpoint_accept(
    CotermIrohEndpoint *endpoint,
    uint64_t timeout_ms,
    char *err_buf,
    size_t err_cap);

CotermIrohConnection *coterm_iroh_endpoint_connect(
    CotermIrohEndpoint *endpoint,
    const char *endpoint_id,
    const char *relay_url,
    const char *const *direct_addrs,
    size_t direct_addr_count,
    uint64_t timeout_ms,
    char *err_buf,
    size_t err_cap);

intptr_t coterm_iroh_connection_recv(
    CotermIrohConnection *connection,
    uint8_t *buf,
    size_t cap,
    char *err_buf,
    size_t err_cap);

int coterm_iroh_connection_send(
    CotermIrohConnection *connection,
    const uint8_t *bytes,
    size_t len,
    char *err_buf,
    size_t err_cap);

void coterm_iroh_connection_close(CotermIrohConnection *connection);

void coterm_iroh_endpoint_close(CotermIrohEndpoint *endpoint);

void coterm_iroh_string_free(char *string);

#ifdef __cplusplus
}
#endif

#endif // COTERM_IROH_FFI_H
