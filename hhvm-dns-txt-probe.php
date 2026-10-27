<?hh

<<__EntryPoint>>
function main(): void {
  $groom = vec[];
  for ($i = 0; $i < 20000; $i++) {
    $groom[] = str_repeat(chr(74 + ($i % 10)), 248);
  }
  unset($groom);

  $authns = null;
  $additional = null;
  $records = dns_get_record(
    'multi-string.test',
    DNS_TXT,
    inout $authns,
    inout $additional,
  );
  if ($records === false || count($records) !== 1) {
    throw new Exception('Expected exactly one TXT response');
  }

  $txt = $records[0]['txt'];
  $expected = '';
  for ($letter = 65; $letter < 73; $letter++) {
    $expected .= str_repeat(chr($letter), 30);
  }

  echo 'expected_length='.strlen($expected)."\n";
  echo 'actual_length='.strlen($txt)."\n";
  echo 'matches_expected='.(($txt === $expected) ? 'true' : 'false')."\n";
  echo 'actual_hex='.bin2hex($txt)."\n";

  $gaps = vec[30, 61, 92, 123, 154, 185, 216];
  foreach ($gaps as $gap) {
    echo 'gap['.$gap.']='.ord($txt[$gap])."\n";
  }
}
