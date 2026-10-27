<?hh

<<__EntryPoint>>
function main(): void {
  \file_put_contents('/tmp/hhvm-victim-uid', (string)\posix_geteuid());
  for ($i = 0; $i < 1200; $i++) {
    \usleep(100000);
  }
}

