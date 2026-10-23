// ezmcp.stdin: the JS lane's twin of stdin.c, and the same answer: up to
// `max` bytes from file descriptor 0 as one read returns them, empty at the
// end of input, or the errno.

function ezmcp_stdin(max) {
  const sys = io_sys();
  const len = Math.min(max, 2147483647);
  const b = new Uint8Array(Math.max(len, 1));
  const n = Number(sys.read(0, sys.ptr(b), len));
  return n < 0 ? io_fail(sys.errno()) : io_done(io_list(b, n));
}

io_eff(CID(ezmcp.stdin), ezmcp_stdin);
