<?hh

function mod_intmin(int $value): int {
  return $value % (-9223372036854775807 - 1);
}

<<__EntryPoint>>
function main(): void {
  $inputs = vec[
    -9223372036854775807 - 1,
    -9223372036854775807,
    -123456789,
    -1,
    0,
    1,
    123456789,
    9223372036854775807,
  ];

  for ($round = 0; $round < 20000; $round++) {
    foreach ($inputs as $value) {
      $actual = mod_intmin($value);
      if ($round === 19999) {
        echo $value." => ".$actual."\n";
      }
    }
  }
}
