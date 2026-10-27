<?hh

function send_request(resource $socket, int $seq, string $command, dict<string, mixed> $arguments): void {
  $request = dict[
    'seq' => $seq,
    'type' => 'request',
    'command' => $command,
    'arguments' => $arguments,
  ];
  \fwrite($socket, (string)\json_encode($request)."\0");
}

<<__EntryPoint>>
function main(): void {
  $errno = 0;
  $error = '';
  $socket = \stream_socket_client(
    'unix:///tmp/hhvm-vsdebug.sock',
    inout $errno,
    inout $error,
    5.0,
  );
  if ($socket === false) {
    throw new \Exception('connect failed: '.$error);
  }
  \stream_set_blocking($socket, false);

  send_request($socket, 1, 'initialize', dict['clientID' => 'cross-user-proof']);
  \usleep(200000);
  send_request($socket, 2, 'attach', dict['displayConsoleStartupMsg' => false]);
  \usleep(500000);
  send_request($socket, 3, 'configurationDone', dict[]);
  \usleep(500000);
  send_request(
    $socket,
    4,
    'evaluate',
    dict[
      'expression' => "\\file_put_contents('/tmp/hhvm-cross-user-proof', 'executed-as-uid='.(string)\\posix_geteuid())",
      'context' => 'repl',
    ],
  );

  $buffer = '';
  $deadline = \microtime(true) + 10.0;
  while (\microtime(true) < $deadline) {
    $chunk = \fread($socket, 65536);
    if ($chunk !== false && $chunk !== '') {
      $buffer .= $chunk;
      foreach (\explode("\0", $buffer) as $message) {
        if ($message === '') continue;
        $decoded = \json_decode($message, true);
        if (\is_array($decoded) &&
            ($decoded['type'] ?? null) === 'response' &&
            ($decoded['request_seq'] ?? null) === 4) {
          $success = ($decoded['success'] ?? false) === true;
          echo 'evaluate_success='.($success ? 'true' : 'false')."\n";
          echo $message."\n";
          return;
        }
      }
    }
    \usleep(100000);
  }
  echo "evaluate_success=false\n";
  echo $buffer."\n";
  throw new \Exception('timed out waiting for evaluate response');
}

