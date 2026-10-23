// ezmcp.stdin: up to `max` bytes from file descriptor 0, as one read(2)
// returns them: Done of the bytes (empty at the end of input) or
// Fail{(errno, strerror(errno))}. Reading the descriptor itself, not
// /dev/stdin, works whatever stdin is: a pipe, a file, a terminal or a
// socket (Node spawns children with socket pairs, and opening /dev/stdin on
// a socket fails with ENXIO). The read runs on an IO helper thread, as Base's
// file effects do.

static void ezmcp_stdin_call(IoWork* w) {
  w->size = io_sys_end(w, read(0, w->data, w->word));
}

static Term ezmcp_stdin_pack(Env e, IoWork* w) {
  Term r = io_res(e, w, io_list(e, w->data, w->size));
  free(w->data);
  return r;
}

Term ezmcp_stdin_run(Env e, Term* f, IoWork* w) {
  u64 max = f[0];
  w->word = max < INT32_MAX ? max : INT32_MAX;
  w->data = io_mem(malloc(w->word + 1));
  return io_work(w, ezmcp_stdin_call, ezmcp_stdin_pack);
}

static void __attribute__((constructor)) ezmcp_stdin_use(void) {
  io_eff(CID(ezmcp.stdin), ezmcp_stdin_run);
}
